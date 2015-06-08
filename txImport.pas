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
    procedure VerifyTree(QName:string);
    procedure BuildMapping(QName:string;DefOnly:boolean);
    property Doc:DOMDocument read FDoc;
  end;

const
  QType:array[0..3] of TtxItemType=(itObj,itObjType,itTokType,itRefType);
  QName:array[0..3] of string=('Obj','ObjType','TokType','RefType');
  QDesc:array[0..3] of string=('Objects','Object types','Token types','Reference types');

function DefAttr(x:IXMLDOMElement;aname:string;dval:integer):integer;
function XmlToDate(d:string):TDateTime;
  
implementation

uses SysUtils, txSession, SQLiteData, Variants;

function DefAttr(x:IXMLDOMElement;aname:string;dval:integer):integer;
var
  v:OleVariant;
begin
  if x=nil then v:=Null else v:=x.getAttribute(aname);
  if VarIsNull(v) then Result:=dval else Result:=StrToIntDef(VarToStr(v),dval);
end;  

function XmlToDate(d:string):TDateTime;
var
  i:integer;
  dy,dm,dd,th,tm,ts,tz:word;
  function GetNext:word;
   begin
    Result:=0;
    while (i<=Length(d)) and (d[i] in ['0'..'9']) do
     begin
      Result:=Result*10+byte(d[i])-$30;
      inc(i);
     end;
   end;
begin
  i:=1;
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

{ TtxImport }

procedure TtxImport.VerifyTree(QName:string);
var
  xl:IXMLDOMNodeList;
  x:IXMLDOMElement;
begin
  //Clear?
  xl:=FDoc.documentElement.selectNodes(QName);
  x:=xl.nextNode as IXMLDOMElement;
  while not(x=nil) do
   begin
    if FDoc.documentElement.selectSingleNode(QName+'[@id="'+
      x.getAttribute('pid')+'"]')=nil then x.setAttribute('graft','1');
    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;
end;

procedure TtxImport.BuildMapping(QName:string;DefOnly:boolean);
var
  xl:IXMLDOMNodeList;
  x:IXMLDOMElement;
  id:integer;
  qr:TSQLiteStatement;
  sql:string;
begin
  //Clear?
  xl:=FDoc.documentElement.selectNodes(QName);
  x:=xl.nextNode as IXMLDOMElement;
  while not(x=nil) do
   begin
    id:=x.getAttribute('id');

    //TODO: fix QName into query!
	qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT id FROM '+QName+' WHERE id=?',[id]);
    if qr.EOF then
     begin
      qr.Free;
	  sql:='SELECT id FROM '+QName+' WHERE name LIKE ?';
	  if QName='Obj' then sql:=sql+' AND rlm_id'+Session.Realms[rpView].SQL;
      qr:=TSQLiteStatement.Create(Session.DbCon,sql,[x.selectSingleNode('name').text]);
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