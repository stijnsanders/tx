unit txTerms;

interface

uses Windows, WikiEngine_TLB, Classes, txDefs;

type
  TTermStore=class(TObject)
  private
    FEnabled:boolean;
    FInitError:string;
      FInitTimeMS:integer;
    FEngine:IEngine;
    FList:TStringList;
    FCurrentDomain:integer;
      FCurrentSource:string;
    FRenderLock:TRTLCriticalSection;
    procedure DoCommands;
  public
    constructor Create(const DllPath: string);
    destructor Destroy; override;
    function TermLinks(ItemType:TtxItemType;ItemID,domainID:integer;xHTML:WideString):WideString;
    procedure StoreTerms(ItemType:TtxItemType;ItemID,domainFromObjID:integer;xHTML:WideString);
    function GetDomainID(ObjID:integer):integer;
    property InitError:string read FInitError;
    property InitTimeMS:integer read FInitTimeMS;
  end;

  TTermCheck=class(TInterfacedObject, IWikiPageCheck)
  private
    FStore:TTermStore;
  public
    constructor Create(Store:TTermStore);
    function CheckPage(var Name: WideString;
      const CurrentGroup: WideString): WordBool; safecall;
  end;

implementation

uses SysUtils, DataLank, txSession, ComObj, ActiveX;

//const Class_txWebTermCheck:TGUID='{00007478-0000-C057-0001-5465726D4368}';

type
  ETermStoreException=class(Exception);

{ TTermStore }

constructor TTermStore.Create(const DllPath: string);
type
  T_DGCO=function(const CLSID, IID: TGUID; var Obj): HResult; stdcall;//DllGetClassObject
var
  tc:integer;
  p:T_DGCO;
  f:IClassFactory;
begin
  tc:=integer(GetTickCount);
  inherited Create;
  FInitError:='';
  FInitTimeMS:=-1;
  if Use_Terms then
   begin
    FEnabled:=true;
    FList:=TStringList.Create;
    FList.Sorted:=true;
    FList.CaseSensitive:=false;
    FList.Duplicates:=dupIgnore;
    InitializeCriticalSection(FRenderLock);
    //FEngine:=CoEngine.Create;
    try
      p:=GetProcAddress(LoadLibrary(PChar(DllPath)),'DllGetClassObject');
      if @p=nil then RaiseLastOSError;
      OleCheck(p(CLASS_Engine,IClassFactory,f));
      OleCheck(f.CreateInstance(nil,IEngine,FEngine));
      FEngine.WikiParseXML:=ModulePath+'txWikiEngine.xml';
      FEngine.WikiPageCheck:=TTermCheck.Create(Self);
    except
      on e:Exception do
       begin
        FEnabled:=false;
        FInitError:='{'+e.ClassName+'}'+e.Message;
       end;
    end;
    FInitTimeMS:=integer(GetTickCount)-tc;
   end
  else
   begin
    FEnabled:=false;
   end;
end;

destructor TTermStore.Destroy;
begin
  if Use_Terms then
   begin
    DeleteCriticalSection(FRenderLock);
    FList.Free;
    try
      FEngine:=nil;
    except
      //silent, (issue with closing with WikiPageCheck set?)
      pointer(FEngine):=nil;
    end;
   end;
  inherited;
end;

function TTermStore.TermLinks(ItemType:TtxItemType;ItemID,domainID:integer;xHTML: WideString): WideString;
begin
  FCurrentDomain:=domainID;
  FCurrentSource:=txItemTypeKey[ITemType]+IntToStr(ItemID);
  try
    if FEnabled then
     begin
      EnterCriticalSection(FRenderLock);
      try
        Result:=FEngine.Render(xHTML,'');
        DoCommands;
      finally
        LeaveCriticalSection(FRenderLock);
      end;
     end
    else Result:=xHTML;
  except
    on ETermStoreException do raise;
    on Exception do
     begin
      //TODO: log error somewhere?
      Result:=xHTML;
     end;
  end;
  if FEnabled then FList.Clear;
end;

function TTermStore.GetDomainID(ObjID:integer):integer;
var
  x:integer;
begin
  x:=ObjID;
  Result:=0;
  if FEnabled then
    if Use_ObjPath then
      Result:=DBSingleValue('SELECT Tok.obj_id FROM ObjPath INNER JOIN Tok ON Tok.obj_id=ObjPath.pid '+
        'INNER JOIN TokType ON TokType.id=Tok.toktype_id AND TokType.system=''wiki.prefix'' WHERE ObjPath.oid=? ORDER BY ObjPath.lvl LIMIT 1',[x],0)
    else
      while (x<>0) and (Result=0) do
       begin
        if Session.DbCon.Execute('SELECT Tok.id FROM Tok LEFT JOIN TokType ON TokType.id=Tok.toktype_id WHERE Tok.obj_id=? AND TokType.system=''wiki.prefix'' LIMIT 1',[x]) then
          Result:=x
        else
          x:=DBSingleValue('SELECT pid FROM Obj WHERE id=?',[x],0);
       end;
end;

procedure TTermStore.StoreTerms(ItemType:TtxItemType;ItemID,domainFromObjID:integer;xHTML:WideString);
var
  i,d:integer;
  src:string;
begin
  if FEnabled then
   begin
    d:=GetDomainID(domainFromObjID);
    src:=txItemTypeKey[ITemType]+IntToStr(ItemID);
    FList.Clear;
    EnterCriticalSection(FRenderLock);
    try
      try
        FEngine.Render(xHTML,'');
        DoCommands;
      except
        on ETermStoreException do raise;
        on Exception do ;//silent
      end;
    finally
      LeaveCriticalSection(FRenderLock);
    end;
    //transaction? diff?
    Session.DbCon.Execute('DELETE FROM Trl WHERE Trl.source=?',[src]);
    for i:=0 to FList.Count-1 do
      Session.DbCon.Execute('INSERT INTO Trl (source,domain_id,term) VALUES (?,?,?)',[src,d,FList[i]]);
   end;
end;

procedure TTermStore.DoCommands;
var
  x,y:WideString;
begin
  while FEngine.GetModification(x,y) do
   begin
     if x='error' then raise ETermStoreException.Create(y)
     else
         raise ETermStoreException.Create('[TermStore]Unknown command "'+x+'"');
   end;
end;

{ TTermCheck }

constructor TTermCheck.Create(Store:TTermStore);
begin
  inherited Create;
  FStore:=Store;
end;

function TTermCheck.CheckPage(var Name: WideString;
  const CurrentGroup: WideString): WordBool;
begin
  //TODO: domain?
  FStore.FList.Add(Name);
  Result:=Session.DbCon.Execute('SELECT Trm.obj_id FROM Trm WHERE Trm.domain_id=? AND lower(Trm.term)=lower(?) LIMIT 1',[FStore.FCurrentDomain,Name]);
  //TODO: update name from DB?
  if Result then
    Name:='Term.xxm?d='+IntToStr(FStore.FCurrentDomain)+'&r='+FStore.FCurrentSource+'&n='
  else
    Name:='fTerm.xxm?d='+IntToStr(FStore.FCurrentDomain)+'&r='+FStore.FCurrentSource+'&n=';
end;

end.
