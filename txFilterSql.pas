unit txFilterSql;

interface

uses SysUtils, txDefs, txFilter, SQLiteData;

type
  TtxSqlQueryFragments=class(TObject)
  private
    FItemType:TtxItemType;
    AliasCount,FParentID:integer;
    AddedWhere:boolean;
    DbCon:TSQLiteConnection;
    function BuildSQL:string;

    function SqlStr(s:string):string;
    function Criterium(const El:TtxFilterElement;
      SubQryField, SubQryFrom: string;
      ParentsOnly, Reverse: boolean):string;

  public
    Limit:integer;
    Fields,Tables,Where,GroupBy,Having,OrderBy:string;
    EnvVars:array[TtxFilterEnvVar] of integer;

    constructor Create(ItemType: TtxItemType);
    destructor Destroy; override;

    procedure AddFilter(f:TtxFilter);

    procedure AddWhere(s:string);
    procedure AddWhereSafe(s:string);
    procedure AddOrderBy(s:string);
    procedure AddFrom(s:string);

    property SQL:string read BuildSQL;
    property ParentID:integer read FParentID;
  end;

  EtxSqlQueryError=class(Exception);

  TIdList=class(TObject)
  private
    idCount,idSize:integer;
    ids:array of integer;
    function GetList:string;
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
    property List:string read GetList;
    property Count:integer read idCount;
    property Item[Idx:integer]:integer read GetItem write SetItem; default;
  end;
  
implementation

uses txSession, Classes, Variants;

{ TtxSqlQueryFragments }

constructor TtxSqlQueryFragments.Create(ItemType: TtxItemType);
var
  t:string;
  fe:TtxFilterEnvVar;
begin
  inherited Create;
  AliasCount:=0;
  Limit:=-1;
  FParentID:=0;
  FItemType:=ItemType;
  DbCon:=Session.DbCon;
  case FItemType of
    itObj:
     begin
      Fields:='Obj.id, Obj.pid, Obj.[name], Obj.[desc], Obj.[weight], Obj.[c_uid], Obj.[c_ts], Obj.[m_uid], Obj.[m_ts], ObjType.[icon], ObjType.[name] AS [typename]';
      Tables:='(Obj LEFT JOIN ObjType ON ObjType.id=Obj.objtype_id)';
      Where:='';
      GroupBy:='';
      Having:='';
      OrderBy:='Obj.weight, Obj.name, Obj.c_ts';
     end;
    itReport:
     begin
      Fields:='Rpt.id, Rpt.obj_id, Rpt.[desc], Rpt.uid, Rpt.ts, Rpt.toktype_id, Rpt.reftype_id, Rpt.obj2_id,'+
       ' Obj.[name], Obj.pid, ObjType.[icon], ObjType.[name] AS [typename],'+
       ' UsrObj.id AS [usrid], UsrObj.[name] AS [usrname], UsrObjType.[icon] AS [usricon], UsrObjType.[name] AS [usrtypename],'+
       ' RelTokType.[icon] AS [tokicon], RelTokType.[name] AS [tokname], RelTokType.[system] AS [toksystem],'+
       ' RelRefType.[icon] AS [reficon], RelRefType.[name] AS [refname],'+
       ' RelObj.[name] AS [relname], RelObjType.[icon] AS [relicon], RelObjType.[name] AS [reltypename]';
      Tables:='Rpt'#13#10+
       '  INNER JOIN Obj ON Obj.id=Rpt.obj_id'#13#10+
       '  INNER JOIN ObjType ON ObjType.id=Obj.objtype_id'#13#10+
       '  INNER JOIN Obj AS UsrObj ON UsrObj.id=Rpt.uid'#13#10+
       '  INNER JOIN ObjType AS UsrObjType ON UsrObjType.id=UsrObj.objtype_id'#13#10+
       '  LEFT OUTER JOIN Obj AS RelObj ON RelObj.id=Rpt.obj2_id'#13#10+
       '  LEFT OUTER JOIN ObjType AS RelObjType ON RelObjType.id=RelObj.objtype_id'#13#10+
       '  LEFT OUTER JOIN TokType AS RelTokType ON RelTokType.id=Rpt.toktype_id'#13#10+
       '  LEFT OUTER JOIN RefType AS RelRefType ON RelRefType.id=Rpt.reftype_id'#13#10;
      Where:='';
      GroupBy:='';
      Having:='';
      OrderBy:='Rpt.ts DESC';
     end;
    else
     begin
      t:=txItemTypeTable[ItemType];
      Fields:='*';
      Tables:=t;
      Where:='';
      GroupBy:='';
      Having:='';
      OrderBy:=t+'.weight, '+t+'.name, '+t+'.c_ts';
     end;
  end;
  if Use_ObjTokRefCache and (FItemType in [itObj,itReport]) then
   begin
	  Fields:=Fields+', ObjTokRefCache.tokHTML, ObjTokRefCache.refHTML';
	  Tables:=Tables+#13#10'  LEFT OUTER JOIN ObjTokRefCache ON ObjTokRefCache.id=Obj.id';
   end;  
  for fe:=TtxFilterEnvVar(0) to fe_Unknown do EnvVars[feMe]:=0;
  EnvVars[feMe]:=Session.UserID;
end;

destructor TtxSqlQueryFragments.Destroy;
begin
  //clean-up
  DbCon:=nil;
  inherited;
end;

procedure TtxSqlQueryFragments.AddFilter(f: TtxFilter);
var
  i,j,k:integer;
  s,t:string;
  qr:TSQLiteStatement;
  fx:TtxFilter;
  fq:TtxSqlQueryFragments;
  procedure LocalPrefetch;
  begin
    with TIdList.Create do
      try
	    qr:=TSQLiteStatement.Create(Session.DbCon,s);
		try
		  while qr.Read do Add(qr.GetInt(0));
		finally
		  qr.Free;
		end;
        s:=List;
      finally
        Free;
      end;
  end;
const
  RefBSel:array[boolean] of string=('1','2');
begin
  //TODO: when FItemType<>itObj

  for i:=0 to f.Count-1 do with f[i] do
   begin

    //check global para count?
    for j:=1 to ParaOpen do Where:=Where+'(';

    //no para's when not AddedWhere?
    AddedWhere:=false;
    case Action of
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
          t:='ttSQ'+IntToStr(AliasCount);
          s:='SELECT DISTINCT Tok.obj_id FROM Tok WHERE Tok.toktype_id'+Criterium(f[i],
            'DISTINCT '+t+'.toktype_id','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,false);
          if Prefetch then LocalPrefetch;
          AddWhere('Obj.id IN ('+s+')');
         end;
      faRefType:
        //dummy check:
        if (f[i].IDType=dtNumber) and (f[i].ID='0') and (f[i].Descending) then
          AddWhere('EXISTS (SELECT id FROM Ref WHERE obj1_id=Obj.id)')
        else
         begin
          inc(AliasCount);
          t:='rtSQ'+IntToStr(AliasCount);
          s:='SELECT DISTINCT Ref.obj1_id FROM Ref WHERE Ref.reftype_id'+Criterium(f[i],
            'DISTINCT '+t+'.reftype_id','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj1_id=Obj.id',false,false);
          if Prefetch then LocalPrefetch;
          AddWhere('Obj.id IN ('+s+')');
         end;
      faBackRef:
       begin
        s:='';
        if Parameters<>'' then
         begin
          fx:=TtxFilter.Create;
          try
            fx.FilterExpression:=Parameters;
            for j:=0 to fx.Count-1 do with fx[j] do
              case Action of
                faRefType:
                 begin
                  inc(AliasCount);
                  t:='rxSQ'+IntToStr(AliasCount);
                  s:=' AND Ref.reftype_id'+Criterium(fx[j],
                    'DISTINCT '+t+'.id','RIGHT JOIN Ref AS '+t+' ON '+t+'.ref_obj1_id=Obj.id',false,false);
                 end
                else
                  raise EtxSqlQueryError.Create('Unexpected rx parameter at position '+IntToStr(Idx1));
              end;
          finally
            fx.Free;
          end;
         end;
        AddWhere('Obj.id IN (SELECT Ref.obj1_id FROM Ref WHERE Ref.obj2_id'+Criterium(f[i],
          'Obj.id','',false,false)+s+')');
       end;

      faParent:
        case IDType of
          dtNumber:FParentID:=StrToInt(ID);
          //TODO
          //dtSystem:;
          //dtSubQuery:;
          //dtEnvironment:;
          else
            raise EtxSqlQueryError.Create('Unsupported IDType at position: '+IntToStr(Idx1));
        end;

      faFilter:
       begin
        if Descending then raise EtxSqlQueryError.Create('Descending into filter not supported');
        fx:=TtxFilter.Create;
        try
          //TODO: detect loops?
          qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT Flt.expression FROM Flt WHERE Flt.id'+Criterium(f[i],'','',false,false)+' LIMIT 1');
          try
            if qr.EOF then raise EtxSqlQueryError.Create('Filter not found at position '+IntToStr(Idx1));
              fx.FilterExpression:=qr.GetStr(0);
          finally
            qr.Free;
          end;
          if fx.ParseError<>'' then raise EtxSqlQueryError.Create(
            'Invalid filter at position '+IntToStr(Idx1)+': '+fx.ParseError);
          if Prefetch then
           begin
            fq:=TtxSqlQueryFragments.Create(FItemType);
            try
              fq.AddFilter(fx);
              fq.Fields:='Obj.id';
              fq.OrderBy:='';
              s:=fq.SQL;
              LocalPrefetch;
              AddWhere('Obj.id IN ('+s+')');
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
        AddWhere('Obj.name='+SqlStr(ID));
        OrderBy:='Obj.m_ts, Obj.weight, Obj.name';
       end;
      faDesc:
       begin
        AddWhere('Obj.[desc] LIKE '+SqlStr(ID));
        OrderBy:='Obj.m_ts, Obj.weight, Obj.name';
       end;
      faSearchName:
       begin
        AddWhere('Obj.name LIKE '+SqlStr(ID));//parentheses?
        OrderBy:='Obj.m_ts, Obj.weight, Obj.name';
       end;
      faSearch:
       begin
        //parameters?
        k:=1;
        s:='';
        while k<=Length(ID) do
         begin
          j:=k;
          while (k<=Length(ID)) and not(ID[k] in [#0..#32]) do inc(k);
          if k-j<>0 then
           begin
            if s<>'' then s:=s+' AND ';
            s:=s+'(Obj.name LIKE '+SqlStr('%'+Copy(ID,j,k-j)+'%')+' OR Obj.[desc] LIKE '+SqlStr('%'+Copy(ID,j,k-j)+'%')+')';
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
        while k<=Length(ID) do
         begin
          j:=k;
          while (k<=Length(ID)) and not(ID[k] in [#0..#32]) do inc(k);
          if k-j<>1 then
           begin
            if s<>'' then s:=s+' AND ';
            s:=s+'Rpt.[desc] LIKE '+SqlStr('%'+Copy(ID,j,k-j)+'%');
           end;
          inc(k);
         end;
        if s='' then s:='0=1';//match none? match all?
        AddWhere('('+s+')');
        //OrderBy:=//assert already Rpt.ts desc
       end;
      faTerm:
       begin
        AddFrom('INNER JOIN Trm ON Trm.obj_id=Obj.id');
        //parameters?
        k:=1;
        s:='';
        while k<=Length(ID) do
         begin
          j:=k;
          while (k<=Length(ID)) and not(ID[k] in [#0..#32]) do inc(k);
          if k-j<>1 then
           begin
            if s<>'' then s:=s+' OR ';//AND?
            //s:=s+'Trm.term LIKE '+SqlStr('%'+Copy(ID,j,k-j)+'%');
            s:=s+'Trm.term='+SqlStr(Copy(ID,j,k-j));
           end;
          inc(k);
         end;
        if s='' then s:='0=1';//match none? match all?
        AddWhere('('+s+')');
       end;

      faAlwaysTrue:
        if (ParaClose=0) and (i<>f.Count-1) then
          case Operator of
            foAnd:;//skip
            foAndNot:Where:=Where+'NOT ';
            else AddWhere('1=1');
          end
        else AddWhere('1=1');
      faAlwaysFalse:
        if (ParaClose=0) and (i<>f.Count-1) then
          case Operator of
            foOr:;//skip
            foOrNot:Where:=Where+'NOT ';
            else AddWhere('0=1');
          end
        else AddWhere('0=1');
      faSQL:
       begin
        AddWhereSafe(ID);
        AddWhereSafe(Parameters);
       end;
      faExtra:;//TODO: filterparameters

      faPath:
        AddWhere('Obj.id'+Criterium(f[i],'Obj.pid','',false,true));
        //descending?
      faPathObjType:
        AddWhere('Obj.objtype_id'+Criterium(f[i],'DISTINCT ObjType.pid','',false,true));
      faPathTokType:
       begin
        inc(AliasCount);
        t:='ptSQ'+IntToStr(AliasCount);
        s:='SELECT DISTINCT Tok.obj_id FROM Tok WHERE Tok.toktype_id'+Criterium(f[i],
          'DISTINCT '+t+'.toktype_pid','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,true);
        if Prefetch then LocalPrefetch;
        AddWhere('Obj.id IN ('+s+')');
       end;
      faPathRefType:
       begin
        inc(AliasCount);
        t:='prSQ'+IntToStr(AliasCount);
        s:='SELECT DISTINCT Ref.obj1_id FROM Ref WHERE Ref.reftype_id'+Criterium(f[i],
          'DISTINCT '+t+'.reftype_pid','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj1_id=Obj.id',false,true);
        if Prefetch then LocalPrefetch;
        AddWhere('Obj.id IN ('+s+')');
       end;

      faCreated:
        AddWhere('Obj.c_uid'+Criterium(f[i],'Obj.id','',false,false));
      faTokCreated:
       begin
        s:='SELECT DISTINCT Tok.obj_id FROM Tok WHERE Tok.c_uid'+Criterium(f[i],'Obj.id','',false,false);
        if Prefetch then LocalPrefetch;
        AddWhere('Obj.id IN ('+s+')');
       end;
      faRefCreated,faBackRefCreated:
       begin
        s:='';
        if Parameters<>'' then
         begin
          fx:=TtxFilter.Create;
          try
            fx.FilterExpression:=Parameters;
            for j:=0 to fx.Count-1 do with fx[j] do
              case Action of
                faRefType:
                 begin
                  inc(AliasCount);
                  t:='urSQ'+IntToStr(AliasCount);
                  s:=' AND Ref.reftype_id'+Criterium(fx[j],'DISTINCT '+t+'.id','RIGHT JOIN Ref AS '+t+' ON '+t+
                    '.ref_obj'+RefBSel[Action=faBackRefCreated]+'_id=Obj.id',false,false);
                 end
                else
                  raise EtxSqlQueryError.Create('Unexpected rx parameter at position '+IntToStr(Idx1));
              end;
          finally
            fx.Free;
          end;
         end;
        s:='SELECT DISTINCT Ref.obj'+RefBSel[Action=faBackRefCreated]+'_id FROM Ref WHERE Ref.c_uid'+
          Criterium(f[i],'Obj.id','',false,false)+s;
        if Prefetch then LocalPrefetch;
        AddWhere('Obj.id IN ('+s+')');
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
        t:='ttSQ'+IntToStr(AliasCount);
        if Prefetch then
         begin
          s:='SELECT DISTINCT Tok.id FROM Tok WHERE Tok.toktype_id'+Criterium(f[i],
            'DISTINCT '+t+'toktype_id','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,false);
          LocalPrefetch;
          AddWhere('Tok.ID IN ('+s+')');
         end
        else
          AddWhere('Tok.toktype_id'+Criterium(f[i],
            'DISTINCT '+t+'toktype_id','RIGHT JOIN Tok AS '+t+' ON '+t+'.obj_id=Obj.id',false,false));
       end;
      faRecentRef,faRecentBackRef:
       begin
        AddFrom('INNER JOIN Ref ON Ref.obj'+RefBSel[Action=faRecentBackRef]+'_id=Obj.id');
        AddOrderBy('Ref.m_ts DESC');
        inc(AliasCount);
        t:='rtSQ'+IntToStr(AliasCount);
        if Prefetch then
         begin
           s:='SELECT DISTINCT Ref.id FROM Ref WHERE Ref.reftype_id'+Criterium(f[i],
             'DISTINCT '+t+'reftype_id','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj'+
             RefBSel[Action=faRecentBackRef]+'_id=Obj.id',false,false);
         end
        else
          AddWhere('Ref.reftype_id'+Criterium(f[i],
            'DISTINCT '+t+'.reftype_id','RIGHT JOIN Ref AS '+t+' ON '+t+'.obj'+
            RefBSel[Action=faRecentBackRef]+'_id=Obj.id',false,false));
       end;
      faRealm:
        AddWhere('Obj.rlm_id'+Criterium(f[i],'Rlm.id','',false,false));

      else
        raise EtxSqlQueryError.Create('Unsupported filter action at position '+IntToStr(Idx1));
    end;

    //check global para count?
    for j:=1 to ParaClose do Where:=Where+')';

    if (i<>f.Count-1) and AddedWhere then
      Where:=Where+' '+txFilterOperatorSQL[Operator]+' ';
   end;
end;

function TtxSqlQueryFragments.BuildSQL: string;
var
  s:TStringStream;
  procedure Add(t,u:string);
  begin
    if u<>'' then
     begin
      s.WriteString(t);
      s.WriteString(u);
     end;
  end;
begin
  s:=TStringStream.Create('');
  try
    s.WriteString('SELECT ');
    s.WriteString(Fields);
    s.WriteString(' FROM ');
    s.WriteString(Tables);
    Add(' WHERE ',Where);
    Add(' GROUP BY ',GroupBy);
    Add(' HAVING ',Having);
    Add(' ORDER BY ',OrderBy);
    if Limit<>-1 then s.WriteString(' LIMIT '+IntToStr(Limit));
    //MySql: s.WriteString(' LIMIT '+IntToStr(Limit)+',0');
    Result:=s.DataString;
  finally
    s.Free;
  end;
end;

procedure TtxSqlQueryFragments.AddWhere(s: string);
begin
  Where:=Where+s;
  AddedWhere:=true;
end;

procedure TtxSqlQueryFragments.AddWhereSafe(s: string);
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

procedure TtxSqlQueryFragments.AddFrom(s: string);
begin
  if s<>'' then
    if Pos(s,Tables)=0 then
      Tables:='('+Tables+') '+s;
end;

function TtxSqlQueryFragments.SqlStr(s: string): string;
begin
  Result:=''''+StringReplace(s,'''','''''',[rfReplaceAll])+'''';
end;

function TtxSqlQueryFragments.Criterium(const El:TtxFilterElement;
  SubQryField, SubQryFrom: string;
  ParentsOnly, Reverse: boolean): string;
const
  idGrow=$1000;
var
  ItemType:TtxItemType;
  idSQL,t:string;
  ids,ids1:TIdList;
  i:integer;
  fe:TtxFilterEnvVar;
  f:TtxFilter;
  fq:TtxSqlQueryFragments;
  qr:TSQLiteStatement;
begin
  ItemType:=txFilterActionItemType[El.Action];
  idSQL:='';
  ids:=TIdList.Create;
  try
    t:=txItemTypeTable[ItemType];
    case El.IDType of
      dtNumber:
        ids.Add(StrToInt(El.ID));
      dtSystem: //TODO: realms?
        case ItemType of
          itObj:
            idSQL:='SELECT Obj.id FROM Obj WHERE Obj.name LIKE '+SqlStr(El.ID);
          itObjType,itTokType,itRefType,itRealm:
            idSQL:='SELECT '+t+'.id FROM '+t+' WHERE '+t+'.system='+SqlStr(El.ID);
          itFilter:
            idSQL:='SELECT Flt.id FROM Flt WHERE Flt.name='+SqlStr(El.ID);
          itUser:
            idSQL:='SELECT Usr.id FROM Usr WHERE Usr.login='+SqlStr(El.ID);
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
		  feUs:idSQL:='SELECT Obj.id FROM Obj WHERE Obj.pid='+IntToStr(EnvVars[feMe]);
          fe_Unknown:raise EtxSqlQueryError.Create('Unknown Filter Environment Variable: '+El.ID);
		  else ids.Add(EnvVars[fe]);
        end;
       end;
      else raise EtxSqlQueryError.Create('Unsupported IDType at position '+IntToStr(El.Idx1));
    end;

    if (El.Descending or El.Prefetch) and (idSQL<>'') then
     begin
	  qr:=TSQLiteStatement.Create(Session.DbCon,idSQL);
	  try
	    while qr.Read do ids.Add(qr.GetInt(0));
	  finally
	    qr.Free;
	  end;
      idSQL:='';
     end;
	 
    if Reverse then //exclude starting point
      for i:=0 to ids.Count-1 do
	   begin
	    qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT '+t+'.pid FROM '+t+' WHERE '+t+'.id='+IntToStr(ids[i]));
		try
		  ids[i]:=qr.GetInt(0);
		finally
		  qr.Free;
		end;
	   end;

    if El.Descending then
     begin
      if Reverse then
	    if Use_ObjPath and (ItemType=itObj) then
		  if idSQL='' then
		    idSQL:='SELECT pid FROM ObjPath WHERE oid IN ('+ids.List+')'
		  else
		    idSQL:='SELECT pid FROM ObjPath WHERE oid IN ('+idSQL+')'
		else
         begin
          i:=0;
          while i<ids.Count do
           begin
		    qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT '+t+'.pid FROM '+t+' WHERE '+t+'.id='+IntToStr(ids[i]));
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
          ids1:=TIdList.Create;
          try
            ids1.AddList(ids);
            ids.Clear;
            i:=0;
            while i<ids1.Count do
             begin
              //only add those with children
			  qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT '+t+'.id FROM '+t+' WHERE '+t+'.pid='+IntToStr(ids1[i]));
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
         end
        else
         begin
          //full expand
		  if Use_ObjPath and (ItemType=itObj) then
		    if idSQL='' then
		      idSQL:='SELECT oid FROM ObjPath WHERE pid IN ('+ids.List+')'
			else
			  idSQL:='SELECT oid FROM ObjPath WHERE pid IN ('+idSQL+')'
		  else
		   begin
            i:=0;
            while i<ids.Count do
             begin
		      qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT '+t+'.id FROM '+t+' WHERE '+t+'.pid='+IntToStr(ids[i]));
			  try
			    while qr.Read do ids.Add(qr.GetInt(0));
			  finally
			    qr.Free;
			  end;
              inc(i);
             end;
		   end;
         end;

     end;

    if idSQL='' then
      case ids.Count of
        0:Result:='=-1';
        1:Result:='='+IntToStr(ids[0]);
        else Result:=' IN ('+ids.List+')';	
      end
    else
      Result:=' IN ('+idSQL+')';

  finally
    ids.Free;
  end;
end;

procedure TtxSqlQueryFragments.AddOrderBy(s: string);
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

function TIdList.GetList: string;
var
  i:integer;
  s:TStringStream;
begin
  if idCount=0 then Result:='' else
   begin
    s:=TStringStream.Create('');
    try
      s.WriteString(IntToStr(ids[0]));
      for i:=1 to idCount-1 do s.WriteString(','+IntToStr(ids[i]));
      Result:=s.DataString;
    finally
      s.Free;
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
