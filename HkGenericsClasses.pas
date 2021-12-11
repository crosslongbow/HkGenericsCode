unit HkGenericsClasses;

{$include 'DelphiVersions.inc'}

interface

uses
  {$IFDEF HAS_UNIT_SCOPE}
  System.Rtti, System.SysUtils,
  {$ELSE}
  Rtti, SysUtils, TypInfo,
  {$ENDIF HAS_UNIT_SCOPE}
  HkGenericsTypes, HashFuncs;

type
  TRttiUtils<T> = class
    class procedure GetKeyInfo(var Kind: TTypeKind; var Offset: integer);
  end;

type
  // 外部处理函数，同THkCompareClass。2020.11.23
  // 建议优先级顺序：匿名函数 > 全局函数 > 类成员函数。匿名函数稍慢
  // 使用这个类的目的是减少数据出入时的耗时。之前的方法需要多次比较，选出正确的
  // 处理函数
  //
  // 2021.05.10
  // 外部函数BeforePut，增加：ExtraItem清零

  // 基类
  THkActionClass = class
  private
    FClearItemBeforePut: boolean;
    FExtraSize: integer;
    FIsExtMethod: boolean;                // 如果是外部函数，Cleanup必须调用
    FItemSize: integer;
  public
    constructor Create(ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); virtual; abstract;
    // 内部函数里，在回收节点时受ClearItemBeforePut参数控制，但在释放节点时必须
    // 执行。Forced参数就是跳过ClearItemBeforePut检查
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); virtual;
    procedure OnRelease(Item: Pointer); virtual; abstract;

    property ClearItemBeforePut: boolean write FClearItemBeforePut;
    property IsExtMethod: boolean read FIsExtMethod;
  end;

  THkActionClassA = class(THkActionClass) // 外部匿名函数
  private
    FMethod: THkActionEventA;
  public
    constructor Create(Method: THkActionEventA; ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

  THkActionClassC = class(THkActionClass) // 外部类函数
  private
    FMethod: THkActionEventC;
  public
    constructor Create(Method: THkActionEventC; ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

  THkActionClassG = class(THkActionClass) // 外部全局函数
  private
    FMethod: THkActionEventG;
  public
    constructor Create(Method: THkActionEventG; ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

  // 内部处理函数不处理AfterGet，对于BeforePut清空用户数据
  THkActionClassI<T> = class(THkActionClass) // 内置函数
  public
    constructor Create(ItemSize, ExtraSize: integer; ClearItemBeforePut: boolean);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

type
  // 哈希计算基类
  THashClass = class
  private
    FCaseSensitive: boolean;
    FHashFunc: TOnHashFunc;
    FKeyKind: TTypeKind;
    FKeyOffset: integer;
  public
    function GetHash(Item: Pointer): Cardinal; overload; virtual; abstract;
    function GetHash(const Key: array of const): Cardinal; overload; virtual; abstract;

    property CaseSensitive: boolean write FCaseSensitive;
  end;

  {TIntHashClass = class(THashClass) // 整数哈希计算类(采用取余法)
  private
    FDataLen: integer;
    FRemainder: integer;    // 用于整数取余计算的分母值
    function CalcHash(P: PByte): Cardinal;
    procedure GetDataInfo(Item: Pointer; const Key: array of const; var P: PByte);
  public
    constructor Create(KeyKind: TTypeKind; KeyOffset: integer; Remainder: integer;
      HashFunc: TOnHashFunc = nil);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;}

  TStringHashClass = class(THashClass) // 字符串哈希计算类
  private
    FBuf: array[0..4095] of byte; // 4K缓冲区
    procedure GetCaseSensitiveValue(var P: PByte; Len: integer; var StrBuf: TBytes);
    procedure GetDataInfo(Item: Pointer; const Key: array of const; var P: PByte;
      var Len: integer);
    function GetHash(var P: PByte; Len: integer): Cardinal; overload;
  public
    constructor Create(KeyKind: TTypeKind; KeyOffset: integer;
      CaseSensitive: boolean; HashFunc: TOnHashFunc);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;

  TExtHashClasscG = class(THashClass) // 外部全局函数哈希计算类
  private
    FExtHashEvent: THkHashEventG;
  public
    constructor Create(ExtHashEvent: THkHashEventG);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;

  TExtHashClassC = class(THashClass) // 外部全局函数哈希计算类
  private
    FExtHashEvent: THkHashEventC;
  public
    constructor Create(ExtHashEvent: THkHashEventC);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;

  TExtHashClassA = class(THashClass) // 外部全局函数哈希计算类
  private
    FExtHashEvent: THkHashEventA;
  public
    constructor Create(ExtHashEvent: THkHashEventA);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;

implementation

{$IFDEF HAS_UNIT_SCOPE}
uses
  System.TypInfo;
{$ENDIF HAS_UNIT_SCOPE}

// =============================================================================
//  TRttiUtils<T>
// =============================================================================

// 用于IHkStdList/IHkHashedList读取Record类型的参数类型和偏移值
// 如果指定参数不存在或不符合要求，返回tkUnknown
// 作为输入参数，Offset是KeyIndex
class procedure TRttiUtils<T>.GetKeyInfo(var Kind: TTypeKind; var Offset: integer);
const
  CN_Key_Kind: set of TTypeKind = [tkInteger, tkInt64, tkChar, tkWChar, tkLString,
    tkWString, tkUString];
var
  ElementInfo: PTypeInfo;
  ctx: TRttiContext;
  Rt: TRttiType;
  Fields: TArray<TRttiField>;
begin
  ElementInfo := TypeInfo(T);
  Kind := ElementInfo.Kind;

  ctx := TRttiContext.Create;
  try
    Rt := ctx.GetType(ElementInfo);
    if Kind = tkRecord then
    begin
      Fields := Rt.GetFields;
      if (Offset >= 0) and (Offset < Length(Fields)) then
      begin
        Rt := Fields[Offset].FieldType; // array[0..n] of xxx 的 TRttiType=nil
        Offset := Fields[Offset].Offset;
        if Rt <> nil then
          Kind := Rt.TypeKind;
      end
      else Rt := nil;
    end
    else Offset := 0;

    if Rt <> nil then // Record的参数如果是array[0..n] of xxx，TRttiType=nil
    begin
      if Kind = tkPointer then
      begin
        if Rt.Name = 'PAnsiChar' then
          Kind := tkChar
        else if Rt.Name = 'PWideChar' then
          Kind := tkWChar;
      end
      else if Kind in [tkChar, tkWChar] then
        Kind := tkUnknown;

      if not (Kind in [tkInteger, tkInt64, tkChar, tkWChar, tkLString, tkWString, tkUString]) then
        Kind := tkUnknown;
    end
    else Kind := tkUnknown;
  finally
    ctx.Free;
  end;
end;

// =============================================================================
//  THkActionClass
// =============================================================================

constructor THkActionClass.Create(ItemSize, ExtraSize: integer);
begin
  inherited Create;

  FItemSize := ItemSize;
  FExtraSize := ExtraSize;
end;

procedure THkActionClass.BeforePut(Item: Pointer; Forced: boolean);
var
  ExtraItem: Pointer;
begin
  if FExtraSize > 0 then
  begin
    ExtraItem := PByte(Item) + FItemSize; // 附加数据
    FillChar(ExtraItem^, FExtraSize, 0);
  end;
end;

// =============================================================================
//  THkActionClassA
// =============================================================================

constructor THkActionClassA.Create(Method: THkActionEventA;
  ItemSize, ExtraSize: integer);
begin
  inherited Create(ItemSize, ExtraSize);

  FMethod := Method;
  FIsExtMethod := TRUE;
end;

procedure THkActionClassA.AfterGet(Item: Pointer);
begin
  FMethod(atpAfterGet, Item);
end;

procedure THkActionClassA.BeforePut(Item: Pointer; Forced: boolean);
begin
  FMethod(atpBeforePut, Item);

  inherited;
end;

procedure THkActionClassA.OnRelease(Item: Pointer);
begin
  FMethod(atpRelease, Item);
end;

// =============================================================================
//  THkActionClassC
// =============================================================================

constructor THkActionClassC.Create(Method: THkActionEventC; ItemSize,
  ExtraSize: integer);
begin
  inherited Create(ItemSize, ExtraSize);

  FMethod := Method;
  FIsExtMethod := TRUE;
end;

procedure THkActionClassC.AfterGet(Item: Pointer);
begin
  FMethod(atpAfterGet, Item);
end;

procedure THkActionClassC.BeforePut(Item: Pointer; Forced: boolean);
begin
  FMethod(atpBeforePut, Item);

  inherited;
end;

procedure THkActionClassC.OnRelease(Item: Pointer);
begin
  FMethod(atpRelease, Item);
end;

// =============================================================================
//  THkActionClassG
// =============================================================================

constructor THkActionClassG.Create(Method: THkActionEventG; ItemSize,
  ExtraSize: integer);
begin
  inherited Create(ItemSize, ExtraSize);

  FMethod := Method;
  FIsExtMethod := TRUE;
end;

procedure THkActionClassG.AfterGet(Item: Pointer);
begin
  FMethod(atpAfterGet, Item);
end;

procedure THkActionClassG.BeforePut(Item: Pointer; Forced: boolean);
begin
  FMethod(atpBeforePut, Item);

  inherited;
end;

procedure THkActionClassG.OnRelease(Item: Pointer);
begin
  FMethod(atpRelease, Item);
end;

// =============================================================================
//  THkActionClassI
// =============================================================================

constructor THkActionClassI<T>.Create(ItemSize, ExtraSize: integer;
  ClearItemBeforePut: boolean);
begin
  inherited Create(ItemSize, ExtraSize);

  FClearItemBeforePut := ClearItemBeforePut;
  FIsExtMethod := FALSE;
end;

procedure THkActionClassI<T>.AfterGet(Item: Pointer);
begin

end;

procedure THkActionClassI<T>.BeforePut(Item: Pointer; Forced: boolean);
begin
  if FClearItemBeforePut or Forced then
  begin
    //THkElement<T>(Item^) := Default(THkElement<T>);
    T(Item^) := Default(T);

    inherited;
  end;
end;

procedure THkActionClassI<T>.OnRelease(Item: Pointer);
begin
  BeforePut(Item, TRUE);
end;

// =============================================================================
//  TIntHashClass
// =============================================================================

{constructor TIntHashClass.Create(KeyKind: TTypeKind; KeyOffset,
  Remainder: integer; HashFunc: TOnHashFunc);
begin
  inherited Create;

  if not (KeyKind in [tkInteger, tkInt64]) then
    raise Exception.Create('Error Key Data TYpe!');

  FKeyKind := KeyKind;
  FKeyOffset := KeyOffset;
  FRemainder := Remainder;
  FHashFunc := HashFunc;

  if KeyKind = tkInteger then
    FDataLen := SizeOf(integer)
  else FDataLen := SizeOf(int64);
end;

function TIntHashClass.CalcHash(P: PByte): Cardinal;
begin
  if FKeyKind = tkInteger then
    Result := PInteger(P)^ mod FRemainder
  else Result := PInt64(P)^ mod FRemainder;
end;

procedure TIntHashClass.GetDataInfo(Item: Pointer; const Key: array of const;
  var P: PByte);
begin
  if Length(Key) > 0 then
  begin
    if FKeyKind = tkInteger then
      P := @Key[0].VInteger
    else P := PByte(Key[0].VInt64); // int64
  end
  else P := PByte(Item) + FKeyOffset;
end;

function TIntHashClass.GetHash(const Key: array of const): Cardinal;
var
  P: PByte;
begin
  GetDataInfo(nil, Key, P);
  if Assigned(FHashFunc) then
    Result := FHashFunc(P, FDataLen)
  else Result := CalcHash(P);
end;

function TIntHashClass.GetHash(Item: Pointer): Cardinal;
var
  P: PByte;
begin
  GetDataInfo(Item, [], P);
  if Assigned(FHashFunc) then
    Result := FHashFunc(P, FDataLen)
  else Result := CalcHash(P);
end;}

// =============================================================================
//  TStringHashClass
// =============================================================================

constructor TStringHashClass.Create(KeyKind: TTypeKind; KeyOffset: integer;
  CaseSensitive: boolean; HashFunc: TOnHashFunc);
begin
  inherited Create;

  if not (KeyKind in [tkChar, tkWChar, tkLString, tkUString, tkWString]) then
    raise Exception.Create('Error Key Data TYpe!');

  FKeyKind := KeyKind;
  FKeyOffset := KeyOffset;
  FCaseSensitive := CaseSensitive;
  FHashFunc := HashFunc;
end;

// 如果字符串长度小于4K，使用内部缓冲区，避免分配内存
procedure TStringHashClass.GetCaseSensitiveValue(var P: PByte; Len: integer;
  var StrBuf: TBytes);
var
  i: integer;
  PB, PBuf: PByte;
  PC, PCBuf: PChar;
begin
  if Len < Length(FBuf) then // 使用内部缓冲区。复制过程中转为小写
  begin
    FillChar(FBuf[0], SizeOf(FBuf), 0);
    if FKeyKind in [tkChar, tkLString] then // PAnsiChar
    begin
      PBuf := @FBuf[0];
      PB := P;
      for i := 0 to Len - 1 do // 复制字符串，并改为全小写
      begin
        case PB^ of
          65..90: PBuf^ := PB^ or $20;
        else
          PBuf^ := PB^;
        end;
        Inc(PBuf);
        Inc(PB);
      end;
    end
    else begin // PChar
      PCBuf := PChar(@FBuf[0]);
      PC := PChar(P);
      for i := 0 to (Len shr 1) - 1 do // 复制字符串，并改为全小写
      begin
        case PC^ of
          'A'..'Z': PCBuf^ := Char(Word(PC^) or $0020);
        else
          PCBuf^ := PC^;
        end;
        Inc(PCBuf);
        Inc(PC);
      end;
    end;

    P := @FBuf[0]; // 指向内部缓冲区
  end
  else begin // 使用Bytesof函数。先复制，再转小写
    if FKeyKind in [tkChar, tkLString] then
    begin
      StrBuf := Bytesof(PAnsiChar(P));
      PB := @StrBuf[0]; // 参考Delphi2010 SysUtils LowerCaseFromAnsiString函数
      for i := 0 to Len - 1 do
      begin
        case PB^ of
          65..90: PB^ := PB^ or $20; // 'A'..'Z'
        end;
        Inc(PB);
      end;
    end
    else begin
      StrBuf := WideBytesof(PChar(P));
      PC := PChar(@StrBuf[0]); // 参考Delphi2010 SysUtils LowerCaseFromAnsiString函数
      for i := 0 to (Len shr 1) - 1 do
      begin
        case PC^ of
          'A'..'Z': PC^ := Char(Word(PC^) or $0020); // 'A'..'Z'
        end;
        Inc(PC);
      end;
    end;

    P := @StrBuf[0]; // 指向新分配的缓冲区
  end;
end;

// 读取Key的指针和字符串长度
procedure TStringHashClass.GetDataInfo(Item: Pointer; const Key: array of const;
  var P: PByte; var Len: integer);
var
  PK: Pointer;
begin
  P := nil;
  Len := 0;

  if Length(Key) <> 0 then
  begin
    case FKeyKind of
      tkLString, tkChar:
      begin
        P := PByte(Key[0].VPChar);
        Len := Length(PAnsiChar(P));
      end;
      tkUString, tkWString, tkWChar:
      begin
        P := PByte(Key[0].VPWideChar);
        Len := Length(PChar(P)) * SizeOf(Char);
      end;
    end;
  end
  else begin
    PK := PByte(Item) + FKeyOffset;
    case FKeyKind of
      tkChar:
      begin
        P := PPointer(PK)^;
        Len := Length(PAnsiChar(P));
      end;
      tkWChar:
      begin
        P := PPointer(PK)^;
        Len := Length(PChar(P)) * SizeOf(Char);
      end;
      tkLString:
      begin
        P := PByte(PAnsiChar(ansistring(PK^)));
        Len := Length(PAnsiChar(P));
      end;
      tkUString, tkWString:
      begin
        P := PByte(PChar(string(PK^)));
        Len := Length(PChar(P)) * SizeOf(Char);
      end;
    end;
  end;
end;

function TStringHashClass.GetHash(var P: PByte; Len: integer): Cardinal;
var
  StrBuf: TBytes;
begin
  if not FCaseSensitive then // 大小写不敏感，转为全小写字符串再计算Hash
    GetCaseSensitiveValue(P, Len, StrBuf);

  Result := FHashFunc(P, Len);
end;

function TStringHashClass.GetHash(Item: Pointer): Cardinal;
var
  P: PByte;
  Len: integer;
begin
  GetDataInfo(Item, [], P, Len);
  Result := GetHash(P, Len);
end;

function TStringHashClass.GetHash(const Key: array of const): Cardinal;
var
  P: PByte;
  Len: integer;
begin
  GetDataInfo(nil, Key, P, Len);
  Result := GetHash(P, Len);
end;

// =============================================================================
//  TExtHashClasscG
// =============================================================================

constructor TExtHashClasscG.Create(ExtHashEvent: THkHashEventG);
begin
  FExtHashEvent := ExtHashEvent;
end;

function TExtHashClasscG.GetHash(Item: Pointer): Cardinal;
begin
  Result := FExtHashEvent(Item, []);
end;

function TExtHashClasscG.GetHash(const Key: array of const): Cardinal;
begin
  Result := FExtHashEvent(nil, Key);
end;

// =============================================================================
//  TExtHashClassC
// =============================================================================

constructor TExtHashClassC.Create(ExtHashEvent: THkHashEventC);
begin
  FExtHashEvent := ExtHashEvent;
end;

function TExtHashClassC.GetHash(Item: Pointer): Cardinal;
begin
  Result := FExtHashEvent(Item, []);
end;

function TExtHashClassC.GetHash(const Key: array of const): Cardinal;
begin
  Result := FExtHashEvent(nil, Key);
end;

// =============================================================================
//  TExtHashClassA
// =============================================================================

constructor TExtHashClassA.Create(ExtHashEvent: THkHashEventA);
begin
  FExtHashEvent := ExtHashEvent;
end;

function TExtHashClassA.GetHash(Item: Pointer): Cardinal;
begin
  Result := FExtHashEvent(Item, []);
end;

function TExtHashClassA.GetHash(const Key: array of const): Cardinal;
begin
  Result := FExtHashEvent(nil, Key);
end;

end.
