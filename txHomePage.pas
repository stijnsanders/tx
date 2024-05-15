unit txHomePage;

interface

uses SysUtils, Windows, Classes;

type
  THomePages=class(TObject)
  private 
    FPath:string;
    FLock:TRTLCriticalSection;
    FPages:array of record
      Name:string;
      Data:TStringList;
      Timestamp:TFileTime;
    end;
    FPagesIndex,FPagesSize:integer;
    FLastCheck:cardinal;
  public
    constructor Create(const Path:string);
    destructor Destroy; override;
    function GetPage(const Name:string):TStringList;
    procedure CheckFiles;
  end;

var
  HomePages:THomePages;

implementation

const
  HomePages_CheckAfterMS=5000;

{ THomePages }

constructor THomePages.Create(const Path:string);
begin
  inherited Create;
  FPath:=Path;
  InitializeCriticalSection(FLock);
  FPagesIndex:=0;
  FPagesSize:=0;
  FLastCheck:=GetTickCount;
end;

destructor THomePages.Destroy;
var
  i:integer;
begin
  DeleteCriticalSection(FLock);
  for i:=0 to FPagesIndex-1 do FreeAndNil(FPages[i].Data);
  inherited;
end;

function THomePages.GetPage(const Name:string):TStringList;
var
  i:integer;
  fn:string;
  fh:THandle;
  fd:TWin32FindData;
begin
  i:=0;
  while (i<FPagesIndex) and (FPages[i].Name<>Name) do inc(i);
  if i=FPagesIndex then
   begin
    //new one? lock
    EnterCriticalSection(FLock);
    try
      //check again in case we were not alone waiting on a lock
      i:=0;
      while (i<FPagesIndex) and (FPages[i].Name<>Name) do inc(i);
      if i=FPagesIndex then
       begin
        if FPagesIndex=FPagesSize then
         begin
          inc(FPagesSize,4);//growstep
          SetLength(FPages,FPagesSize);
         end;
        FPages[i].Name:=Name;
        FPages[i].Data:=TStringList.Create;

        fn:=FPath+Name+'.txt';
        fh:=FindFirstFile(PChar(fn),fd);
        if fh<>INVALID_HANDLE_VALUE then
         begin
          FPages[i].Data.LoadFromFile(fn);
          FPages[i].Timestamp:=fd.ftLastWriteTime;
          Windows.FindClose(fh);
         end;

        inc(FPagesIndex);

       end;
    finally
      LeaveCriticalSection(FLock);
    end;
   end;
  Result:=FPages[i].Data;
end;

procedure THomePages.CheckFiles;
var
  i:integer;
  fn:string;
  fh:THandle;
  fd:TWin32FindData;
begin
  if cardinal(GetTickCount-FLastCheck)>HomePages_CheckAfterMS then
   begin
    EnterCriticalSection(FLock);
    try
      //check again in case we were not alone waiting on a lock
      if cardinal(GetTickCount-FLastCheck)>HomePages_CheckAfterMS then
       begin

        for i:=0 to FPagesIndex-1 do
         begin
          fn:=FPath+FPages[i].Name+'.txt';
          fh:=FindFirstFile(PChar(fn),fd);
          if fh=INVALID_HANDLE_VALUE then
            FPages[i].Data.Clear //Raise? default content?
          else
           begin
            if (fd.ftLastWriteTime.dwLowDateTime<>FPages[i].Timestamp.dwLowDateTime) or 
              (fd.ftLastWriteTime.dwHighDateTime<>FPages[i].Timestamp.dwHighDateTime) then
             begin
              FPages[i].Data.LoadFromFile(fn);
              FPages[i].Timestamp:=fd.ftLastWriteTime;
             end;
            Windows.FindClose(fh);
           end;

         end;
        FLastCheck:=GetTickCount;

       end;
    finally
      LeaveCriticalSection(FLock);
    end;
   end;
end;

initialization
//see txSession LoadProjectSettings
end.