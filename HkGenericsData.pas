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
  // IHkGenericsPLQS<T>使用的双向链表类
  // 取消延迟分配，采用双链表来分别保存已使用队列和空闲队列
  // 延迟分配和单链表队列的方式可以参考HkCodeE的代码
  THkLinkedList = class
  private
    FDataSize: integer;                        // 用户数据+附加数据的大小
    FExtraSize: integer;                       // 附加数据大小
    FItemSize: integer;                        // 用户数据大小
    FNodeSize: integer;                        // 节点大小(含用户数据/附加数据/链表节点)
  private
    FBlockCount, FMaxBlockCount: integer;      // 内存块数量(内存块链表长度)
    FBlockSize: integer;                       // 内存块大小
    FCapacity, FInitCapacity: integer;
    FHeapHandle: THandle;
    FMemoryBlock: POwlPureNode;                // 内存块的头节点
    function AllocMemBlock: PByte;
    function GrowNoDelay: boolean;
  private                                      // 链表基础结构
    FCount: integer;                           // 已分配数量
    FHead, FTail: PTwlPureNode;                // 已使用链表
    FIdle, FLast: PTwlPureNode;                // 空闲链表
    FUseAllocatedNodeFirst: boolean;           // 优先使用分配过的节点，缺省值为TRUE
    function GetHead: Pointer;                 // 读取已分配数据的头节点
    function GetIdleHead: Pointer;             // 读取空闲列表的头节点
    function GetNext(Item: Pointer): Pointer;  // 读取下一个记录
    function GetPrev(Item: Pointer): Pointer;  // 读取上一个记录
    function GetTail: Pointer;                 // 读取已分配数据的尾节点
  public
    constructor Create(Capacity, MaxCapacity, ItemSize, ExtraSize: integer;
      HeapHandle: THandle);
    destructor Destroy; override;

    procedure Clear;
    function RequireItem(var Item: Pointer): boolean; // Item：用户数据指针
    procedure ReturnItem(Item: Pointer);              // Item：用户数据指针

    property Capacity: integer read FCapacity;
    property Count: integer read FCount;
    function GetDataItem(ExtraItem: Pointer): Pointer; // 根据附加数据指针读取用户数据
    function GetExtraItem(Item: Pointer): Pointer;     // 读取附加数据指针
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

  FItemSize := ItemSize;                         // 用户数据大小(不含附加数据)
  FExtraSize := ExtraSize;
  FDataSize := ItemSize + ExtraSize;             // 用户数据大小(含附加数据)
  FNodeSize := FDataSize + SizeOf(TTwlPureNode); // 链表节点大小

  FInitCapacity := Capacity;                     // 初始容量
  FHeapHandle := TMemoryUtils.GetHeapHandle(HeapHandle);
  // 内存块单向链表 + 用户申请容量
  FBlockSize := Capacity * FNodeSize + SizeOf(TOwlPureNode);
  FMemoryBlock := nil;                           // 内存块链表头节点

  FBlockCount := 0;                              // 已申请的内存块数量
  if MaxCapacity <> 0 then                       // 最多可申请的内存块数量
  begin
    FMaxBlockCount := MaxCapacity div Capacity;
    if MaxCapacity mod Capacity <> 0 then
      Inc(FMaxBlockCount);
  end
  else FMaxBlockCount := 0; // 无限制

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

  // 插入内存块链表头部
  Inc(FBlockCount);
  POwlPureNode(Result).Next := FMemoryBlock;
  FMemoryBlock := POwlPureNode(Result);
end;

procedure THkLinkedList.Clear;
begin
  if FHead = nil then Exit;

  // 双链表的代码
  FTail.Next := FIdle; // 两个链表合并
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
    Result := PByte(ExtraItem) - FItemSize // 附加数据紧随在用户数据之后
  else Result := nil;
end;

function THkLinkedList.GetExtraItem(Item: Pointer): Pointer;
begin
  if (FExtraSize > 0) and (Item <> nil) then
    Result := PByte(Item) + FItemSize // 附加数据紧随在用户数据之后
  else Result := nil;
end;

// 返回用户数据指针
function THkLinkedList.GetHead: Pointer;
begin
  if FHead <> nil then
    Result := PByte(FHead) - FDataSize
  else Result := nil;
end;

// 用于IHkBasePLQS清理所有曾分配出去的节点
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

  // 双链表的代码
  Result := Node.Next;
  if Result <> nil then
    Result := PByte(Result) - FDataSize;
end;

function THkLinkedList.GetPrev(Item: Pointer): Pointer;
var
  Node: PTwlPureNode;
begin
  Node := PTwlPureNode(PByte(Item) + FDataSize);

  // 双链表的代码
  Result := Node.Prev;
  if Result <> nil then
    Result := PByte(Result) - FDataSize;
end;

// 返回用户数据指针
function THkLinkedList.GetTail: Pointer;
begin
  if FTail <> nil then
    Result := PByte(FTail) - FDataSize
  else Result := nil;
end;

// 非延迟分配的内存申请函数
function THkLinkedList.GrowNoDelay: boolean;
var
  i: integer;
  MB: PByte;
  Prev, Head, Tail: PTwlPureNode;
begin
  MB := AllocMemBlock;
  if MB = nil then Exit(FALSE);

  Inc(FCapacity, FInitCapacity);
  // 把内存块分割成用户双向链表。H为新链表头，T为新链表尾
  Inc(MB, SizeOf(TOwlPureNode) + FDataSize); // MB指向第一个链表节点
  Head := PTwlPureNode(MB); // 新内存块的头节点
  Head.Prev := nil;
  //Head.Allocated := FALSE;

  if FInitCapacity = 1 then // 内存块只包含一个节点
  begin
    Head.Next := nil;
    Tail := Head;
  end
  else begin
    Prev := Head; // 从第二个节点开始
    i := 1; // 链表长度
    repeat
      Inc(MB, FNodeSize); // 指向下一个节点
      Tail := PTwlPureNode(MB);
      //Tail.Allocated := FALSE;

      Tail.Prev := Prev;
      Prev.Next := Tail; // 如果前面设置 Prev := nil，这里就要做判断
      Prev := Tail;

      Inc(i);
    until i = FInitCapacity;
  end;

  Result := TRUE;
  // 双链表的代码
  // 调用本函数前，空闲链表已经为空，所以新增链表直接设为空闲链表
  Tail.Next := nil;
  FIdle := Head;
  FLast := Tail;
end;

// 申请节点，直接返回用户数据指针
function THkLinkedList.RequireItem(var Item: Pointer): boolean;
var
  Node: PTwlPureNode;
begin
  Result := FALSE;
  Item := nil;

  if FIdle = nil then // 链表扩容
  begin
    if not GrowNoDelay then
      Exit;
  end;

  //if FIdle.Allocated then
    //raise Exception.Create('Realloc Data Block!');

  // 双链表的代码
  Node := FIdle; // 待分配的节点

  FIdle := FIdle.Next;
  if FIdle <> nil then
    FIdle.Prev := nil;

  Node.Prev := FTail; // 节点移动到已分配链表的尾部
  Node.Next := nil;
  //Node.Allocated := TRUE;
  if FHead = nil then // 第一个被分配的节点
    FHead := Node
  else FTail.Next := Node;
  FTail := Node;

  Item := PByte(Node) - FDataSize;
  Inc(FCount);
  Result := TRUE;
end;

// 回收节点，参数是用户数据指针
procedure THkLinkedList.ReturnItem(Item: Pointer);
var
  Node: PTwlPureNode;
begin
  Node := PTwlPureNode(PByte(Item) + FDataSize);

  //if not Node.Allocated then
    //raise Exception.Create('Recycle Idle Data Block!');
  //Node.Allocated := FALSE;

  // 双链表的代码
  if Node = FHead then
  begin
    FHead := FHead.Next;
    if FHead <> nil then // 有多于一个已分配节点
      FHead.Prev := nil
    else FTail := nil; // 只有一个已分配节点，清空已分配链表
  end
  else if Node = FTail then // 已分配节点>=2
  begin
    FTail := FTail.Prev;
    FTail.Next := nil;
  end
  else begin // 节点位于中间位置，修改前后节点
    Node.Prev.Next := Node.Next;
    Node.Next.Prev := Node.Prev;
  end;

  if FUseAllocatedNodeFirst then // 插入空闲链表头部
  begin
    Node.Prev := nil;
    Node.Next := FIdle;
    if FIdle <> nil then
      FIdle.Prev := Node
    else FLast := Node;
    FIdle := Node;
  end
  else begin // 放到空闲列表的尾部
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
    Result := AllocMem(Size) // 内存初始化为0
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

// 输入参数HeapHandle的取值：
// 0：使用程序缺省堆
// > 0：使用指定的私有堆
// INVALID_HANDLE_VALUE：使用系统分配内存
class function TMemoryUtils.GetHeapHandle(HeapHandle: THandle): THandle;
begin
  if HeapHandle = 0 then
    Result := GetProcessHeap
  else Result := HeapHandle;
end;

end.
