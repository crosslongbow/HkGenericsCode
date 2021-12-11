unit HkGenericsTree;

(*
 * �޸�IHkBasePLQS(���Ӹ�������)������νӿڡ�
 * ���Ժ���HkCodeC���롣
 *
 * ��Ŀ�ﾭ������ʹ�����νṹ�ĳ��ϣ����磺����Ŀ¼��DiskCatalog������Ŀ¼���ȡ�
 * ʹ��StdList�����������ٲ��ң����Ƕ����νṹû���κ��Ż������ȡͬ��Ŀ¼������
 * ��ȡ������Ŀ¼�Ȳ������Ƚ��鷳����һ����ֻ�ܱ�����
 * ����PLQS�ڲ��ĸ�����Ϣ��(ExtraItem)��HkGenericsTree���Ᵽ�����������ݣ��Ӷ���
 * �����б��Ļ������ṩ�˶����νṹ��֧�֣�������BFS/DFS������
 * HkGenericsTree�ĺ���������StdList��Ԫ�ص��޸�/�ƶ�/ɾ���Ƚ����⣺
 * - �޸ģ�����Ǵ���Ŀ¼��������ΪKey���޸�����ʱ��Ҫ������Ŀ¼���Ƶ�ͬ���޸�
 * - �ƶ���ͬ�޸�
 * - ɾ�������νڵ��ɾ����Ҫɾ����������Ҷ��
 *
 *
 * 2021.01.10
 * ����
 * ��������IHkBasePLQS�������б�һ������������
 * ��������ʱ�����ṩ���ڵ㡣
 *
 * 2021.01.11
 * �����б���Ϊ�����ݣ�
 * 1. ��������ʱ���������������б�
 * 2. ���ṩIHkBasePLQS���ԣ���ͨ�������б���ȡ
 * 3. ��������������ʱ����BeginUpdate/EndUpdate����
 *
 * �������ݵ����ӷ�ʽ��
 * ���з�ʽ�ʺϴ���Ŀ¼���ݣ�����ʱ�������Ľṹ�Ӹ���Ҷһ������(����BFS����)��
 * ��֮Ϊ˳�����ݡ�
 * ���Ƕ�����������ݣ�����DiskCatalog������Ŀ¼���������Դ��������ԣ�����ʹ����
 * һ�����ӷ�������Ϊ�������ݣ�
 * 1. ���ȶ�������ԭʼ���ݣ���ע���ڵ�ͷǸ��ڵ㣬�������ڵ��ϵ��
 * 2. ���������Ŀ���ǿ��ٲ��Ҹ��ڵ㣬��������δ����Key���򣬱�Ҫʱ��Ҫ�ṩ��
 *    ����
 * 3. ��ͷ��ʼ���������б������ڵ����账�����Ǹ��ڵ��ṩ����ָ��������б�������
 *    ���������Ҹ��ڵ㣬�����ظ��ڵ�ָ�룻
 * 4. ���ݸ��ڵ�����ָ�룬��һ�����ڵ��ϵ��
 *
 * ��������Ҫ��
 * 1. ����ʹ�������б���Key���ظ�ֵ�����ڲ��Ҹ��ڵ㣻
 * 2. �������ض�������ʼ/����(BeginUpdate/EndUpdate)��
 *
 * �ܽ᣺
 * 1. �����Ǻ������ݣ�������ʹ��BeginUpdate/EndUpdate�����������Ǳ��룬��˳����
 *    �����ǲ�����д����������ķ�����Ч�ʸ���
 * 2. ����ʹ��˳������ ��Ч�ʽϸ�
 *
 * 2021.01.12
 * ����ɾ��/�޸Ĺ��ܡ�
 * �޸Ĺ��ܣ����ڴ���Ŀ¼����Ҫʹ�øù��ܣ���Ϊ����Ŀ¼��һ��ʹ��Ŀ¼·����ΪKey��
 *           �޸�Ŀ¼��������Ŀ¼·��������ͬʱ������
 *
 *
 * 2021.08.04
 * ��HkGenericsCodeΪ�������á�
 *
 *
 * 2021.08.05
 * ���ں�����function ChangeItem(OldItem: Pointer; const NewItem: T): boolean;
 *   �޸���ָ�޸�Key����(Ʃ����Ŀ¼����)�������ַ�����
 *   1. ֱ���������ݸ��Ǿ����ݣ�Ȼ��������б�������
 *   2. ��������Ϊ�½ڵ����ӣ��Ѿ����ݵ�������Ϣ���Ƶ��������Ȼ���滻���ڵ��
 *      �ӽڵ�������ľ����ݣ���Ҫ���������ݵ��ӽڵ��������޸������ӽڵ�ĸ��ڵ�
 *
 * ǰ�ߴ���򵥣�������Ҫ�����򣻺��ߴ��븴�ӣ�����ɾ����¼��Ҫ�ƶ��ڴ�2�Ρ�
 * ����Ч�ʸ��߲����жϣ��������ǰ��(��ǰ�Ĵ���ʹ���˺���)
 *
 * ʹ�õ�һ�ַ����Ļ����޸ľ����ݵĲ������û��ⲿ��ɣ��������������ظ��ļ��ȣ�
 * ���ӿڽ����������޸ĺ�������������Խӿں���Ҳ��Ҫ�޸ģ�
 * 1. ����ChangeItem����
 * 2. ʹ��Resort����
 *
 *
 * 2021.08.08
 * ȡ���Զ�����ڵ��֧�֣�һ���ӿ�ֻ�ܶ��ұ�����һ�����ڵ㡣
 *
 *
 * 2021.11.21
 * IHkStdList�޸��˱Ƚ�����ʹ�ã�Tree��ͬ���޸ġ�
 * ȡ�����������ݡ�
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
  // ����Ŀ¼ʱ��ȡÿ����Ŀʱ���õĺ���
  TTraverseEventA = reference to procedure(Item: Pointer; var MoveNext: boolean);
  TTraverseEventC = procedure(Item: Pointer; var MoveNext: boolean) of Object;

  IGenericsTree<T> = interface
    function GetChildCount(Item: Pointer): integer;
    function GetCount: integer;            // ���ڵ�����
    function GetFirstChild(Item: Pointer): Pointer;
    function GetList: IHkStdList<T>;       // ��ȡ�����б�
    function GetNextSibling(Item: Pointer): Pointer;
    function GetParent(Item: Pointer): Pointer; // ��ȡ������
    function GetRoot: Pointer;             // ��ȡ���ڵ�
    function GetSiblingCount(Item: Pointer): integer;
    // ����(Traverse)
    procedure BFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventA;
      ChildOnly: boolean = FALSE); overload;
    procedure BFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventC;
      ChildOnly: boolean = FALSE); overload;
    procedure DFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventA;
      ChildOnly: boolean = FALSE); overload;
    procedure DFSTraverse(Item: Pointer; TreeItemEvent: TTraverseEventC;
      ChildOnly: boolean = FALSE); overload;

    function Add(const Value: T; Parent: Pointer): Pointer;
    procedure BeginUpdate;                 // �������ݵ������ʼ����
    procedure Clear;
    function Contains(const Key: array of const): Pointer; overload;
    function Contains(var Value: T; const Key: array of const): boolean; overload;
    procedure EndUpdate;
    function Move(Item, NewParent: Pointer): boolean;
    function Remove(Item: Pointer): integer; overload;
    function Remove(const Key: array of const): integer; overload;
    procedure Resort;                      // �޸�/�ƶ����ݺ���������

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
      Parent: PBaseTreeItem;               // ��Ŀ¼
      NextSibling: PBaseTreeItem;          // ͬ��Ŀ¼����
      Children: PBaseTreeItem;             // ��Ŀ¼����������
      ChildCount: integer;                 // ��Ŀ¼����
      LastChild: PBaseTreeItem;            // �����Ҫ�������˳��������ʹ�ø���Ŀ
    end;
  private
    FItemPool: IHkGenericsPLQS<T>;         // THkTreeItem���ݳ�
    FList: IHkStdList<T>;                  // �����б�
    FRoot: Pointer;                        // Ψһ���ڵ�
    procedure BFSGetChildren(Item: PBaseTreeItem;
      const Queue: IHkGenericsPLQS<Pointer>);
    function BFSGetQueue(Item: Pointer; ChildOnly: boolean): IHkGenericsPLQS<Pointer>;
    function DFSGetNext(Current, Root: PBaseTreeItem): PBaseTreeItem;
    procedure SetParent(Child, Parent: PBaseTreeItem);
  private                                  // IGenericsTree<T>
    function GetChildCount(Item: Pointer): integer;
    function GetCount: integer;            // ���ڵ�����
    function GetFirstChild(Item: Pointer): Pointer;
    function GetList: IHkStdList<T>;       // ��ȡ�����б�
    function GetNextSibling(Item: Pointer): Pointer;
    function GetParent(Item: Pointer): Pointer; // ��ȡ������
    function GetRoot: Pointer;             // ��ȡ��һ�����ڵ�
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
    procedure Resort;                      // �޸����ݺ���������
  public
    constructor Create(Capacity: integer = 4096; KeyIndex: integer = 0); overload;
    constructor Create(                    // �����ȽϺ���
      ItemComparer: THkComparerA;
      Capacity: integer = 4096); overload;
    constructor Create(                    // ��ȽϺ���
      ItemComparer: THkComparerC;
      Capacity: integer = 4096); overload;
    constructor Create(                    // ȫ�ֱȽϺ���
      ItemComparer: THkComparerG;
      Capacity: integer = 4096); overload;
  end;

// ���¶������ڴ���Ŀ¼�Ķ�ȡ��Ҳ��Tree�ӿ���õĳ��ϡ�
// ����Ŀ¼��ȡ��һ��ע���������⣺
// 1. ����FindFirst/FindNext����ʱ��Ҫ�����ⲿ����д��Tree�ӿڣ���Ϊ�ӿڲ�֪��
//    <T>������ϸ�ڣ�
// 2. �ڶ�ȡĿ¼���󣬿�����Ҫͳ��Ŀ¼��Ϣ(��Ŀ¼/�ļ���)��ͬ����Ҫ�ⲿ����
// �ⲿ������ʹ�����������ǱȽϷ���ģ���������������Ч�ʱȽϵͣ�����ȡ��Ŀ¼��
// �Ļ���Ч�ʻ�����Ҫ��ģ����ԱȽϼ��ߣ�����ֱ�����ⲿʹ��FindFirst/FindNext��
// ���շ���������Ŀ¼�����ӿڵĴ��㡣

type
  // IsFolder��SR������Ŀ��Ŀ¼���ص���������ʱ��IsFolder��ʾ����Ч����Ŀ¼����
  // Ҫ����������б�
  TSearchEvent = reference to procedure(var IsFolder: boolean;
    var Parent: string; const SR: TSearchRec);

procedure DF(const Folder: string; const SearchEvent: TSearchEvent);

implementation

// =============================================================================
//  ��������
//  DF��Disk Folder����ȡ����Ŀ¼��
// =============================================================================

procedure DF(const Folder: string; const SearchEvent: TSearchEvent);
var
  List: IHkGenericsPLQS<string>; // Ŀ¼�б�
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
      if IsFolder then // ��Ч��Ŀ¼�����ӵ��б�
        List.Enqueue(s);

      found := FindNext(SR); // ������һ��
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
  else FRoot := Result; // ���ӵ���Root
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

// ���ɱ������ڵ����
// 1. ���Item<>nil��
//    - ChildOnly������ýڵ������ӽڵ�
//    - �������ýڵ㼴��
// 2. ���Item=nil��
//    - ChildOnly������Root�ڵ���ӽڵ�
//    - �������Root�ڵ�
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

// ����ָ��·����Ŀ¼(Breadth First Search���������)��Item=nil��ʾ�Ӹ�Ŀ¼��ʼ
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
    TreeItemEvent(Item, MoveNext); // ������Ч�ڵ�
    if not MoveNext then Break;

    BFSGetChildren(TreeItem, Queue);
  end;
end;

// ����ָ��·����Ŀ¼(Breadth First Search���������)��Item=nil��ʾ�Ӹ�Ŀ¼��ʼ
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
    TreeItemEvent(Item, MoveNext); // ������Ч�ڵ�
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

// ������ȱ�������������(��Ŀ¼)����(ͬ��Ŀ¼)��ԭ���ȡ��һ���ڵ�
function TGenericsTree<T>.DFSGetNext(Current, Root: PBaseTreeItem): PBaseTreeItem;
begin
  Result := nil;

  if Current.Children <> nil then // ������
    Result := Current.Children
  else if Current.NextSibling <> nil then // ������
    Result := Current.NextSibling
  else begin // �����ϼ�
    repeat
      Current := Current.Parent;
    until (Current = Root) or (Current.NextSibling <> nil);

    if Current <> Root then
      Result := Current.NextSibling;
  end;
end;

// ����ָ��·����Ŀ¼(Depth First Search���������)��
// �Ӹ��ڵ㿪ʼ����������(��Ŀ¼)����(ͬ��Ŀ¼)��ԭ�����Ŀ¼�������û����Ч��
// ���򷵻���һ����ֱ�����ظ�Ŀ¼��
procedure TGenericsTree<T>.DFSTraverse(Item: Pointer;
  TreeItemEvent: TTraverseEventA; ChildOnly: boolean);
var
  Root, TreeItem: PBaseTreeItem;
  MoveNext: boolean;
begin
  if (not Assigned(TreeItemEvent)) or (FItemPool.Count = 0) then Exit;

  // DFS�Ľ�����DFSGetNext����ȷ�����ص���Ŀ¼��ֹͣ
  if Item = nil then // ���ڵ�
    Root := FItemPool.GetExtraItem(FRoot)
  else Root := FItemPool.GetExtraItem(Item);

  MoveNext := TRUE;
  if not ChildOnly then // �������ڵ�
  begin
    Item := FItemPool.GetDataItem(Root);
    TreeItemEvent(Item, MoveNext);
  end;
  if not MoveNext then Exit;

  TreeItem := Root.Children;
  while TreeItem <> nil do
  begin
    Item := FItemPool.GetDataItem(TreeItem);
    TreeItemEvent(Item, MoveNext); // ������Ч�ڵ�
    if not MoveNext then Break;

    TreeItem := DFSGetNext(TreeItem, Root);
  end;
end;

// ����ָ��·����Ŀ¼(Depth First Search���������)��
// �Ӹ��ڵ㿪ʼ����������(��Ŀ¼)����(ͬ��Ŀ¼)��ԭ�����Ŀ¼�������û����Ч��
// ���򷵻���һ����ֱ�����ظ�Ŀ¼��
procedure TGenericsTree<T>.DFSTraverse(Item: Pointer;
  TreeItemEvent: TTraverseEventC; ChildOnly: boolean);
var
  Root, TreeItem: PBaseTreeItem;
  MoveNext: boolean;
begin
  if (not Assigned(TreeItemEvent)) or (FItemPool.Count = 0) then Exit;

  // DFS�Ľ�����DFSGetNext����ȷ�����ص���Ŀ¼��ֹͣ�����Ա���ÿ����Ŀ¼�������
  if Item = nil then // ���и��ڵ�
    Root := FItemPool.GetExtraItem(FRoot)
  else Root := FItemPool.GetExtraItem(Item);

  MoveNext := TRUE;
  if not ChildOnly then // �������ڵ�
  begin
    Item := FItemPool.GetDataItem(Root);
    TreeItemEvent(Item, MoveNext);
  end;
  if not MoveNext then Exit;

  TreeItem := Root.Children;
  while TreeItem <> nil do
  begin
    Item := FItemPool.GetDataItem(TreeItem);
    TreeItemEvent(Item, MoveNext); // ������Ч�ڵ�
    if not MoveNext then Break;

    TreeItem := DFSGetNext(TreeItem, Root);
  end;
end;

procedure TGenericsTree<T>.EndUpdate;
begin
  FList.Sorted := TRUE; // �ָ�ԭ������
end;

// Item=nilʱ����ȡRoot����
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

// Item=nilʱ����ȡRoot
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

// ����ֵ��ɾ����Ŀ������
function TGenericsTree<T>.Remove(const Key: array of const): integer;
var
  Item: Pointer;
begin
  Item := Contains(Key);
  if Item <> nil then
    Result := Remove(Item)
  else Result := 0;
end;

// ����ֵ��ɾ����Ŀ������
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

// �б���������һ�������ⲿ�޸�Key����֮��(Ʃ��Ŀ¼����)
procedure TGenericsTree<T>.Resort;
begin
  FList.Sorted := FALSE;
  FList.Sorted := TRUE;
end;

procedure TGenericsTree<T>.SetParent(Child, Parent: PBaseTreeItem);
begin
  Child.Parent := Parent;
  if Parent.Children = nil then // ��һ���ӽڵ�
    Parent.Children := Child
  else Parent.LastChild.NextSibling := Child;
  Parent.LastChild := Child;
  //Item.NextSibling := Parent.Children; // ��������ͷ��
  //Parent.Children := Item;
  Inc(Parent.ChildCount);
end;

end.