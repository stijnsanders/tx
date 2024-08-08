unit txFilterSql;

interface

uses SysUtils, txDefs, txFilter, DataLank;

type
  TtxSqlQueryFragments=class(TObject)
  private
    FItemType:TtxItemType;
    AliasCount,FParentID:integer;
    AddedWhere,Distinct:boolean;
    DbCon:TDataConnection;
    function BuildSQL:UTF8String;

    function SqlStr(const s:UTF8String):UTF8String;
    function Criterium(const El:TtxFilterElement;
      const SubQryField, SubQryFrom: UTF8String;
      ParentsOnly, Reverse: boolean):UTF8String;

  public
    Limit:integer;
    Fields,Tables,Where,GroupBy,Having,OrderBy:UTF8String;
    EnvVars:array[TtxFilterEnvVar] of integer;

    constructor Create(ItemType: TtxItemType);
    destructor Destroy; override;

    procedure AddFilter(f:TtxFilter);

    procedure AddWhere(const s:UTF8String);
    procedure AddWhereSafe(const s:UTF8String);
    procedure AddOrderBy(const s:UTF8String);
    procedure AddFrom(const s:UTF8String);

    property SQL:UTF8String read BuildSQL;
    property ParentID:integer read FParentID;
  end;

  EtxSqlQueryError=class(Exception);

  TIdList=class(TObject)
  private
    idCount,idSize:integer;
    ids:array of integer;
    function GetList:UTF8String;
    function GetItem(Idx:integer):integer;
    procedure SetItem(Idx,Value:integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(id:integer);
    procedure AddList(list:TIdList);
    procedure AddClip(id:integer; var Clip:integer);
    procedure Clear;
    function Contains(id:integer):boolean;
    property List:UTF8String read GetList;
    property Count:integer read idCount;
    property Item[Idx:integer]:integer read GetItem write SetItem; default;
  end;

implementation

uses txSession, Classes, Variants;

{ TtxSqlQueryFragments }

constructor TtxSqlQueryFragments.Create(ItemType: TtxItemType);
var
  t:UTF8String;
  fe:TtxFilterEnvVar;
begin
  inherited Create;
  AliasCount:=0;
  Limit:=-1;
  AddedWhere:=false;
  Distinct:=false;
  FParentID:=0;
  FItemType:=ItemType;
  DbCon:=Session.DbCon;
  case FItemType of
    itObj:
     begin
      Fields:='Obj.id, Obj.pid, Obj.name, Obj.'+sqlDesc+', Obj.weight, Obj.c_uid, Obj.c_ts, Obj.m_uid, Obj.m_ts, ObjType.icon, ObjType.name AS typename';
      Tables:='Obj LEFT JOIN ObjType ON ObjType.id=Obj.objtype_id'#13#10;
      Where:='';
      GroupBy:='';
      Having:='';
      OrderBy:='Obj.weight, Obj.name, Obj.c_ts';
     end;
    itReport:
     begin
      Fields:='Rpt.id, Rpt.obj_id, Rpt.'+sqlDesc+', Rpt.uid, Rpt.ts, Rpt.toktype_id, Rpt.reftype_id, Rpt.obj2_id,'+
       ' Obj.name, Obj.pid, ObjType.icon, ObjType.name AS typename,'+
       ' UsrObj.id AS usrid, UsrObj.name AS usrname, UsrObjType.icon AS usricon, UsrObjType.name AS usrtypename,'+
       ' RelTokType.icon AS tokicon, RelTokType.name AS tokname, RelTokType.system AS toksystem,'+
       ' RelRefType.icon AS reficon, RelRefType.name AS refname,'+
       ' RelObj.name AS relname, RelObjType.icon AS relicon, RelObjType.name AS reltypename';
      Tables:='Rpt'#13#10+
       'INNER JOIN Obj ON Obj.id=Rpt.obj_id'#13#10+
       'INNER JOIN ObjType ON ObjType.id=Obj.objtype_id'#13#10+
       'INNER JOIN Obj AS UsrObj ON UsrObj.id=Rpt.uid'#13#10+
       'INNER JOIN ObjType AS UsrObjType ON UsrObjType.id=UsrObj.objtype_id'#13#10+
       'LEFT OUTER JOIN Obj AS RelObj ON RelObj.id=Rpt.obj2_id'#13#10+
       'LEFT OUTER JOIN ObjType AS RelObjType ON RelObjType.id=RelObj.objtype_id'#13#10+
       'LEFT OUTER JOIN TokType AS RelTokType ON RelTokType.id=Rpt.toktype_id'#13#10+
       'LEFT OUTER JOIN RefType AS RelRefType ON RelRefType.id=Rpt.reftype_id'#13#10;
      Where:='';
      GroupBy:='';
      Having:='';
      OrderBy:='Rpt.ts DESC';
     end;
    itJournalEntry:
     begin
      Fields:='Jre.id, Jre.obj_id, Jre.ts, Jre.minutes, Jre.uid,'+
       ' Jre.jrt_id, Jrt.icon AS jrt_icon, Jrt.name AS jrt_name,'+
       ' Obj.name, Obj.pid, ObjType.icon, ObjType.name AS typename,'+
       ' UsrObj.id AS usrid, UsrObj.name AS usrname, UsrObjType.icon AS usricon, UsrObjType.name AS usrtypename';
      Tables:='Jre'#13#10+
       'INNER JOIN Jrt ON Jrt.id=Jre.jrt_id'#13#10+
       //'INNER JOIN Jrl ON Jrl.id=Jrt.jrl_id'#13#10+
       'INNER JOIN Obj ON Obj.id=Jre.obj_id'#13#10+
       'INNER JOIN ObjType ON ObjType.id=Obj.objtype_id'#13#10+
       'INNER JOIN Obj AS UsrObj ON UsrObj.id=Jre.uid'#13#10+
       'INNER JOIN ObjType AS UsrObjType ON UsrObjType.id=UsrObj.objtype_id'#13#10;
      Where:='';
      GroupBy:='';
      Having:='';
      OrderBy:='Jre.ts DESC';
     end;
    else
     begin
      t:=txItemTypeTable[ItemType];
      Fields:='*';
      Tables:=t+#13#10;
      Where:='';
      GroupBy:='';
      Having:='';
      OrderBy:=t+'.weight, '+t+'.name, '+t+'.c_ts';
     end;
  end;
  if Use_ObjTokRefCache and (FItemType in [itObj,itReport,itJournalEntry]) then
   begin
    Fields:=Fields+', ObjTokRefCache.tokHTML, ObjTokRefCache.refHTML';
    Tables:=Tables+'LEFT OUTER JOIN ObjTokRefCache ON ObjTokRefCache.id=Obj.id'#13#10;
   end;
  for fe:=TtxFilterEnvVar(0) to fe_Unknown do EnvVars[feMe]:=0;
  EnvVars[feMe]:=Session.UserID;
  //TODO: EnvVars[feUs]:=?
end;

destructor TtxSqlQueryFragments.Destroy;
begin
  //clean-up
  DbCon:=nil;
  inherited;
end;

function CritDate(fx:TtxFilterElement):UTF8String;
var
  i:integer;
begin
  case fx.IDType of
    dtNumber:
      if TryStrToInt(string(fx.ID),i) then
        //Result:='{d '''+FormatDate('yyyy-mm-dd',Date-i)+'''}'
        Result:=UTF8String(FloatToStr(Date-i))//SQLite allows storing Delphi date-as-float
      else
        raise EtxSqlQueryError.Create('Invalid ID at position: '+IntToStr(fx.Idx1));
    //TODO
    else
      raise EtxSqlQueryError.Create('Unsupported IDType at position: '+IntToStr(fx.Idx1));
  end;
end;

function CritTime(fx:TtxFilterElement):UTF8String;
var
  dy,dm,dd,th,tm,ts,tz:word;
  d:TDateTime;
  i,l:integer;
  procedure Next(var vv:word;max:integer);
  var
    j:integer;
  begin
    vv:=0;
    j:=i+max;
    while (i<=l) and (i<j) and (fx.ID[i] in ['0'..'9']) do
     begin
      vv:=vv*10+(byte(fx.ID[i]) and $0F);
      inc(i);
     end;
    while (i<=l) and not(fx.ID[i] in ['0'..'9']) do inc(i);
  end;
begin
  case fx.IDType of
    dtNumber,dtSystem:
     begin
      //defaults
      dy:=1900;
      dm:=1;
      dd:=1;
      th:=0;
      tm:=0;
      ts:=0;
      tz:=0;
      l:=Length(fx.ID);
      i:=1;
      while (i<=l) and not(fx.ID[i] in ['0'..'9']) do inc(i);
      if i<=l then
       begin
        Next(dy,4);//year
        if i<=l then
         begin
          Next(dm,2);//month
          if i<=l then
           begin
            Next(dd,2);//day
            Next(th,2);//hours
            Next(tm,2);//minutes
            Next(ts,2);//seconds
            Next(tz,3);//milliseconds
           end;
         end;
       end;
      d:=EncodeDate(dy,dm,dd)+EncodeTime(th,tm,ts,tz);
      //Result:='{ts '''+FormatDate('yyyy-mm-dd hh:nn:ss.zzz',d)+'''}';
      Result:=UTF8String(FloatToStr(d));//SQLite allows storing Delphi date-as-float
     end;
    //TODO
    else
      raise EtxSqlQueryError.Create('Unsupported IDType at position: '+IntToStr(fx.Idx1));
  end;
end;

procedure TtxSqlQueryFragments.AddFilter(f: TtxFilter);
var
  i,j,k:integer;
  s,t:UTF8String;
  qr:TQueryResult;
  fx:TtxFilter;
  fq:TtxSqlQueryFragments;
  procedure AddWhereQuery(const Field,Query:UTF8String);
  var
    ids:TIdList;
  begin
    if f[i].Prefetch then
     begin
      ids:=TIdList.Create;
      try
        qr:=TQueryResult.Create(Session.DbCon,s,[]);
        try
          while qr.Read do ids.Add(qr.GetInt(0));
        finally
          qr.Free;
        end;
        AddWhere(Field+' in ('+ids.List+')');
      finally
        ids.Free;
      end;
     end
    else
      AddWhere(Field+' in ('+Query+')');
  end;
const
  RefBSel:array[boolean] of UTF8String=('1','2');
begin
  //TODO: when FItemType<>itObj

  for i:=0 to f.Count-1 do
   begin

    //check global para count?
    for j:=1 to f[i].ParaOpen do Where:=Where+'(';

    //no para's when not AddedWhere?
    AddedWhere:=false;
    case f[i].Action of
      faChild:
        //dummy check:
        if (f[i].IDType=dtNumber) and (f[i].ID='0') and (f[i].Descending) then
          AddWhere('1=1')//match all
        else
          AddWhere('Obj.pid'+Criterium(f[i],'Obj.id','',true,false));
      faObj:
        AddWhere('Obj.id'+Criterium(f[i],'Obj.id','',false,false));
      faObjType:
        if (f[i].IDType=dtNumber) and (f[i].ID='0') then
          if f[i].Descending then
            AddWhere('1=1')//match all
          else
            AddWhere('0=1')//match none
        else
          AddWhere('ObjType.id'+Criterium(f[i],'DISTINCT ObjType.id','',false,false));
      faTokType:
        //dummy check:
        if (f[i].IDType=dtNumber) and (f[i].ID='0') and (f[i].Descending) then
          AddWhere('EXISTS (SELECT id FROM Tok WHERE obj_id=Obj.id)')
        else
         begin
          inc(AliasCount);
          t:='ttSQ'+IntToStrU(AliasCount);
          s:='SELECT DISTINCT Tok.obj_id FROM Tok WHERE Tok.toktype_id'+Criterium(f[i],
            'DISTINCT '+t+'.toktype_id','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,false);
          if f[i].Parameters<>'' then
           begin
            fx:=TtxFilter.Create;
            try
              fx.FilterExpression:=f[i].Parameters;
              for j:=0 to fx.Count-1 do
                case fx[j].Action of
                  faModified:
                    s:=s+' AND Tok.m_ts<'+CritDate(fx[j]);
                  faFrom:
                    s:=s+' AND Tok.m_ts>='+CritTime(fx[j]);
                  faTill:
                    s:=s+' AND Tok.m_ts<='+CritTime(fx[j])
                  else
                    raise EtxSqlQueryError.Create('Unexpected tt parameter at position '+IntToStr(fx[j].Idx1));
                end;
              //TODO: fx[j].Operator
            finally
              fx.Free;
            end;
           end;
          AddWhereQuery('Obj.id',s);
         end;
      faRefType:
        //dummy check:
        if (f[i].IDType=dtNumber) and (f[i].ID='0') and (f[i].Descending) then
          AddWhere('EXISTS (SELECT id FROM Ref WHERE obj1_id=Obj.id)')
        else
         begin
          inc(AliasCount);
          t:='rtSQ'+IntToStrU(AliasCount);
          s:='SELECT DISTINCT Ref.obj1_id FROM Ref WHERE Ref.reftype_id'+Criterium(f[i],
            'DISTINCT '+t+'.reftype_id','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj1_id=Obj.id',false,false);
          if f[i].Parameters<>'' then
           begin
            fx:=TtxFilter.Create;
            try
              fx.FilterExpression:=f[i].Parameters;
              for j:=0 to fx.Count-1 do
                case fx[j].Action of
                  faModified:
                    s:=s+' AND Ref.m_ts<'+CritDate(fx[j]);
                  faFrom:
                    s:=s+' AND Ref.m_ts>='+CritTime(fx[j]);
                  faTill:
                    s:=s+' AND Ref.m_ts<='+CritTime(fx[j]);
                  else
                    raise EtxSqlQueryError.Create('Unexpected rt parameter at position '+IntToStr(fx[j].Idx1));
                end;
              //TODO: fx[j].Operator
            finally
              fx.Free;
            end;
           end;
          AddWhereQuery('Obj.id',s);
         end;
      faRef,faBackRef:
       begin
        s:='';
        if f[i].Parameters<>'' then
         begin
          fx:=TtxFilter.Create;
          try
            fx.FilterExpression:=f[i].Parameters;
            for j:=0 to fx.Count-1 do
              case fx[j].Action of
                faRefType:
                 begin
                  inc(AliasCount);
                  t:='rxSQ'+IntToStrU(AliasCount);
                  s:=s+' AND Ref.reftype_id'+Criterium(fx[j],
                    'DISTINCT '+t+'.id','RIGHT JOIN Ref AS '+t+' ON '+t+'.ref_obj'+RefBSel[f[i].Action=faBackRef]+'_id=Obj.id',false,false);
                 end;
                faModified:
                  s:=s+' AND Ref.m_ts<'+CritDate(fx[j]);
                faFrom:
                  s:=s+' AND Ref.m_ts>='+CritTime(fx[j]);
                faTill:
                  s:=s+' AND Ref.m_ts<='+CritTime(fx[j]);
                else
                  raise EtxSqlQueryError.Create('Unexpected rx parameter at position '+IntToStr(f[i].Idx1));
              end;
            //TODO: fx[j].Operator
          finally
            fx.Free;
          end;
         end;
        AddWhere('Obj.id IN (SELECT Ref.obj'+RefBSel[f[i].Action=faRef]+'_id FROM Ref WHERE Ref.obj'+RefBSel[f[i].Action=faBackRef]+'_id'+Criterium(f[i],
          'Obj.id','',false,false)+s+')');
       end;

      faParent:
        case f[i].IDType of
          dtNumber:
            if TryStrToInt(string(f[i].ID),j) then FParentID:=j else
              raise EtxSqlQueryError.Create('Invalid ID at position: '+IntToStr(f[i].Idx1));
          //TODO
          //dtSystem:;
          //dtSubQuery:;
          //dtEnvironment:;
          else
            raise EtxSqlQueryError.Create('Unsupported IDType at position: '+IntToStr(f[i].Idx1));
        end;

      faModified:
        AddWhere('Obj.m_ts<'+CritDate(f[i]));
      faFrom:
        AddWhere('Obj.m_ts>='+CritTime(f[i]));
      faTill:
        AddWhere('Obj.m_ts<='+CritTime(f[i]));

      faFilter:
       begin
        if f[i].Descending then raise EtxSqlQueryError.Create('Descending into filter not supported');
        fx:=TtxFilter.Create;
        try
          //TODO: detect loops?
          qr:=TQueryResult.Create(Session.DbCon,'SELECT Flt.expression FROM Flt WHERE Flt.id'+Criterium(f[i],'','',false,false)+' LIMIT 1',[]);
          try
            if qr.EOF then raise EtxSqlQueryError.Create('Filter not found at position '+IntToStr(f[i].Idx1));
              fx.FilterExpression:=UTF8Encode(qr.GetStr(0));
          finally
            qr.Free;
          end;
          if fx.ParseError<>'' then raise EtxSqlQueryError.Create(
            'Invalid filter at position '+IntToStr(f[i].Idx1)+': '+fx.ParseError);
          if f[i].Prefetch then
           begin
            fq:=TtxSqlQueryFragments.Create(FItemType);
            try
              fq.AddFilter(fx);
              fq.Fields:='Obj.id';
              fq.OrderBy:='';
              AddWhereQuery('Obj.id',fq.SQL);
            finally
              fq.Free;
            end;
           end
          else
            AddFilter(fx);
        finally
          fx.Free;
        end;
       end;
      faName:
       begin
        AddWhere('Obj.name='+SqlStr(f[i].ID));
        OrderBy:='Obj.m_ts, Obj.weight, Obj.name';
       end;
      faDesc:
       begin
        AddWhere('Obj.'+sqlDesc+' LIKE '+SqlStr(f[i].ID));
        OrderBy:='Obj.m_ts, Obj.weight, Obj.name';
       end;
      faSearchName:
       begin
        AddWhere('Obj.name LIKE '+SqlStr(f[i].ID));//parentheses?
        OrderBy:='Obj.m_ts, Obj.weight, Obj.name';
       end;
      faSearch:
       begin
        //parameters?
        k:=1;
        s:='';
        t:=f[i].ID;
        while k<=Length(t) do
         begin
          j:=k;
          while (k<=Length(t)) and not(AnsiChar(t[k]) in [#0..#32]) do inc(k);
          if k-j<>0 then
           begin
            if s<>'' then s:=s+' AND ';
            s:=s+'(Obj.name LIKE '+SqlStr('%'+Copy(t,j,k-j)+'%')+' OR Obj.'+sqlDesc+' LIKE '+SqlStr('%'+Copy(t,j,k-j)+'%')+')';
           end;
          inc(k);
         end;
        if s='' then s:='0=1';//match none? match all?
        AddWhere(s);//parentheses?
        OrderBy:='Obj.m_ts, Obj.weight, Obj.name';
       end;
      faSearchReports:
       begin
        AddFrom('INNER JOIN Rpt ON Rpt.obj_id=Obj.id');
        //parameters?
        k:=1;
        s:='';
        t:=f[i].ID;
        while k<=Length(t) do
         begin
          j:=k;
          while (k<=Length(t)) and not(AnsiChar(t[k]) in [#0..#32]) do inc(k);
          if k-j<>0 then
           begin
            if s<>'' then s:=s+' AND ';
            s:=s+'Rpt.'+sqlDesc+' LIKE '+SqlStr('%'+Copy(t,j,k-j)+'%');
           end;
          inc(k);
         end;
        if s='' then s:='0=1';//match none? match all?
        AddWhere('('+s+')');
        //OrderBy:=//assert already Rpt.ts desc
       end;
      faTerm:
       begin
        Distinct:=true;
        AddFrom('INNER JOIN Trm ON Trm.obj_id=Obj.id');
        //parameters?
        k:=1;
        s:='';
        t:=f[i].ID;
        while k<=Length(t) do
         begin
          j:=k;
          while (k<=Length(t)) and not(AnsiChar(t[k]) in [#0..#32]) do inc(k);
          if k-j<>1 then
           begin
            if s<>'' then s:=s+' OR ';//AND?
            //s:=s+'Trm.term LIKE '+SqlStr('%'+Copy(t,j,k-j)+'%');
            s:=s+'Trm.term='+SqlStr(Copy(t,j,k-j));
           end;
          inc(k);
         end;
        if s='' then s:='0=1';//match none? match all?
        AddWhere('('+s+')');
       end;

      faAlwaysTrue:
        if (f[i].ParaClose=0) and (i<>f.Count-1) then
          case f[i].Operator of
            foAnd:;//skip
            foAndNot:Where:=Where+'NOT ';
            else AddWhere('1=1');
          end
        else AddWhere('1=1');
      faAlwaysFalse:
        if (f[i].ParaClose=0) and (i<>f.Count-1) then
          case f[i].Operator of
            foOr:;//skip
            foOrNot:Where:=Where+'NOT ';
            else AddWhere('0=1');
          end
        else AddWhere('0=1');
      faSQL:
       begin
        AddWhereSafe(f[i].ID);
        AddWhereSafe(f[i].Parameters);
       end;
      faExtra:;//TODO: filterparameters

      faPath:
        AddWhere('Obj.id'+Criterium(f[i],'Obj.pid','',false,true));
      faPathObjType:
        AddWhere('Obj.objtype_id'+Criterium(f[i],'DISTINCT ObjType.pid','',false,true));
      faPathTokType:
       begin
        inc(AliasCount);
        t:='ptSQ'+IntToStrU(AliasCount);
        AddWhereQuery('Obj.id','SELECT DISTINCT Tok.obj_id FROM Tok WHERE Tok.toktype_id'+Criterium(f[i],
          'DISTINCT '+t+'.toktype_pid','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,true));
       end;
      faPathRefType:
       begin
        inc(AliasCount);
        t:='prSQ'+IntToStrU(AliasCount);
        AddWhereQuery('Obj.id','SELECT DISTINCT Ref.obj1_id FROM Ref WHERE Ref.reftype_id'+Criterium(f[i],
          'DISTINCT '+t+'.reftype_pid','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj1_id=Obj.id',false,true));
       end;
      faPathInclSelf:
        AddWhere('Obj.id'+Criterium(f[i],'Obj.id','',false,true));

      faCreated:
        AddWhere('Obj.c_uid'+Criterium(f[i],'Obj.id','',false,false));
      faTokCreated:
       begin
        s:='SELECT DISTINCT Tok.obj_id FROM Tok WHERE Tok.c_uid'+Criterium(f[i],'Obj.id','',false,false);
        if f[i].Parameters<>'' then
         begin
          fx:=TtxFilter.Create;
          try
            fx.FilterExpression:=f[i].Parameters;
            for j:=0 to fx.Count-1 do
              case fx[j].Action of
                faModified:
                  s:=s+' AND Tok.m_ts<'+CritDate(fx[j]);
                faFrom:
                  s:=s+' AND Tok.m_ts>='+CritTime(fx[j]);
                faTill:
                  s:=s+' AND Tok.m_ts<='+CritTime(fx[j]);
                else
                  raise EtxSqlQueryError.Create('Unexpected ttr parameter at position '+IntToStr(fx[j].Idx1));
              end;
            //TODO: fx[j].Operator
          finally
            fx.Free;
          end;
         end;
        AddWhereQuery('Obj.id',s);
       end;
      faRefCreated,faBackRefCreated:
       begin
        s:='';
        if f[i].Parameters<>'' then
         begin
          fx:=TtxFilter.Create;
          try
            fx.FilterExpression:=f[i].Parameters;
            for j:=0 to fx.Count-1 do
              case fx[j].Action of
                faRefType:
                 begin
                  inc(AliasCount);
                  t:='urSQ'+IntToStrU(AliasCount);
                  s:=s+' AND Ref.reftype_id'+Criterium(fx[j],'DISTINCT '+t+'.id','RIGHT JOIN Ref AS '+t+' ON '+t+
                    '.ref_obj'+RefBSel[fx[j].Action=faBackRefCreated]+'_id=Obj.id',false,false);
                 end;
                faModified:
                  s:=s+' AND Ref.m_ts<'+CritDate(fx[j]);
                faFrom:
                  s:=s+' AND Ref.m_ts>='+CritTime(fx[j]);
                faTill:
                  s:=s+' AND Ref.m_ts<='+CritTime(fx[j]);
                else
                  raise EtxSqlQueryError.Create('Unexpected rtr parameter at position '+IntToStr(fx[j].Idx1));
              end;
            //TODO: fx[j].Operator
          finally
            fx.Free;
          end;
         end;
        AddWhereQuery('Obj.id','SELECT DISTINCT Ref.obj'+RefBSel[f[i].Action=faBackRefCreated]+'_id FROM Ref WHERE Ref.c_uid'+
          Criterium(f[i],'Obj.id','',false,false)+s);
       end;

      faRecentObj:
       begin
        AddWhere('Obj.id'+Criterium(f[i],'Obj.id','',false,false));
        AddOrderBy('Obj.m_ts DESC');
       end;
      faRecentTok:
       begin
        AddFrom('INNER JOIN Tok ON Obj.id=Tok.obj_id');
        AddOrderBy('Tok.m_ts DESC');
        inc(AliasCount);
        t:='ttSQ'+IntToStrU(AliasCount);
        if f[i].Prefetch then
          AddWhereQuery('Tok.id','SELECT DISTINCT Tok.id FROM Tok WHERE Tok.toktype_id'+Criterium(f[i],
            'DISTINCT '+t+'toktype_id','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,false))
        else
          AddWhere('Tok.toktype_id'+Criterium(f[i],
            'DISTINCT '+t+'toktype_id','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,false));
       end;
      faRecentRef,faRecentBackRef:
       begin
        AddFrom('INNER JOIN Ref ON Ref.obj'+RefBSel[f[i].Action=faRecentBackRef]+'_id=Obj.id');
        AddOrderBy('Ref.m_ts DESC');
        inc(AliasCount);
        t:='rtSQ'+IntToStrU(AliasCount);
        if f[i].Prefetch then
          AddWhereQuery('Ref.id','SELECT DISTINCT Ref.id FROM Ref WHERE Ref.reftype_id'+Criterium(f[i],
             'DISTINCT '+t+'reftype_id','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj'+
             RefBSel[f[i].Action=faRecentBackRef]+'_id=Obj.id',false,false))
        else
          AddWhere('Ref.reftype_id'+Criterium(f[i],
            'DISTINCT '+t+'.reftype_id','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj'+
            RefBSel[f[i].Action=faRecentBackRef]+'_id=Obj.id',false,false));
       end;
      faUser:
       begin
        AddFrom('INNER JOIN Usr ON Usr.uid=Obj.id');
        AddWhere('Obj.id'+Criterium(f[i],'Usr.uid','',false,false));
       end;
      faRealm:
        AddWhere('Obj.rlm_id'+Criterium(f[i],'Rlm.id','',false,false));
      faUnread:
       begin
        if Session.IsAdmin('logins') and not((f[i].IDType=dtNumber) and ((f[i].ID='0') or (f[i].ID=''))) then
          s:=Criterium(f[i],'Obj.id','',false,false)
        else
          s:='='+IntToStrU(Session.UserID);
        AddWhere('EXISTS (SELECT Obx.id FROM Obx'+
          ' LEFT OUTER JOIN Urx ON Urx.uid'+s+
          ' AND Obx.id BETWEEN Urx.id1 AND Urx.id2'+
          ' WHERE Obx.obj_id=Obj.id AND Urx.id IS NULL)');
       end;

      faJournal,faJournalUser,faJournalEntry,faJournalEntryUser:
       begin
        if Session.IsAdmin('journals') then s:='' else
         begin
          s:='';
          k:=0;
          for j:=0 to Length(Session.Journals)-1 do
            if Session.Journals[j].CanConsult then 
             begin
              s:=s+','+IntToStrU(Session.Journals[j].jrl_id);
              inc(k);
             end;
          case k of
            0:raise Exception.Create('You currently have no consult permissions on any journals.');//s:=' AND 0=1';//?
            1:s[1]:='=';
            else
             begin
              s[1]:='(';
              s:='IN '+s+')';
             end;
          end;
          s:='Jrt.jrl_id'+s;
         end;
        if f[i].Parameters<>'' then
         begin
          fx:=TtxFilter.Create;
          try
            fx.FilterExpression:=f[i].Parameters;
            for j:=0 to fx.Count-1 do
              case fx[j].Action of
                faJournal:
                 begin
                  if s<>'' then s:=s+' AND ';
                  s:=s+'Jrt.jrl_id'+Criterium(fx[j],'Jrl.id','',false,false);
                 end;
                else
                  raise EtxSqlQueryError.Create('Unexpected j parameter at position '+IntToStr(fx[j].Idx1));
              end;
            //TODO: fx[j].Operator
          finally
            fx.Free;
          end;
         end;
        if s<>'' then s:=s+' AND ';
        case f[i].Action of
          faJournal:
            AddWhereQuery('Obj.id','SELECT DISTINCT Jre.obj_id FROM Jre INNER JOIN Jrt ON Jrt.id=Jre.jrt_id WHERE '+s+
              'Jrt.jrl_id'+Criterium(f[i],'Jrl.id','',false,false));
          faJournalUser:
            AddWhereQuery('Obj.id','SELECT DISTINCT Jre.uid FROM Jre INNER JOIN Jrt ON Jrt.id=Jre.jrt_id WHERE '+s+
              'Jrt.jrl_id'+Criterium(f[i],'Jrl.id','',false,false));
          faJournalEntry:
            AddWhereQuery('Obj.id','SELECT DISTINCT Jre.obj_id FROM Jre INNER JOIN Jrt ON Jrt.id=Jre.jrt_id WHERE '+s+
              'Jre.uid'+Criterium(f[i],'Obj.id','',false,false));
          faJournalEntryUser:
            AddWhereQuery('Obj.id','SELECT DISTINCT Jre.uid FROM Jre INNER JOIN Jrt ON Jrt.id=Jre.jrt_id WHERE '+s+
              'Jre.obj_id'+Criterium(f[i],'Obj.id','',false,false));
        end;
       end;

      else
        raise EtxSqlQueryError.Create('Unsupported filter action at position '+IntToStr(f[i].Idx1));
    end;

    //check global para count?
    for j:=1 to f[i].ParaClose do Where:=Where+')';

    if (i<>f.Count-1) and AddedWhere then
      Where:=Where+' '+txFilterOperatorSQL[f[i].Operator]+' ';
   end;
end;

function TtxSqlQueryFragments.BuildSQL: UTF8String;
var
  m:TMemoryStream;
  procedure Add1(const s:UTF8String);
  begin
    m.Write(s[1],Length(s));
  end;
  procedure Add(const t,u:UTF8String);
  begin
    if u<>'' then
     begin
      m.Write(t[1],Length(t));
      m.Write(u[1],Length(u));
     end;
  end;
var
  l:integer;
begin
  m:=TMemoryStream.Create;
  try
    Add1('SELECT ');
    if Distinct then Add1('DISTINCT ');
    Add1(Fields);
    Add1(#13#10'FROM ');
    Add1(Tables);//assert ends in #13#10
    Add('WHERE ',Where);
    Add(#13#10'GROUP BY ',GroupBy);
    Add(#13#10'HAVING ',Having);
    Add(#13#10'ORDER BY ',OrderBy);
    if Limit<>-1 then Add1(#13#10'LIMIT '+IntToStrU(Limit));
    //MySql: Add1(' LIMIT '+IntToStrU(Limit)+',0');
    l:=m.Position;
    SetLength(Result,l);
    m.Position:=0;
    m.Read(Result[1],l);
  finally
    m.Free;
  end;
end;

procedure TtxSqlQueryFragments.AddWhere(const s:UTF8String);
begin
  Where:=Where+s;
  AddedWhere:=true;
end;

procedure TtxSqlQueryFragments.AddWhereSafe(const s:UTF8String);
var
  i,j:integer;
begin
  j:=0;
  for i:=1 to Length(s) do
    case s[i] of
      '''':inc(j);
      ';':if (j and 1)=0 then raise EtxSqlQueryError.Create('Semicolon in external SQL not allowed');
      //TODO: detect and refuse comment? '--' and '/*'
    end;
  if (j and 1)=1 then raise EtxSqlQueryError.Create('Unterminated string in external SQL detected');
  Where:=Where+s;
  AddedWhere:=true;
end;

procedure TtxSqlQueryFragments.AddFrom(const s:UTF8String);
begin
  if s<>'' then
    if Pos(s,Tables)=0 then
      Tables:=Tables+s+#13#10;
end;

function TtxSqlQueryFragments.SqlStr(const s:UTF8String): UTF8String;
var
  i,j:integer;
begin
  j:=0;
  for i:=1 to Length(s) do if s[i]='''' then inc(j);
  if j=0 then
    Result:=''''+s+''''
  else
   begin
    i:=Length(s)+j+2;
    SetLength(Result,i);
    Result[1]:='''';
    Result[i]:='''';
    i:=1;
    j:=2;
    while i<=Length(s) do
     begin
      if s[i]='''' then
       begin
        Result[j]:='''';
        inc(j);
       end;
      Result[j]:=s[i];
      inc(j);
      inc(i);
     end;
   end;
end;

function TtxSqlQueryFragments.Criterium(const El:TtxFilterElement;
  const SubQryField, SubQryFrom: UTF8String;
  ParentsOnly, Reverse: boolean): UTF8String;
const
  idGrow=$1000;
var
  ItemType:TtxItemType;
  idSQL,t:UTF8String;
  ids,ids1:TIdList;
  i,j,l:integer;
  fe:TtxFilterEnvVar;
  f:TtxFilter;
  fq:TtxSqlQueryFragments;
  qr:TQueryResult;
begin
  ItemType:=txFilterActionItemType[El.Action];
  idSQL:='';
  ids:=TIdList.Create;
  try
    t:=txItemTypeTable[ItemType];
    case El.IDType of
      dtNumber:
        if TryStrToInt(string(El.ID),i) then ids.Add(i) else
          raise EtxSqlQueryError.Create('Invalid ID at position: '+IntToStr(El.Idx1));
      dtNumberList:
       begin
        i:=1;
        l:=Length(El.ID);
        while (i<=l) and not(AnsiChar(El.ID[i]) in ['0'..'9']) do inc(i);
        while (i<=l) do
         begin
          j:=0;
          while (i<=l) and (AnsiChar(El.ID[i]) in ['0'..'9']) do
           begin
            j:=j*10+(byte(El.ID[i]) and $F);
            inc(i);
           end;
          ids.Add(j);
          while (i<=l) and not(AnsiChar(El.ID[i]) in ['0'..'9']) do inc(i);
         end;
       end;
      dtSystem: //TODO: realms?
        case ItemType of
          itObj:
            idSQL:='SELECT Obj.id FROM Obj WHERE Obj.name LIKE '+SqlStr(El.ID);
          itObjType,itTokType,itRefType,itRealm:
            idSQL:='SELECT '+t+'.id FROM '+t+' WHERE '+t+'.system='+SqlStr(El.ID);
          itFilter:
            idSQL:='SELECT Flt.id FROM Flt WHERE Flt.name='+SqlStr(El.ID);
          itUser:
            idSQL:='SELECT Usr.uid FROM Usr WHERE Usr.login='+SqlStr(El.ID);
          itJournal:
            idSQL:='SELECT Jrl.id FROM Jrl WHERE Jrl.system='+SqlStr(El.ID);
          else
            raise EtxSqlQueryError.Create('String search on '+txItemTypeName[ItemType]+' is not allowed');
        end;
      dtSubQuery:
       begin
        f:=TtxFilter.Create;
        fq:=TtxSqlQueryFragments.Create(ItemType);
        try
          f.FilterExpression:=El.ID;
          if f.ParseError<>'' then
            raise EtxSqlQueryError.Create('Error in sub-query :'+f.ParseError);
          fq.AddFilter(f);

          fq.Fields:=SubQryField;
          fq.AddFrom(SubQryFrom);
          fq.OrderBy:='';

          idSQL:=fq.BuildSQL;
          //TODO: realms?
        finally
          f.Free;
          fq.Free;
        end;
       end;
      dtEnvironment:
       begin
        fe:=TtxFilter.GetFilterEnvVar(El.ID);
        case fe of
          feUs:idSQL:='SELECT Obj.id FROM Obj WHERE Obj.pid='+IntToStrU(EnvVars[feMe]);
          fe_Unknown:raise EtxSqlQueryError.Create('Unknown Filter Environment Variable: '+string(El.ID));
          else ids.Add(EnvVars[fe]);
        end;
       end;
      else raise EtxSqlQueryError.Create('Unsupported IDType at position '+IntToStr(El.Idx1));
    end;

    if (El.Descending or El.Prefetch) and (idSQL<>'') then
     begin
      qr:=TQueryResult.Create(Session.DbCon,idSQL,[]);
      try
        while qr.Read do ids.Add(qr.GetInt(0));
      finally
        qr.Free;
      end;
      idSQL:='';
     end;

    if El.Descending then
     begin
      if Reverse then
        if Use_ObjPath and (ItemType=itObj) then
          if idSQL='' then
            if ids.Count=1 then
              idSQL:='SELECT pid FROM ObjPath WHERE oid='+IntToStrU(ids[0])
            else
              idSQL:='SELECT pid FROM ObjPath WHERE oid IN ('+ids.List+')'
          else
            idSQL:='SELECT pid FROM ObjPath WHERE oid IN ('+idSQL+')'
        else
         begin
          i:=0;
          while i<ids.Count do
           begin
            qr:=TQueryResult.Create(Session.DbCon,'SELECT '+t+'.pid FROM '+t+' WHERE '+t+'.id='+IntToStrU(ids[i]),[]);
            try
              while qr.Read do ids.Add(qr.GetInt(0));
            finally
              qr.Free;
            end;
            inc(i);
           end;
         end
      else
        if ParentsOnly then
         begin
          if Use_ObjPath and (ItemType=itObj) then
            if idSQL='' then
              if ids.Count=1 then
                idSQL:='SELECT DISTINCT X2.pid FROM ObjPath X1 INNER JOIN Obj X2 ON X1.pid<>X1.oid AND X2.id=X1.oid WHERE X1.pid='+IntToStrU(ids[0])
              else
                idSQL:='SELECT DISTINCT X2.pid FROM ObjPath X1 INNER JOIN Obj X2 ON X1.pid<>X1.oid AND X2.id=X1.oid WHERE X1.pid IN ('+ids.List+')'
            else
              idSQL:='SELECT DISTINCT X2.pid FROM ObjPath X1 INNER JOIN Obj X2 ON X1.pid<>X1.oid AND X2.id=X1.oid WHERE X1.pid IN ('+idSQL+')'
          else
           begin
            ids1:=TIdList.Create;
            try
              ids1.AddList(ids);
              ids.Clear;
              i:=0;
              while i<ids1.Count do
               begin
                //only add those with children
                qr:=TQueryResult.Create(Session.DbCon,'SELECT '+t+'.id FROM '+t+' WHERE '+t+'.pid='+IntToStrU(ids1[i]),[]);
                try
                  if not qr.EOF then ids.Add(ids1[i]);
                  while qr.Read do ids1.AddClip(qr.GetInt(0),i);
                finally
                  qr.Free;
                end;
                inc(i);
               end;
            finally
              ids1.Free;
            end;
           end;
         end
        else
         begin
          //full expand
          if Use_ObjPath and (ItemType=itObj) then
            if idSQL='' then
              if ids.Count=1 then
                idSQL:='SELECT oid FROM ObjPath WHERE pid='+IntToStrU(ids[0])
              else
                idSQL:='SELECT oid FROM ObjPath WHERE pid IN ('+ids.List+')'
            else
              idSQL:='SELECT oid FROM ObjPath WHERE pid IN ('+idSQL+')'
          else
           begin
            i:=0;
            while i<ids.Count do
             begin
              qr:=TQueryResult.Create(Session.DbCon,'SELECT '+t+'.id FROM '+t+' WHERE '+t+'.pid='+IntToStrU(ids[i]),[]);
              try
                while qr.Read do ids.Add(qr.GetInt(0));
              finally
                qr.Free;
              end;
              inc(i);
             end;
           end;
         end;

     end
    else
      if Reverse then //one level up
        for i:=0 to ids.Count-1 do
         begin
          qr:=TQueryResult.Create(Session.DbCon,'SELECT '+t+'.pid FROM '+t+' WHERE '+t+'.id='+IntToStrU(ids[i]),[]);
          try
            ids[i]:=qr.GetInt(0);
          finally
            qr.Free;
          end;
         end;

    if idSQL='' then
      case ids.Count of
        0:Result:='=-1';
        1:Result:='='+IntToStrU(ids[0]);
        else Result:=' IN ('+ids.List+')';
      end
    else
      Result:=' IN ('+idSQL+')';

  finally
    ids.Free;
  end;
end;

procedure TtxSqlQueryFragments.AddOrderBy(const s: UTF8String);
begin
  if s<>'' then
    if OrderBy='' then OrderBy:=s else
      if Pos(s,OrderBy)=0 then
        OrderBy:=s+', '+OrderBy;
end;

{ TIdList }

constructor TIdList.Create;
begin
  inherited Create;
  Clear;
end;

destructor TIdList.Destroy;
begin
  SetLength(ids,0);
  inherited;
end;

const
  IdListGrow=$1000;

procedure TIdList.Add(id: integer);
begin
  if idCount=idSize then
   begin
    inc(idSize,IdListGrow);
    SetLength(ids,idSize);
   end;
  ids[idCount]:=id;
  inc(idCount);
end;

procedure TIdList.AddList(list: TIdList);
var
  l:integer;
begin
  l:=List.Count;
  while (idSize<idCount+l) do inc(idSize,IdListGrow);
  SetLength(ids,idSize);
  Move(list.ids[0],ids[idCount],l*4);
  inc(idCount,l);
end;

procedure TIdList.AddClip(id:integer; var Clip:integer);
var
  i:integer;
begin
  //things before Clip no longer needed
  i:=Clip div IdListGrow;
  if i<>0 then
   begin
    i:=i*IdListGrow;
    //shrink? keep data for re-use (idSize)
    Move(ids[i],ids[0],i*4);
    dec(Clip,i);
    dec(idCount,i);
   end;
  Add(id);
end;

procedure TIdList.Clear;
begin
  idCount:=0;
  idSize:=0;
  //SetLength(ids,idSize);//keep allocated data for re-use
end;

function TIdList.GetList: UTF8String;
var
  i:integer;
begin
  if idCount=0 then Result:='' else
   begin
    Result:=IntToStrU(ids[0]);
    i:=1;
    while i<idCount do
     begin
      Result:=Result+','+IntToStrU(ids[i]) ;
      inc(i);
     end;
   end;
end;

function TIdList.GetItem(Idx: integer): integer;
begin
  Result:=ids[Idx];
end;

procedure TIdList.SetItem(Idx, Value: integer);
begin
  ids[Idx]:=Value;
end;

function TIdList.Contains(id:integer):boolean;
var
  i:integer;
begin
  i:=0;
  while (i<idCount) and (ids[i]<>id) do inc(i);
  Result:=i<idCount;
end;

end.
