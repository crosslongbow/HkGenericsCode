unit HkGenericsData;

{$include 'DelphiVersions.inc'}

interface

uses
  {$IFDEF HAS_UNIT_SCOPE}
  Winapi.Windows,
  {$ELSE}
  Windows,
  {$ENDIF HAS_UNIT_SCOPE}
  HkGenericsTypes;

type
  // IHkGenericsPLQS<T>ʹ�õ�˫��������
  // ȡ���ӳٷ��䣬����˫�������ֱ𱣴���ʹ�ö��кͿ��ж���
  // �ӳٷ���͵�������еķ�ʽ���Բο�HkCodeE�Ĵ���
  THkLinkedList = class
  private
    FDataSize: integer;                        // �û�����+�������ݵĴ�С
    FExtraSize: integer;                       // �������ݴ�С
    FItemSize: integer;                        // �û����ݴ�С
    FNodeSize: integer;                        // �ڵ��С(���û�����/��������/����ڵ�)
  private
    FBlockCount, FMaxBlockCount: integer;      // �ڴ������(�ڴ��������)
    FBlockSize: integer;                       // �ڴ���С
    FCapacity, FInitCapacity: integer;
    FHeapHandle: THandle;
    FMemoryBlock: POwlPureNode;                // �ڴ���ͷ�ڵ�
    function AllocMemBlock: PByte;
    function GrowNoDelay: boolean;
  private                                      // ��������ṹ
    FCount: integer;                           // �ѷ�������
    FHead, FTail: PTwlPureNode;                // ��ʹ������
    FIdle, FLast: PTwlPureNode;                // ��������
    FUseAllocatedNodeFirst: boolean;           // ����ʹ�÷�����Ľڵ㣬ȱʡֵΪTRUE
    function GetHead: Pointer;                 // ��ȡ�ѷ������ݵ�ͷ�ڵ�
    function GetIdleHead: Pointer;             // ��ȡ�����б��ͷ�ڵ�
    function GetNext(Item: Pointer): Pointer;  // ��ȡ��һ����¼
    function GetPrev(Item: Pointer): Pointer;  // ��ȡ��һ����¼
    function GetTail: Pointer;                 // ��ȡ�ѷ������ݵ�β�ڵ�
  public
    constructor Create(Capacity, MaxCapacity, ItemSize, ExtraSize: integer;
      HeapHandle: THandle);
    destructor Destroy; override;

    procedure Clear;
    function RequireItem(var Item: Pointer): boolean; // Item���û�����ָ��
    procedure ReturnItem(Item: Pointer);              // Item���û�����ָ��

    property Capacity: integer read FCapacity;
    property Count: integer read FCount;
    function GetDataItem(ExtraItem: Pointer): Pointer; // ���ݸ�������ָ���ȡ�û�����
    function GetExtraItem(Item: Pointer): Pointer;     // ��ȡ��������ָ��
    property Head: Pointer read GetHead;
    property IdleHead: Pointer read GetIdleHead;
    property InitCapacity: integer read FInitCapacity;
    property Next[Item: Pointer]: Pointer read GetNext;
    property Prev[Item: Pointer]: Pointer read GetPrev;
    property UseAllocatedNodeFirst: boolean write FUseAllocatedNodeFirst;
    property Tail: Pointer read GetTail;
  end;

  TMemoryUtils = class
    class function AllocMemBlock(Size: integer;
      HeapHandle: THandle = INVALID_HANDLE_VALUE): Pointer;
    class procedure FreeAllMemBlock(Head: Pointer;
      HeapHandle: THandle = INVALID_HANDLE_VALUE);
    class procedure FreeMemBlock(MB: Pointer;
      HeapHandle: THandle = INVALID_HANDLE_VALUE);
    class function GetHeapHandle(HeapHandle: THandle = INVALID_HANDLE_VALUE): THandle;
  end;

implementation

uses
  {$IFDEF HAS_UNIT_SCOPE}
  System.SysUtils;
  {$ELSE}
  SysUtils;
  {$ENDIF HAS_UNIT_SCOPE}

// =============================================================================
//  THkLinkedList
// =============================================================================

constructor THkLinkedList.Create(Capacity, MaxCapacity, ItemSize,
  ExtraSize: integer; HeapHandle: THandle);
begin
  inherited Create;

  FItemSize := ItemSize;                         // �û����ݴ�С(������������)
  FExtraSize := ExtraSize;
  FDataSize := ItemSize + ExtraSize;             // �û����ݴ�С(����������)
  FNodeSize := FDataSize + SizeOf(TTwlPureNode); // ����ڵ��С

  FInitCapacity := Capacity;                     // ��ʼ����
  FHeapHandle := TMemoryUtils.GetHeapHandle(HeapHandle);
  // �ڴ�鵥������ + �û���������
  FBlockSize := Capacity * FNodeSize + SizeOf(TOwlPureNode);
  FMemoryBlock := nil;                           // �ڴ������ͷ�ڵ�

  FBlockCount := 0;                              // ��������ڴ������
  if MaxCapacity <> 0 then                       // ����������ڴ������
  begin
    FMaxBlockCount := MaxCapacity div Capacity;
    if MaxCapacity mod Capacity <> 0 then
      Inc(FMaxBlockCount);
  end
  else FMaxBlockCount := 0; // ������

  GrowNoDelay;
  FUseAllocatedNodeFirst := TRUE;
end;

destructor THkLinkedList.Destroy;
begin
  TMemoryUtils.FreeAllMemBlock(FMemoryBlock, FHeapHandle);

  inherited;
end;

function THkLinkedList.AllocMemBlock: PByte;
begin
  if (FMaxBlockCount <> 0) and (FBlockCount >= FMaxBlockCount) then
    Exit(nil);

  Result := TMemoryUtils.AllocMemBlock(FBlockSize, FHeapHandle);
  if Result = nil then Exit;

  // �����ڴ������ͷ��
  Inc(FBlockCount);
  POwlPureNode(Result).Next := FMemoryBlock;
  FMemoryBlock := POwlPureNode(Result);
end;

procedure THkLinkedList.Clear;
begin
  if FHead = nil then Exit;

  // ˫����Ĵ���
  FTail.Next := FIdle; // ��������ϲ�
  if FIdle <> nil then
    FIdle.Prev := FTail;

  FIdle := FHead;
  FHead := nil;
  FTail := nil;
  FCount := 0;
end;

function THkLinkedList.GetDataItem(ExtraItem: Pointer): Pointer;
begin
  if (FExtraSize > 0) and (ExtraItem <> nil) then
    Result := PByte(ExtraItem) - FItemSize // �������ݽ������û�����֮��
  else Result := nil;
end;

function THkLinkedList.GetExtraItem(Item: Pointer): Pointer;
begin
  if (FExtraSize > 0) and (Item <> nil) then
    Result := PByte(Item) + FItemSize // �������ݽ������û�����֮��
  else Result := nil;
end;

// �����û�����ָ��
function THkLinkedList.GetHead: Pointer;
begin
  if FHead <> nil then
    Result := PByte(FHead) - FDataSize
  else Result := nil;
end;

// ����IHkBasePLQS���������������ȥ�Ľڵ�
function THkLinkedList.GetIdleHead: Pointer;
begin
  if FIdle = nil then
    Result := nil
  else Result := PByte(FIdle) - FDataSize;
end;

function THkLinkedList.GetNext(Item: Pointer): Pointer;
var
  Node: PTwlPureNode;
begin
  Node := PTwlPureNode(PByte(Item) + FDataSize);

  // ˫����Ĵ���
  Result := Node.Next;
  if Result <> nil then
    Result := PByte(Result) - FDataSize;
end;

function THkLinkedList.GetPrev(Item: Pointer): Pointer;
var
  Node: PTwlPureNode;
begin
  Node := PTwlPureNode(PByte(Item) + FDataSize);

  // ˫����Ĵ���
  Result := Node.Prev;
  if Result <> nil then
    Result := PByte(Result) - FDataSize;
end;

// �����û�����ָ��
function THkLinkedList.GetTail: Pointer;
begin
  if FTail <> nil then
    Result := PByte(FTail) - FDataSize
  else Result := nil;
end;

// ���ӳٷ�����ڴ����뺯��
function THkLinkedList.GrowNoDelay: boolean;
var
  i: integer;
  MB: PByte;
  Prev, Head, Tail: PTwlPureNode;
begin
  MB := AllocMemBlock;
  if MB = nil then Exit(FALSE);

  Inc(FCapacity, FInitCapacity);
  // ���ڴ��ָ���û�˫������HΪ������ͷ��TΪ������β
  Inc(MB, SizeOf(TOwlPureNode) + FDataSize); // MBָ���һ������ڵ�
  Head := PTwlPureNode(MB); // ���ڴ���ͷ�ڵ�
  Head.Prev := nil;
  //Head.Allocated := FALSE;

  if FInitCapacity = 1 then // �ڴ��ֻ����һ���ڵ�
  begin
    Head.Next := nil;
    Tail := Head;
  end
  else begin
    Prev := Head; // �ӵڶ����ڵ㿪ʼ
    i := 1; // ������
    repeat
      Inc(MB, FNodeSize); // ָ����һ���ڵ�
      Tail := PTwlPureNode(MB);
      //Tail.Allocated := FALSE;

      Tail.Prev := Prev;
      Prev.Next := Tail; // ���ǰ������ Prev := nil�������Ҫ���ж�
      Prev := Tail;

      Inc(i);
    until i = FInitCapacity;
  end;

  Result := TRUE;
  // ˫����Ĵ���
  // ���ñ�����ǰ�����������Ѿ�Ϊ�գ�������������ֱ����Ϊ��������
  Tail.Next := nil;
  FIdle := Head;
  FLast := Tail;
end;

// ����ڵ㣬ֱ�ӷ����û�����ָ��
function THkLinkedList.RequireItem(var Item: Pointer): boolean;
var
  Node: PTwlPureNode;
begin
  Result := FALSE;
  Item := nil;

  if FIdle = nil then // ��������
  begin
    if not GrowNoDelay then
      Exit;
  end;

  //if FIdle.Allocated then
    //raise Exception.Create('Realloc Data Block!');

  // ˫����Ĵ���
  Node := FIdle; // ������Ľڵ�

  FIdle := FIdle.Next;
  if FIdle <> nil then
    FIdle.Prev := nil;

  Node.Prev := FTail; // �ڵ��ƶ����ѷ��������β��
  Node.Next := nil;
  //Node.Allocated := TRUE;
  if FHead = nil then // ��һ��������Ľڵ�
    FHead := Node
  else FTail.Next := Node;
  FTail := Node;

  Item := PByte(Node) - FDataSize;
  Inc(FCount);
  Result := TRUE;
end;

// ���սڵ㣬�������û�����ָ��
procedure THkLinkedList.ReturnItem(Item: Pointer);
var
  Node: PTwlPureNode;
begin
  Node := PTwlPureNode(PByte(Item) + FDataSize);

  //if not Node.Allocated then
    //raise Exception.Create('Recycle Idle Data Block!');
  //Node.Allocated := FALSE;

  // ˫����Ĵ���
  if Node = FHead then
  begin
    FHead := FHead.Next;
    if FHead <> nil then // �ж���һ���ѷ���ڵ�
      FHead.Prev := nil
    else FTail := nil; // ֻ��һ���ѷ���ڵ㣬����ѷ�������
  end
  else if Node = FTail then // �ѷ���ڵ�>=2
  begin
    FTail := FTail.Prev;
    FTail.Next := nil;
  end
  else begin // �ڵ�λ���м�λ�ã��޸�ǰ��ڵ�
    Node.Prev.Next := Node.Next;
    Node.Next.Prev := Node.Prev;
  end;

  if FUseAllocatedNodeFirst then // �����������ͷ��
  begin
    Node.Prev := nil;
    Node.Next := FIdle;
    if FIdle <> nil then
      FIdle.Prev := Node
    else FLast := Node;
    FIdle := Node;
  end
  else begin // �ŵ������б��β��
    Node.Next := nil;
    Node.Prev := FLast;
    if FIdle = nil then
      FIdle := Node;
    FLast := Node;
  end;

  Dec(FCount);
end;

// =============================================================================
//  TMemoryUtils
// =============================================================================

class function TMemoryUtils.AllocMemBlock(Size: integer;
  HeapHandle: THandle): Pointer;
begin
  if HeapHandle = INVALID_HANDLE_VALUE then
    Result := AllocMem(Size) // �ڴ��ʼ��Ϊ0
  else Result := HeapAlloc(HeapHandle, HEAP_ZERO_MEMORY, Size);
end;

class procedure TMemoryUtils.FreeAllMemBlock(Head: Pointer;
  HeapHandle: THandle);
var
  MB, Next: POwlPureNode;
begin
  MB := Head;
  while MB <> nil do
  begin
    Next := MB.Next;
    FreeMemBlock(MB, HeapHandle);

    MB := Next;
  end;
end;

class procedure TMemoryUtils.FreeMemBlock(MB: Pointer; HeapHandle: THandle);
begin
  if HeapHandle = INVALID_HANDLE_VALUE then
    FreeMem(MB)
  else HeapFree(HeapHandle, 0, MB);
end;

// �������HeapHandle��ȡֵ��
// 0��ʹ�ó���ȱʡ��
// > 0��ʹ��ָ����˽�ж�
// INVALID_HANDLE_VALUE��ʹ��ϵͳ�����ڴ�
class function TMemoryUtils.GetHeapHandle(HeapHandle: THandle): THandle;
begin
  if HeapHandle = 0 then
    Result := GetProcessHeap
  else Result := HeapHandle;
end;

end.
