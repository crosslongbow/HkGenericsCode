unit HkGenericsTypes;

{$include 'DelphiVersions.inc'}

interface

type
  // 基础链表定义。HkCodeD开始使用
  // 单向链表: One-way Linked List，缩写Owl
  // 双向链表: Two-way Linked List，缩写Twl
  POwlPureNode = ^TOwlPureNode;
  TOwlPureNode = record
    Next: POwlPureNode;
  end;

  POwlNode = ^TOwlNode;
  TOwlNode = record
    Next: POwlNode;
    Data: Pointer;
  end;

  // 和用户数据绑定的双向链表节点
  PTwlPureNode = ^TTwlPureNode;
  TTwlPureNode = record
    Next, Prev: PTwlPureNode;
    //Allocated: boolean; // 该数据块是否已经被分配，2021.04.29
  end;

  PTwlNode = ^TTwlNode;
  TTwlNode = record
    Next, Prev: PTwlNode;
    Data: Pointer;
  end;

  TDynIntegerArray = array of integer;
  TDynPointerArray = array of Pointer;
  TDynBucketArray = array of POwlNode;
  PDynBucketArray = ^TDynBucketArray;

  THkLockType = (lktNone, lktCS, lktSpinLock);
  THkActionType = (atpAfterGet, atpBeforePut, atpRelease);

  // 以下分别是：全局函数，类成员函数，匿名函数
  THkActionEventG = procedure(Action: THkActionType; Item: Pointer);
  THkActionEventC = procedure(Action: THkActionType; Item: Pointer) of Object;
  THkActionEventA = reference to procedure(Action: THkActionType; Item: Pointer);

  // 接口内部调用参数为"T"的函数时，不能使用具体的参数类型
  // SetText函数调用Add添加字符串必须通过外部处理
  TSetTextEvent = reference to procedure(const Value: string);

  // 辅助参数，原本用于赋值/清空，后来发现了更简单的方法(以下Item为用户数据指针)：
  // Action    THkElement<T>方法                                最终方法
  // ===========================================================================
  // Export    T := THkElement<T>(Item^).Value;                 T := T(Item^);
  // Import    THkElement<T>(Item^).Value := T;                 T(Item^) := T;
  // BeforePut THkElement<T>(Item^) := Default(THkElement<T>);  T(Item^) := Default(T);
  // 所以这个定义是辅助的，可以不用
  {THkElement<T> = record
    Value: T;
  end;}
  //PHkElement = ^THkElement<T>; // 无法编译

  // 以下分别是：全局函数，类函数，匿名函数。
  // Left是内部数据的指针，Right是内部数据或<T>参数的指针
  THkComparerG = function(Left, Right: Pointer; const Key: array of const): integer;
  THkComparerC = function(Left, Right: Pointer; const Key: array of const): integer of Object;
  THkComparerA = reference to function(Left, Right: Pointer; const Key: array of const): integer;

  // 用于IHkHashedList的哈希计算函数，HkCodeD开始使用
  // 以下分别是：全局函数，类函数，匿名函数。
  THkHashEventG = function(Item: Pointer; const Key: array of const): Cardinal;
  THkHashEventC = function(Item: Pointer; const Key: array of const): Cardinal of Object;
  THkHashEventA = reference to function(Item: Pointer; const Key: array of const): Cardinal;

implementation

end.
