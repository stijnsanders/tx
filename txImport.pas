unit txImport;

interface

uses MSXML, Classes, txDefs;

type
  TtxImport=class(TObject)
  private
    FDoc:DOMDocument;
  public
    constructor Create(Doc:DOMDocument);
    destructor Destroy; override;
    procedure VerifyTree(const QName:UTF8String);
    procedure BuildMapping(const QName:UTF8String;DefOnly:boolean);
    property Doc:DOMDocument read FDoc;
  end;

const
  QType:array[0..3] of TtxItemType=(itObj,itObjType,itTokType,itRefType);
  QName:array[0..3] of UTF8String=('Obj','ObjType','TokType','RefType');
  QDesc:array[0..3] of string=('Objects','Object types','Token types','Reference types');

function DefAttr(x:IXMLDOMElement;const aname:string;dval:integer):integer;
function XmlToDate(const d:string):TDateTime;

implementation

uses SysUtils, txSession, DataLank, Variants;

function DefAttr(x:IXMLDOMElement;const aname:string;dval:integer):integer;
var
  v:OleVariant;
begin
  if x=nil then v:=Null else v:=x.getAttribute(aname);
  if VarIsNull(v) then Result:=dval else Result:=StrToIntDef(VarToStr(v),dval);
end;

function XmlToDate(const d:string):TDateTime;
var
  i,l:integer;
  dy,dm,dd,th,tm,ts,tz:word;
  function GetNext:word;
   begin
    Result:=0;
    while (i<=l) and (AnsiChar(d[i]) in ['0'..'9']) do
     begin
      Result:=Result*10+byte(d[i])-$30;
      inc(i);
     end;
   end;
begin
  i:=1;
  l:=Length(d);
  dy:=GetNext;
  inc(i);//-
  dm:=GetNext;
  inc(i);//-
  dd:=GetNext;
  inc(i);//T
  th:=GetNext;
  inc(i);//:
  tm:=GetNext;
  inc(i);//:
  ts:=GetNext;
  inc(i);//.
  tz:=GetNext;
  Result:=EncodeDate(dy,dm,dd)+EncodeTime(th,tm,ts,tz);
end;

{$IF not Declared(UTF8ToWideString)}
function UTF8ToWideString(const s: UTF8String): WideString;
begin
  Result:=UTF8Decode(s);
end;
{$IFEND}

{ TtxImport }

procedure TtxImport.VerifyTree(const QName:UTF8String);
var
  xl:IXMLDOMNodeList;
  x:IXMLDOMElement;
begin
  //Clear?
  xl:=FDoc.documentElement.selectNodes(UTF8ToWideString(QName));
  x:=xl.nextNode as IXMLDOMElement;
  while not(x=nil) do
   begin
    if FDoc.documentElement.selectSingleNode(QName+'[@id="'+
      x.getAttribute('pid')+'"]')=nil then x.setAttribute('graft','1');
    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;
end;

procedure TtxImport.BuildMapping(const QName:UTF8String;DefOnly:boolean);
var
  xl:IXMLDOMNodeList;
  x:IXMLDOMElement;
  id:integer;
  qr:TQueryResult;
  sql:UTF8String;
begin
  //Clear?
  xl:=FDoc.documentElement.selectNodes(UTF8ToWideString(QName));
  x:=xl.nextNode as IXMLDOMElement;
  while not(x=nil) do
   begin
    id:=x.getAttribute('id');

    //TODO: fix QName into query!
    qr:=TQueryResult.Create(Session.DbCon,'SELECT id FROM '+QName+' WHERE id=?',[id]);
    if qr.EOF then
     begin
      qr.Free;
      sql:='SELECT id FROM '+QName+' WHERE name LIKE ?';
      if QName='Obj' then sql:=sql+' AND rlm_id'+Session.Realms[rpView].SQL;
      qr:=TQueryResult.Create(Session.DbCon,sql,[x.selectSingleNode('name').text]);
     end;
    if not(qr.EOF) then
     begin
      if not(DefOnly) then x.setAttribute('propo',IntToStr(qr.GetInt('id')));
      x.setAttribute('propoDef',IntToStr(qr.GetInt('id')));
     end;
    //if more than one? count?
    qr.Free;

    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;
end;

constructor TtxImport.Create(Doc: DOMDocument);
begin
  //create from IxxmParameterPostFile?
  inherited Create;
  FDoc:=Doc;
end;

destructor TtxImport.Destroy;
begin
  FDoc:=nil;
  inherited;
end;

end.
