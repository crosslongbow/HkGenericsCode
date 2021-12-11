unit HkGenericsUtils;

(*
 * 项目常用的代码，和HkGenericsCode没有必然联系，仅使用HkGenericsCode作为基础数
 * 据类型。
 *)

{$include 'DelphiVersions.inc'}

interface

uses
  SuperObject;

type
  // 一般用于项目配置文件的读取和保存
  // 对Json类的简单封装，采用SuperObject，主要作用是：
  // 1. 文本文件的读取和保存，SuperObject需要List类来处理含中文的文件；
  // 2. 读取配置项时提供缺省值，在配置项不存在时使用自定义的缺省值；
  // 3. 对复杂数据类型(如数组等)提供高级数据类型(如列表类)输出(暂时未完成)
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
  if Length(Default) > 0 then // 有缺省值
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

  if Assigned(FJson) then // 已有缺省值，合并数据
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
