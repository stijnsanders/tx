unit xxmp;

interface

uses SysUtils, xxm;

type
  TXxmtx=class(TXxmProject, IXxmProjectEvents)
  public
    function LoadPage(Context:IXxmContext;Address:WideString):IXxmFragment; override;
    function LoadFragment(Context:IXxmContext;Address,RelativeTo:WideString):IXxmFragment; override;
    procedure UnloadFragment(Fragment: IXxmFragment); override;
    function HandleException(Context:IxxmContext;PageClass:WideString;Ex:Exception):boolean;
  end;

function XxmProjectLoad(AProjectName:WideString): IXxmProject; stdcall;

implementation

uses txSession, SQLiteData, xxmFReg, Windows, Classes;

function XxmProjectLoad(AProjectName:WideString): IXxmProject;
begin
  LoadProjectSettings;
  Result:=TXxmtx.Create(AProjectName);
end;

{ TXxmtx }

function TXxmtx.LoadPage(Context:IXxmContext;Address:WideString): IXxmFragment;
var
  uname,s,x:string;
  qr:TSQLiteStatement;
  id:integer;
begin
  inherited;
  Result:=nil;
  s:=LowerCase(Address);
  if SetSession(Context) then //new session?
    try
      uname:=Context.ContextString(csAuthUser);
      if uname='' then qr:=nil else
        qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT uid, email, 0 as isanon FROM Usr WHERE LOWER(auth)=LOWER(?)',[uname]);
      if (qr=nil) or (qr.EOF) then
       begin
        if qr<>nil then FreeAndNil(qr);
        x:=Context.GetCookie(AutoLogonCookieName);
        if x<>'' then
         begin
          qr:=TSQLiteStatement.Create(Session.DbCon,
            'SELECT Usr.id, Usr.uid, Usr.email, 0 as isanon, Ust.usl_id, Ust.seq'+
            ' FROM Usr INNER JOIN Usl ON Usl.usr_id=Usr.id'+
            ' INNER JOIN Ust ON Ust.usl_id=Usl.id WHERE Ust.token=?',[x]);
          if qr.EOF then
           begin
            //TODO: raise? log?
            ClearAutoLogonToken(Context);
           end
          else
           begin
            Session.DbCon.Execute('BEGIN TRANSACTION');
            try
              id:=qr.GetInt('usl_id');
              if qr.GetInt('seq')=0 then
               begin
                Session.DbCon.Execute('UPDATE Ust SET seq=seq+1 WHERE usl_id=?',[id]);
                Session.DbCon.Execute('DELETE FROM Ust WHERE usl_id=? and c_ts<?',[id,VNow-AutoLogonCookieTimeoutDays]);
                NewAutoLogonToken(Context,id);
               end
              else
               begin
                //TODO: raise? log?
                //invalidate compromised Usl records
                Session.DbCon.Execute('DELETE FROM Ust WHERE usl_id=?',[id]);
                Session.DbCon.Execute('DELETE FROM Usl WHERE id=?',[id]);
                FreeAndNil(qr);
                ClearAutoLogonToken(Context);
               end;
              Session.DbCon.Execute('COMMIT TRANSACTION');
            except
              Session.DbCon.Execute('ROLLBACK TRANSACTION');
              raise;
            end;
           end;
         end;
       end;
      if (qr=nil) or (qr.EOF) then
       begin
        if qr<>nil then qr.Free;
        qr:=TSQLiteStatement.Create(Session.DbCon,'SELECT uid, email, 1 as isanon FROM Usr WHERE auth=?',['anonymous']);
       end;
      if qr.EOF then
       begin
         if (s<>'logon.xxm') and (s<>'logonnew.xxm') and (copy(s,2,5)<>'logon') and
           (s<>'404.xxm') and
           (s<>'sql.xxm') and
           (s<>'tx.js.xxm') and (copy(s,1,3)<>'js/') and
           (s<>'tx.css.xxm') and (copy(s,1,4)<>'img/') then
           Result:=XxmFragmentRegistry.GetFragment(Self,'LogonRedir.xxm','');
       end;
      Session.LoadUser(qr);
    finally
      if qr<>nil then qr.Free;
    end;
  if (s='tx.ini') or (s='tx.db') or (s='tx.xxl') then Result:=XxmFragmentRegistry.GetFragment(Self,'404.xxm','');
  if Result=nil then
   begin
    Result:=XxmFragmentRegistry.GetFragment(Self,Address,'');
	  Context.BufferSize:=$40000;//256KiB
   end;
end;

function TXxmtx.LoadFragment(Context:IXxmContext;Address,RelativeTo:WideString): IXxmFragment;
begin
  //TODO: support relative paths
  Result:=XxmFragmentRegistry.GetFragment(Self,Address,RelativeTo);
  //TODO: cache created instance, incease ref count
  //XxmFragmentRegistry.CacheAdd(Result);
end;

procedure TXxmtx.UnloadFragment(Fragment: IXxmFragment);
begin
  inherited;
  //TODO: set cache TTL, decrease ref count
  //XxmFragmentRegistry.CacheRelease(Result);//Fragment.Free?
end;

function TXxmtx.HandleException(Context:IxxmContext;PageClass:WideString;Ex:Exception):boolean;
begin
  //TODO: admin e-mail
  Result:=false;
end;

initialization
//  MemCheckLogFileName:='C:\temp\log\tx.log';
//  MemChk;

end.
