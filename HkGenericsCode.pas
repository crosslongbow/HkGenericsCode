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
   * �ο���https://blog.synopse.info/?post/2016/01/09/Safe-locks-for-multi-thread-applications
   * ��¼�ڣ�TCriticalSection @ͬ���밲ȫ @���߳� @Delphi
   * - TRTLCriticalSection��Record����TCriticalSection�����һ�㡣
   * - TFixedCriticalSection�ڱ���ʱ�ܻ�����һ�����档
   *
   * ʹ��ʱ�����������ã�THkRtlCS.Enabled := TRUE | FALSE
   * �ͷ�ʱ��THkRtlCS.Delete
   *)
  THkRtlCS = Record
  private
    FDummy: array[0..11] of int64; // ��һλ���ڱ���Enabled������11λ����
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
    function GetCapacity: integer;             // ��ǰ����
    function GetCount: integer;                // �ѷ�����Ŀ����
    function GetInitCapacity: integer;         // ��ʼ����

    function GetElementKind: TTypeKind;        // Ԫ������
    function GetElementSize: integer;          // Ԫ�ش�С

    procedure ExportValue(Src: Pointer; var Value: T); // ��ֵ���ⲿ����(�����ӿ�ʹ��)
    function GetDataItem(ExtraItem: Pointer): Pointer; // ���ݸ�������ָ���ȡ�û�����
    function GetExtraItem(Item: Pointer): Pointer;     // ��ȡ��������ָ��
    function GetFirst: Pointer;                // ��ȡ��һ����¼
    function GetLast: Pointer;                 // ��ȡ���һ����¼
    function GetNext(CurrentItem: Pointer): Pointer;   // ��ȡ��һ����¼
    function GetPrev(CurrentItem: Pointer): Pointer;   // ��ȡ��һ����¼
    function PeekFirst(var Value: T): boolean;
    function PeekLast(var Value: T): boolean;

    function Add(const Value: T): Pointer;     // Listģʽ���������Ŀ
    function Dequeue(var Value: T): boolean;   // Queueģʽ��ȡ����Ŀ(�Ƴ�)
    function Enqueue(const Value: T): boolean; // Queueģʽ���������Ŀ
    function Get: Pointer;                     // Poolģʽ�������ڴ�
    function Pop(var Value: T): boolean;       // Stackģʽ��ȡ����Ŀ(�Ƴ�)
    function Push(const Value: T): boolean;    // Stackģʽ���������Ŀ
    procedure Put(Item: Pointer);              // Poolģʽ���黹�ڴ�
    procedure Remove(Item: Pointer);           // Listģʽ���Ƴ���Ŀ

    // for..inֻ�ṩ���ѷ���ռ�ı�����δ����ռ����޷����ʵ�
    function GetCurrent: Pointer;               // for..in
    function GetEnumerator: IHkGenericsPLQS<T>; // for..in
    function MoveNext: boolean;                 // for..in

    procedure Clear;                           // ��ղ������ѷ�����ڴ�
    function GetItem(Index: integer): Pointer; // ˳���ȡ(�ٶ���������)
    // 2021.06.08
    // ȱʡ״ֻ̬�����ѷ���Ľڵ㡣��ģʽ�£����յĽڵ����Ҳ��Ҫ�ͷ���Դ��
    // �ò���ֻӰ��Cleanup��������ֻ���˳�OnReleaseʱ��Ч
    procedure SetClearAllNode(Value: boolean);
    procedure SetClearItemBeforePut(Value: boolean); // ����ʱ�ڴ������
    // 2021.09.23
    // ȱʡ״̬�»��յĽڵ��Ƿ��ڿ����б��ͷ����Ҳ��������ʹ�ñ�������Ľڵ㡣
    // ��ĳЩ����¿�����Ҫƽ��ʹ��ÿ���ڵ㣬���Ի��յĽڵ��ŵ������б��β����
    // ȱʡֵ�Ƿ��ڿ����б��ͷ������ѡ�Ӱ���ⲿʹ�ã��������κ�ʱ���޸ġ�
    // ע�⣺��ѡ��ܺ���ǰ�汾���ӳٷ��䷽��һ��ʹ��(��Ҫ����������)��
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
    FClearAllNode: boolean;                    // ���������ѷ�����ѻ��յĽڵ㡣ȱʡ��ֻ�����ѷ���ڵ�
    FElementKind: TTypeKind;
    FLinkedList: THkLinkedList;                // �ڲ�����
    function AddItem(const Value: T): Pointer;
    procedure Cleanup;
    procedure _Cleanup(Item: Pointer);
    function _Init(Capacity, MaxCapacity: integer; HeapHandle: THandle;
      LockType: THkLockType; ExtraSize: integer): integer;
  private
    FLock: THkRtlCS;
  private                                      // IHkGenericsPLQS<T>
    function GetCapacity: integer;             // ��ǰ����
    function GetCount: integer;                // �ѷ�����Ŀ����
    function GetElementKind: TTypeKind;        // Ԫ������
    function GetElementSize: integer;          // Ԫ�ش�С
    function GetInitCapacity: integer;         // ��ʼ����
    function GetItem(Index: integer): Pointer; // ˳���ȡ(�ٶ���������)
    function GetFirst: Pointer;                // ��ȡ��һ����¼
    function GetLast: Pointer;                 // ��ȡ���һ����¼
    function GetNext(CurrentItem: Pointer): Pointer;   // ��ȡ��һ����¼
    function GetPrev(CurrentItem: Pointer): Pointer;   // ��ȡ��һ����¼
    procedure SetClearAllNode(Value: boolean);
    procedure SetClearItemBeforePut(Value: boolean); // ����ʱ�ڴ������
    procedure SetUseAllocatedNodeFirst(Value: boolean); // ����ʹ�÷�����Ľڵ�
  private                                      // IHkGenericsPLQS<T>
    FCurrentItem: Pointer;
    function GetCurrent: Pointer;               // for..in
    function GetEnumerator: IHkGenericsPLQS<T>; // for..in
    function MoveNext: boolean;                 // for..in
  public                                       // IHkGenericsPLQS<T>
    function Add(const Value: T): Pointer;     // Listģʽ���������Ŀ
    procedure Clear;                           // ��ղ������ѷ�����ڴ�
    function Dequeue(var Value: T): boolean;   // Queueģʽ��ȡ����Ŀ(�Ƴ�)
    function Enqueue(const Value: T): boolean; // Queueģʽ���������Ŀ
    procedure ExportValue(Src: Pointer; var Value: T); // ��ֵ���ⲿ����(�����ӿ�ʹ��)
    function Get: Pointer;                     // Poolģʽ�������ڴ�
    function GetDataItem(ExtraItem: Pointer): Pointer; // ���ݸ�������ָ���ȡ�û�����
    function GetExtraItem(Item: Pointer): Pointer;     // ��ȡ��������ָ��
    function PeekFirst(var Value: T): boolean;
    function PeekLast(var Value: T): boolean;
    function Pop(var Value: T): boolean;       // Stackģʽ��ȡ����Ŀ(�Ƴ�)
    function Push(const Value: T): boolean;    // Stackģʽ���������Ŀ
    procedure Put(Item: Pointer);              // Poolģʽ���黹�ڴ�
    procedure Remove(Item: Pointer);           // Listģʽ���Ƴ���Ŀ
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
   * �Ƚ���
   *
   * IHkStdList��IHkGenericsPLQS����������ǰ���ǿ��ڲ����ҵ��б���������ڲ���
   * �ң�����֮���Ψһ�������ǰ���ṩ����ź�Insert/Exchange������������������
   * �ͷ����б���Ŀ����������������б���������ʹ��IHkGenericsPLQS��
   *
   * ֻҪ����Ҫ���ң�����Ҫ�Ƚ�����
   * ֮ǰ��CustomSort������Զ��������ͻָ�ԭ�бȽ�����������ġ���Ϊ�����
   * ����Ӧ��ʹ��ͬһ���Ƚ�����������ö��ַ��Ĳ��Һ������ܻ�ó�����Ľ����
   *
   * ����б���Ҫ�����������ã���Ҫʹ�ò�ͬ�ıȽ����������ַ�����
   * 1. ���õ�һ�ڶ��Ƚ��������Ƚ�����������ǰ���ߵ����á���һ�Ƚ������б������
   *    �������ڶ��Ƚ�������ʱ�Ƚ�������Ҫ����ʱ����ʱ�������һ�Ƚ���״̬���л�
   *    ���ڶ��Ƚ�����֮����ָ���һ�Ƚ�����
   * 2. ֻ��һ���Ƚ�����������Ҫ���ⲿ���ã��л�ʱ��Ϊ�������ⲿ��������
   * ��Ȼѡ�񷽷�2...�߼��Ƚϼ򵥡�
   *
   * �ܽ᣺
   * 1. IHkStdList�ӿڿ���û�бȽ���ʵ�������ڲ������б�
   * 2. �Ƚ���ʵ��ֻ��һ����ͨ���ӿ����ã�֧����������/�ຯ��/ȫ�ֺ���
   * 3. �л��Ƚ���ʱ��������Sorted=FALSE����Ҫ�ⲿ������������
   * 4. �Ƚ�����Sorted�����޹������������3�»���Ӱ��
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
    // ���߳��¶�ȡָ����ܲ���ȫ(ͨ��ָ���ȡֵ�ǲ�ͬ����)�������ö�̬���ָ��
    // ��ֵ����Ԫ����Pointerʱ��ԭ��Contains���������������壬���ܻ�������ң�
    // ϣ�����ú��߷���ֵ��ʵ��ȴ������ǰ��
    // ���Դ�HkGenericsCode��ʼ���ò�ͬ�ĸ�ʽ
    // �����Hash�б�ͬ��
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
  // ������ƱȽ��������������ӿڲ���
  //
  THkStdList<T> = class(TInterfacedObject, IHkStdList<T>)
  private
    FRawList: IHkGenericsPLQS<T>;              // ԭʼ�����б�
  private
    FComparer: THkCompareClass;                // ���Ƚ���
    //FFirstComparer: THkCompareClass;           // ��һ�Ƚ���
    //FSecondComparer: THkCompareClass;          // �ڶ��Ƚ���
    FSorted: boolean;
  private
    FCaseSensitive: boolean;                   // ָ��Key���Զ���������Ҫʹ��
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
    constructor Create(                        // ����������ʹ���ڲ��Ƚ���
      const BindingList: IHkGenericsPLQS<T>;
      Sorted: boolean = FALSE;
      KeyIndex: integer = 0;                   // ����-1ʱ��ʾ�ж��Key
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // �����ȽϺ���
      const BindingList: IHkGenericsPLQS<T>;
      ItemComparer: THkComparerA;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // ��ȽϺ���
      const BindingList: IHkGenericsPLQS<T>;
      ItemComparer: THkComparerC;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // ȫ�ֱȽϺ���
      const BindingList: IHkGenericsPLQS<T>;
      ItemComparer: THkComparerG;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // �Դ�IHkBasePLQS��ʹ���ڲ��Ƚ���
      Capacity: integer = 64;
      Sorted: boolean = FALSE;
      KeyIndex: integer = 0;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // �Դ�IHkBasePLQS��ʹ�������ȽϺ���
      Capacity: integer;
      ItemComparer: THkComparerA;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // �Դ�IHkBasePLQS��ʹ����ȽϺ���
      Capacity: integer;
      ItemComparer: THkComparerC;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                        // �Դ�IHkBasePLQS��ʹ��ȫ�ֱȽϺ���
      Capacity: integer;
      ItemComparer: THkComparerG;
      Sorted: boolean = FALSE;
      LockType: THkLockType = lktNone); overload;
    destructor Destroy; override;
  end;

type
  // Hash�������ǲ��ܼ�¼��ţ���Ϊ�б���Ż�䶯�������Ǵ������ı䶯��һ���䶯
  // ��Ҫȫ�����¼��㡣����Hash�б����ṩ��Ŵ�ȡ��
  // IHkHashedList֧�ֵ��������ͽ��٣�CN_Key_Kind + tkRecord��
  // �����Record��Key���ݱ���ֻ��1���ҷ���CN_Key_Kind��
  // ��IHkStdList��ͬ���ǣ�Keyͬʱ���ڼ����ϣ�ͱȽϣ����ԣ�����Ҫ�ⲿ�ȽϺ�����
  // �����ַ����Ĵ�Сд������Ҫע�⡣
  // ��Сд���У��ַ�������ʹ��Դ�ַ�����Ҫ����ת��ΪȫСд��ȫ��д��Ȼ���ת��
  // ����ַ������й�ϣ�������ԣ��ڽӿ��ڲ����û������洢ת������ַ�����
  //
  // 2020.02.25
  // �ο�����ϣͰ���ȵ�ѡ��.md(Tech\Develop\Delphi\�㷨\��ϣ��)
  // ��Java HashMap��������Ͱ������2���ݣ�����Indexֵ����ȡģ���㣬����λ���㣬
  // ����ֵ��Ͱ����-1
  //
  // ���߳��²�Ҫʹ��ָ�룬���Ƕ�ȡ���ݵĸ�����
  //
  // 2020.04.12
  // ������������ϣ�㷨����ֱ��ȡ�෨�����õĻ��У��˻�ȡ������ƽ��ȡ�з���
  // һ��ֱ��ȡ�෨��ĸ�����������������Ͱ������
  //
  // 2021.02.08
  // ͬIHkStdList(2021.01.11)�����Ӷ�����ָ���֧�֡��������״γ�����IHkTree��
  // �ⲿ��������Ԫ��ʱ������Key/Index������ⲿ����ֻ��Ԫ������ָ�룬�����޷���
  // ��Key(����������)�����з����޷������������ӽӿڶ�Ԫ������ָ���֧��
  //
  // 2021.05.11
  // ��ϣ�б�ֻ��ʹ���ڲ�����������֧�ֵ��������ͱȽ��٣�����˵ָ�롣
  // ��ȻKeyͬʱ���ڼ����ϣֵ�ͱȽϣ�����ⲿ������ͬʱ�ṩ����ܾͿ��Խ����
  // 1. �ȽϺ������ο�IHkStdList
  // 2. ��ϣ���㺯��
  //
  // 2021.05.20
  // ��ϣ����ʹ��������ΪKeyʱ����һ����������������˳���������������С�����
  // DnsHub���Session�б���Ϊ���б���˳��������ѭ��ʹ�ã����Թ�ϣͰ��������Ϊ
  // �б�ĳ��ȣ�û���������࣬��ϣ�ļ����ȡģ����������Ժ�һ��ֱ��ʹ��AND������
  // �ǳ��졣
  // �ڲ�������ͨ�������Ҫָ��ȡ�����������ֵ���ٶȻ���һЩ�����Զ�����������
  // ����ʹ���ⲿ����������
  // ����������Ϊ��ϣKeyʱ���ڲ���֧�֣�����ʹ���ⲿ����

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

    //function GetBucket: PBucketDynArray;     // ����ͳ������(��ͻ/������)

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
    FRawList: IHkGenericsPLQS<T>;              // ԭʼ�����б�
  private
    FBucketSize: Cardinal;
    FComparer: THkCompareClass;
    FCount: integer;
    FHashBuckets: TDynBucketArray;             // ��ϣͰ
    FHashClass: THashClass;
    FZipPool: IHkGenericsPLQS<TOwlNode>;       // �����أ������������������ͷ�����ڵ��ڴ������
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
    constructor Create(                // ʹ���ڲ�����
      Capacity: integer = 64;
      KeyIndex: integer = 0;
      HashBucketSize: integer = 1024;
      HashFunc: TOnHashFunc = nil;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // ʹ���ڲ�����
      BindingList: IHkGenericsPLQS<T>;
      KeyIndex: integer = 0;
      HashBucketSize: integer = 1024;
      HashFunc: TOnHashFunc = nil;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // ʹ���ⲿȫ�ֺ���
      BindingList: IHkGenericsPLQS<T>;
      HashEvent: THkHashEventG;
      Comparer: THkComparerG;
      HashBucketSize: integer = 1024;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // ʹ���ⲿ�ຯ��
      BindingList: IHkGenericsPLQS<T>;
      HashEvent: THkHashEventC;
      Comparer: THkComparerC;
      HashBucketSize: integer = 1024;
      LockType: THkLockType = lktNone); overload;
    constructor Create(                // ʹ���ⲿ��������
      BindingList: IHkGenericsPLQS<T>;
      HashEvent: THkHashEventA;
      Comparer: THkComparerA;
      HashBucketSize: integer = 1024;
      LockType: THkLockType = lktNone); overload;
    destructor Destroy; override;
  end;

type
  // ԭHkCodeA��IHkMemoryBlock�ӿڡ�
  // �ṩ���ڴ�飬��Ҫ���ڲ���������(�ַ���)�Ĵ洢��ȱ���Ƿ���Ŀռ��޷��ջء�
  // ����ʹ�ã�����DnsHub��Ŀ��Log�Ĵ洢��
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

  // 2021.05.18��HkCodeD
  // THkMemoryStoreʹ��THkMemoryBlock�����ڴ������THkMemoryBlock������ڵ���
  // TSllPureNode������Data�������޷�������ڵ��ﱣ���ѷ����ֽ�(ԭHkCodeC���õ�
  // ����)���������û���������ǰ4���ֽڱ����ѷ������
  THkMemoryStore = class(TInterfacedObject, IHkMemoryStore)
  private
    FBlockCount: integer;                  // ������(������)
    FBlockSize: integer;                   // ÿ���ڴ��Ĵ�С(�û�����)
    FHead: POwlNode;                       // ����ͷ�ڵ㣬Data������ʾ���ѷ����ֽ�
    FFixed: boolean;                       // �̶���С
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
  // ֧�������������������
  //CN_Batchable_Kind: set of TTypeKind = [tkInteger, tkWString, tkUString];
  // IHkStdList�ڲ�֧�ֵ���������(��������)��ͬʱ������IHkHashedList(���ڼ����ϣֵ)
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
  // ����û����ݲ������������ͣ����账��
  ElementInfo := TypeInfo(T);
  Managed := IsManaged(ElementInfo);

  FLock.Enter;
  try
    if FActionClass.IsExtMethod or Managed then // ���������������Ұ������ݵĽڵ�
    begin
      Item := FLinkedList.Head;
      _Cleanup(Item);

      if FClearAllNode then // �����ѻ��սڵ�
      begin
        Item := FLinkedList.IdleHead;
        _Cleanup(Item);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

// ����б����������ѷ�����ڴ�飬δ����Ĳ��账��
// �൱�ڿͻ���ִ��Put/Remove/Dequeue����
// 1. ������ⲿ�������������ⲿ����ִ��
procedure THkGenericsPLQS<T>.Clear;
var
  Data: Pointer;
begin
  FLock.Enter;
  try
    // ������ʹ�õĽڵ�ȫ������
    // 2021.05.20
    // ֮ǰû�п��ǵ��б�Ϊ�յ����(FHead=nil)
    Data := FLinkedList.Head; // ��������û�������
    while Data <> nil do
    begin
      FActionClass.BeforePut(Data, TRUE); // ǿ������
      Data := FLinkedList.Next[Data];
    end;

    FLinkedList.Clear; // �������
  finally
    FLock.Leave;
  end;
end;

// Queueģʽ���൱��Put/Remove
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

// Queueģʽ���൱��Get/Add
function THkGenericsPLQS<T>.Enqueue(const Value: T): boolean;
begin
  FLock.Enter;
  try
    Result := AddItem(Value) <> nil;
  finally
    FLock.Leave;
  end;
end;

// Public����Ҫ����IHkStdList/IHkHashedList
procedure THkGenericsPLQS<T>.ExportValue(Src: Pointer; var Value: T);
begin
  //Value := THkElement<T>(Src^).Value; // ����Record������
  Value := T(Src^);
end;

// Poolģʽ
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

// �ٶ��������ã�
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

// Poolģʽ
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

// Listģʽ��ͬPoolģʽ��Put����
procedure THkGenericsPLQS<T>.Remove(Item: Pointer);
begin
  Put(Item);
end;

// ����ֻӰ���ڲ�������
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
  // ����������򣬲������Ƚ���(֮ǰֻ�ж�KeyIndex����)
  if Sorted and (KeyIndex <> -1) then // ��Ҫ�����ڲ��Ƚ���
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
    for PS in FRawList do // �ۼ�������(�����س���)
      Inc(Size, Length(PS^) + Length(LB));

    SetString(Result, nil, Size);
    P := Pointer(Result); // ָ��string������
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

// ��������ӵ������б�
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

// �ο�Delphi2007/XE Classes��ֻ֧��string�ͻس����з�
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

// ��Ҫ���ڶ��̣߳�ɾ����ͬʱ�����Ŀֵ
// ������IHkBasePLQS.Dequeue������һ���������������
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
  FRawList.Put(Item); // Remove�����Put����һ�ε���
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

// �ο�Delphi XE Classes��ֻ֧��string�ͻس����з�
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

// ֻ֧�ֻس����з�
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

    IsSorted := FSorted; // ����ԭʼ״̬
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

    FSorted := IsSorted; // �ָ�״̬
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

// �����������Ӳ�������ָ�룬�������Key�Ѵ��ڣ��򷵻��������ݵ�ָ��
// ֻ������ӳɹ����ŷ���TRUE�����򷵻�FALSE��Item��������Key������ָ��
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

// ʹ���ڲ�����
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

// ʹ���ڲ�����
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
  if not (Kind in [tkChar, tkWChar, tkLString, tkWString, tkUString]) then // ֻ֧���ַ���
    raise Exception.Create('Unsupport data type!');

  FComparer := THkCompareClassI.Create(Kind, Offset);
  if Assigned(HashFunc) then
    FHashClass := TStringHashClass.Create(Kind, Offset, FALSE, HashFunc)
  else FHashClass := TStringHashClass.Create(Kind, Offset, FALSE, BKDRHash); // �ַ���ȱʡ������JSHashҲ�ǲ����ѡ��
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

    Node.Next := FHashBuckets[BucketIndex]; // ��������ͷ��
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

// ��չ�ϣͰ
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

// ��Ҫ���ڶ��̣߳�ɾ����ͬʱ�����Ŀֵ(������IHkBasePLQS.Dequeue)
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

// �ڵ�ӹ�ϣͰ��������ժ�������ؽڵ��������ָ��
function THkHashedList<T>.RemoveFromBucket(BucketIndex: integer;
  Prev, Node: POwlNode): Pointer;
begin
  Result := Node.Data;

  if Prev = nil then // Ŀ����ͷ�ڵ�
    FHashBuckets[BucketIndex] := Node.Next // ��һ���ڵ���Ϊͷ�ڵ�
  else Prev.Next := Node.Next; // ��������ժ��Ŀ��ڵ�
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

  // ��֤��2���ݴΣ�����10000->16384
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
  while MB <> nil do // ������������Ƿ���ʣ��ռ�
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
    MB.Data := Pointer(SizeOf(TOwlNode)); // ��Ч������������ڽڵ����ݺ�
    MB.Next := FHead; // �·���Ŀ��������ͷ��
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
    Inc(P, SizeOf(TOwlNode)); // ָ���û�������
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
