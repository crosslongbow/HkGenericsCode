unit HkGenericsTree;

(*
 * 修改IHkBasePLQS(增加附加数据)后的树形接口。
 * 测试后并入HkCodeC代码。
 *
 * 项目里经常遇到使用树形结构的场合，比如：磁盘目录，DiskCatalog的虚拟目录树等。
 * 使用StdList可以做到快速查找，但是对树形结构没有任何优化，像读取同级目录，或者
 * 读取所有子目录等操作都比较麻烦，无一例外只能遍历。
 * 基于PLQS内部的附加信息块(ExtraItem)，HkGenericsTree额外保存了树形数据，从而在
 * 排序列表的基础上提供了对树形结构的支持，尤其是BFS/DFS遍历。
 * HkGenericsTree的核心数据是StdList，元素的修改/移动/删除比较特殊：
 * - 修改：如果是磁盘目录等以名称为Key，修改名称时需要考虑子目录名称的同步修改
 * - 移动：同修改
 * - 删除：树形节点的删除需要删除其下所有叶子
 *
 *
 * 2021.01.10
 * 初版
 * 主数据是IHkBasePLQS，排序列表一般用于搜索。
 * 数据添加时必须提供父节点。
 *
 * 2021.01.11
 * 排序列表作为主数据：
 * 1. 添加数据时操作主体是排序列表
 * 2. 不提供IHkBasePLQS属性，可通过排序列表读取
 * 3. 大批量添加数据时采用BeginUpdate/EndUpdate函数
 *
 * 对于数据的添加方式：
 * 现有方式适合磁盘目录数据，添加时按照树的结构从根到叶一层层进行(类似BFS遍历)，
 * 称之为顺序数据。
 * 但是对于乱序的数据，比如DiskCatalog的虚拟目录树，就难以处理。所以，考虑使用另
 * 一种添加方法，称为乱序数据：
 * 1. 首先读入所有原始数据，标注根节点和非根节点，不处理节点关系；
 * 2. 读入后排序，目的是快速查找父节点，所以排序未必以Key排序，必要时需要提供排
 *    序函数
 * 3. 从头开始遍历排序列表，根节点无需处理，非根节点提供数据指针和排序列表，由外
 *    部函数查找父节点，并返回父节点指针；
 * 4. 根据父节点数据指针，逐一处理节点关系。
 *
 * 乱序数据要求：
 * 1. 必须使用排序列表，Key无重复值，用于查找父节点；
 * 2. 必须由特定函数开始/结束(BeginUpdate/EndUpdate)。
 *
 * 总结：
 * 1. 无论是何种数据，均建议使用BeginUpdate/EndUpdate。乱序数据是必须，而顺序数
 *    据则是采用先写数据再排序的方法，效率更高
 * 2. 尽量使用顺序数据 ，效率较高
 *
 * 2021.01.12
 * 增加删除/修改功能。
 * 修改功能：用于磁盘目录树不要使用该功能！因为磁盘目录树一般使用目录路径作为Key，
 *           修改目录名后其子目录路径并不会同时改名。
 *
 *
 * 2021.08.04
 * 以HkGenericsCode为基础重置。
 *
 *
 * 2021.08.05
 * 关于函数：function ChangeItem(OldItem: Pointer; const NewItem: T): boolean;
 *   修改是指修改Key数据(譬如子目录改名)，有两种方法：
 *   1. 直接用新数据覆盖旧数据，然后对排序列表重排序；
 *   2. 新数据作为新节点添加，把旧数据的树形信息复制到新数据里，然后替换父节点的
 *      子节点链表里的旧数据，还要遍历旧数据的子节点链表，修改所有子节点的父节点
 *
 * 前者代码简单，但是需要重排序；后者代码复杂，增加删除记录需要移动内存2次。
 * 哪种效率更高不好判断，这里采用前者(以前的代码使用了后者)
 *
 * 使用第一种方法的话，修改旧数据的步骤由用户外部完成，包括避免数据重复的检查等，
 * 本接口仅处理数据修改后的重新排序，所以接口函数也需要修改：
 * 1. 无需ChangeItem函数
 * 2. 使用Resort函数
 *
 *
 * 2021.08.08
 * 取消对多个根节点的支持，一个接口只能而且必须有一个根节点。
 *
 *
 * 2021.11.21
 * IHkStdList修改了比较器的使用，Tree做同步修改。
 * 取消乱序导入数据。
 *)

{$include 'DelphiVersions.inc'}

interface

uses
  {$IFDEF HAS_UNIT_SCOPE}
  System.SysUtils,
  {$ELSE}
  SysUtils,
  {$ENDIF HAS_UNIT_SCOPE}
  HkGenericsCode, HkGenericsTypes;

type
  // 遍历目录时读取每个项目时调用的函数
  TTraverseEventA = reference to procedure(Item: Pointer; var MoveNext: boolean);
  TTraverseEventC = procedure(Item: Pointer; var MoveNext: boolean) of Object;

  IGenericsTree<T> = interface
    function GetChildCount(Item: Pointer): integer;
    function GetCount: integer;            // 树节点总数
    function GetFirstChild(Item: Pointer): Pointer;
    function GetList: IHkStdList<T>;       // 读取排序列表
    function GetNextSibling(Item: Pointer): Pointer;
    function GetParent(Item: Pointer): Pointer; // 读取父数据
    function GetRoot: Pointer;             // 读取根节点
    function GetSiblingCount(Item: Pointer): integer;
    // 遍历(Traverse)
    procedure BFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventA;
      ChildOnly: boolean = FALSE); overload;
    procedure BFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventC;
      ChildOnly: boolean = FALSE); overload;
    procedure DFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventA;
      ChildOnly: boolean = FALSE); overload;
    procedure DFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventC;
      ChildOnly: boolean = FALSE); overload;

    function Add(const Value: T; Parent: Pointer): Pointer;
    procedure BeginUpdate;                 // 乱序数据导入的起始函数
    procedure Clear;
    function Contains(const Key: array of const): Pointer; overload;
    function Contains(var Value: T; const Key: array of const): boolean; overload;
    procedure EndUpdate;
    function Move(Item, NewParent: Pointer): boolean;
    function Remove(Item: Pointer): integer; overload;
    function Remove(const Key: array of const): integer; overload;
    procedure Resort;                      // 修改/移动数据后重新排序

    property ChildCount[Item: Pointer]: integer read GetChildCount;
    property Count: integer read GetCount;
    property FirstChild[Item: Pointer]: Pointer read GetFirstChild;
    property List: IHkStdList<T> read GetList;
    property NextSibling[Item: Pointer]: Pointer read GetNextSibling;
    property Parent[Item: Pointer]: Pointer read GetParent;
    property Root: Pointer read GetRoot;
    property SiblingCount[Item: Pointer]: integer read GetSiblingCount;
  end;

  TGenericsTree<T> = class(TInterfacedObject, IGenericsTree<T>)
  private type
    PBaseTreeItem = ^TBaseTreeItem;
    TBaseTreeItem = packed record          // 20 bytes(x86)
      Parent: PBaseTreeItem;               // 父目录
      NextSibling: PBaseTreeItem;          // 同层目录链表
      Children: PBaseTreeItem;             // 子目录链表。倒序
      ChildCount: integer;                 // 子目录数量
      LastChild: PBaseTreeItem;            // 如果需要按加入的顺序排列则使用该项目
    end;
  private
    FItemPool: IHkGenericsPLQS<T>;         // THkTreeItem数据池
    FList: IHkStdList<T>;                  // 排序列表
    FRoot: Pointer;                        // 唯一根节点
    procedure BFSGetChildren(Item: PBaseTreeItem;
      const Queue: IHkGenericsPLQS<Pointer>);
    function BFSGetQueue(Item: Pointer; ChildOnly: boolean): IHkGenericsPLQS<Pointer>;
    function DFSGetNext(Current, Root: PBaseTreeItem): PBaseTreeItem;
    procedure SetParent(Child, Parent: PBaseTreeItem);
  private                                  // IGenericsTree<T>
    function GetChildCount(Item: Pointer): integer;
    function GetCount: integer;            // 树节点总数
    function GetFirstChild(Item: Pointer): Pointer;
    function GetList: IHkStdList<T>;       // 读取排序列表
    function GetNextSibling(Item: Pointer): Pointer;
    function GetParent(Item: Pointer): Pointer; // 读取父数据
    function GetRoot: Pointer;             // 读取第一个根节点
    function GetSiblingCount(Item: Pointer): integer;
  private                                  // IGenericsTree<T>
    procedure BFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventA;
      ChildOnly: boolean = FALSE); overload;
    procedure BFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventC;
      ChildOnly: boolean = FALSE); overload;
    procedure DFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventA;
      ChildOnly: boolean = FALSE); overload;
    procedure DFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventC;
      ChildOnly: boolean = FALSE); overload;
  public                                   // IGenericsTree<T>
    function Add(const Value: T; Parent: Pointer): Pointer;
    procedure BeginUpdate;                 // 
    procedure Clear;
    function Contains(const Key: array of const): Pointer; overload;
    function Contains(var Value: T; const Key: array of const): boolean; overload;
    procedure EndUpdate;
    function Move(Item, NewParent: Pointer): boolean;
    function Remove(Item: Pointer): integer; overload;
    function Remove(const Key: array of const): integer; overload;
    procedure Resort;                      // 修改数据后重新排序
  public
    constructor Create(Capacity: integer = 4096; KeyIndex: integer = 0); overload;
    constructor Create(                    // 匿名比较函数
      ItemComparer: THkComparerA;
      Capacity: integer = 4096); overload;
    constructor Create(                    // 类比较函数
      ItemComparer: THkComparerC;
      Capacity: integer = 4096); overload;
    constructor Create(                    // 全局比较函数
      ItemComparer: THkComparerG;
      Capacity: integer = 4096); overload;
  end;

// 以下定义用于磁盘目录的读取，也是Tree接口最常用的场合。
// 磁盘目录读取，一般注意两个问题：
// 1. 采用FindFirst/FindNext函数时需要调用外部函数写入Tree接口，因为接口不知道
//    <T>参数的细节；
// 2. 在读取目录树后，可能需要统计目录信息(子目录/文件等)，同样需要外部函数
// 外部函数，使用匿名方法是比较方便的，但是匿名函数的效率比较低，而读取大目录树
// 的话对效率还是有要求的，所以比较鸡肋，不如直接在外部使用FindFirst/FindNext。
// 最终放弃做磁盘目录派生接口的打算。

type
  // IsFolder：SR查找项目是目录，回调函数返回时，IsFolder表示是有效的子目录，需
  // 要加入待遍历列表
  TSearchEvent = reference to procedure(var IsFolder: boolean;
    var Parent: string; const SR: TSearchRec);

procedure DF(const Folder: string; const SearchEvent: TSearchEvent);

implementation

// =============================================================================
//  独立函数
//  DF：Disk Folder，读取磁盘目录树
// =============================================================================

procedure DF(const Folder: string; const SearchEvent: TSearchEvent);
var
  List: IHkGenericsPLQS<string>; // 目录列表
  found: integer;
  IsFolder: boolean;
  SR: TSearchRec;
  s, Parent: string;
begin
  List := THkGenericsPLQS<string>.Create(1024);
  List.Enqueue(Folder);

  while List.Dequeue(Parent) do
  begin
    found := FindFirst(Parent + '\*.*', faAnyFile, SR);
    while found = 0 do
    begin
      s := Parent;
      IsFolder := SR.Attr and faDirectory <> 0;
      SearchEvent(IsFolder, s, SR);
      if IsFolder then // 有效子目录，添加到列表
        List.Enqueue(s);

      found := FindNext(SR); // 查找下一个
    end;
    System.SysUtils.FindClose(SR);
  end;
end;

// =============================================================================
//  TGenericsTree<T>
// =============================================================================

constructor TGenericsTree<T>.Create(Capacity, KeyIndex: integer);
begin
  inherited Create;

  FItemPool := THkGenericsPLQS<T>.Create(Capacity, 0, INVALID_HANDLE_VALUE,
    lktNone, SizeOf(TBaseTreeItem));
  FList := THkStdList<T>.Create(FItemPool, TRUE, KeyIndex);
end;

constructor TGenericsTree<T>.Create(ItemComparer: THkComparerA;
  Capacity: integer);
begin
  inherited Create;

  FItemPool := THkGenericsPLQS<T>.Create(Capacity, 0, INVALID_HANDLE_VALUE,
    lktNone, SizeOf(TBaseTreeItem));
  FList := THkStdList<T>.Create(FItemPool, ItemComparer, TRUE);
end;

constructor TGenericsTree<T>.Create(ItemComparer: THkComparerC;
  Capacity: integer);
begin
  inherited Create;

  FItemPool := THkGenericsPLQS<T>.Create(Capacity, 0, INVALID_HANDLE_VALUE,
    lktNone, SizeOf(TBaseTreeItem));
  FList := THkStdList<T>.Create(FItemPool, ItemComparer, TRUE);
end;

constructor TGenericsTree<T>.Create(ItemComparer: THkComparerG;
  Capacity: integer);
begin
  inherited Create;

  FItemPool := THkGenericsPLQS<T>.Create(Capacity, 0, INVALID_HANDLE_VALUE,
    lktNone, SizeOf(TBaseTreeItem));
  FList := THkStdList<T>.Create(FItemPool, ItemComparer, TRUE);
end;

function TGenericsTree<T>.Add(const Value: T; Parent: Pointer): Pointer;
var
  TreeItem, ParentTreeItem: PBaseTreeItem;
begin
  if (Parent = nil) and (FRoot <> nil) then
    raise Exception.Create('Duplicated Root!');
  if FList.Add(Value, Result) = -1 then Exit;

  if Parent <> nil then
  begin
    ParentTreeItem := FItemPool.GetExtraItem(Parent);
    TreeItem := FItemPool.GetExtraItem(Result);
    SetParent(TreeItem, ParentTreeItem);
  end
  else FRoot := Result; // 添加的是Root
end;

procedure TGenericsTree<T>.BeginUpdate;
begin
  FList.Sorted := FALSE;
end;

procedure TGenericsTree<T>.BFSGetChildren(Item: PBaseTreeItem;
  const Queue: IHkGenericsPLQS<Pointer>);
begin
  Item := Item.Children;
  while Item <> nil do
  begin
    Queue.Enqueue(Item);
    Item := Item.NextSibling;
  end;
end;

// 生成遍历根节点队列
// 1. 如果Item<>nil：
//    - ChildOnly，加入该节点所有子节点
//    - 否则加入该节点即可
// 2. 如果Item=nil：
//    - ChildOnly，加入Root节点的子节点
//    - 否则加入Root节点
function TGenericsTree<T>.BFSGetQueue(Item: Pointer;
  ChildOnly: boolean): IHkGenericsPLQS<Pointer>;
var
  TreeItem: PBaseTreeItem;
begin
  Result := THkGenericsPLQS<Pointer>.Create(FItemPool.Capacity); // PBaseTreeItem

  if Item = nil then
    TreeItem := FItemPool.GetExtraItem(FRoot)
  else TreeItem := FItemPool.GetExtraItem(Item);

  if ChildOnly then
    BFSGetChildren(TreeItem, Result)
  else Result.Enqueue(TreeItem);
end;

// 遍历指定路径的目录(Breadth First Search，广度优先)。Item=nil表示从根目录开始
procedure TGenericsTree<T>.BFSTraverse(Item: Pointer;
  TreeItemEvent: TTraverseEventA; ChildOnly: boolean);
var
  P: Pointer;
  TreeItem: PBaseTreeItem;
  Queue: IHkGenericsPLQS<Pointer>;
  MoveNext: boolean;
begin
  if (not Assigned(TreeItemEvent)) or (FItemPool.Count = 0) then Exit;

  Queue := BFSGetQueue(Item, ChildOnly);
  if Queue.Count = 0 then Exit;

  MoveNext := TRUE;
  while Queue.Dequeue(P) do
  begin
    TreeItem := P;
    Item := FItemPool.GetDataItem(TreeItem);
    TreeItemEvent(Item, MoveNext); // 处理有效节点
    if not MoveNext then Break;

    BFSGetChildren(TreeItem, Queue);
  end;
end;

// 遍历指定路径的目录(Breadth First Search，广度优先)。Item=nil表示从根目录开始
procedure TGenericsTree<T>.BFSTraverse(Item: Pointer;
  TreeItemEvent: TTraverseEventC; ChildOnly: boolean);
var
  P: Pointer;
  TreeItem: PBaseTreeItem;
  Queue: IHkGenericsPLQS<Pointer>;
  MoveNext: boolean;
begin
  if (not Assigned(TreeItemEvent)) or (FItemPool.Count = 0) then Exit;

  Queue := BFSGetQueue(Item, ChildOnly);
  if Queue.Count = 0 then Exit;

  MoveNext := TRUE;
  while Queue.Dequeue(P) do
  begin
    TreeItem := P;
    Item := FItemPool.GetDataItem(TreeItem);
    TreeItemEvent(Item, MoveNext); // 处理有效节点
    if not MoveNext then Break;

    BFSGetChildren(TreeItem, Queue);
  end;
end;

procedure TGenericsTree<T>.Clear;
begin
  FRoot := nil;
  FList.Clear;
end;

function TGenericsTree<T>.Contains(var Value: T;
  const Key: array of const): boolean;
begin
  Result := FList.Contains(Value, Key);
end;

function TGenericsTree<T>.Contains(const Key: array of const): Pointer;
begin
  Result := FList.Contains(Key);
end;

// 深度优先遍历，按照先下(子目录)再右(同级目录)的原则读取下一个节点
function TGenericsTree<T>.DFSGetNext(Current, Root: PBaseTreeItem): PBaseTreeItem;
begin
  Result := nil;

  if Current.Children <> nil then // 先往下
    Result := Current.Children
  else if Current.NextSibling <> nil then // 再往右
    Result := Current.NextSibling
  else begin // 返回上级
    repeat
      Current := Current.Parent;
    until (Current = Root) or (Current.NextSibling <> nil);

    if Current <> Root then
      Result := Current.NextSibling;
  end;
end;

// 遍历指定路径的目录(Depth First Search，深度优先)。
// 从根节点开始，按照先下(子目录)再右(同级目录)的原则遍历目录树，如果没有有效节
// 点则返回上一级，直到返回根目录。
procedure TGenericsTree<T>.DFSTraverse(Item: Pointer;
  TreeItemEvent: TTraverseEventA; ChildOnly: boolean);
var
  Root, TreeItem: PBaseTreeItem;
  MoveNext: boolean;
begin
  if (not Assigned(TreeItemEvent)) or (FItemPool.Count = 0) then Exit;

  // DFS的结束由DFSGetNext函数确定，回到根目录就停止
  if Item = nil then // 根节点
    Root := FItemPool.GetExtraItem(FRoot)
  else Root := FItemPool.GetExtraItem(Item);

  MoveNext := TRUE;
  if not ChildOnly then // 处理根节点
  begin
    Item := FItemPool.GetDataItem(Root);
    TreeItemEvent(Item, MoveNext);
  end;
  if not MoveNext then Exit;

  TreeItem := Root.Children;
  while TreeItem <> nil do
  begin
    Item := FItemPool.GetDataItem(TreeItem);
    TreeItemEvent(Item, MoveNext); // 处理有效节点
    if not MoveNext then Break;

    TreeItem := DFSGetNext(TreeItem, Root);
  end;
end;

// 遍历指定路径的目录(Depth First Search，深度优先)。
// 从根节点开始，按照先下(子目录)再右(同级目录)的原则遍历目录树，如果没有有效节
// 点则返回上一级，直到返回根目录。
procedure TGenericsTree<T>.DFSTraverse(Item: Pointer;
  TreeItemEvent: TTraverseEventC; ChildOnly: boolean);
var
  Root, TreeItem: PBaseTreeItem;
  MoveNext: boolean;
begin
  if (not Assigned(TreeItemEvent)) or (FItemPool.Count = 0) then Exit;

  // DFS的结束由DFSGetNext函数确定，回到根目录就停止，所以必须每个根目录逐个处理
  if Item = nil then // 所有根节点
    Root := FItemPool.GetExtraItem(FRoot)
  else Root := FItemPool.GetExtraItem(Item);

  MoveNext := TRUE;
  if not ChildOnly then // 处理根节点
  begin
    Item := FItemPool.GetDataItem(Root);
    TreeItemEvent(Item, MoveNext);
  end;
  if not MoveNext then Exit;

  TreeItem := Root.Children;
  while TreeItem <> nil do
  begin
    Item := FItemPool.GetDataItem(TreeItem);
    TreeItemEvent(Item, MoveNext); // 处理有效节点
    if not MoveNext then Break;

    TreeItem := DFSGetNext(TreeItem, Root);
  end;
end;

procedure TGenericsTree<T>.EndUpdate;
begin
  FList.Sorted := TRUE; // 恢复原有排序
end;

// Item=nil时，读取Root数量
function TGenericsTree<T>.GetChildCount(Item: Pointer): integer;
var
  TreeItem: PBaseTreeItem;
begin
  if Item <> nil then
  begin
    TreeItem := FItemPool.GetExtraItem(Item);
    Result := TreeItem.ChildCount;
  end
  else if FRoot <> nil then
    Result := 1
  else Result := 0;
end;

function TGenericsTree<T>.GetCount: integer;
begin
  Result := FItemPool.Count;
end;

// Item=nil时，读取Root
function TGenericsTree<T>.GetFirstChild(Item: Pointer): Pointer;
var
  TreeItem: PBaseTreeItem;
begin
  if Item <> nil then
  begin
    TreeItem := FItemPool.GetExtraItem(Item);
    Result := FItemPool.GetDataItem(TreeItem.Children);
  end
  else Result := FRoot; // Root
end;

function TGenericsTree<T>.GetList: IHkStdList<T>;
begin
  Result := FList;
end;

function TGenericsTree<T>.GetNextSibling(Item: Pointer): Pointer;
var
  TreeItem: PBaseTreeItem;
begin
  if Item <> nil then
  begin
    TreeItem := FItemPool.GetExtraItem(Item);
    Result := FItemPool.GetDataItem(TreeItem.NextSibling);
  end
  else Result := nil;
end;

function TGenericsTree<T>.GetParent(Item: Pointer): Pointer;
var
  TreeItem: PBaseTreeItem;
begin
  if Item <> nil then
  begin
    TreeItem := FItemPool.GetExtraItem(Item);
    Result := FItemPool.GetDataItem(TreeItem.Parent);
  end
  else Result := nil;
end;

function TGenericsTree<T>.GetRoot: Pointer;
begin
  Result := FRoot;
end;

function TGenericsTree<T>.GetSiblingCount(Item: Pointer): integer;
var
  Parent: PBaseTreeItem;
begin
  if Item <> nil then
  begin
    Parent := PBaseTreeItem(FItemPool.GetExtraItem(Item)).Parent;
    if Parent = nil then
      Result := 1
    else Result := Parent.ChildCount;
  end
  else Result := 1;
end;

function TGenericsTree<T>.Move(Item, NewParent: Pointer): boolean;
begin
  SetParent(FItemPool.GetExtraItem(Item), FItemPool.GetExtraItem(NewParent));
end;

// 返回值是删除项目的总数
function TGenericsTree<T>.Remove(const Key: array of const): integer;
var
  Item: Pointer;
begin
  Item := Contains(Key);
  if Item <> nil then
    Result := Remove(Item)
  else Result := 0;
end;

// 返回值是删除项目的总数
function TGenericsTree<T>.Remove(Item: Pointer): integer;
var
  List: IHkGenericsPLQS<Pointer>;
begin
  List := THkGenericsPLQS<Pointer>.Create(256);
  DFSTraverse(Item,
    procedure(Data: Pointer; var MoveNext: boolean)
    begin
      List.Push(Data);
    end);

  Result := List.Count;
  while List.Pop(Item) do
    FList.Remove(Item);
end;

// 列表重新排序。一般用于外部修改Key数据之后(譬如目录改名)
procedure TGenericsTree<T>.Resort;
begin
  FList.Sorted := FALSE;
  FList.Sorted := TRUE;
end;

procedure TGenericsTree<T>.SetParent(Child, Parent: PBaseTreeItem);
begin
  Child.Parent := Parent;
  if Parent.Children = nil then // 第一个子节点
    Parent.Children := Child
  else Parent.LastChild.NextSibling := Child;
  Parent.LastChild := Child;
  //Item.NextSibling := Parent.Children; // 插入链表头部
  //Parent.Children := Item;
  Inc(Parent.ChildCount);
end;

end.
