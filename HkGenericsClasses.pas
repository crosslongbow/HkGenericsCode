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
  // �ⲿ��������ͬTHkCompareClass��2020.11.23
  // �������ȼ�˳���������� > ȫ�ֺ��� > ���Ա������������������
  // ʹ��������Ŀ���Ǽ������ݳ���ʱ�ĺ�ʱ��֮ǰ�ķ�����Ҫ��αȽϣ�ѡ����ȷ��
  // ������
  //
  // 2021.05.10
  // �ⲿ����BeforePut�����ӣ�ExtraItem����

  // ����
  THkActionClass = class
  private
    FClearItemBeforePut: boolean;
    FExtraSize: integer;
    FIsExtMethod: boolean;                // ������ⲿ������Cleanup�������
    FItemSize: integer;
  public
    constructor Create(ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); virtual; abstract;
    // �ڲ�������ڻ��սڵ�ʱ��ClearItemBeforePut�������ƣ������ͷŽڵ�ʱ����
    // ִ�С�Forced������������ClearItemBeforePut���
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); virtual;
    procedure OnRelease(Item: Pointer); virtual; abstract;

    property ClearItemBeforePut: boolean write FClearItemBeforePut;
    property IsExtMethod: boolean read FIsExtMethod;
  end;

  THkActionClassA = class(THkActionClass) // �ⲿ��������
  private
    FMethod: THkActionEventA;
  public
    constructor Create(Method: THkActionEventA; ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

  THkActionClassC = class(THkActionClass) // �ⲿ�ຯ��
  private
    FMethod: THkActionEventC;
  public
    constructor Create(Method: THkActionEventC; ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

  THkActionClassG = class(THkActionClass) // �ⲿȫ�ֺ���
  private
    FMethod: THkActionEventG;
  public
    constructor Create(Method: THkActionEventG; ItemSize, ExtraSize: integer);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

  // �ڲ�������������AfterGet������BeforePut����û�����
  THkActionClassI<T> = class(THkActionClass) // ���ú���
  public
    constructor Create(ItemSize, ExtraSize: integer; ClearItemBeforePut: boolean);

    procedure AfterGet(Item: Pointer); override;
    procedure BeforePut(Item: Pointer; Forced: boolean = FALSE); override;
    procedure OnRelease(Item: Pointer); override;
  end;

type
  // ��ϣ�������
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

  {TIntHashClass = class(THashClass) // ������ϣ������(����ȡ�෨)
  private
    FDataLen: integer;
    FRemainder: integer;    // ��������ȡ�����ķ�ĸֵ
    function CalcHash(P: PByte): Cardinal;
    procedure GetDataInfo(Item: Pointer; const Key: array of const; var P: PByte);
  public
    constructor Create(KeyKind: TTypeKind; KeyOffset: integer; Remainder: integer;
      HashFunc: TOnHashFunc = nil);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;}

  TStringHashClass = class(THashClass) // �ַ�����ϣ������
  private
    FBuf: array[0..4095] of byte; // 4K������
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

  TExtHashClasscG = class(THashClass) // �ⲿȫ�ֺ�����ϣ������
  private
    FExtHashEvent: THkHashEventG;
  public
    constructor Create(ExtHashEvent: THkHashEventG);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;

  TExtHashClassC = class(THashClass) // �ⲿȫ�ֺ�����ϣ������
  private
    FExtHashEvent: THkHashEventC;
  public
    constructor Create(ExtHashEvent: THkHashEventC);

    function GetHash(Item: Pointer): Cardinal; overload; override;
    function GetHash(const Key: array of const): Cardinal; overload; Override;
  end;

  TExtHashClassA = class(THashClass) // �ⲿȫ�ֺ�����ϣ������
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

// ����IHkStdList/IHkHashedList��ȡRecord���͵Ĳ������ͺ�ƫ��ֵ
// ���ָ�����������ڻ򲻷���Ҫ�󣬷���tkUnknown
// ��Ϊ���������Offset��KeyIndex
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
        Rt := Fields[Offset].FieldType; // array[0..n] of xxx �� TRttiType=nil
        Offset := Fields[Offset].Offset;
        if Rt <> nil then
          Kind := Rt.TypeKind;
      end
      else Rt := nil;
    end
    else Offset := 0;

    if Rt <> nil then // Record�Ĳ��������array[0..n] of xxx��TRttiType=nil
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
    ExtraItem := PByte(Item) + FItemSize; // ��������
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

// ����ַ�������С��4K��ʹ���ڲ�����������������ڴ�
procedure TStringHashClass.GetCaseSensitiveValue(var P: PByte; Len: integer;
  var StrBuf: TBytes);
var
  i: integer;
  PB, PBuf: PByte;
  PC, PCBuf: PChar;
begin
  if Len < Length(FBuf) then // ʹ���ڲ������������ƹ�����תΪСд
  begin
    FillChar(FBuf[0], SizeOf(FBuf), 0);
    if FKeyKind in [tkChar, tkLString] then // PAnsiChar
    begin
      PBuf := @FBuf[0];
      PB := P;
      for i := 0 to Len - 1 do // �����ַ���������ΪȫСд
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
      for i := 0 to (Len shr 1) - 1 do // �����ַ���������ΪȫСд
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

    P := @FBuf[0]; // ָ���ڲ�������
  end
  else begin // ʹ��Bytesof�������ȸ��ƣ���תСд
    if FKeyKind in [tkChar, tkLString] then
    begin
      StrBuf := Bytesof(PAnsiChar(P));
      PB := @StrBuf[0]; // �ο�Delphi2010 SysUtils LowerCaseFromAnsiString����
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
      PC := PChar(@StrBuf[0]); // �ο�Delphi2010 SysUtils LowerCaseFromAnsiString����
      for i := 0 to (Len shr 1) - 1 do
      begin
        case PC^ of
          'A'..'Z': PC^ := Char(Word(PC^) or $0020); // 'A'..'Z'
        end;
        Inc(PC);
      end;
    end;

    P := @StrBuf[0]; // ָ���·���Ļ�����
  end;
end;

// ��ȡKey��ָ����ַ�������
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
  if not FCaseSensitive then // ��Сд�����У�תΪȫСд�ַ����ټ���Hash
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
