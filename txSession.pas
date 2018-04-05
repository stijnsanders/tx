unit txSession;

interface

uses SysUtils, Classes, xxm, DataLank, txDefs, txTerms;

const
  //SessionTimeout=20\1440; //20 mins
  SessionTimeout=2; //48 hours
  MaxSessions=1000;
  FilterRecentCount=25;
  ViewedLastCount=50;
  AutoLogonCookieName='txAutoLogon';
  AutoLogonCookieTimeoutDays=100;
  sqlDesc='desc';//='[desc]';? ='"desc"';?

var
  //see LoadProjectSettings
  AdministratorEmailAddress: string;
  UseNTAuth: boolean;

type
  TtxRealmPermission=(rpView,rpEdit,rpAny,rpBoth);

  TtxFilterViewInfo=record
    filter,filterU,view:string;
    rp:TtxRealmPermission;
  end;

  TtxSession=class(TObject)
  private
    FSessionID,FSessionCrypt:string;
    FRealmsCounter,FLogonAttemptCount: integer;
    FTerms: TTermStore;
    FIsAnonymous: boolean;
    function Grow(rp:TtxRealmPermission):integer;
    function GetDbCon: TDataConnection;
  public
    Expires:TDateTime;
    Data:TObject;//used with import for now, maybe more later, then review this

    //TODO: properties
    UserID,UpdateID,DeleteID:integer;
    JsLoaded,QryUnread,Stealth:boolean;
    Realms:array[TtxRealmPermission] of record
      Ids:array of integer;
      Count,Size:integer;
      SQL:string;
    end;
    RealmsSQLExtra:string;
    FilterRecent:array[itObj..itRefType,0..FilterRecentCount-1] of integer;
    FilterCache:TStringList;
    FooterDisplay:string;
    ViewedLast:array[0..ViewedLastCount-1] of integer;
    CssPrefs:record
      BaseSizePt:integer;
      FontName:string;
      DemoMode:boolean;
    end;
    CssModSince,JsModSince:string;
    RevertUserID:integer;
    RevertFooterDisplay:string;
    RecentReferences:array[0..FilterRecentCount-1] of record reftype,obj2:integer; end;

    constructor Create(const SessionID:string);
    destructor Destroy; override;
    property SessionID:string read FSessionID;
    property SessionCrypt:string read FSessionCrypt;
    property DbCon: TDataConnection read GetDbCon;
    property IsAnonymous: boolean read FIsAnonymous;
    procedure LoadUser(qr:TQueryResult);
    procedure LoadRealmPermissions;
    procedure BuildRealmPermissionsSQL;
    procedure SetViewRealm(AddRemove:boolean;RealmID:integer);//used by Realm.xxm only!
    procedure HasRealmPermission(ObjID,RealmID:integer;RealmPerm:TtxRealmPermission);
    function IsAdmin(const Key:string):boolean;
    procedure AddFilterRecent(ItemType:TtxItemType;id:integer);
    procedure RemoveFilterRecent(ItemType:TtxItemType;id:integer);
    procedure AddViewedLast(id:integer);
    procedure RemoveViewedLast(id:integer);
    procedure AddRecentReference(reftype,obj2:integer);
    procedure LogonAttemptCheck;
    class procedure Abandon;
    class function PermissionByName(const x:string):TtxRealmPermission;
  end;

  ERealmNotEditableByUser=class(Exception);

procedure LoadProjectSettings;
function ModulePath:string;
function SetSession(Context: IXxmContext): boolean;
function PageRenderTimeMS:cardinal;
function TermStore:TTermStore;

function DBSingleValue(const SQL:UTF8String;Parameters:array of OleVariant;Default:OleVariant):OleVariant;
function DBExists(const SQL:UTF8String;Parameters:array of OleVariant):boolean;
function sqlObjsByPid:string;
function txCallProtect:string;
function txFormProtect:string;
procedure CheckCallProtect(Context:IXxmContext);
procedure CheckFormProtect(Context:IXxmContext);
procedure CheckMaintProtect(Context:IXxmContext);
function NewPasswordSalt:string;
function PasswordToken(const Salt,Password:string):string;
procedure NewAutoLogonToken(Context:IXxmContext;UslID:integer);
procedure ClearAutoLogonToken(Context:IXxmContext);

procedure GetFilterViewInfo(ctx:IXxmContext;var fv:TtxFilterViewInfo);

function RFC822DateGMT(dd: TDateTime): string;

function TryGetUserName(const Logon:WideString):WideString;

type
  LPCWSTR=PWideChar;
  DWORD=cardinal;
function NetUserGetInfo (servername: LPCWSTR; username: LPCWSTR;
  level: DWORD; var bufptr: Pointer): DWORD; stdcall;
function NetApiBufferFree(buffer: Pointer): DWORD ; stdcall;


threadvar
  Session: TtxSession;
  PageStartTQ,PageStartTF:int64;
  ThreadDbCon: TDataConnection;
var
  RealmsCounter: integer;

implementation

uses Windows, txFilter, txFilterSql, sha1, Math;

//TODO: something better than plain objectlist
//TODO: thread to check session expiry
var
  SessionStore:TStringList;
  SessionStoreLock:TRTLCriticalSection;

  //see LoadProjectSettings
  DbFilePath:string;
  MaintAuthKey:string;

function SetSession(Context: IXxmContext): boolean;
var
  i:integer;
  sid:string;
begin
  if not(QueryPerformanceCounter(PageStartTQ) and
    QueryPerformanceFrequency(PageStartTF)) then
   begin
    PageStartTQ:=GetTickCount;
    PageStartTF:=0;
   end;
  sid:=Context.SessionID+'|'+Context.ContextString(csUserAgent);//hash?
  EnterCriticalSection(SessionStoreLock);
  try
    //TODO: much better look-up (sorted?)
    {
    i:=0;
    while (i<SessionStore.Count) and (SessionStore[i]<>sid) do
      if (Now>=(SessionStore.Objects[i] as TtxSession).Expires) then
       begin
        SessionStore.Objects[i].Free;
        SessionStore.Delete(i);
       end
      else
        inc(i);
    if i<SessionStore.Count then
    }
    i:=SessionStore.IndexOf(sid);
    if i<>-1 then
     begin
      Session:=SessionStore.Objects[i] as TtxSession;
      Result:=Session.UserID=0;//:=false;//session found
     end
    else
     begin
      if SessionStore.Count=MaxSessions then
       begin
        //TODO: SetStatus(503,'Service Unavailable')?
        i:=RandomRange(0,MaxSessions-1);
        SessionStore.Objects[i].Free;
        SessionStore.Delete(i);
       end;
      Session:=TtxSession.Create(sid);
      SessionStore.AddObject(sid,Session);
      Result:=true;//new session
     end;
    Session.Expires:=Now+SessionTimeout;
  finally
    LeaveCriticalSection(SessionStoreLock);
  end;
end;

function ModulePath:string;
var
  i:integer;
begin
  SetLength(Result,MAX_PATH);
  i:=GetModuleFileName(HInstance,PChar(Result),MAX_PATH);
  while (i<>0) and (Result[i]<>PathDelim) do dec(i);
  SetLength(Result,i);
end;

procedure LoadProjectSettings;
var
  sl:TStringList;
begin
  sl:=TStringList.Create;
  try
    try
      sl.LoadFromFile(ModulePath+'tx.ini');
    except
      on EFOpenError do
       begin
        //default settings
        sl.Add('DB=[tx.ini not found]\tx.db');
       end;
    end;
    DbFilePath:=sl.Values['DB'];
    //relative?
    if (DbFilePath<>'') and not(DbFilePath[2] in [':','\']) then DbFilePath:=ModulePath+DbFilePath;
    MaintAuthKey:=sl.Values['AuthKey'];
    AdministratorEmailAddress:=sl.Values['AdministratorEmailAddress'];
    UseNTAuth:=sl.Values['NTAuth']='1';
  finally
    sl.Free;
  end;
end;

function PageRenderTimeMS:cardinal;
var
  x:int64;
begin
  if PageStartTF=0 then
    Result:=GetTickCount-PageStartTQ
  else
    if QueryPerformanceCounter(x) then
      Result:=(x-PageStartTQ)*1000 div PageStartTF
    else
      Result:=9009009;//error?raise?
end;

function TermStore:TTermStore;
begin
  //assert thread is CoInit'ed
  if Session.FTerms=nil then Session.FTerms:=TTermStore.Create(ModulePath+'WikiEngine.dll');
  Result:=Session.FTerms;
end;

{ TtxSession }

constructor TtxSession.Create(const SessionID: string);
var
  i:TtxItemType;
  j:integer;
  rp:TtxRealmPermission;
const
  //IMPORTANT: don't edit this constant or existing salted passwords will no longer work!
  SessionCryptSalt='[[[tx]]]'+
    '  inherited Create;'#13#10+
    '  FSessionID:=SessionID;'#13#10+
    '  FSessionCrypt:=SHA1Hash(SessionCryptSalt+FSessionID);'#13#10+
    '  FIsAnonymous:=false;'#13#10+
    '  FilterCache:=TStringList.Create;'#13#10+
    '  Data:=nil;'#13#10+
    '  FTerms:=nil;'#13#10+
    '  fn:=ModulePath;'#13#10+
    '  SetCurrentDir(ExtractFilePath(fn));'#13#10+
    '[[[tx]]]';
begin
  inherited Create;
  FSessionID:=SessionID;
  FSessionCrypt:=Copy(SHA1Hash(SessionCryptSalt+FSessionID),7,17);
  FIsAnonymous:=false;
  FLogonAttemptCount:=0;
  FilterCache:=TStringList.Create;
  Data:=nil;
  FTerms:=nil;
  JsLoaded:=false;
  JsModSince:=RFC822DateGMT(Now);
  QryUnread:=false;//see LoadUser
  Stealth:=false;

  //start session
  UserID:=0;
  UpdateID:=0;
  DeleteID:=0;
  FooterDisplay:='';
  RevertUserID:=0;
  RevertFooterDisplay:='';

  CssPrefs.DemoMode:=false;
  CssPrefs.BaseSizePt:=11;
  CssPrefs.FontName:='Calibri, Verdana, sans-serif';
  CssModSince:=RFC822DateGMT(Now);

  for i:=itObj to itRefType do for j:=0 to FilterRecentCount-1 do FilterRecent[i,j]:=0;
  for j:=0 to FilterRecentCount-1 do begin RecentReferences[j].reftype:=0; RecentReferences[j].obj2:=0; end;
  for j:=0 to ViewedLastCount-1 do ViewedLast[j]:=0;

  for rp:=rpView to rpBoth do with Realms[rp] do
   begin
    Count:=0;
    Size:=0;
    SQL:=' = (NULL)';//'safe' defaults
   end;
  RealmsSQLExtra:='';
  //LoadRealmPermissions called later (see LoadUser)
end;

destructor TtxSession.Destroy;
begin
  //FDbCon:=nil;//strange, COM object already died, Release doesn't respond
  //FDbCon.Free;
  FilterCache.Free;
  //FreeAndNil(FTerms);
  //FreeAndNil(Data);
  inherited;
end;

function TtxSession.GetDbCon: TDataConnection;
begin
  if ThreadDbCon=nil then
   begin
    ThreadDBCon:=TDataConnection.Create(DbFilePath);
    ThreadDBCon.BusyTimeout:=5000;
   end;
  Result:=ThreadDbCon;
end;

class procedure TtxSession.Abandon;
begin
  EnterCriticalSection(SessionStoreLock);
  try
    SessionStore.Delete(SessionStore.IndexOf(Session.SessionID));
    Session.Free;
  finally
    LeaveCriticalSection(SessionStoreLock);
  end;
  Session:=nil;
end;

procedure TtxSession.LoadUser(qr:TQueryResult);
begin
  FIsAnonymous:=qr.EOF or (qr.GetInt('isanon')=1);
  if qr.EOF then
   begin
    UserID:=0;
    FooterDisplay:='-';
   end
  else
   begin
    UserID:=qr.GetInt('uid');
    FooterDisplay:=qr.GetStr('email');
    AddFilterRecent(itObj,UserID);
   end;
  QryUnread:=Use_Unread and not(FIsAnonymous);
  FLogonAttemptCount:=0;//reset
  //Stealth:=?
  LoadRealmPermissions;
end;

function TtxSession.Grow(rp:TtxRealmPermission):integer;
begin
  //lock?
  with Realms[rp] do
   begin
    if Count=Size then
     begin
      inc(Size,$100);
      SetLength(Ids,Size);
     end;
    Result:=Count;
    inc(Count);
   end;
end;

procedure TtxSession.LoadRealmPermissions;
var
  qr,qr1:TQueryResult;
  fx,s:string;
  f:TtxFilter;
  fq:TtxSqlQueryFragments;
  rid,i,fcl:integer;
  rp:TtxRealmPermission;
  b:boolean;
  fc:array of record
    x:string;
    b:boolean;
  end;
const
  rname:array[TtxRealmPermission] of string=('view','edit','','');
begin
  //lock?
  FRealmsCounter:=RealmsCounter;
  for rp:=rpView to rpEdit do with Realms[rp] do
   begin
    Count:=0;
    SQL:='';
   end;
  RealmsSQLExtra:='';
  fcl:=0;
  SetLength(fc,fcl);
  //rpView, rpEdit only, rpAny, rpBoth: see BuildRealmPermissionsSQL
  qr:=TQueryResult.Create(DbCon,'SELECT id, view_expression, edit_expression, limit_expression FROM Rlm ORDER BY id',[]);
  try
    if qr.EOF or (qr.GetInt('id')<>0) then
      for rp:=rpView to rpEdit do Realms[rp].Ids[Grow(rp)]:=0;
    while qr.Read do
     begin
      rid:=qr.GetInt('id');
      for rp:=rpView to rpEdit do
       begin
        fx:=qr.GetStr(rname[rp]+'_expression');
        if fx='' then
          b:=rid=0 //no access by default, except with default realm
        else
         begin
          i:=0;
          //check filter cache
          while (i<fcl) and (fc[i].x<>fx) do inc(i);
          if i<fcl then b:=fc[i].b else
           begin
            //check filter
            f:=TtxFilter.Create;
            fq:=TtxSqlQueryFragments.Create(itObj);
            try
              fq.Fields:='Obj.id';
              fq.Tables:='Obj LEFT JOIN ObjType ON ObjType.id=Obj.objtype_id'#13#10;
              fq.Where:='Obj.id='+IntToStr(UserID)+' AND ';
              fq.GroupBy:='';
              fq.Having:='';
              fq.OrderBy:='';
              f.FilterExpression:=fx;
              fq.AddFilter(f);
              qr1:=TQueryResult.Create(DbCon,fq.Sql,[]);
              try
                b:=not(qr1.EOF);
              finally
                qr1.Free;
              end;
            finally
              f.Free;
              fq.Free;
            end;
            //add result to cache
            SetLength(fc,fcl+1);
            fc[fcl].x:=fx;
            fc[fcl].b:=b;
            inc(fcl);
           end;
         end;
        //add to list
        if b then Realms[rp].Ids[Grow(rp)]:=rid;
       end;
      fx:=qr.GetStr('limit_expression');
      if (fx<>'') and Use_ObjPath then
       begin
        f:=TtxFilter.Create;
        fq:=TtxSqlQueryFragments.Create(itObj);
        try
          fq.Fields:='Obj.id';
          fq.Tables:='Obj LEFT JOIN ObjType ON ObjType.id=Obj.objtype_id'#13#10;
          //fq.Where:='';
          fq.GroupBy:='';
          fq.Having:='';
          fq.OrderBy:='';
          f.FilterExpression:=fx;
          fq.AddFilter(f);
          qr1:=TQueryResult.Create(Session.DbCon,fq.Sql,[]);
          try
            if not qr1.EOF then
             begin
              s:='';
              while qr1.Read do s:=s+IntToStr(qr1['id'])+',';
              s[Length(s)]:=')';
              RealmsSQLExtra:=' AND (Obj.rlm_id<>'+IntToStr(rid)+' OR EXISTS (SELECT lvl FROM ObjPath WHERE ObjPath.oid=Obj.id AND ObjPath.pid IN ('+s+'))';
             end;
          finally
            qr1.Free;
          end;
        finally
          f.Free;
          fq.Free;
        end;
       end;
     end;
  finally
    qr.Free;
  end;
  BuildRealmPermissionsSQL;
end;

procedure TtxSession.BuildRealmPermissionsSQL;
var
  i,j,r:integer;
  rp:TtxRealmPermission;
begin
  //copy rpView to rpAny
  Realms[rpAny].Count:=0;
  for i:=0 to Realms[rpView].Count-1 do Realms[rpAny].Ids[Grow(rpAny)]:=Realms[rpView].Ids[i];
  //add unique rpEdit to rpAny
  for i:=0 to Realms[rpEdit].Count-1 do
   begin
    r:=Realms[rpEdit].Ids[i];
    j:=0;
    while (j<Realms[rpAny].Count) and (Realms[rpAny].Ids[j]<>r) do inc(j);
      if j=Realms[rpAny].Count then Realms[rpAny].Ids[Grow(rpAny)]:=r;
   end;
  //clear rpBoth
  Realms[rpBoth].Count:=0;
  //add join rpView, rpEdit to rpBoth
  for i:=0 to Realms[rpView].Count-1 do
   begin
    r:=Realms[rpView].Ids[i];
    j:=0;
    while (j<Realms[rpEdit].Count) and (Realms[rpEdit].Ids[j]<>r) do inc(j);
      if j<Realms[rpEdit].Count then Realms[rpBoth].Ids[Grow(rpBoth)]:=r;
   end;
  //build SQL
  for rp:=rpView to rpBoth do with Realms[rp] do
   begin
    if Count=0 then
      SQL:='=-1' //??
    else
     begin
      SQL:=' IN (';
      for i:=0 to Count-1 do SQL:=SQL+IntToStr(Ids[i])+',';
      SQL[Length(SQL)]:=')';
     end;
    SQL:=SQL+RealmsSQLExtra;
   end;
end;

procedure TtxSession.HasRealmPermission(ObjID,RealmID:integer;RealmPerm:TtxRealmPermission);
var
  i:integer;
  qr:TQueryResult;
begin
  if FRealmsCounter<>RealmsCounter then LoadRealmPermissions;
  //assert RealmID=DBSingleValue('SELECT rlm_id FROM Obj WHERE id=?',[ObjID],DefaultRlmID), got by any previous query
  with Realms[RealmPerm] do
   begin
    i:=0;
    while (i<Count) and (Ids[i]<>RealmID) do inc(i);
    if not(i<Count) then
      raise ERealmNotEditableByUser.CreateFmt('You''re not allowed to control this realm. %d',[RealmID]);
    //else
    if (RealmsSQLExtra<>'') and (ObjID<>0) then
     begin
      qr:=TQueryResult.Create(DbCon,'SELECT id FROM Obj WHERE id=?'+RealmsSQLExtra,[ObjID]);
      try
        if qr.EOF then
          raise ERealmNotEditableByUser.CreateFmt('Your control is limited in this realm. %d',[RealmID]);
      finally
        qr.Free;
      end;
     end;
   end;
end;

procedure TtxSession.SetViewRealm(AddRemove:boolean;RealmID:integer);
var
  i:integer;
begin
  i:=0;
  with Realms[rpView] do
    if AddRemove then
     begin
      while (i<Count) and (Ids[i]<>RealmID) do inc(i);
      if i=Count then Ids[Grow(rpView)]:=RealmID;
     end
    else
     begin
      while (i<Count) and (Ids[i]<>RealmID) do inc(i);
      if i<Count then
       begin
        while i<Count-1 do
         begin
          Ids[i]:=Ids[i+1];
          inc(i);
         end;
        dec(Count);
       end;
     end;
  BuildRealmPermissionsSQL;
end;

procedure TtxSession.AddFilterRecent(ItemType: TtxItemType; id: integer);
var
  i,a,b,d:integer;
begin
  if id<>0 then
   begin
    i:=0;
    d:=0;
    b:=id;
    repeat
      a:=FilterRecent[ItemType,i+d];
      FilterRecent[ItemType,i]:=b;
      if (a=id) and (i+d<FilterRecentCount) then
       begin
        inc(d);
        a:=FilterRecent[ItemType,i+d];
       end;
      inc(i);
      b:=a;
    until (a=0) or (i+d=FilterRecentCount);
   end;
end;

procedure TtxSession.RemoveFilterRecent(ItemType: TtxItemType; id: integer);
var
  i:integer;
begin
  if id<>0 then
   begin
    i:=0;
    while (i<FilterRecentCount) and (FilterRecent[ItemType,i]<>id) do inc(i);
    while (i<FilterRecentCount-1) and (FilterRecent[ItemType,i]<>0) do
      begin
      FilterRecent[ItemType,i]:=FilterRecent[ItemType,i+1];
      inc(i);
     end;
    if i<FilterRecentCount then FilterRecent[ItemType,i]:=0;
   end;
end;

procedure TtxSession.AddViewedLast(id:integer);
var
  i,a,b:integer;
begin
  i:=0;
  a:=id;
  while (i<ViewedLastCount) and (a<>0) do
    if ViewedLast[i]=id then
     begin
      ViewedLast[i]:=a;
      i:=ViewedLastCount;
     end
    else
     begin
      b:=ViewedLast[i];
      ViewedLast[i]:=a;
      a:=b;
      inc(i);
     end;
end;

procedure TtxSession.RemoveViewedLast(id:integer);
var
  i:integer;
begin
  i:=0;
  while (i<ViewedLastCount) and (ViewedLast[i]<>id) do inc(i);
  while (i<ViewedLastCount-1) and (ViewedLast[i]<>0) do
   begin
    ViewedLast[i]:=ViewedLast[i+1];
    inc(i);
   end;
  if i<ViewedLastCount then ViewedLast[i]:=0;
end;

procedure TtxSession.AddRecentReference(reftype,obj2:integer);
var
  i,r1,x1,r2,x2,d:integer;
begin
  if (reftype<>0) and (obj2<>0) then
   begin
    i:=0;
    d:=0;
    r2:=reftype;
    x2:=obj2;
    repeat
      r1:=RecentReferences[i+d].reftype;
      x1:=RecentReferences[i+d].obj2;
      RecentReferences[i].reftype:=r2;
      RecentReferences[i].obj2:=x2;
      if (r1=reftype) and (x1=obj2) and (i+d<FilterRecentCount) then
       begin
        inc(d);
        r1:=RecentReferences[i+d].reftype;
        x1:=RecentReferences[i+d].obj2;
       end;
      inc(i);
      r2:=r1;
      x2:=x1;
    until (r1=0) or (x1=0) or (i+d=FilterRecentCount);
   end;
end;

class function TtxSession.PermissionByName(const x:string):TtxRealmPermission;
begin
  if x='any' then Result:=rpAny else
    //if x='both' then Result:=rpBoth else
      Result:=rpView;
end;

function TtxSession.IsAdmin(const Key: string): boolean;
begin
  Result:=(UserID=-1) or (DbCon.Exists(
    'SELECT Tok.id FROM Tok LEFT JOIN TokType ON TokType.id=Tok.toktype_id '+
    'WHERE Tok.obj_id=? AND TokType.system=?',[UserID,'auth.'+Key]));
end;

procedure TtxSession.LogonAttemptCheck;
var
  i:integer;
begin
  inc(FLogonAttemptCount);
  i:=FLogonAttemptCount div 3;
  if i<>0 then Sleep(i*500);//slow down many failed attempts (//TODO: block? log? blacklist?)
end;

procedure ClearSessionStore;
var
  i:integer;
begin
  EnterCriticalSection(SessionStoreLock);
  try
    for i:=0 to SessionStore.Count-1 do
      TtxSession(SessionStore[i]).Free;
  finally
    LeaveCriticalSection(SessionStoreLock);
  end;
  FreeAndNil(SessionStore);
  FreeAndNil(SessionStoreLock);
end;

function DBSingleValue(const SQL:UTF8String;Parameters:array of OleVariant;Default:OleVariant):OleVariant;
var
  qr:TQueryResult;
begin
  qr:=TQueryResult.Create(Session.DbCon,SQL,Parameters);
  try
    if qr.Read and not(qr.IsNull(0)) then Result:=qr[0] else Result:=Default;
  finally
    qr.Free;
  end;
end;

function DBExists(const SQL:UTF8String;Parameters:array of OleVariant):boolean;
var
  qr:TQueryResult;
begin
  qr:=TQueryResult.Create(Session.DbCon,SQL,Parameters);
  try
    Result:=not qr.EOF;
  finally
    qr.Free;
  end;
end;

function sqlObjsByPid:string;
begin
  Result:=
    'SELECT Obj.id, Obj.objtype_id, Obj.name, Obj.'+sqlDesc+', Obj.url, Obj.weight,'+
    ' Obj.rlm_id, Obj.c_uid, Obj.c_ts, Obj.m_uid, Obj.m_ts,'+
    ' ObjType.icon, ObjType.name AS typename';
  if Use_ObjTokRefCache then Result:=Result+', ObjTokRefCache.tokHTML, ObjTokRefCache.refHTML';
  if Session.QryUnread then Result:=Result+', (SELECT MIN(Obx.id) FROM Obx LEFT OUTER JOIN Urx'+
    ' ON Urx.uid='+IntToStr(Session.UserID)+' AND Obx.id BETWEEN Urx.id1 AND Urx.id2'+
    ' WHERE Obx.obj_id=Obj.id AND Urx.id IS NULL) AS r0, '+
    '(SELECT COUNT(DISTINCT U1.id) FROM ObjPath U0'+
    ' INNER JOIN Obj U1 ON U1.id=U0.oid AND U1.rlm_id'+Session.Realms[rpView].SQL+
    ' INNER JOIN Obx U2 ON U2.obj_id=U0.oid'+
    ' LEFT OUTER JOIN Urx U3 ON U3.uid='+IntToStr(Session.UserID)+' AND U2.id BETWEEN U3.id1 AND U3.id2'+
    ' WHERE U0.pid=Obj.id AND U0.pid<>U0.oid AND U3.id IS NULL) AS r1';
  Result:=Result+
    ' FROM Obj'+
    ' INNER JOIN ObjType ON ObjType.id=Obj.objtype_id';
  if Use_ObjTokRefCache then Result:=Result+
    ' LEFT OUTER JOIN ObjTokRefCache ON ObjTokRefCache.id=Obj.id';
  Result:=Result+
    ' WHERE Obj.pid=? AND Obj.rlm_id'+Session.Realms[rpView].SQL+' ORDER BY Obj.weight, Obj.name, Obj.c_ts';
end;

procedure GetFilterViewInfo(ctx:IXxmContext;var fv:TtxFilterViewInfo);
begin
  fv.filter:=ctx['filter'].Value;
  fv.filterU:=URLEncode(fv.filter);
  fv.view:=ctx['view'].Value;
  if fv.view<>'' then fv.filterU:=fv.filterU+'&view='+URLEncode(fv.view);
  //if fv.view='both' then fv.rp:=rpBoth else
  if (fv.view='any') or (fv.view='all') or (fv.view='both') then fv.rp:=rpAny else
    if fv.view='edit' then fv.rp:=rpEdit else
      fv.rp:=rpView;
end;

function txCallProtect:string;
begin
  Result:='&xxx='+Session.SessionCrypt;//assert doesn't need URLEncode since hex
  //assert caller does HTMLEncode
end;

function txFormProtect:string;
begin
  Result:='<input type="hidden" name="XxmFormProtect" value="'+Session.SessionCrypt+'" />';
end;

procedure CheckCallProtect(Context:IXxmContext);
begin
  if Context['xxx'].Value<>Session.SessionCrypt then
    raise Exception.Create('Invalid request source detected.');//log security breach attempt?
end;

procedure CheckFormProtect(Context:IXxmContext);
var
  p:IXxmParameter;
  pp:IXxmParameterPost;
begin
  if Context.ContextString(csVerb)='POST' then
   begin
    p:=Context['XxmFormProtect'];
    if not((p.QueryInterface(IXxmParameterPost,pp)=S_OK) and (p.Value=Session.SessionCrypt)) then
      raise Exception.Create('Invalid request source detected.');//log security breach attempt?
   end
  else
    raise Exception.Create('CheckFormProtect only works with POST requests!');
end;

procedure CheckMaintProtect(Context:IXxmContext);
var
  h:boolean;
begin
  //TODO: mask remote address? local?
  if MaintAuthKey='' then
   begin
    h:=Context.ContentType='text/html';
    if h then Context.SendHTML('<p><b>') else Context.SendHTML('##### ');
    Context.SendHTML('To protect access to maintenance pages, set a "AuthKey" value in tx.ini and call this page with a parameter "auth" set to that value.');
    if h then Context.SendHTML('</b></p>') else Context.SendHTML(' #####'#13#10#13#10);
   end
  else
    if Context['auth'].Value<>MaintAuthKey then
      raise Exception.Create('Access denied');
end;

function NewPasswordSalt:string;
var
  i,l:integer;
const
  x:array[0..63] of char='AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789!?';
begin
  l:=15+Random(15);
  SetLength(Result,l);
  for i:=1 to l do Result[i]:=x[Random(64)];
end;

function PasswordToken(const Salt,Password:string):string;
begin
  if Password='' then Result:='' else Result:=SHA1Hash('[[[tx]]]'+Salt+'[[[tx]]]'+Password);
end;

procedure NewAutoLogonToken(Context:IXxmContext;UslID:integer);
var
  x:string;
begin
  //assert caller does transaction
  x:=SHA1Hash(IntToHex(integer(Session),8)+'_'+Context.ContextString(csRemoteAddress)+'_'+IntToStr(GetTickCount)+'_'+FormatDateTime('yyyymmss_hhnnss_zzz',Now));
  //assert called did UPDATE Ust SET seq=seq+1 WHERE usl_id=?
  Session.DbCon.Insert('Ust',
    ['usl_id',UslID
    ,'seq',0
    ,'token',x
    ,'address',Context.ContextString(csRemoteAddress)
    ,'agent',Context.ContextString(csUserAgent)
    ,'c_ts',VNow
    ]);
  Context.SetCookie(AutoLogonCookieName,x,AutoLogonCookieTimeoutDays*24*60*60,'','','',false,true);//domain?secure?
end;

procedure ClearAutoLogonToken(Context:IXxmContext);
begin
  Context.SetCookie(AutoLogonCookieName,'',0,'','','',false,true);//domain?secure?
end;

function RFC822DateGMT(dd: TDateTime): string;
const
  Days:array [1..7] of string=
    ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
  Months:array [1..12] of string=
    ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
//  SignStr:array[boolean] of string=('-','+');
var
  dg:TDateTime;
  y,m,d,wd,th,tm,ts,tms:Word;
  tz:TIME_ZONE_INFORMATION;
begin
  GetTimeZoneInformation(tz);
  dg:=dd+tz.Bias/1440;
  DecodeDateFully(dg,y,m,d,wd);
  DecodeTime(dg,th,tm,ts,tms);
  FmtStr(Result, '%s, %d %s %d %.2d:%.2d:%.2d GMT',
    [Days[wd],d,Months[m],y,th,tm,ts]);
end;

function TryGetUserName(const Logon:WideString):WideString;
type
  TUserInfo2=record
    usri2_name: LPWSTR;
    usri2_password: LPWSTR;
    usri2_password_age: DWORD;
    usri2_priv: DWORD ;
    usri2_home_dir: LPWSTR;
    usri2_comment: LPWSTR;
    usri2_flags: DWORD;
    usri2_script_path: LPWSTR;
    usri2_auth_flags: DWORD ;
    usri2_full_name: LPWSTR;
    usri2_usr_comment: LPWSTR;
    usri2_parms: LPWSTR;
    usri2_workstations: LPWSTR;
    usri2_last_logon: DWORD;
    usri2_last_logoff: DWORD;
    usri2_acct_expires: DWORD;
    usri2_max_storage: DWORD;
    usri2_units_per_week: DWORD;
    usri2_logon_hours: PBYTE;
    usri2_bad_pw_count: DWORD;
    usri2_num_logons: DWORD;
    usri2_logon_server: LPWSTR;
    usri2_country_code: DWORD;
    usri2_code_page: DWORD;
  end;
  PUserInfo2=^TUserInfo2;
var
  s:WideString;
  p:pointer;
begin
  Result:='';//default
  s:=GetEnvironmentVariable('LOGONSERVER');
  if s<>'' then
    if NetUserGetInfo(PWideChar(s),PWideChar(WideString(Logon)),2,p)=0 then
     begin
      Result:=PUserInfo2(p).usri2_full_name;
      NetApiBufferFree(p);
     end;
end;

function NetUserGetInfo; external 'netapi32.dll' name 'NetUserGetInfo';
function NetApiBufferFree; external 'netapi32.dll' name 'NetApiBufferFree';

initialization
  Randomize;
  SessionStore:=TStringList.Create;
  SessionStore.Sorted:=true;
  InitializeCriticalSection(SessionStoreLock);
  RealmsCounter:=0;
finalization
  //ClearSessionStore;
  //DeleteCriticalSection(SessionStoreLock);

end.
