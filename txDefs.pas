unit txDefs;

interface

uses SysUtils;

type
  TtxItemType=(
    itObj,itObjType,
    itTok,itTokType,
    itRef,itRefType,
    itFilter,
    itRealm,
    itUser,
    itReport,
    itJournal,
    //add new here above
    it_Unknown
  );

const
  ApplicationName='tx';

  //TODO: dynamic settings?
  Use_Terms=true;//requires WikiEngine.dll and tables Trm, Trl
  Use_ObjTokRefCache=true;//requires table ObjTokRefCache
  Use_ObjHist=true;//requires table ObjHist
  Use_ObjPath=true;//requires table ObjPath
  Use_NewUserEmailActivation=true;
  Use_Unread=true;//requires table Obx,Urx
  Use_Journals=true;//requires table Jrl,Jre
  Use_Extra=false;//use prefix "::" on ObjType.system

  txItemTypeKey:array[TtxItemType] of string=(
    'i','ot','t','tt','r','rt','f','rm','u','rp','j',
    //add new here above (see also procedure txItem below)
    ''
  );
  txItemTypeName:array[TtxItemType] of string=(
    'object','objecttype',
    'token','tokentype',
    'reference','referencetype',
    'filter','realm','user','report','journal',
    //add new here above
    'unknown'
  );
  txItemTypeTable:array[TtxItemType] of UTF8String=(
    'Obj','ObjType',
    'Tok','TokType',
    'Ref','RefType',
    'Flt','Rlm','Usr','Rpt','Jrl',
    //add new here above
    ''
  );
  txItemSQL_PidById:array[TtxItemType] of UTF8String=(
    'SELECT pid FROM Obj WHERE id=?',
    'SELECT pid FROM ObjType WHERE id=?',
    '','SELECT pid FROM TokType WHERE id=?',
    '','SELECT pid FROM RefType WHERE id=?',
    '','','','','',
    //add new here above
    ''
  );
  txItemSQL_Move:array[TtxItemType] of UTF8String=(
    'UPDATE Obj SET pid=? WHERE id=?',
    'UPDATE ObjType SET pid=? WHERE id=?',
    '','UPDATE TokType SET pid=? WHERE id=?',
    '','UPDATE RefType SET pid=? WHERE id=?',
    '','','','','',
    //add new here above
    ''
  );

  globalIconAlign='align="top" border="0" ';

  lblLocation=   '<img src="img_loc.png" width="16" height="16" alt="location:" '+globalIconAlign+'/>';
  lblDescendants='<img src="img_dsc.png" width="16" height="16" alt="children:" '+globalIconAlign+'/>';
  lblTokens=     '<img src="img_tok.png" width="16" height="16" alt="tokens:" '+globalIconAlign+'/>';
  lblReferences= '<img src="img_ref.png" width="16" height="16" alt="references:" '+globalIconAlign+'/>';
  {
  lblTreeNone=   '<img src="img_trx.png" width="16" height="16" alt="" '+globalIconAlign+'/>';
  lblTreeOpen=   '<img src="img_tr0.png" width="16" height="16" alt="[-]" '+globalIconAlign+'/>';
  lblTreeClosed= '<img src="img_tr1.png" width="16" height="16" alt="[+]" '+globalIconAlign+'/>';
   }
  txFormButton='<input type="submit" value="Apply" id="formsubmitbutton" class="formsubmitbutton" />';
  lblLoading='<i style="color:#CC3300;"><img src="loading.gif" width="16" height="16" alt="" '+globalIconAlign+'/> Loading...</i>';

  DefaultRlmID=0;//do not change
  EmailCheckRegEx='^[-_\.a-z0-9]+?@[-\.a-z0-9]+?\.[a-z][a-z]+$';//TODO: unicode?

procedure txItem(const KeyX:string;var ItemType:TtxItemType;var ItemID:integer);
function txImg(IconNr:integer; const Desc:string=''):string;
function txForm(const Action:string; const HVals:array of OleVariant;const OnSubmitEval:string=''):string; overload;

function DateToXML(d:TDateTime):string;
function NiceDateTime(const x:OleVariant):string;
function ShortDateTime(d:TDateTime):string;
function JournalTime(d:TDateTime):string;

function IntToStrU(x:integer):UTF8String;

implementation

uses Variants;

procedure txItem(const KeyX:string;var ItemType:TtxItemType;var ItemID:integer);
var
  Key:AnsiString;
  i:integer;
begin
  Key:=AnsiString(KeyX);
  ItemType:=itObj;//default;
  ItemID:=0;
  for i:=1 to Length(Key) do if Key[i] in ['0'..'9'] then ItemID:=ItemID*10+(byte(Key[i]) and $F);
  if Length(Key)>1 then
    case Key[1] of
      'i':ItemType:=itObj;
      'o':
        case Key[2] of
          't': ItemType:=itObjType;
          else ItemType:=itObj;
        end;
      't':
        case Key[2] of
          't': ItemType:=itTokType;
          else ItemType:=itTok;
        end;
      'r':
        case Key[2] of
          't': ItemType:=itRefType;
          'p': ItemType:=itReport;
          'm': ItemType:=itRealm;
          else ItemType:=itRef;
        end;
      'f':ItemType:=itFilter;
      'u':ItemType:=itUser;
      'j':ItemType:=itJournal;
      //else raise?
      else ItemType:=it_Unknown;
    end;
end;

//HTMLEncode here since no other units required
function HTMLEncode(const x:string):string;
begin
  Result:=
    StringReplace(
    StringReplace(
    StringReplace(
    StringReplace(
      x,
      '&','&amp;',[rfReplaceAll]),
      '<','&lt;',[rfReplaceAll]),
      '>','&gt;',[rfReplaceAll]),
      '"','&quot;',[rfReplaceAll]);
end;

function txImg(IconNr:integer; const Desc:string): string;
begin
  Result:='<img src="img/ic'+IntToStr(IconNr)+'.png" width="16" height="16" ';
  if Desc<>'' then Result:=Result+'alt="'+HTMLEncode(Desc)+'" title="'+HTMLEncode(Desc)+'" ';
  Result:=Result+globalIconAlign+'/>';
end;

function txForm(const Action:string; const HVals:array of OleVariant;const OnSubmitEval:string=''):string; overload;
var
  s:string;
  i:integer;
begin
  if OnSubmitEval='' then s:='true' else
    s:=HTMLEncode(StringReplace(OnSubmitEval,'"','''',[rfReplaceAll]));
  Result:='<form action="'+HTMLEncode(Action)+
    '" method="post" onsubmit="return default_form_submit('+s+');">'#13#10;
  for i:=0 to (Length(HVals) div 2)-1 do
    if not VarIsNull(HVals[i*2+1]) then
      Result:=Result+'<input type="hidden" name="'+HTMLEncode(VarToStr(HVals[i*2]))+'" value="'+
        HTMLEncode(VarToStr(HVals[i*2+1]))+'" />'#13#10;
end;

function DateToXML(d:TDateTime):string;
var
  dy,dm,dd,dw,th,tm,ts,tz:word;
const
  EngDayNames:array[0..6] of string=('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
  EngMonthNames:array[1..12] of string=('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Okt','Nov','Dec');
begin
  DecodeDateFully(d,dy,dm,dd,dw);
  DecodeTime(d,th,tm,ts,tz);
  //TODO: get time info bias
  Result:=EngDayNames[dw]+', '+IntToStr(dd)+' '+EngMonthNames[dm]+' '+IntToStr(dy)+' '+Format('%.2d:%.2d:%.2d',[th,tm,ts])+' +01:00';
end;

function NiceDateTime(const x:OleVariant):string;
begin
  if VarIsNull(x) then Result:='?' else Result:=FormatDateTime('ddd c',VarFromDateTime(x));
end;

function ShortDateTime(d:TDateTime):string;
var
  d1:TDateTime;
  dy1,dy2,dm,dd:word;
begin
  if d=0.0 then
    Result:='?'
  else
   begin
    d1:=Date;
    if Trunc(d)=d1 then
      Result:=FormatDateTime('hh:nn',d)
    else
     begin
      DecodeDate(d,dy1,dm,dd);
      DecodeDate(d1,dy2,dm,dd);
      if dy1=dy2 then
        Result:=FormatDateTime('ddd d/mm',d)
      else
      if d>d1-533.0 then
        Result:=FormatDateTime('d/mm/yyyy',d)
      else
        Result:=FormatDateTime('mm/yyyy',d);
     end;
   end;
end;

function JournalTime(d:TDateTime):string;
var
  d0:TDateTime;
begin
  d0:=Now;
  if Trunc(d)=Trunc(d0) then Result:=FormatDateTime('hh:nn',d) else Result:=FormatDateTime('ddd d/mm hh:nn',d);
  Result:=Result+' ('+IntToStr(Round((d0-d)*1440.0))+''')';
end;

function IntToStrU(x:integer):UTF8String;
var
  c:array[0..11] of byte;
  i,j:integer;
  neg:boolean;
begin
  //Result:=UTF8String(IntToStr(x));
  neg:=x<0;
  if neg then x:=-x;
  i:=0;
  while x<>0 do
   begin
    c[i]:=x mod 10;
    x:=x div 10;
    inc(i);
   end;
  if i=0 then
   begin
    c[0]:=0;
    inc(i);
   end;
  if neg then
   begin
    SetLength(Result,i+1);
    Result[1]:='-';
    j:=2;
   end
  else
   begin
    SetLength(Result,i);
    j:=1;
   end;
  while i<>0 do
   begin
    dec(i);
    Result[j]:=AnsiChar($30+c[i]);
    inc(j);
   end;
end;

end.
