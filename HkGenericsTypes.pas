unit HkGenericsTypes;

{$include 'DelphiVersions.inc'}

interface

type
  // ���������塣HkCodeD��ʼʹ��
  // ��������: One-way Linked List����дOwl
  // ˫������: Two-way Linked List����дTwl
  POwlPureNode = ^TOwlPureNode;
  TOwlPureNode = record
    Next: POwlPureNode;
  end;

  POwlNode = ^TOwlNode;
  TOwlNode = record
    Next: POwlNode;
    Data: Pointer;
  end;

  // ���û����ݰ󶨵�˫������ڵ�
  PTwlPureNode = ^TTwlPureNode;
  TTwlPureNode = record
    Next, Prev: PTwlPureNode;
    //Allocated: boolean; // �����ݿ��Ƿ��Ѿ������䣬2021.04.29
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

  // ���·ֱ��ǣ�ȫ�ֺ��������Ա��������������
  THkActionEventG = procedure(Action: THkActionType; Item: Pointer);
  THkActionEventC = procedure(Action: THkActionType; Item: Pointer) of Object;
  THkActionEventA = reference to procedure(Action: THkActionType; Item: Pointer);

  // �ӿ��ڲ����ò���Ϊ"T"�ĺ���ʱ������ʹ�þ���Ĳ�������
  // SetText��������Add����ַ�������ͨ���ⲿ����
  TSetTextEvent = reference to procedure(const Value: string);

  // ����������ԭ�����ڸ�ֵ/��գ����������˸��򵥵ķ���(����ItemΪ�û�����ָ��)��
  // Action    THkElement<T>����                                ���շ���
  // ===========================================================================
  // Export    T := THkElement<T>(Item^).Value;                 T := T(Item^);
  // Import    THkElement<T>(Item^).Value := T;                 T(Item^) := T;
  // BeforePut THkElement<T>(Item^) := Default(THkElement<T>);  T(Item^) := Default(T);
  // ������������Ǹ����ģ����Բ���
  {THkElement<T> = record
    Value: T;
  end;}
  //PHkElement = ^THkElement<T>; // �޷�����

  // ���·ֱ��ǣ�ȫ�ֺ������ຯ��������������
  // Left���ڲ����ݵ�ָ�룬Right���ڲ����ݻ�<T>������ָ��
  THkComparerG = function(Left, Right: Pointer; const Key: array of const): integer;
  THkComparerC = function(Left, Right: Pointer; const Key: array of const): integer of Object;
  THkComparerA = reference to function(Left, Right: Pointer; const Key: array of const): integer;

  // ����IHkHashedList�Ĺ�ϣ���㺯����HkCodeD��ʼʹ��
  // ���·ֱ��ǣ�ȫ�ֺ������ຯ��������������
  THkHashEventG = function(Item: Pointer; const Key: array of const): Cardinal;
  THkHashEventC = function(Item: Pointer; const Key: array of const): Cardinal of Object;
  THkHashEventA = reference to function(Item: Pointer; const Key: array of const): Cardinal;

implementation

end.
