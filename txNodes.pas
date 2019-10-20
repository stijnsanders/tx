unit txNodes;

interface

uses txDefs, txCache;

type
  TLocationNodeDisplayItem=(ghLink,ghIcon,ghTypeName,ghName,ghTitle,ghListItemSelect,ghFrameListClass);
  TLocationNodeDisplayItems=set of TLocationNodeDisplayItem;
  TLocationNode=class(TItemCacheNode)
  private
    it:TtxItemType;
    pid,id,icon:integer;
    typename,name:string;
  public
    constructor Create(ItemType:TtxItemType; QueryID:integer);
    function GetHTML(Display:TLocationNodeDisplayItems; var ParentID:integer):WideString;
    function GetListItemSelectHTML(var ParentID:integer):WideString;
  end;

const
  ghFull:TLocationNodeDisplayItems=[ghLink,ghIcon,ghTypeName,ghName];

implementation

uses SysUtils, xxm, txSession, DataLank;

{ TLocationNode }

constructor TLocationNode.Create(ItemType:TtxItemType;QueryID:integer);
var
  qr:TQueryResult;
  sql:UTF8String;
begin
  inherited Create;
  it:=ItemType;
  if it=itObj then
    sql:='SELECT Obj.id, Obj.pid, ObjType.icon, ObjType.name AS typename, Obj.name FROM Obj INNER JOIN ObjType ON ObjType.id=Obj.objtype_id WHERE Obj.id=?'
  else
    sql:='SELECT * FROM '+txItemTypeTable[ItemType]+' WHERE id=?';
  qr:=TQueryResult.Create(Session.DbCon,sql,[QueryID]);
  try
    id:=qr.GetInt('id');
    pid:=qr.GetInt('pid');
    icon:=qr.GetInt('icon');
    if it=itObj then typename:=qr.GetStr('typename');
    name:=qr.GetStr('name');
  finally
    qr.Free;
  end;
end;

function TLocationNode.GetHTML(Display:TLocationNodeDisplayItems;
  var ParentID:integer):WideString;
begin
  ParentID:=pid;
  Result:='';
  if ghLink in Display then 
   begin
    Result:=Result+'<a href="Item.xxm?x='+txItemTypeKey[it]+IntToStr(id)+'"';
    if ghListItemSelect in Display then Result:=Result+' onclick="return listitem_select(event,'+IntToStr(id)+');"';
    if ghTitle in Display then Result:=Result+' title="'+HTMLEncode(name)+'"';
    if ghTypeName in Display then Result:=Result+' title="'+HTMLEncode(typename)+'"';
    if ghFrameListClass in Display then Result:=Result+' class="fli fli'+IntToStr(id)+'"';
    Result:=Result+'>';
   end;
  if ghIcon in Display then Result:=Result+txImg(icon);
  if ghName in Display then Result:=Result+'&nbsp;'+HTMLEncode(name);
  if ghLink in Display then Result:=Result+'</a>';
end;

function TLocationNode.GetListItemSelectHTML(var ParentID:integer):WideString;
begin
  ParentID:=pid;
  Result:='<a href="Item.xxm?x=i'+IntToStr(id)+'" onclick="return listitem_select(event,'+IntToStr(id)+');" title="'+HTMLEncode(name)+'" class="fli fli'+IntToStr(id)+'">'+txImg(icon)+'</a>';
end;


end.
