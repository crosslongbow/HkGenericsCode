unit HkGenericsCode;

{$include 'DelphiVersions.inc'}

interface

uses
  {$IFDEF HAS_UNIT_SCOPE}
  System.Classes, Winapi.Windows,
  {$ELSE}
  Classes, Windows, TypInfo,
  {$ENDIF HAS_UNIT_SCOPE}
  HkGenericsTypes, HkGenericsData, HkGenericsClasses, HkGenericsComparer,
  HashFuncs;

type
  (*
   * 参考：https://blog.synopse.info/?post/2016/01/09/Safe-locks-for-multi-thread-applications
   * 收录在：TCriticalSection @同步与安全 @多线程 @Delphi
   * - TRTLCriticalSection是Record，比TCriticalSection稍轻便一点。
   * - TFixedCriticalSection在编译时总会引起一个警告。
   *
   * 使用时，必须先设置：THkRtlCS.Enabled := TRUE | FALSE
   * 释放时：THkRtlCS.Delete
   *)
  THkRtlCS = Record
  private
    FDummy: array[0..11] of int64; // 第一位用于保存Enabled，其余11位可用
    FRtlCS: TRTLCriticalSection;
    function GetBoolean(Index: integer): boolean;
    function GetEnabled: boolean;
    function GetInteger(Index: integer): integer;
    function GetNativeInt(Index: integer): NativeInt;
    function GetObject(Index: integer): TObject;
    function GetPointer(Index: integer): Pointer;
    procedure SetBoolean(Index: integer; Value: boolean);
    procedure SetEnabled(Value: boolean);
    procedure SetInteger(Index: integer; Value: integer);
    procedure SetNativeInt(Index: integer; Value: NativeInt);
    procedure SetObject(Index: integer; Value: TObject);
    procedure SetPointer(Index: integer; Value: Pointer);
  public
    constructor Create(Enabled: boolean);

    procedure Delete;
    procedure Enter;
    procedure Leave;

    property Enabled: boolean read GetEnabled write SetEnabled;
    property B[Index: integer]: boolean read GetBoolean write SetBoolean;
    property I[Index: integer]: integer read GetInteger write SetInteger;
    property N[Index: integer]: NativeInt read GetNativeInt write SetNativeInt;
    property O[Index: integer]: TObject read GetObject write SetObject;
    property P[Index: integer]: Pointer read GetPointer write SetPointer;
  end;

type
  IHkGenericsPLQS<T> = interface
    ['{BB0FA3A7-85D3-4423-B3FE-961DC9B2D760}']
    function GetCapacity: integer;             // 当前容量
    function GetCount: integer;                // 已分配项目数量
    function GetInitCapacity: integer;         // 初始容量

    function GetElementKind: TTypeKind;        // 元素类型
    function GetElementSize: integer;          // 元素大小

    procedure ExportValue(Src: Pointer; var Value: T); // 赋值给外部变量(派生接口使用)
    function GetDataItem(ExtraItem: Pointer): Pointer; // 根据附加数据指针读取用户数据
    function GetExtraItem(Item: Pointer): Pointer;     // 读取附加数据指针
    function GetFirst: Pointer;                // 读取第一个记录
    function GetLast: Pointer;                 // 读取最后一个记录
    function GetNext(CurrentItem: Pointer): Pointer;   // 读取下一个记录
    function GetPrev(CurrentItem: Pointer): Pointer;   // 读取上一个记录
    function PeekFirst(var Value: T): boolean;
    function PeekLast(var Value: T): boolean;

    function Add(const Value: T): Pointer;     // List模式：添加新项目
    function Dequeue(var Value: T): boolean;   // Queue模式：取出项目(移除)
    function Enqueue(const Value: T): boolean; // Queue模式：添加新项目
    function Get: Pointer;                     // Pool模式：申请内存
    function Pop(var Value: T): boolean;       // Stack模式：取出项目(移除)
    function Push(const Value: T): boolean;    // Stack模式：添加新项目
    procedure Put(Item: Pointer);              // Pool模式：归还内存
    procedure Remove(Item: Pointer);           // List模式：移除项目

    // for..in只提供对已分配空间的遍历，未分配空间是无法访问的
    function GetCurrent: Pointer;               // for..in
    function GetEnumerator: IHkGenericsPLQS<T>; // for..in
    function MoveNext: boolean;                 // for..in

    procedure Clear;                           // 清空并回收已分配的内存
    function GetItem(Index: integer): Pointer; // 顺序读取(速度慢，慎用)
    // 2021.06.08
    // 缺省状态只清理已分配的节点。池模式下，回收的节点可能也需要释放资源。
    // 该参数只影响Cleanup函数，即只在退出OnRelease时有效
    procedure SetClearAllNode(Value: boolean);
    procedure SetClearItemBeforePut(Value: boolean); // 回收时内存块置零
    // 2021.09.23
    // 缺省状态下回收的节点是放在空闲列表的头部，也就是优先使用被分配过的节点。
    // 在某些情况下可能需要平均使用每个节点，所以回收的节点会放到空闲列表的尾部。
    // 缺省值是放在空闲列表的头部。该选项不影响外部使用，可以在任何时候修改。
    // 注意：该选项不能和以前版本的延迟分配方法一起使用(需要完整的链表)。
    procedure SetUseAllocatedNodeFirst(Value: boolean);

    //procedure SetOnChanged(Value: TNotifyEvent);

    property Capacity: integer read GetCapacity;
    property ClearAllNode: boolean write SetClearAllNode;
    property ClearItemBeforePut: boolean write SetClearItemBeforePut;
    property Count: integer read GetCount;
    property Current: Pointer read GetCurrent; // for..in
    property ElementKind: TTypeKind read GetElementKind;
    property ElementSize: integer read GetElementSize;
    property First: Pointer read GetFirst;
    property InitCapacity: integer read GetInitCapacity;
    property Item[Index: integer]: Pointer read GetItem;
    property Last: Pointer read GetLast;
    property Next[CurrentItem: Pointer]: Pointer read GetNext;
    //property OnChanged: TNotifyEvent write SetOnChanged;
    property Prev[CurrentItem: Pointer]: Pointer read GetPrev;
    property UseAllocatedNodeFirst: boolean write SetUseAllocatedNodeFirst;
  end;

  THkGenericsPLQS<T> = class(TInterfacedObject, IHkGenericsPLQS<T>)
  private
    FActionClass: THkActionClass;
    FClearAllNode: boolean;                    // 清理所有已分配和已回收的节点。缺省是只清理已分配节点
    FElementKind: TTypeKind;
    FLinkedList: THkLinkedList;                // 内部链表
    function AddItem(const Value: T): Pointer;
    procedure Cleanup;
    procedure _Cleanup(Item: Pointer);
    function _Init(Capacity, MaxCapacity: integer; HeapHandle: THandle;
      LockType: THkLockType; ExtraSize: integer): integer;
  private
    FLock: THkRtlCS;
  private                                      // IHkGenericsPLQS<T>
    function GetCapacity: integer;             // 当前容量
    function GetCount: integer;                // 已分配项目数量
    function GetElementKind: TTypeKind;        // 元素类型
    function GetElementSize: integer;          // 元素大小
    function GetInitCapacity: integer;         // 初始容量
    function GetItem(Index: integer): Pointer; // 顺序读取(速度慢，慎用)
    function GetFirst: Pointer;                // 读取第一个记录
    function GetLast: Pointer;                 // 读取最后一个记录
    function GetNext(CurrentItem: Pointer): Pointer;   // 读取下一个记录
    function GetPrev(CurrentItem: Pointer): Pointer;   // 读取上一个记录
    procedure SetClearAllNode(Value: boolean);
    procedure SetClearItemBeforePut(Value: boolean); // 回收时内存块置零
    procedure SetUseAllocatedNodeFirst(Value: boolean); // 优先使用分配过的节点
  private                                      // IHkGenericsPLQS<T>
    FCurrentItem: Pointer;
    function GetCurrent: Pointer;               // for..in
    function GetEnumerator: IHkGenericsPLQS<T>; // for..in
    function MoveNext: boolean;                 // for..in
  public                                       // IHkGenericsPLQS<T>
    function Add(const Value: T): Pointer;     // List模式：添加新项目
    procedure Clear;                           // 清空并回收已分配的内存
    function Dequeue(var Value: T): boolean;   // Queue模式：取出项目(移除)
    function Enqueue(const Value: T): boolean; // Queue模式：添加新项目
    procedure ExportValue(Src: Pointer; var Value: T); // 赋值给外部变量(派生接口使用)
    function Get: Pointer;                     // Pool模式：申请内存
    function GetDataItem(ExtraItem: Pointer): Pointer; // 根据附加数据指针读取用户数据
    function GetExtraItem(Item: Pointer): Pointer;     // 读取附加数据指针
    function PeekFirst(var Value: T): boolean;
    function PeekLast(var Value: T): boolean;
    function Pop(var Value: T): boolean;       // Stack模式：取出项目(移除)
    function Push(const Value: T): boolean;    // Stack模式：添加新项目
    procedure Put(Item: Pointer);              // Pool模式：归还内存
    procedure Remove(Item: Pointer);           // List模式：移除项目
  public
    constructor Create(
      ActionEvent: THkActionEventA;
      Capacity: integer = 64;
      MaxCapacity: integer = 0;
      HeapHandle: THandle = INVALID_HANDLE_VALUE;
      LockType: THkLockType = lktNone;
      ExtraSize: integer = 0); overload;
    constructor Create(
      ActionEvent: THkActionEventC;
      Capacity: integer = 64;
      MaxCapacity: integer = 0;
      HeapHandle: THandle = INVALID_HANDLE_VALUE;
      LockType: THkLockType = lktNone;
      ExtraSize: integer = 0); overload;
    constructor Create(
      ActionEvent: THkActionEventG;
      Capacity: integer = 64;
      MaxCapacity: integer = 0;
      HeapHandle: THandle = INVALID_HANDLE_VALUE;
      LockType: THkLockType = lktNone;
      ExtraSize: integer = 0); overload;
    constructor Create(
      Capacity: integer = 64;
      MaxCapacity: integer = 0;
      HeapHandle: THandle = INVALID_HANDLE_VALUE;
      LockType: THkLockType = lktNone;
      ExtraSize: integer = 0); overload;
    destructor Destroy; override;
  end;

type
  (*
   *****************************************************************************
   * 比较器
   *
   * IHkStdList和IHkGenericsPLQS的区别在于前者是可内部查找的列表。如果无需内部查
   * 找，两者之间的唯一区别就是前者提供了序号和Insert/Exchange函数，可以自由设置
   * 和访问列表项目。所以如果是无序列表，建议优先使用IHkGenericsPLQS。
   *
   * 只要是需要查找，都需要比较器。
   * 之前在CustomSort函数里，自定义排序后就恢复原有比较器是有问题的。因为排序和
   * 查找应该使用同一个比较器，否则采用二分法的查找函数可能会得出错误的结果。
   *
   * 如果列表需要多种排序配置，就要使用不同的比较器，有两种方法：
   * 1. 设置第一第二比较器和主比较器，后者是前两者的引用。第一比较器是列表的主比
   *    较器，第二比较器是临时比较器。需要做临时排序时，保存第一比较器状态，切换
   *    到第二比较器，之后按需恢复第一比较器；
   * 2. 只设一个比较器，根据需要由外部设置，切换时设为无序，由外部重新排序。
   * 当然选择方法2...逻辑比较简单。
   *
   * 总结：
   * 1. IHkStdList接口可以没有比较器实例，用于不排序列表
   * 2. 比较器实例只有一个，通过接口设置，支持匿名函数/类函数/全局函数
   * 3. 切换比较器时，将设置Sorted=FALSE，需要外部安排重新排序
   * 4. 比较器和Sorted属性无关联，除了情况3下互不影响
   *****************************************************************************
   *)

  IHkStdList<T> = interface
    ['{94A5BD4E-A232-4194-9A9A-209A17B96C4B}']
    function Add(const Value: T): integer; overload;
    function Add(const Value: T; out Item: Pointer): integer; overload;
    procedure Clear; overload;
    procedure Clear(ClearEvent: THkActionEventA); overload;
    procedure Clear(ClearEvent: THkActionEventC); overload;
    procedure Clear(ClearEvent: THkActionEventG); overload;
    // 多线程下读取指针可能不安全(通过指针读取值是不同的锁)，所以用多态输出指针
    // 或值。当元素是Pointer时，原有Contains函数参数存在歧义，可能会产生混乱，
    // 希望调用后者返回值，实际却调用了前者
    // 所以从HkGenericsCode开始采用不同的格式
    // 后面的Hash列表同理
    function Contains(const Key: array of const): Pointer; overload;
    function Contains(var Value: T; const Key: array of const): boolean; overload;
    procedure Exchange(Index1, Index2: Integer);
    function Get(Index: integer): Pointer;
    function GetCount: integer;
    function GetRawList: IHkGenericsPLQS<T>;
    function GetSorted: boolean;
    function GetText: string;
    function GetValue(Index: integer; var Value: T): boolean; overload;
    function GetValue(Item: Pointer; var Value: T): boolean; overload;
    function IndexOf(Item: Pointer): integer; overload;
    function IndexOf(const Key: array of const): integer; overload;
    function IndexOf(const Value: T): integer; overload;
    function Insert(Index: integer; const Value: T): Pointer;
    procedure LoadFromFile(const FileName: string; OnSetText: TSetTextEvent);
    procedure Move(CurIndex, NewIndex: Integer);
    procedure Remove(const Key: array of const); overload;
    procedure Remove(Index: integer); overload;
    procedure Remove(Item: Pointer); overload;
    function Remove(var Value: T; const Key: array of const): boolean; overload;
    procedure Reset;
    procedure SaveToFile(const FileName: string);
    procedure SetCaseSensitive(Value: boolean);
    procedure SetComparer(Value: THkComparerA); overload;
    procedure SetComparer(Value: THkComparerC); overload;
    procedure SetComparer(Value: THkComparerG); overload;
    procedure SetKeyIndex(Value: integer);
    procedure SetSorted(Value: boolean);
    procedure SetText(const Value: string; OnSetText: TSetTextEvent);
    procedure Sort;
    //procedure Sort(Comparer: THkComparerA; ReleaseComparer: boolean = TRUE); overload;
    //procedure Sort(Comparer: THkComparerG; ReleaseComparer: boolean = TRUE); overload;
    //procedure Sort(KeyIndex: integer; ReleaseComparer: boolean = TRUE); overload;
    function TryAdd(const Value: T; out Item: Pointer): boolean;

    function GetCurrent: Pointer;              // for..in
    function GetEnumerator: IHkStdList<T>;     // for..in
    function MoveNext: boolean;                // for..in

    property CaseSensitive: boolean write SetCaseSensitive;
    property Comparer: THkComparerA write SetComparer;
    property Comparer: THkComparerC write SetComparer;
    property Comparer: THkComparerG write SetComparer;
    property Count: integer read GetCount;
    property Current: Pointer read GetCurrent; // for..in
    property Item[Index: integer]: Pointer read Get; default;
    property KeyIndex: Integer Write SetKeyIndex;
    property RawList: IHkGenericsPLQS<T> read GetRawList;
    property Sorted: boolean read GetSorted write SetSorted;
    property Text: string read GetText;
  end;

  // 2021.11.17
  // 重新设计比较器，具体见上面接口部分
  //
  THkStdList<T> = class(TInterfacedObject, IHkStdList<T>)
  private
    FRawList: IHkGenericsPLQS<T>;              // 原始数据列表
  private
    FComparer: THkCompareClass;                // 主比较器
    //FFirstComparer: THkCompareClass;           // 第一比较器
    //FSecondComparer: THkCompareClass;          // 第二比较器
    FSorted: boolean;
  private
    FCaseSensitive: boolean;                   // 指定Key的自定义排序需要使用
    FCount: integer;
    FList: TDynPointerArray;
    FLock: THkRtlCS;
    procedure _Init(const BindingList: IHkGenericsPLQS<T>; Sorted: boolean;
      LockType: THkLockType);
    function AddItem(const Value: T; out Item: Pointer): integer;
    procedure ExchangeItem(Index1, Index2: Integer);
    function Find(var Index: integer; const Value: T): Boolean; overload;
    function Find(var Index: integer; Item: Pointer): Boolean; overload;
    function Find(var Index: integer; const Key: array of const): Boolean; overload;
    function InsertItem(const Value: T; Index: integer): Pointer;
    procedure QuickSort(L, R: Integer; Comparer: THkCompareClass);
    procedure RemoveItem(Index: integer);
    procedure ReleaseComparer;
  private                                      // IHkStdList<T>
    function Get(Index: integer): Pointer;
    function GetCount: integer;
    function GetRawList: IHkGenericsPLQS<T>;
    function GetSorted: boolean;
    function GetText: string;
    procedure SetCaseSensitive(Value: boolean);
    procedure SetComparer(Value: THkComparerA); overload;
    procedure SetComparer(Value: THkComparerC); overload;
    procedure SetComparer(Value: THkComparerG); overload;
    procedure SetKeyIndex(Value: integer);
    procedure SetSorted(Value: boolean);
  private                                      // IHkStdList<T>
    FCurrent: integer;                         // for..in
    function GetCurrent: Pointer;              // for..in
    function GetEnumerator: IHkStdList<T>;     // for..in
    function MoveNext: boolean;
  public                                       // IHkStdList<T>
    function Add(const Value: T): integer; overload;
    function Add(const Value: T; out Item: Pointer): integer; overload;
    procedure Clear; overload;
    procedure Clear(ClearEvent: THkActionEventA); overload;
    procedure Clear(ClearEvent: THkActionEventC); overload;
    procedure Clear(ClearEvent: THkActionEventG); overload;
    function Contains(const Key: array of const): Pointer; overload;
    function Contains(var Value: T; const Key: array of const): boolean; overload;
    procedure Exchange(Index1, Index2: Integer);
    function GetValue(Index: integer; var Value: T): boolean; overload;
    function GetValue(Item: Pointer; var Value: T): boolean; overload;
    function IndexOf(Item: Pointer): integer; overload;
    function IndexOf(const Key: array of const): integer; overload;
    function IndexOf(const Value: T): integer; overload;
    function Insert(Index: integer; const Value: T): Pointer;
    procedure LoadFromFile(const FileName: string; OnSetText: TSetTextEvent);
    procedure Move(CurIndex, NewIndex: Integer);
    procedure Remove(const Key: array of const); overload;
    procedure Remove(Index: integer); overload;
    procedure Remove(Item: Pointer); overload;
    function Remove(var Value: T; const Key: array of const): boolean; overload;
    procedure Reset;
    procedure SaveToFile(const FileName: string);
    procedure SetText(const Value: string; OnSetText: TSetTextEvent);
    procedure Sort;
    //procedure Sort(Comparer: THkComparerA; ReleaseComparer: boolean = TRUE); overload;
    //procedure Sort(Comparer: THkComparerG; ReleaseComparer: boolean = TRUE); overload;
    //procedure Sort(KeyIndex: integer; ReleaseComparer: boolean = TRUE); overload;
    function TryAdd(const Value: T; out Item: Pointer): boolean;
  public
    constructor Create(                        // 基础函数，使用内部比较器
      const BindingList: IHkGenericsPLQS<T>;
      Sorted: boolean = FALSE;
      KeyIndex: integer = 0;                   // 等于-1时表示有多个Key
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // 匿名比较函数
      const BindingList: IHkGenericsPLQS<T>;
      ItemComparer: THkComparerA;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // 类比较函数
      const BindingList: IHkGenericsPLQS<T>;
      ItemComparer: THkComparerC;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // 全局比较函数
      const BindingList: IHkGenericsPLQS<T>;
      ItemComparer: THkComparerG;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // 自带IHkBasePLQS，使用内部比较器
      Capacity: integer = 64;
      Sorted: boolean = FALSE;
      KeyIndex: integer = 0;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // 自带IHkBasePLQS，使用匿名比较函数
      Capacity: integer;
      ItemComparer: THkComparerA;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // 自带IHkBasePLQS，使用类比较函数
      Capacity: integer;
      ItemComparer: THkComparerC;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // 自带IHkBasePLQS，使用全局比较函数
      Capacity: integer;
      ItemComparer: THkComparerG;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    destructor Destroy; override;
  end;

type
  // Hash的问题是不能记录序号，因为列表序号会变动，而且是大批量的变动。一旦变动
  // 就要全部重新计算。所以Hash列表不能提供序号存取。
  // IHkHashedList支持的数据类型较少：CN_Key_Kind + tkRecord。
  // 如果是Record，Key数据必须只有1个且符合CN_Key_Kind。
  // 和IHkStdList不同的是，Key同时用于计算哈希和比较，所以，不需要外部比较函数，
  // 而且字符串的大小写敏感需要注意。
  // 大小写敏感：字符串不能使用源字符串，要将其转换为全小写或全大写，然后对转换
  // 后的字符串进行哈希处理，所以，在接口内部设置缓冲区存储转换后的字符串。
  //
  // 2020.02.25
  // 参考：哈希桶长度的选择.md(Tech\Develop\Delphi\算法\哈希表)
  // 按Java HashMap的做法，桶容量是2的幂，计算Index值不用取模运算，采用位运算，
  // 运算值是桶长度-1
  //
  // 多线程下不要使用指针，而是读取数据的副本。
  //
  // 2020.04.12
  // 对于整数，哈希算法采用直接取余法。常用的还有：乘积取整法和平方取中法。
  // 一般直接取余法分母采用素数，这里采用桶容量。
  //
  // 2021.02.08
  // 同IHkStdList(2021.01.11)，增加对数据指针的支持。该需求首次出现在IHkTree。
  // 外部函数搜索元素时，采用Key/Index。如果外部函数只有元素数据指针，而且无法处
  // 理Key(比如派生类)，现有方法无法处理。所以增加接口对元素数据指针的支持
  //
  // 2021.05.11
  // 哈希列表只能使用内部函数，所以支持的数据类型比较少，比如说指针。
  // 既然Key同时用于计算哈希值和比较，如果外部函数能同时提供两项功能就可以解决。
  // 1. 比较函数，参考IHkStdList
  // 2. 哈希计算函数
  //
  // 2021.05.20
  // 哈希链表使用整数作为Key时，有一个特殊的情况，就是顺序增长的整数序列。比如
  // DnsHub里的Session列表。因为该列表是顺序增长且循环使用，所以哈希桶容量设置为
  // 列表的长度，没有数据冗余，哈希的计算和取模两个步骤可以合一，直接使用AND操作，
  // 非常快。
  // 内部整数的通用设计需要指定取余操作的整数值，速度会慢一些。所以对于上述的情
  // 况，使用外部函数来处理。
  // 即：整数作为哈希Key时，内部不支持，必须使用外部函数

  IHkHashedList<T> = interface
    ['{5FF4AAE1-6996-4475-AE9C-9ED0F1C242C0}']
    function Add(const Value: T): Pointer; overload;
    function Add(const Value: T; out Hash: Cardinal): Pointer; overload;
    procedure Clear; overload;
    procedure Clear(ClearEvent: THkActionEventA); overload;
    procedure Clear(ClearEvent: THkActionEventC); overload;
    procedure Clear(ClearEvent: THkActionEventG); overload;
    function Contains(Item: Pointer): boolean; overload;
    function Contains(const Key: array of const): Pointer; overload;
    function Contains(var Value: T; const Key: array of const): boolean; overload;
    function GetBucketSize: integer;
    function GetCount: integer;
    //function GetHashFunc: TOnHashFunc;
    function GetRawList: IHkGenericsPLQS<T>;
    procedure Remove(Item: Pointer); overload;
    procedure Remove(const Key: array of const); overload;
    function Remove(var Value: T; const Key: array of const): boolean; overload;
    procedure Reset;
    procedure SetCaseSensitive(Value: boolean);

    //function GetBucket: PBucketDynArray;     // 用于统计数据(冲突/链表长度)

    //property Bucket: PBucketDynArray read GetBucket;
    property BucketSize: integer read GetBucketSize;
    property CaseSensitive: boolean write SetCaseSensitive;
    property Count: integer read GetCount;
    //property HashFunc: TOnHashFunc read GetHashFunc;
    property RawList: IHkGenericsPLQS<T> read GetRawList;
  end;

  THkHashedList<T> = class(TInterfacedObject, IHkHashedList<T>)
  private
    FLock: THkRtlCS;
    FRawList: IHkGenericsPLQS<T>;              // 原始数据列表
  private
    FBucketSize: Cardinal;
    FComparer: THkCompareClass;
    FCount: integer;
    FHashBuckets: TDynBucketArray;             // 哈希桶
    FHashClass: THashClass;
    FZipPool: IHkGenericsPLQS<TOwlNode>;       // 拉链池，减少拉链法里申请释放链表节点内存的消耗
    procedure _Init(HashBucketSize: integer; LockType: THkLockType);
    procedure _InnerInit(KeyIndex: integer; HashFunc: TOnHashFunc);
    function AddHashItem(BucketIndex: integer; Item: Pointer): boolean;
    procedure ClearBucket;
    function Find(Item: Pointer; BucketIndex: integer;
      Remove: boolean = FALSE): Pointer; overload;
    function Find(const Key: array of const; BucketIndex: integer;
      Remove: boolean = FALSE): Pointer; overload;
    function GetBucketIndex(Item: Pointer; out Hash: Cardinal): integer; overload;
    function GetBucketIndex(const Key: array of const; out Hash: Cardinal): integer; overload;
    function GetBucketIndex(const Value: T; out Hash: Cardinal): integer; overload;
    function RemoveFromBucket(BucketIndex: integer; Prev, Node: POwlNode): Pointer;
    procedure SetHashBucketSize(Value: integer);
  private                                      // IHkHashedList<T>
    function GetBucketSize: integer;
    function GetCount: integer;
    function GetRawList: IHkGenericsPLQS<T>;
    procedure SetCaseSensitive(Value: boolean);
  public                                       // IHkHashedList<T>
    function Add(const Value: T): Pointer; overload;
    function Add(const Value: T; out Hash: Cardinal): Pointer; overload;
    procedure Clear; overload;
    procedure Clear(ClearEvent: THkActionEventA); overload;
    procedure Clear(ClearEvent: THkActionEventC); overload;
    procedure Clear(ClearEvent: THkActionEventG); overload;
    function Contains(Item: Pointer): boolean; overload;
    function Contains(const Key: array of const): Pointer; overload;
    function Contains(var Value: T; const Key: array of const): boolean; overload;
    procedure Remove(Item: Pointer); overload;
    procedure Remove(const Key: array of const); overload;
    function Remove(var Value: T; const Key: array of const): boolean; overload;
    procedure Reset;
  public
    constructor Create(                // 使用内部函数
      Capacity: integer = 64;
      KeyIndex: integer = 0;
      HashBucketSize: integer = 1024;
      HashFunc: TOnHashFunc = nil;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // 使用内部函数
      BindingList: IHkGenericsPLQS<T>;
      KeyIndex: integer = 0;
      HashBucketSize: integer = 1024;
      HashFunc: TOnHashFunc = nil;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // 使用外部全局函数
      BindingList: IHkGenericsPLQS<T>;
      HashEvent: THkHashEventG;
      Comparer: THkComparerG;
      HashBucketSize: integer = 1024;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // 使用外部类函数
      BindingList: IHkGenericsPLQS<T>;
      HashEvent: THkHashEventC;
      Comparer: THkComparerC;
      HashBucketSize: integer = 1024;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // 使用外部匿名函数
      BindingList: IHkGenericsPLQS<T>;
      HashEvent: THkHashEventA;
      Comparer: THkComparerA;
      HashBucketSize: integer = 1024;
      LockType: THkLockType = lktNone); overload;
    destructor Destroy; override;
  end;

type
  // 原HkCodeA的IHkMemoryBlock接口。
  // 提供大内存块，主要用于不定长数据(字符串)的存储，缺点是分配的空间无法收回。
  // 特殊使用，比如DnsHub项目里Log的存储。
  IHkMemoryStore = interface
    function Get(Size: integer; var P: PByte): boolean;
    function GetBlockCount: integer;
    function GetBlockSize: integer;
    function GetTotalSize: integer;
    procedure Reset;
    function TryToGet(Size: integer): boolean;

    property BlockCount: integer read GetBlockCount;
    property BlockSize: integer read GetBlockSize;
    property TotalSize: integer read GetTotalSize;
  end;

  // 2021.05.18，HkCodeD
  // THkMemoryStore使用THkMemoryBlock管理内存块链表。THkMemoryBlock的链表节点是
  // TSllPureNode，不带Data参数，无法在链表节点里保存已分配字节(原HkCodeC采用的
  // 方法)，所以在用户数据区里前4个字节保存已分配参数
  THkMemoryStore = class(TInterfacedObject, IHkMemoryStore)
  private
    FBlockCount: integer;                  // 块数量(链表长度)
    FBlockSize: integer;                   // 每个内存块的大小(用户申请)
    FHead: POwlNode;                       // 链表头节点，Data参数表示块已分配字节
    FFixed: boolean;                       // 固定大小
    FHeapHandle: THandle;
    procedure GetSpareBlock(Size: integer; var MB: POwlNode);
    function Grow: boolean;
  private
    function GetBlockCount: integer;
    function GetBlockSize: integer;
    function GetTotalSize: integer;
  public
    constructor Create(BlockSize: integer = 4096; Fixed: boolean = FALSE;
      HeapHandle: THandle = INVALID_HANDLE_VALUE);
    destructor Destroy; override;

    function Get(Size: integer; var P: PByte): boolean;
    procedure Reset;
    function TryToGet(Size: integer): boolean;
  end;

implementation

uses
  {$IFDEF HAS_UNIT_SCOPE}
  System.TypInfo, System.Rtti, System.SysUtils;
  {$ELSE}
  Rtti, SysUtils;
  {$ENDIF HAS_UNIT_SCOPE}

const
  // 支持批量输入的数据类型
  //CN_Batchable_Kind: set of TTypeKind = [tkInteger, tkWString, tkUString];
  // IHkStdList内部支持的数据类型(用于排序)，同时适用于IHkHashedList(用于计算哈希值)
  CN_Key_Kind: set of TTypeKind = [tkInteger, tkInt64, tkChar, tkWChar, tkLString,
    tkWString, tkUString];

// =============================================================================
//  THkGenericsPLQS<T>
// =============================================================================

constructor THkGenericsPLQS<T>.Create(ActionEvent: THkActionEventA; Capacity,
  MaxCapacity: integer; HeapHandle: THandle; LockType: THkLockType;
  ExtraSize: integer);
var
  ItemSize: integer;
begin
  inherited Create;

  if not Assigned(ActionEvent) then
    raise Exception.Create('No Valid Item Method!');

  ItemSize := _Init(Capacity, MaxCapacity, HeapHandle, LockType, ExtraSize);
  FActionClass := THkActionClassA.Create(ActionEvent, ItemSize, ExtraSize);
end;

constructor THkGenericsPLQS<T>.Create(ActionEvent: THkActionEventC; Capacity,
  MaxCapacity: integer; HeapHandle: THandle; LockType: THkLockType;
  ExtraSize: integer);
var
  ItemSize: integer;
begin
  inherited Create;

  if not Assigned(ActionEvent) then
    raise Exception.Create('No Valid Item Method!');

  ItemSize := _Init(Capacity, MaxCapacity, HeapHandle, LockType, ExtraSize);
  FActionClass := THkActionClassC.Create(ActionEvent, ItemSize, ExtraSize);
end;

constructor THkGenericsPLQS<T>.Create(ActionEvent: THkActionEventG; Capacity,
  MaxCapacity: integer; HeapHandle: THandle; LockType: THkLockType;
  ExtraSize: integer);
var
  ItemSize: integer;
begin
  inherited Create;

  if not Assigned(ActionEvent) then
    raise Exception.Create('No Valid Item Method!');

  ItemSize := _Init(Capacity, MaxCapacity, HeapHandle, LockType, ExtraSize);
  FActionClass := THkActionClassG.Create(ActionEvent, ItemSize, ExtraSize);
end;

constructor THkGenericsPLQS<T>.Create(Capacity, MaxCapacity: integer;
  HeapHandle: THandle; LockType: THkLockType; ExtraSize: integer);
var
  ItemSize: integer;
begin
  inherited Create;

  ItemSize := _Init(Capacity, MaxCapacity, HeapHandle, LockType, ExtraSize);
  FActionClass := THkActionClassI<T>.Create(ItemSize, ExtraSize, TRUE);
end;

destructor THkGenericsPLQS<T>.Destroy;
begin
  Cleanup;
  FLinkedList.Free;
  FActionClass.Free;

  inherited;
end;

function THkGenericsPLQS<T>._Init(Capacity, MaxCapacity: integer;
  HeapHandle: THandle; LockType: THkLockType; ExtraSize: integer): integer;
var
  ElementInfo: PTypeInfo;
begin
  ElementInfo := TypeInfo(T);
  FElementKind := ElementInfo.Kind;
  Result := SizeOf(T);

  FLinkedList := THkLinkedList.Create(Capacity, MaxCapacity, Result,
    ExtraSize, HeapHandle);
  FLock := THkRtlCS.Create(LockType = lktCS);
end;

function THkGenericsPLQS<T>.Add(const Value: T): Pointer;
begin
  FLock.Enter;
  try
    Result := AddItem(Value);
  finally
    FLock.Leave;
  end;
end;

function THkGenericsPLQS<T>.AddItem(const Value: T): Pointer;
begin
  if FLinkedList.RequireItem(Result) then
  begin
    FActionClass.AfterGet(Result);
    T(Result^) := Value;
    //THkElement<T>(Result^).Value := Value;
  end;
end;

procedure THkGenericsPLQS<T>._Cleanup(Item: Pointer);
begin
  while Item <> nil do
  begin
    FActionClass.OnRelease(Item);
    Item := FLinkedList.Next[Item];
  end;
end;

procedure THkGenericsPLQS<T>.Cleanup;
var
  Item: Pointer;
  ElementInfo: PTypeInfo;
  Managed: boolean;
begin
  // 如果用户数据不包含引用类型，无需处理
  ElementInfo := TypeInfo(T);
  Managed := IsManaged(ElementInfo);

  FLock.Enter;
  try
    if FActionClass.IsExtMethod or Managed then // 仅处理含引用类型且包含数据的节点
    begin
      Item := FLinkedList.Head;
      _Cleanup(Item);

      if FClearAllNode then // 清理已回收节点
      begin
        Item := FLinkedList.IdleHead;
        _Cleanup(Item);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

// 清空列表，回收所有已分配的内存块，未分配的不予处理
// 相当于客户端执行Put/Remove/Dequeue操作
// 1. 如果有外部函数，必须由外部函数执行
procedure THkGenericsPLQS<T>.Clear;
var
  Data: Pointer;
begin
  FLock.Enter;
  try
    // 所有已使用的节点全部置零
    // 2021.05.20
    // 之前没有考虑到列表为空的情况(FHead=nil)
    Data := FLinkedList.Head; // 本体清空用户数据区
    while Data <> nil do
    begin
      FActionClass.BeforePut(Data, TRUE); // 强制清零
      Data := FLinkedList.Next[Data];
    end;

    FLinkedList.Clear; // 清空链表
  finally
    FLock.Leave;
  end;
end;

// Queue模式，相当于Put/Remove
function THkGenericsPLQS<T>.Dequeue(var Value: T): boolean;
var
  Src: Pointer;
begin
  FLock.Enter;
  try
    Src := FLinkedList.Head;
    if Src <> nil then
    begin
      //Value := THkElement<T>(Src^).Value;
      Value := T(Src^);
      FActionClass.BeforePut(Src);
      FLinkedList.ReturnItem(Src);
      Result := TRUE;
    end
    else Result := FALSE;
  finally
    FLock.Leave;
  end;
end;

// Queue模式，相当于Get/Add
function THkGenericsPLQS<T>.Enqueue(const Value: T): boolean;
begin
  FLock.Enter;
  try
    Result := AddItem(Value) <> nil;
  finally
    FLock.Leave;
  end;
end;

// Public下主要用于IHkStdList/IHkHashedList
procedure THkGenericsPLQS<T>.ExportValue(Src: Pointer; var Value: T);
begin
  //Value := THkElement<T>(Src^).Value; // 利用Record，可行
  Value := T(Src^);
end;

// Pool模式
function THkGenericsPLQS<T>.Get: Pointer;
begin
  FLock.Enter;
  try
    if FLinkedList.RequireItem(Result) then
    begin
      FActionClass.AfterGet(Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function THkGenericsPLQS<T>.GetCapacity: integer;
begin
  Result := FLinkedList.Capacity;
end;

function THkGenericsPLQS<T>.GetCount: integer;
begin
  Result := FLinkedList.Count;
end;

function THkGenericsPLQS<T>.GetCurrent: Pointer;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FCurrentItem;
  if FCurrentItem <> nil then
    FCurrentItem := FLinkedList.Next[FCurrentItem];
end;

function THkGenericsPLQS<T>.GetDataItem(ExtraItem: Pointer): Pointer;
begin
  Result := FLinkedList.GetDataItem(ExtraItem);
end;

function THkGenericsPLQS<T>.GetElementKind: TTypeKind;
begin
  Result := FElementKind;
end;

function THkGenericsPLQS<T>.GetElementSize: integer;
begin
  Result := SizeOf(T);
end;

function THkGenericsPLQS<T>.GetEnumerator: IHkGenericsPLQS<T>;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := Self;
  FCurrentItem := FLinkedList.Head;
end;

function THkGenericsPLQS<T>.GetExtraItem(Item: Pointer): Pointer;
begin
  Result := FLinkedList.GetExtraItem(Item);
end;

function THkGenericsPLQS<T>.GetFirst: Pointer;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FLinkedList.Head;
end;

function THkGenericsPLQS<T>.GetInitCapacity: integer;
begin
  Result := FLinkedList.InitCapacity;
end;

// 速度慢，慎用！
function THkGenericsPLQS<T>.GetItem(Index: integer): Pointer;
var
  i: integer;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');
  if (Index < 0) or (Index >= FLinkedList.Count) then
    raise Exception.Create('Out of range!');

  i := 0;
  Result := FLinkedList.Head;
  while i <> Index do
  begin
    Inc(i);
    Result := FLinkedList.Next[Result];
  end;
end;

function THkGenericsPLQS<T>.GetLast: Pointer;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FLinkedList.Tail;
end;

function THkGenericsPLQS<T>.GetNext(CurrentItem: Pointer): Pointer;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FLinkedList.Next[CurrentItem];
end;

function THkGenericsPLQS<T>.GetPrev(CurrentItem: Pointer): Pointer;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FLinkedList.Prev[CurrentItem];
end;

function THkGenericsPLQS<T>.MoveNext: boolean;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FCurrentItem <> nil;
end;

function THkGenericsPLQS<T>.PeekFirst(var Value: T): boolean;
var
  Src: Pointer;
begin
  FLock.Enter;
  try
    Src := FLinkedList.Head;
    if Src <> nil then
    begin
      //Value := THkElement<T>(Src^).Value;
      Value := T(Src^);
      Result := TRUE
    end
    else Result := FALSE;
  finally
    FLock.Leave;
  end;
end;

function THkGenericsPLQS<T>.PeekLast(var Value: T): boolean;
var
  Src: Pointer;
begin
  FLock.Enter;
  try
    Src := FLinkedList.Tail;
    if Src <> nil then
    begin
      //Value := THkElement<T>(Src^).Value;
      Value := T(Src^);
      Result := TRUE
    end
    else Result := FALSE;
  finally
    FLock.Leave;
  end;
end;

function THkGenericsPLQS<T>.Pop(var Value: T): boolean;
var
  Src: Pointer;
begin
  FLock.Enter;
  try
    Src := FLinkedList.Tail;
    if Src <> nil then
    begin
      //Value := THkElement<T>(Src^).Value;
      Value := T(Src^);
      FActionClass.BeforePut(Src);
      FLinkedList.ReturnItem(Src);
      Result := TRUE;
    end
    else Result := FALSE;
  finally
    FLock.Leave;
  end;
end;

function THkGenericsPLQS<T>.Push(const Value: T): boolean;
begin
  Result := Enqueue(Value);
end;

// Pool模式
procedure THkGenericsPLQS<T>.Put(Item: Pointer);
begin
  if Item = nil then Exit;

  FActionClass.BeforePut(Item);

  FLock.Enter;
  try
    FLinkedList.ReturnItem(Item);
  finally
    FLock.Leave;
  end;
end;

// List模式，同Pool模式的Put函数
procedure THkGenericsPLQS<T>.Remove(Item: Pointer);
begin
  Put(Item);
end;

// 参数只影响内部处理函数
procedure THkGenericsPLQS<T>.SetClearAllNode(Value: boolean);
begin
  FClearAllNode := Value;
end;

procedure THkGenericsPLQS<T>.SetClearItemBeforePut(Value: boolean);
begin
  FActionClass.ClearItemBeforePut := Value;
end;

procedure THkGenericsPLQS<T>.SetUseAllocatedNodeFirst(Value: boolean);
begin
  FLinkedList.UseAllocatedNodeFirst := Value;
end;

// =============================================================================
//  THkStdList<T>
// =============================================================================

constructor THkStdList<T>.Create(const BindingList: IHkGenericsPLQS<T>;
  Sorted: boolean; KeyIndex: integer; LockType: THkLockType);
var
  Kind: TTypeKind;
  Offset: integer;
begin
  inherited Create;

  // 2021.11.16
  // 如果无需排序，不创建比较器(之前只判断KeyIndex参数)
  if Sorted and (KeyIndex <> -1) then // 需要创建内部比较器
  begin
    Offset := KeyIndex;
    TRttiUtils<T>.GetKeyInfo(Kind, Offset);
    if Kind = tkUnknown then
      raise Exception.Create('Unsupported Data Kind!');
    FComparer := THkCompareClassI.Create(Kind, Offset);
  end;

  if Sorted and (not Assigned(FComparer)) then
    raise Exception.Create('No Valid Comparer!');

  _Init(BindingList, Sorted, LockType);
end;

constructor THkStdList<T>.Create(const BindingList: IHkGenericsPLQS<T>;
  ItemComparer: THkComparerA; Sorted: boolean; LockType: THkLockType);
begin
  inherited Create;

  FComparer := THkCompareClassA.Create(ItemComparer);
  _Init(BindingList, Sorted, LockType);
end;

constructor THkStdList<T>.Create(const BindingList: IHkGenericsPLQS<T>;
  ItemComparer: THkComparerC; Sorted: boolean; LockType: THkLockType);
begin
  inherited Create;

  FComparer := THkCompareClassC.Create(ItemComparer);
  _Init(BindingList, Sorted, LockType);
end;

constructor THkStdList<T>.Create(const BindingList: IHkGenericsPLQS<T>;
  ItemComparer: THkComparerG; Sorted: boolean; LockType: THkLockType);
begin
  inherited Create;

  FComparer := THkCompareClassG.Create(ItemComparer);
  _Init(BindingList, Sorted, LockType);
end;

constructor THkStdList<T>.Create(Capacity: integer; ItemComparer: THkComparerA;
  Sorted: boolean; LockType: THkLockType);
begin
  inherited Create;

  FRawList := THkGenericsPLQS<T>.Create(Capacity);
  Create(FRawList, ItemComparer, Sorted, LockType);
end;

constructor THkStdList<T>.Create(Capacity: integer; ItemComparer: THkComparerC;
  Sorted: boolean; LockType: THkLockType);
begin
  inherited Create;

  FRawList := THkGenericsPLQS<T>.Create(Capacity);
  Create(FRawList, ItemComparer, Sorted, LockType);
end;

constructor THkStdList<T>.Create(Capacity: integer; ItemComparer: THkComparerG;
  Sorted: boolean; LockType: THkLockType);
begin
  inherited Create;

  FRawList := THkGenericsPLQS<T>.Create(Capacity);
  Create(FRawList, ItemComparer, Sorted, LockType);
end;

constructor THkStdList<T>.Create(Capacity: integer; Sorted: boolean;
  KeyIndex: integer; LockType: THkLockType);
begin
  inherited Create;

  FRawList := THkGenericsPLQS<T>.Create(Capacity);
  Create(FRawList, Sorted, KeyIndex, LockType);
end;

destructor THkStdList<T>.Destroy;
begin
  ReleaseComparer;
  {FComparer := nil;
  if Assigned(FFirstComparer) then
    FFirstComparer.Free;
  if Assigned(FSecondComparer) then
    FSecondComparer.Free;}
  FLock.Delete;

  inherited;
end;

procedure THkStdList<T>._Init(const BindingList: IHkGenericsPLQS<T>;
  Sorted: boolean; LockType: THkLockType);
begin
  if BindingList = nil then
    raise Exception.Create('No Valid List!');

  if FRawList = nil then
    FRawList := BindingList;

  FSorted := Sorted;
  if LockType = lktSpinLock then
    raise Exception.Create('Not support SpinLock!');
  FLock := THkRtlCS.Create(LockType = lktCS);
  Reset;
end;

function THkStdList<T>.Add(const Value: T; out Item: Pointer): integer;
begin
  FLock.Enter;
  try
    Result := AddItem(Value, Item);
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.Add(const Value: T): integer;
var
  Item: Pointer;
begin
  Result := Add(Value, Item);
end;

function THkStdList<T>.AddItem(const Value: T; out Item: Pointer): integer;
begin
  Result := -1;
  Item := nil;

  if FSorted then
  begin
    if Find(Result, Value) then
      Exit;
  end
  else Result := FCount;

  Item := InsertItem(Value, Result);
  if Item = nil then
    Result := -1;
end;

procedure THkStdList<T>.Clear;
begin
  FLock.Enter;
  try
    FRawList.Clear;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.Clear(ClearEvent: THkActionEventA);
var
  Item: Pointer;
begin
  if not Assigned(ClearEvent) then
    raise Exception.Create('No valid function!');

  FLock.Enter;
  try
    for Item in FRawList do
      ClearEvent(atpRelease, Item);
    FRawList.Clear;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.Clear(ClearEvent: THkActionEventC);
var
  Item: Pointer;
begin
  if not Assigned(ClearEvent) then
    raise Exception.Create('No valid function!');

  FLock.Enter;
  try
    for Item in FRawList do
      ClearEvent(atpRelease, Item);
    FRawList.Clear;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.Clear(ClearEvent: THkActionEventG);
var
  Item: Pointer;
begin
  if not Assigned(ClearEvent) then
    raise Exception.Create('No valid function!');

  FLock.Enter;
  try
    for Item in FRawList do
      ClearEvent(atpRelease, Item);
    FRawList.Clear;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.Contains(const Key: array of const): Pointer;
var
  i: integer;
begin
  FLock.Enter;
  try
    if Find(i, Key) then
      Result := FList[i]
    else Result := nil;
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.Contains(var Value: T;
  const Key: array of const): boolean;
var
  i: integer;
begin
  FLock.Enter;
  try
    if Find(i, Key) then
    begin
      FRawList.ExportValue(FList[i], Value);
      Result := TRUE;
    end
    else Result := FALSE;
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.Exchange(Index1, Index2: Integer);
begin
  if FSorted then
    raise Exception.Create('Only for unsorted list!');
  if (Index1 < 0) or (Index1 >= FCount) then
    raise Exception.Create('Out of Index!');
  if (Index2 < 0) or (Index2 >= FCount) then
    raise Exception.Create('Out of Index!');

  FLock.Enter;
  try
    ExchangeItem(Index1, Index2);
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.ExchangeItem(Index1, Index2: Integer);
var
  P: Pointer;
begin
  P := FList[Index1];
  FList[Index1] := FList[Index2];
  FList[Index2] := P;
end;

function THkStdList<T>.Find(var Index: integer; const Key: array of const): Boolean;
var
  L, H, I, C: Integer;
begin
  if not Assigned(FComparer) then
    raise Exception.Create('No Valid Comparer!');

  Result := FALSE;

  if FSorted then
  begin
    L := 0;
    H := FCount - 1;
    while L <= H do
    begin
      I := (L + H) shr 1;
      C := FComparer.CompareKey(FList[I], Key);
      if C < 0 then
      begin
        L := I + 1;
      end
      else begin
        H := I - 1;
        if C = 0 then
        begin
          Result := TRUE;
          L := I;
        end;
      end;
    end;
    Index := L;
  end
  else begin
    Index := 0;
    while Index < FCount do
    begin
      if FComparer.CompareKey(FList[Index], Key) = 0 then Break;

      Inc(Index);
    end;

    Result := Index < FCount;
  end;
end;

function THkStdList<T>.Find(var Index: integer; const Value: T): Boolean;
var
  Item: Pointer;
begin
  Item := @Value;
  Result := Find(Index, Item);
end;

function THkStdList<T>.Find(var Index: integer; Item: Pointer): Boolean;
var
  L, H, I, C: Integer;
begin
  if not Assigned(FComparer) then
    raise Exception.Create('No Valid Comparer!');

  Result := FALSE;

  if FSorted then
  begin
    L := 0;
    H := FCount - 1;
    while L <= H do
    begin
      I := (L + H) shr 1;
      C := FComparer.CompareItem(FList[I], Item);
      if C < 0 then
      begin
        L := I + 1;
      end
      else begin
        H := I - 1;
        if C = 0 then
        begin
          Result := TRUE;
          L := I;
        end;
      end;
    end;
    Index := L;
  end
  else begin
    Index := 0;
    while Index < FCount do
    begin
      if FComparer.CompareItem(FList[Index], Item) = 0 then Break;

      Inc(Index);
    end;

    Result := Index < FCount;
  end;
end;

function THkStdList<T>.Get(Index: integer): Pointer;
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Out of Index!');

  Result := FList[Index];
end;

function THkStdList<T>.GetCount: integer;
begin
  Result := FCount;
end;

function THkStdList<T>.GetCurrent: Pointer;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  if FCurrent = -1 then
    Result := nil
  else Result := FList[FCurrent];
end;

function THkStdList<T>.GetEnumerator: IHkStdList<T>;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := Self;
  FCurrent := -1;
end;

function THkStdList<T>.GetRawList: IHkGenericsPLQS<T>;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FRawList;
end;

function THkStdList<T>.GetSorted: boolean;
begin
  Result := FSorted;
end;

function THkStdList<T>.GetText: string;
var
  i, L, Size: Integer;
  P: PChar;
  PS: PString;
  LB: string;
begin
  if not (FRawList.ElementKind in [tkUString, tkWString]) then
    raise Exception.Create('Only for unicode string!');

  if FCount = 0 then
    Exit('');

  FLock.Enter;
  try
    Size := 0;
    LB := sLineBreak;
    for PS in FRawList do // 累计整长度(包含回车符)
      Inc(Size, Length(PS^) + Length(LB));

    SetString(Result, nil, Size);
    P := Pointer(Result); // 指向string数据区
    for i := 0 to FCount - 1 do
    begin
      PS := FList[i];
      L := Length(PS^);
      if L <> 0 then
      begin
        System.Move(PS^[1], P^, L * SizeOf(Char));
        Inc(P, L);
        System.Move(Pointer(LB)^, P^, 2 * SizeOf(Char));
        Inc(P, 2);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.GetValue(Index: integer; var Value: T): boolean;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Out of Index!');

  FRawList.ExportValue(FList[Index], Value);
end;

function THkStdList<T>.GetValue(Item: Pointer; var Value: T): boolean;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := Item <> nil;
  if Result then
    FRawList.ExportValue(Item, Value);
end;

function THkStdList<T>.IndexOf(const Key: array of const): integer;
begin
  FLock.Enter;
  try
    if not Find(Result, Key) then
      Result := -1;
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.IndexOf(const Value: T): integer;
begin
  FLock.Enter;
  try
    if not Find(Result, Value) then
      Result := -1;
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.IndexOf(Item: Pointer): integer;
begin
  FLock.Enter;
  try
    if not Find(Result, Item) then
      Result := -1;
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.Insert(Index: integer; const Value: T): Pointer;
begin
  if FSorted then
    raise Exception.Create('List is sorted!');
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Out of Index!');

  FLock.Enter;
  try
    Result := InsertItem(Value, Index);
  finally
    FLock.Leave;
  end;
end;

// 新数据添加到基础列表
function THkStdList<T>.InsertItem(const Value: T; Index: integer): Pointer;
var
  Item: Pointer;
begin
  Result := FRawList.Add(Value);
  if Result <> nil then
  begin
    if FCount = Length(FList) then
      SetLength(FList, FRawList.Capacity);

    if Index < FCount then
      System.Move(FList[Index], FList[Index + 1], (FCount - Index) * SizeOf(Pointer));
    FList[Index] := Result;
    Inc(FCount);
  end;
end;

// 参考Delphi2007/XE Classes，只支持string和回车换行符
procedure THkStdList<T>.LoadFromFile(const FileName: string; OnSetText: TSetTextEvent);
var
  Size: Integer;
  Buffer: TBytes;
  Stream: TStream;
  Encoding: TEncoding;
begin
  if not (FRawList.ElementKind in [tkUString, tkWString]) then
    raise Exception.Create('Only for unicode string!');

  Encoding := nil;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Size := Stream.Size - Stream.Position;
    SetLength(Buffer, Size);
    Stream.Read(Buffer[0], Size);
    Size := TEncoding.GetBufferEncoding(Buffer, Encoding, TEncoding.Default);
    SetText(TEncoding.Default.GetString(Buffer, Size, Length(Buffer) - Size),
      OnSetText);
  finally
    Stream.Free;
  end;
end;

procedure THkStdList<T>.Move(CurIndex, NewIndex: Integer);
var
  P: Pointer;
begin
  if FSorted then
    raise Exception.Create('Only for unsorted list!');
  if (CurIndex < 0) or (CurIndex >= FCount) then
    raise Exception.Create('Out of Index!');
  if (NewIndex < 0) or (NewIndex >= FCount) then
    raise Exception.Create('Out of Index!');
  if CurIndex = NewIndex then Exit;

  FLock.Enter;
  try
    P := FList[CurIndex];
    if CurIndex > NewIndex then
      System.Move(FList[NewIndex], FList[NewIndex + 1], (CurIndex - NewIndex) * SizeOf(Pointer))
    else System.Move(FList[CurIndex + 1], FList[CurIndex], (NewIndex - CurIndex) * SizeOf(Pointer));
    FList[NewIndex] := P;
  finally
    FLock.Leave;
  end;
end;

function THkStdList<T>.MoveNext: boolean;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Inc(FCurrent);
  Result := FCurrent < FCount;
end;

procedure THkStdList<T>.QuickSort(L, R: Integer; Comparer: THkCompareClass);
var
  I, J, K: Integer;
begin
  repeat
    I := L;
    J := R;
    K := (L + R) shr 1;
    repeat
      while Comparer.CompareItem(FList[I], FList[K]) < 0 do Inc(I); // Item compare
      while Comparer.CompareItem(FList[J], FList[K]) > 0 do Dec(J);

      if I <= J then
      begin
        if I <> J then
          ExchangeItem(I, J);
        if K = I then
          K := J
        else if K = J then
          K := I;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then QuickSort(L, J, Comparer);
    L := I;
  until I >= R;
end;

procedure THkStdList<T>.ReleaseComparer;
begin
  if Assigned(FComparer) then
  	FreeAndNil(FComparer);
end;

procedure THkStdList<T>.Remove(const Key: array of const);
var
  i: integer;
begin
  FLock.Enter;
  try
    if Find(i, Key) then
      RemoveItem(i);
  finally
    FLock.Leave;
  end;
end;

// 主要用于多线程，删除的同时输出项目值
// 类似于IHkBasePLQS.Dequeue，启用一次锁完成两个操作
function THkStdList<T>.Remove(var Value: T;
  const Key: array of const): boolean;
var
  i: integer;
begin
  FLock.Enter;
  try
    Result := Find(i, Key);
    if Result then
    begin
      FRawList.ExportValue(FList[i], Value);
      RemoveItem(i);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.Remove(Index: integer);
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Out of Index!');

  FLock.Enter;
  try
    RemoveItem(Index);
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.Remove(Item: Pointer);
var
  i: integer;
begin
  FLock.Enter;
  try
    if Find(i, Item) then
      RemoveItem(i);
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.RemoveItem(Index: integer);
var
  Item: Pointer;
begin
  Item := FList[Index];
  FRawList.Put(Item); // Remove会调用Put，多一次调用
  FList[Index] := nil;
  if Index < FCount then
    System.Move(FList[Index + 1], FList[Index], (FCount- Index) * SizeOf(Pointer));
  Dec(FCount);
end;

procedure THkStdList<T>.Reset;
var
  Item: Pointer;
begin
  FLock.Enter;
  try
    FCount := 0;
    SetLength(FList, FRawList.Capacity);
    if FRawList.Count > 0 then
    begin
      for Item in FRawList do
      begin
        FList[FCount] := Item;
        Inc(FCount);
      end;

      if FSorted then
        QuickSort(0, FCount - 1, FComparer);
    end;
  finally
    FLock.Leave;
  end;
end;

// 参考Delphi XE Classes，只支持string和回车换行符
procedure THkStdList<T>.SaveToFile(const FileName: string);
var
  Stream: TStream;
  Buffer: TBytes;
begin
  if not (FRawList.ElementKind in [tkUString, tkWString]) then
    raise Exception.Create('Only for unicode string!');

  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Buffer := TEncoding.Default.GetBytes(GetText);
    Stream.WriteBuffer(Buffer[0], Length(Buffer));
  finally
    Stream.Free;
  end;
end;

procedure THkStdList<T>.SetCaseSensitive(Value: boolean);
begin
  FCaseSensitive := Value;
  FComparer.CaseSensitive := Value;
end;

procedure THkStdList<T>.SetComparer(Value: THkComparerA);
begin
  ReleaseComparer;
  FComparer := THkCompareClassA.Create(Value);
  FSorted := FALSE;
end;

procedure THkStdList<T>.SetComparer(Value: THkComparerC);
begin
  ReleaseComparer;
  FComparer := THkCompareClassC.Create(Value);
  FSorted := FALSE;
end;

procedure THkStdList<T>.SetComparer(Value: THkComparerG);
begin
  ReleaseComparer;
  FComparer := THkCompareClassG.Create(Value);
  FSorted := FALSE;
end;

procedure THkStdList<T>.SetKeyIndex(Value: integer);
var
  Kind: TTypeKind;
  Offset: integer;
begin
  Offset := Value;
  TRttiUtils<T>.GetKeyInfo(Kind, Offset);

  if Kind = tkUnknown then
    raise Exception.Create('Error Key Data TYpe!');
  if Assigned(FComparer) and (FComparer.KeyOffset = Offset) then
  	Exit;

  ReleaseComparer;
  FComparer := THkCompareClassI.Create(Kind, Offset);
  FComparer.CaseSensitive := FCaseSensitive;
  FSorted := FALSE;
end;

procedure THkStdList<T>.SetSorted(Value: boolean);
begin
  if Value and (not Assigned(FComparer)) then
    raise Exception.Create('No Valid Comparer!');

  FLock.Enter;
  try
    if FSorted <> Value then
    begin
      if Value and (FCount > 1) then
        QuickSort(0, FCount - 1, FComparer);
      FSorted := Value;
    end;
  finally
    FLock.Leave;
  end;
end;

// 只支持回车换行符
procedure THkStdList<T>.SetText(const Value: string; OnSetText: TSetTextEvent);
var
  IsSorted: boolean;
  P, Start: PChar;
  S: string;
begin
  if not (FRawList.ElementKind in [tkUString, tkWString]) then
    raise Exception.Create('Only for unicode string!');

  FLock.Enter;
  try
    FRawList.Clear;
    FCount := 0;

    IsSorted := FSorted; // 保存原始状态
    FSorted := FALSE;

    P := Pointer(Value);
    if P <> nil then
      // This is a lot faster than using StrPos/AnsiStrPos when
      // LineBreak is the default (#13#10)
      while P^ <> #0 do
      begin
        Start := P;
        while not CharInSet(P^, [#0, #10, #13]) do
          Inc(P);
        SetString(S, Start, P - Start);
        OnSetText(S);
        if P^ = #13 then Inc(P);
        if P^ = #10 then Inc(P);
      end;

    FSorted := IsSorted; // 恢复状态
    if (FCount > 1) and FSorted then
      QuickSort(0, FCount - 1, FComparer);
  finally
    FLock.Leave;
  end;
end;

procedure THkStdList<T>.Sort;
begin
  if {FSorted or} (FCount <= 1) or (not Assigned(FComparer)) then Exit;

  FLock.Enter;
  try
    QuickSort(0, FCount - 1, FComparer);
  finally
    FLock.Leave;
  end;
end;

{procedure THkStdList<T>.Sort(Comparer: THkComparerA; ReleaseComparer: boolean = TRUE);
begin
  if not CustomSortAllowed then Exit;

  FSecondComparer := THkCompareClassA.Create(Comparer);
  FLock.Enter;
  try
    QuickSort(0, FCount - 1, FSecondComparer);
  finally
    FLock.Leave;
    if ReleaseComparer then
      FreeAndNil(FSecondComparer)
    else FComparer := FSecondComparer;
  end;
end;}

{procedure THkStdList<T>.Sort(Comparer: THkComparerG; ReleaseComparer: boolean = TRUE);
begin
  if not CustomSortAllowed then Exit;

  FSecondComparer := THkCompareClassG.Create(Comparer);
  FLock.Enter;
  try
    QuickSort(0, FCount - 1, FSecondComparer);
  finally
    FLock.Leave;
    if ReleaseComparer then
      FreeAndNil(FSecondComparer)
    else FComparer := FSecondComparer;
  end;
end;}

{procedure THkStdList<T>.Sort(KeyIndex: integer; ReleaseComparer: boolean = TRUE);
var
  Kind: TTypeKind;
  Offset: integer;
begin
  if not CustomSortAllowed then Exit;

  Offset := KeyIndex;
  TRttiUtils<T>.GetKeyInfo(Kind, Offset);
  if Kind = tkUnknown then
    raise Exception.Create('Error Key Data TYpe!');

  FSecondComparer := THkCompareClassI.Create(Kind, Offset);
  FSecondComparer.CaseSensitive := FCaseSensitive;
  FLock.Enter;
  try
    QuickSort(0, FCount - 1, FSecondComparer);
  finally
    FLock.Leave;
    if ReleaseComparer then
      FreeAndNil(FSecondComparer)
    else FComparer := FSecondComparer;
  end;
end;}

// 可以添加则添加并返回新指针，否则如果Key已存在，则返回已有数据的指针
// 只有在添加成功，才返回TRUE，否则返回FALSE，Item包含已有Key的数据指针
function THkStdList<T>.TryAdd(const Value: T; out Item: Pointer): boolean;
var
  i: Integer;
begin
  FLock.Enter;
  try
    if not FSorted then
    begin
      AddItem(Value, Item);
      Result := TRUE;
    end
    else begin
      if Find(i, Value) then
      begin
        Item := FList[i];
        Result := FALSE;
      end
      else Result := AddItem(Value, Item) <> -1;
    end;
  finally
    FLock.Leave;
  end;
end;

// =============================================================================
//  THkHashedList<T>
// =============================================================================

// 使用内部函数
constructor THkHashedList<T>.Create(BindingList: IHkGenericsPLQS<T>; KeyIndex,
  HashBucketSize: integer; HashFunc: TOnHashFunc; LockType: THkLockType);
begin
  inherited Create;

  if BindingList = nil then
    raise Exception.Create('No Valid List!');

  FRawList := BindingList;
  _InnerInit(KeyIndex, HashFunc);
  _Init(HashBucketSize, LockType);
end;

// 使用内部函数
constructor THkHashedList<T>.Create(Capacity, KeyIndex, HashBucketSize: integer;
  HashFunc: TOnHashFunc; LockType: THkLockType);
begin
  inherited Create;

  FRawList := THkGenericsPLQS<T>.Create(Capacity);
  _InnerInit(KeyIndex, HashFunc);
  _Init(HashBucketSize, LockType);
end;

constructor THkHashedList<T>.Create(BindingList: IHkGenericsPLQS<T>;
  HashEvent: THkHashEventA; Comparer: THkComparerA; HashBucketSize: integer;
  LockType: THkLockType);
begin
  if BindingList = nil then
    raise Exception.Create('No Valid List!');

  if (not Assigned(HashEvent)) or (not Assigned(Comparer)) then
    raise Exception.Create('No Valid Ext.Function!');

  FComparer := THkCompareClassA.Create(Comparer);
  FHashClass := TExtHashClassA.Create(HashEvent);

  FRawList := BindingList;
  _Init(HashBucketSize, LockType);
end;

constructor THkHashedList<T>.Create(BindingList: IHkGenericsPLQS<T>;
  HashEvent: THkHashEventC; Comparer: THkComparerC; HashBucketSize: integer;
  LockType: THkLockType);
begin
  if BindingList = nil then
    raise Exception.Create('No Valid List!');

  if (not Assigned(HashEvent)) or (not Assigned(Comparer)) then
    raise Exception.Create('No Valid Ext.Function!');

  FComparer := THkCompareClassC.Create(Comparer);
  FHashClass := TExtHashClassC.Create(HashEvent);

  FRawList := BindingList;
  _Init(HashBucketSize, LockType);
end;

constructor THkHashedList<T>.Create(BindingList: IHkGenericsPLQS<T>;
  HashEvent: THkHashEventG; Comparer: THkComparerG; HashBucketSize: integer;
  LockType: THkLockType);
begin
  if BindingList = nil then
    raise Exception.Create('No Valid List!');

  if (not Assigned(HashEvent)) or (not Assigned(Comparer)) then
    raise Exception.Create('No Valid Ext.Function!');

  FComparer := THkCompareClassG.Create(Comparer);
  FHashClass := TExtHashClasscG.Create(HashEvent);

  FRawList := BindingList;
  _Init(HashBucketSize, LockType);
end;

destructor THkHashedList<T>.Destroy;
begin
  Clear;
  FComparer.Free;
  FHashClass.Free;
  FLock.Delete;

  inherited;
end;

procedure THkHashedList<T>._Init(HashBucketSize: integer;
  LockType: THkLockType);
begin
  SetHashBucketSize(HashBucketSize);
  FZipPool := THkGenericsPLQS<TOwlNode>.Create(FRawList.InitCapacity);

  if LockType = lktSpinLock then
    raise Exception.Create('Not supported SpinLock!');
  FLock := THkRtlCS.Create(LockType = lktCS);
  Reset;
end;

procedure THkHashedList<T>._InnerInit(KeyIndex: integer; HashFunc: TOnHashFunc);
var
  Kind: TTypeKind;
  Offset: integer;
begin
  if KeyIndex >= 0 then
  begin
    Offset := KeyIndex;
    TRttiUtils<T>.GetKeyInfo(Kind, Offset);
  end
  else Kind := tkUnknown;
  if not (Kind in [tkChar, tkWChar, tkLString, tkWString, tkUString]) then // 只支持字符串
    raise Exception.Create('Unsupport data type!');

  FComparer := THkCompareClassI.Create(Kind, Offset);
  if Assigned(HashFunc) then
    FHashClass := TStringHashClass.Create(Kind, Offset, FALSE, HashFunc)
  else FHashClass := TStringHashClass.Create(Kind, Offset, FALSE, BKDRHash); // 字符串缺省函数，JSHash也是不错的选择
end;

function THkHashedList<T>.Add(const Value: T): Pointer;
var
  Hash: Cardinal;
begin
  Result := Add(Value, Hash);
end;

function THkHashedList<T>.Add(const Value: T; out Hash: Cardinal): Pointer;
var
  BucketIndex: integer;
begin
  BucketIndex := GetBucketIndex(Value, Hash);
  FLock.Enter;
  try
    if Find(@Value, BucketIndex) = nil then
    begin
      Result := FRawList.Add(Value);
      if Result <> nil then
        if not AddHashItem(BucketIndex, Result) then
        begin
          FRawList.Put(Result);
          Result := nil;
        end;
    end
    else Result := nil;
  finally
    FLock.Leave;
  end;
end;

function THkHashedList<T>.AddHashItem(BucketIndex: integer;
  Item: Pointer): boolean;
var
  Node: POwlNode;
begin
  Node := FZipPool.Get;
  if Node <> nil then
  begin
    Node.Data := Item;

    Node.Next := FHashBuckets[BucketIndex]; // 插入链表头部
    FHashBuckets[BucketIndex] := Node;
    Inc(FCount);
    Result := TRUE;
  end
  else Result := FALSE;
end;

procedure THkHashedList<T>.Clear;
begin
  FLock.Enter;
  try
    ClearBucket;
    FRawList.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure THkHashedList<T>.Clear(ClearEvent: THkActionEventA);
var
  Item: Pointer;
begin
  if not Assigned(ClearEvent) then
    raise Exception.Create('No valid function!');

  FLock.Enter;
  try
    ClearBucket;

    for Item in FRawList do
      ClearEvent(atpBeforePut, Item);
    FRawList.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure THkHashedList<T>.Clear(ClearEvent: THkActionEventC);
var
  Item: Pointer;
begin
  if not Assigned(ClearEvent) then
    raise Exception.Create('No valid function!');

  FLock.Enter;
  try
    ClearBucket;

    for Item in FRawList do
      ClearEvent(atpBeforePut, Item);
    FRawList.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure THkHashedList<T>.Clear(ClearEvent: THkActionEventG);
var
  Item: Pointer;
begin
  if not Assigned(ClearEvent) then
    raise Exception.Create('No valid function!');

  FLock.Enter;
  try
    ClearBucket;

    for Item in FRawList do
      ClearEvent(atpBeforePut, Item);
    FRawList.Clear;
  finally
    FLock.Leave;
  end;
end;

// 清空哈希桶
procedure THkHashedList<T>.ClearBucket;
begin
  if FCount = 0 then Exit;

  FillChar(FHashBuckets[0], Length(FHashBuckets) * SizeOf(POwlNode), 0);
  FZipPool.Clear;
  FCount := 0;
end;

function THkHashedList<T>.Contains(Item: Pointer): boolean;
var
  BucketIndex: integer;
  Hash: Cardinal;
begin
  BucketIndex := GetBucketIndex(Item, Hash);
  FLock.Enter;
  try
    //Result := Find(Item, BucketIndex, Prev, Node);
    Result := Find(Item, BucketIndex) <> nil;
  finally
    FLock.Leave;
  end;
end;

function THkHashedList<T>.Contains(const Key: array of const): Pointer;
var
  BucketIndex: integer;
  Hash: Cardinal;
begin
  BucketIndex := GetBucketIndex(Key, Hash);
  FLock.Enter;
  try
    //if Find(Key, BucketIndex, Prev, Node) then
    Result := Find(Key, BucketIndex);
  finally
    FLock.Leave;
  end;
end;

function THkHashedList<T>.Contains(var Value: T;
  const Key: array of const): boolean;
var
  BucketIndex: integer;
  Hash: Cardinal;
  Item: Pointer;
begin
  BucketIndex := GetBucketIndex(Key, Hash);
  FLock.Enter;
  try
    Item := Find(Key, BucketIndex);
    Result := Item <> nil;
    if Result then
      FRawList.ExportValue(Item, Value);
  finally
    FLock.Leave;
  end;
end;

function THkHashedList<T>.Find(Item: Pointer; BucketIndex: integer;
  Remove: boolean): Pointer;
var
  Prev, Node: POwlNode;
begin
  Prev := nil;
  Node := FHashBuckets[BucketIndex];
  while Node <> nil do
  begin
    if FComparer.CompareItem(Node.Data, Item) = 0 then
      Break;

    Prev := Node;
    Node := Node.Next;
  end;

  if Node <> nil then
  begin
    Result := Node.Data;
    if Remove then
      RemoveFromBucket(BucketIndex, Prev, Node);
  end
  else Result := nil;
end;

function THkHashedList<T>.Find(const Key: array of const; BucketIndex: integer;
  Remove: boolean): Pointer;
var
  Prev, Node: POwlNode;
begin
  Prev := nil;
  Node := FHashBuckets[BucketIndex];
  while Node <> nil do
  begin
    if FComparer.CompareKey(Node.Data, Key) = 0 then
      Break;

    Prev := Node;
    Node := Node.Next;
  end;

  if Node <> nil then
  begin
    Result := Node.Data;
    if Remove then
      RemoveFromBucket(BucketIndex, Prev, Node);
  end
  else Result := nil;
end;

function THkHashedList<T>.GetBucketIndex(Item: Pointer;
  out Hash: Cardinal): integer;
begin
  Hash := FHashClass.GetHash(Item);
  Result := Hash and (FBucketSize - 1);
end;

function THkHashedList<T>.GetBucketIndex(const Key: array of const;
  out Hash: Cardinal): integer;
begin
  Hash := FHashClass.GetHash(Key);
  Result := Hash and (FBucketSize - 1);
end;

function THkHashedList<T>.GetBucketIndex(const Value: T;
  out Hash: Cardinal): integer;
begin
  Result := GetBucketIndex(@Value, Hash);
end;

function THkHashedList<T>.GetBucketSize: integer;
begin
  Result := Length(FHashBuckets);
end;

function THkHashedList<T>.GetCount: integer;
begin
  Result := FCount;
end;

function THkHashedList<T>.GetRawList: IHkGenericsPLQS<T>;
begin
  if FLock.Enabled then
    raise Exception.Create('Unsupported in Thread!');

  Result := FRawList;
end;

procedure THkHashedList<T>.Remove(Item: Pointer);
var
  BucketIndex: integer;
  Hash: Cardinal;
  Data: Pointer;
begin
  BucketIndex := GetBucketIndex(Item, Hash);
  FLock.Enter;
  try
    Data := Find(Item, BucketIndex, TRUE);
    if Data <> nil then
    begin
      FRawList.Put(Data);
      Dec(FCount);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THkHashedList<T>.Remove(const Key: array of const);
var
  BucketIndex: integer;
  Hash: Cardinal;
  Data: Pointer;
begin
  BucketIndex := GetBucketIndex(Key, Hash);
  FLock.Enter;
  try
    Data := Find(Key, BucketIndex, TRUE);
    if Data <> nil then
    begin
      FRawList.Put(Data);
      Dec(FCount);
    end;
  finally
    FLock.Leave;
  end;
end;

// 主要用于多线程，删除的同时输出项目值(类似于IHkBasePLQS.Dequeue)
function THkHashedList<T>.Remove(var Value: T;
  const Key: array of const): boolean;
var
  BucketIndex: integer;
  Hash: Cardinal;
  Item: Pointer;
begin
  BucketIndex := GetBucketIndex(Key, Hash);
  FLock.Enter;
  try
    Item := Find(Key, BucketIndex, TRUE);
    Result := Item <> nil;
    if Result then
    begin
      FRawList.ExportValue(Item, Value);
      FRawList.Put(Item);
      Dec(FCount);
    end;
  finally
    FLock.Leave;
  end;
end;

// 节点从哈希桶的链表里摘除，返回节点里的数据指针
function THkHashedList<T>.RemoveFromBucket(BucketIndex: integer;
  Prev, Node: POwlNode): Pointer;
begin
  Result := Node.Data;

  if Prev = nil then // 目标是头节点
    FHashBuckets[BucketIndex] := Node.Next // 下一个节点作为头节点
  else Prev.Next := Node.Next; // 从链表中摘除目标节点
  Node.Data := nil;
  FZipPool.Put(Node);
end;

procedure THkHashedList<T>.Reset;
var
  BucketIndex: integer;
  Hash: Cardinal;
  Item: Pointer;
begin
  if FRawList.Count = 0 then Exit;

  FLock.Enter;
  try
    ClearBucket;
    for Item in FRawList do
    begin
      BucketIndex := GetBucketIndex(Item, Hash);
      AddHashItem(BucketIndex, Item);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THkHashedList<T>.SetCaseSensitive(Value: boolean);
begin
  if FComparer.CaseSensitive = Value then Exit;

  FComparer.CaseSensitive := Value;
  FHashClass.CaseSensitive := Value;
  if FCount > 0 then
    Reset;
end;

procedure THkHashedList<T>.SetHashBucketSize(Value: integer);
const
  MIN_BUCKET = 1 shl 8;  // 256
  MAX_BUCKET = 1 shl 28;
var
  i: Cardinal;
begin
  if Length(FHashBuckets) = Value then Exit;

  // 保证是2的幂次，比如10000->16384
  i := Value - 1;
  i := i or (i shr 1);
  i := i or (i shr 2);
  i := i or (i shr 4);
  i := i or (i shr 8);
  i := i or (i shr 16);
  if i < MIN_BUCKET then
    i := MIN_BUCKET
  else if i > MAX_BUCKET then
    i := MAX_BUCKET
  else i := i + 1;

  if i <> Cardinal(Length(FHashBuckets)) then
  begin
    SetLength(FHashBuckets, i);
    FBucketSize := i;

    if FCount > 0 then
      Reset;
  end;
end;

// =============================================================================
//  THkMemoryStore
// =============================================================================

constructor THkMemoryStore.Create(BlockSize: integer; Fixed: boolean;
  HeapHandle: THandle);
begin
  inherited Create;

  FBlockSize := BlockSize;
  FFixed := Fixed;
  FHeapHandle := TMemoryUtils.GetHeapHandle(HeapHandle);

  FBlockCount := 0;
  FHead := nil;
  Grow;
end;

destructor THkMemoryStore.Destroy;
begin
  TMemoryUtils.FreeAllMemBlock(FHead, FHeapHandle);

  inherited;
end;

function THkMemoryStore.Get(Size: integer; var P: PByte): boolean;
var
  MB: POwlNode;
  Offset: integer;
begin
  Result := FALSE;
  P := nil;
  if (Size <= 0) or (Size > FBlockSize) then Exit;

  GetSpareBlock(Size, MB);
  if MB <> nil then
  begin
    P := PByte(MB);
    Offset := integer(MB.Data);
    Inc(P, Offset);
    MB.Data := Pointer(Offset + Size);
    Result := TRUE;
  end;
end;

function THkMemoryStore.GetBlockCount: integer;
begin
  Result := FBlockCount;
end;

function THkMemoryStore.GetBlockSize: integer;
begin
  Result := FBlockSize;
end;

procedure THkMemoryStore.GetSpareBlock(Size: integer; var MB: POwlNode);
begin
  MB := FHead;
  while MB <> nil do // 遍历链表，检查是否有剩余空间
  begin
    if integer(MB.Data) + Size <= FBlockSize + SizeOf(TOwlNode) then
      Break;

    MB := MB.Next;
  end;

  if (MB = nil) and (not FFixed) then
    if Grow then
      MB := FHead;
end;

function THkMemoryStore.GetTotalSize: integer;
begin
  Result := FBlockCount * (FBlockSize + SizeOf(TOwlNode));
end;

function THkMemoryStore.Grow: boolean;
var
  MB: POwlNode;
begin
  MB := TMemoryUtils.AllocMemBlock(FBlockSize + SizeOf(TOwlNode), FHeapHandle);
  if MB <> nil then
  begin
    MB.Data := Pointer(SizeOf(TOwlNode)); // 有效分配区域紧跟在节点数据后
    MB.Next := FHead; // 新分配的块插入链表头部
    FHead := MB;

    Inc(FBlockCount);
    Result := TRUE;
  end
  else Result := FALSE;
end;

procedure THkMemoryStore.Reset;
var
  MB: POwlNode;
  P: PByte;
begin
  MB := FHead;
  while MB <> nil do
  begin
    P := PByte(MB);
    Inc(P, SizeOf(TOwlNode)); // 指向用户数据区
    ZeroMemory(P, FBlockSize);
    MB.Data := Pointer(SizeOf(TOwlNode));

    MB := MB.Next;
  end;
end;

function THkMemoryStore.TryToGet(Size: integer): boolean;
var
  MB: POwlNode;
begin
  Result := FALSE;
  if (Size <= 0) or (Size > FBlockSize) then Exit;

  GetSpareBlock(Size, MB);
  Result := MB <> nil;
end;

// =============================================================================
//  THkRtlCS
// =============================================================================

constructor THkRtlCS.Create(Enabled: boolean);
begin
  FillChar(FDummy, SizeOf(FDummy), 0);
  FDummy[0] := integer(Enabled);
  InitializeCriticalSection(FRtlCS);
end;

procedure THkRtlCS.Delete;
begin
  DeleteCriticalSection(FRtlCS);
end;

procedure THkRtlCS.Enter;
begin
  if FDummy[0] <> 0 then
    EnterCriticalSection(FRtlCS);
end;

function THkRtlCS.GetBoolean(Index: integer): boolean;
begin
  Result := FDummy[Index] <> 0;
end;

function THkRtlCS.GetEnabled: boolean;
begin
  Result := FDummy[0] <> 0;
end;

function THkRtlCS.GetInteger(Index: integer): integer;
begin
  Result := FDummy[Index];
end;

function THkRtlCS.GetNativeInt(Index: integer): NativeInt;
begin
  Result := FDummy[Index];
end;

function THkRtlCS.GetObject(Index: integer): TObject;
begin
  Result := TObject(FDummy[Index]);
end;

function THkRtlCS.GetPointer(Index: integer): Pointer;
begin
  Result := Pointer(FDummy[Index]);
end;

procedure THkRtlCS.Leave;
begin
  if FDummy[0] <> 0 then
    LeaveCriticalSection(FRtlCS);
end;

procedure THkRtlCS.SetBoolean(Index: integer; Value: boolean);
begin
  FDummy[Index] := integer(Value);
end;

procedure THkRtlCS.SetEnabled(Value: boolean);
begin
  FDummy[0] := integer(Value);
end;

procedure THkRtlCS.SetInteger(Index, Value: integer);
begin
  FDummy[Index] := Value;
end;

procedure THkRtlCS.SetNativeInt(Index: integer; Value: NativeInt);
begin
  FDummy[Index] := Value;
end;

procedure THkRtlCS.SetObject(Index: integer; Value: TObject);
begin
  FDummy[Index] := int64(Value);
end;

procedure THkRtlCS.SetPointer(Index: integer; Value: Pointer);
begin
  FDummy[Index] := int64(Value);
end;

end.
