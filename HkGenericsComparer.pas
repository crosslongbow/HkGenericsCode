unit HkGenericsComparer;

(*
 * 本单元和HkCodeE.HkComparer完全一样
 *)

{$include 'DelphiVersions.inc'}

interface

uses
  {$IFNDEF HAS_UNIT_SCOPE}
  TypInfo,
  {$ENDIF HAS_UNIT_SCOPE}
  HkGenericsTypes;

type
  TItemComparer = function(Left, Right: Pointer): integer of object;
  TKeyComparer = function(Left: Pointer; const Key: array of const): integer of object;

type
  // 比较器基类
  THkCompareClass = class
  private
    FCaseSensitive: boolean; // 缺省值为FALSE
    function GetItemComparer: TItemComparer;
    function GetKeyComparer: TKeyComparer;
    function GetKeyOffset: Integer; virtual; abstract;
  public
    function CompareItem(Left, Right: Pointer): integer; virtual; abstract;
    function CompareKey(Left: Pointer; const Key: array of const): integer; virtual; abstract;

    property CaseSensitive: boolean read FCaseSensitive write FCaseSensitive;
    property ItemComparer: TItemComparer read GetItemComparer;
    property KeyComparer: TKeyComparer read GetKeyComparer;
    property KeyOffset: integer read GetKeyOffset;
  end;

  // 采用外部匿名比较函数的比较器
  THkCompareClassA = class(THkCompareClass)
  private
    FComparer: THkComparerA;
    function GetKeyOffset: Integer; override;
public
    constructor Create(const Comparer: THkComparerA);

    function CompareItem(Left, Right: Pointer): integer; override;
    function CompareKey(Left: Pointer; const Key: array of const): integer; override;
  end;

  // 采用外部类比较函数的比较器
  THkCompareClassC = class(THkCompareClass)
  private
    FComparer: THkComparerC;
    function GetKeyOffset: Integer; override;
  public
    constructor Create(const Comparer: THkComparerC);

    function CompareItem(Left, Right: Pointer): integer; override;
    function CompareKey(Left: Pointer; const Key: array of const): integer; override;
  end;

  // 采用外部全局比较函数的比较器
  THkCompareClassG = class(THkCompareClass)
  private
    FComparer: THkComparerG;
    function GetKeyOffset: Integer; override;
  public
    constructor Create(const Comparer: THkComparerG);

    function CompareItem(Left, Right: Pointer): integer; override;
    function CompareKey(Left: Pointer; const Key: array of const): integer; override;
  end;

  // 采用内部(Inner)比较函数的比较器
  THkCompareClassI = class(THkCompareClass)
  private
    FKeyKind: TTypeKind;
    FKeyOffset: integer;
    function GetKeyOffset: Integer; override;
    function GetKeyPointer(const Item: Pointer): Pointer;
    function ValueCompare(Left, Right: Pointer; Kind: TTypeKind): integer;
  public
    constructor Create(Kind: TTypeKind; Offset: integer = 0;
      CaseSensitive: boolean = FALSE);

    function CompareItem(Left, Right: Pointer): integer; override;
    function CompareKey(Left: Pointer; const Key: array of const): integer; override;
  end;

implementation

uses
  {$IFDEF HAS_UNIT_SCOPE}
  System.AnsiStrings, System.SysUtils;
  {$ELSE}
  AnsiStrings, SysUtils;
  {$ENDIF HAS_UNIT_SCOPE}

// =============================================================================
//  THkCompareClass (基类)
// =============================================================================

function THkCompareClass.GetItemComparer: TItemComparer;
begin
  Result := CompareItem;
end;

function THkCompareClass.GetKeyComparer: TKeyComparer;
begin
  Result := CompareKey;
end;

// =============================================================================
//  THkCompareClassA
// =============================================================================

constructor THkCompareClassA.Create(const Comparer: THkComparerA);
begin
  inherited Create;

  FComparer := Comparer;
end;

function THkCompareClassA.CompareItem(Left, Right: Pointer): integer;
begin
  Result := FComparer(Left, Right, [])
end;

function THkCompareClassA.CompareKey(Left: Pointer;
  const Key: array of const): integer;
var
  P: Pointer;
begin
  P := nil;
  Result := FComparer(Left, P, Key);
end;

function THkCompareClassA.GetKeyOffset: Integer;
begin
  Result := -1;
end;

// =============================================================================
//  THkCompareClassC
// =============================================================================

constructor THkCompareClassC.Create(const Comparer: THkComparerC);
begin
  inherited Create;

  FComparer := Comparer;
end;

function THkCompareClassC.CompareItem(Left, Right: Pointer): integer;
begin
  Result := FComparer(Left, Right, [])
end;

function THkCompareClassC.CompareKey(Left: Pointer;
  const Key: array of const): integer;
var
  P: Pointer;
begin
  P := nil;
  Result := FComparer(Left, P, Key);
end;

function THkCompareClassC.GetKeyOffset: Integer;
begin
  Result := -1;
end;

// =============================================================================
//  THkCompareClassG
// =============================================================================

constructor THkCompareClassG.Create(const Comparer: THkComparerG);
begin
  inherited Create;

  FComparer := Comparer;
end;

function THkCompareClassG.CompareItem(Left, Right: Pointer): integer;
begin
  Result := FComparer(Left, Right, [])
end;

function THkCompareClassG.CompareKey(Left: Pointer;
  const Key: array of const): integer;
var
  P: Pointer;
begin
  P := nil;
  Result := FComparer(Left, P, Key);
end;

function THkCompareClassG.GetKeyOffset: Integer;
begin
  Result := -1;
end;

// =============================================================================
//  THkCompareClassI (内部比较器)
// =============================================================================

constructor THkCompareClassI.Create(Kind: TTypeKind; Offset: integer;
  CaseSensitive: boolean);
begin
  inherited Create;

  FKeyKind := Kind;
  FKeyOffset := Offset;
  FCaseSensitive := CaseSensitive;
end;

function THkCompareClassI.CompareItem(Left, Right: Pointer): integer;
var
  LeftPt, RightPt: Pointer;
begin
  LeftPt := GetKeyPointer(Left);
  RightPt := GetKeyPointer(Right);
  if (LeftPt = nil) or (RightPt = nil) then
    Result := 0
  else Result := ValueCompare(LeftPt, RightPt, FKeyKind);
end;

function THkCompareClassI.CompareKey(Left: Pointer;
  const Key: array of const): integer;
var
  LeftPt, KeyPt: Pointer;
  Kind: TTYpeKind;
begin
  LeftPt := GetKeyPointer(Left);
  if LeftPt = nil then Exit(0);

  Kind := FKeyKind;
  case Kind of
    tkInteger: KeyPt := @Key[0].VInteger;
    tkInt64: KeyPt := Key[0].VInt64;
    tkChar: KeyPt := Key[0].VPChar;
    tkLString:
    begin
      Kind := tkString; // 和CompareItem的AnsiString区分
      KeyPt := Key[0].VPChar;
    end;
    tkWChar: KeyPt := Key[0].VPWideChar;
    tkWString, tkUString: KeyPt := Key[0].VUnicodeString;
  else
    KeyPt := nil;
  end;

  if KeyPt <> nil then
    Result := ValueCompare(LeftPt, KeyPt, Kind)
  else Result := 0;
end;

function THkCompareClassI.GetKeyOffset: Integer;
begin
  Result := FKeyOffset;
end;

function THkCompareClassI.GetKeyPointer(const Item: Pointer): Pointer;
begin
  case FKeyKind of
    tkInteger, tkInt64: Result := PByte(Item) + FKeyOffset;
    tkChar, tkWChar, tkLString, tkWString, tkUString: Result := PPointer(PByte(Item) + FKeyOffset)^;
  else // 无效的数据类型，用于不排序的列表
    Result := nil;
  end;
end;

function THkCompareClassI.ValueCompare(Left, Right: Pointer;
  Kind: TTypeKind): integer;
begin
  case Kind of
    tkInteger: Result := PInteger(Left)^ - PInteger(Right)^;
    tkInt64: Result := PInt64(Left)^ - PInt64(Right)^;
    tkChar:
    begin
      if FCaseSensitive then
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.AnsiStrings.CompareStr(PAnsiChar(Left), PAnsiChar(Right))
        {$ELSE}
        Result := AnsiStrings.CompareStr(PAnsiChar(Left), PAnsiChar(Right))
        {$ENDIF HAS_UNIT_SCOPE}
      else
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.AnsiStrings.CompareText(PAnsiChar(Left), PAnsiChar(Right));
        {$ELSE}
        Result := AnsiStrings.CompareText(PAnsiChar(Left), PAnsiChar(Right));
        {$ENDIF HAS_UNIT_SCOPE}
    end;
    tkLString: // ItemCompare.AnsiString
    begin
      if FCaseSensitive then
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.AnsiStrings.CompareStr(AnsiString(Left), AnsiString(Right))
        {$ELSE}
        Result := AnsiStrings.CompareStr(AnsiString(Left), AnsiString(Right))
        {$ENDIF HAS_UNIT_SCOPE}
      else
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.AnsiStrings.CompareText(AnsiString(Left), AnsiString(Right));
        {$ELSE}
        Result := AnsiStrings.CompareText(AnsiString(Left), AnsiString(Right));
        {$ENDIF HAS_UNIT_SCOPE}
    end;
    tkString: // KeyCompare.AnsiString
    begin
      if FCaseSensitive then
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.AnsiStrings.CompareStr(AnsiString(Left), PAnsiChar(Right))
        {$ELSE}
        Result := AnsiStrings.CompareStr(AnsiString(Left), PAnsiChar(Right))
        {$ENDIF HAS_UNIT_SCOPE}
      else
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.AnsiStrings.CompareText(AnsiString(Left), PAnsiChar(Right));
        {$ELSE}
        Result := AnsiStrings.CompareText(AnsiString(Left), PAnsiChar(Right));
        {$ENDIF HAS_UNIT_SCOPE}
    end;
    tkWChar:
    begin
      if FCaseSensitive then
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.SysUtils.CompareStr(PChar(Left), PChar(Right))
        {$ELSE}
        Result := SysUtils.CompareStr(PChar(Left), PChar(Right))
        {$ENDIF HAS_UNIT_SCOPE}
      else
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.SysUtils.CompareText(PChar(Left), PChar(Right));
        {$ELSE}
        Result := SysUtils.CompareText(PChar(Left), PChar(Right));
        {$ENDIF HAS_UNIT_SCOPE}
    end;
    tkWString, tkUString:
    begin
      if FCaseSensitive then
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.SysUtils.CompareStr(string(Left), string(Right))
        {$ELSE}
        Result := SysUtils.CompareStr(string(Left), string(Right))
        {$ENDIF HAS_UNIT_SCOPE}
      else
        {$IFDEF HAS_UNIT_SCOPE}
        Result := System.SysUtils.CompareText(string(Left), string(Right));
        {$ELSE}
        Result := SysUtils.CompareText(string(Left), string(RIght));
        {$ENDIF HAS_UNIT_SCOPE}
    end
  else
    Result := 0;
  end;
end;

end.
