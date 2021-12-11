unit HkGenericsUtils;

(*
 * ��Ŀ���õĴ��룬��HkGenericsCodeû�б�Ȼ��ϵ����ʹ��HkGenericsCode��Ϊ������
 * �����͡�
 *)

{$include 'DelphiVersions.inc'}

interface

uses
  SuperObject;

type
  // һ��������Ŀ�����ļ��Ķ�ȡ�ͱ���
  // ��Json��ļ򵥷�װ������SuperObject����Ҫ�����ǣ�
  // 1. �ı��ļ��Ķ�ȡ�ͱ��棬SuperObject��ҪList�����������ĵ��ļ���
  // 2. ��ȡ������ʱ�ṩȱʡֵ�������������ʱʹ���Զ����ȱʡֵ��
  // 3. �Ը�����������(�������)�ṩ�߼���������(���б���)���(��ʱδ���)
  IJsonFile = interface
    function B(const Path: string; DefaultValue: boolean = FALSE): boolean;
    function I(const Path: string; DefaultValue: integer = 0): integer;
    function S(const Path: string; const DefaultValue: String = ''): String;
    procedure SetValue(const Path: string; const Value: boolean); overload;
    procedure SetValue(const Path: string; const Value: integer); overload;
    procedure SetValue(const Path: string; const Value: string); overload;
  end;

  TJsonFile = class(TInterfacedObject, IJsonFile)
  private
    FJson: ISuperObject;
    FFile: string;
    function GetObject(const Path: string): ISuperObject;
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);
  public
    constructor Create(const FileName: string; const Default: string = '');
    destructor Destroy; override;

    function B(const Path: string; DefaultValue: boolean = FALSE): boolean;
    function I(const Path: string; DefaultValue: integer = 0): integer;
    function S(const Path: string; const DefaultValue: String = ''): String;
    procedure SetValue(const Path: string; const Value: boolean); overload;
    procedure SetValue(const Path: string; const Value: integer); overload;
    procedure SetValue(const Path: string; const Value: string); overload;
  end;

implementation

uses
  System.SysUtils,
  HkGenericsCode;

// =============================================================================
//  TJsonFile
// =============================================================================

constructor TJsonFile.Create(const FileName, Default: string);
begin
  FFile := FileName;
  if Length(Default) > 0 then // ��ȱʡֵ
    FJson := SO(Default);
  LoadFromFile(FileName);
end;

destructor TJsonFile.Destroy;
begin
  SaveToFile(FFile);

  inherited;
end;

function TJsonFile.B(const Path: string; DefaultValue: boolean): boolean;
var
  jo: ISuperObject;
begin
  jo := GetObject(Path);
  if jo <> nil then
    Result := jo.AsBoolean
  else Result := DefaultValue;
end;

function TJsonFile.GetObject(const Path: string): ISuperObject;
begin
  if Assigned(FJson) then
    Result := FJson.O[Path]
  else Result := nil;
end;

function TJsonFile.I(const Path: string; DefaultValue: integer): integer;
var
  jo: ISuperObject;
begin
  jo := GetObject(Path);
  if jo <> nil then
    Result := jo.AsInteger
  else Result := DefaultValue;
end;

procedure TJsonFile.LoadFromFile(const FileName: string);
var
  TmpList: IHkStdList<string>;
begin
  if not FileExists(FileName) then Exit;

  TmpList := THkStdList<string>.Create();
  TmpList.LoadFromFile(FileName,
    procedure(const Value: string)
    begin
      TmpList.Add(Value);
    end);

  if Assigned(FJson) then // ����ȱʡֵ���ϲ�����
    FJson.Merge(TmpList.Text)
  else FJson := SO(TmpList.Text);
end;

function TJsonFile.S(const Path, DefaultValue: String): String;
var
  jo: ISuperObject;
begin
  jo := GetObject(Path);
  if jo <> nil then
    Result := jo.AsString
  else Result := DefaultValue;
end;

procedure TJsonFile.SaveToFile(const FileName: string);
var
  TmpList: IHkStdList<string>;
begin
  if (not Assigned(FJson)) or (Length(FileName) = 0) then Exit;

  TmpList := THkStdList<string>.Create();
  TmpList.SetText(FJson.AsJSon(TRUE, FALSE),
    procedure(const Value: string)
    begin
      TmpList.Add(Value);
    end);
  TmpList.SaveToFile(FileName);
end;

procedure TJsonFile.SetValue(const Path: string; const Value: boolean);
begin
  if Assigned(FJson) then
    FJson.B[Path] := Value;
end;

procedure TJsonFile.SetValue(const Path: string; const Value: integer);
begin
  if Assigned(FJson) then
    FJson.I[Path] := Value;
end;

procedure TJsonFile.SetValue(const Path, Value: string);
begin
  if Assigned(FJson) then
    FJson.S[Path] := Value;
end;

end.
