unit txImgs;

interface

uses SysUtils, Classes;

type
  TForwardStream=class(TCustomMemoryStream);

procedure ImgsLoadLibrary;
function ImgByName(const ImgPath:string):TForwardStream;

var
  ImgBankDate:TDateTime;

implementation

uses Windows, txSession;

type
  TImgInfo=class(TObject)
  public
    p,q:integer;
  end;

var
  ImgData:TMemoryStream;
  ImgBank:TStringList;

procedure ImgsLoadLibrary;
var
  fn,fe,fp:string;
  fh:THandle;
  fd:TWin32FindData;
  d:TImgInfo;
  i,p,q:integer;
  f:TFileStream;
begin
  ImgData:=TMemoryStream.Create;
  ImgBank:=TStringList.Create;
  ImgBank.Sorted:=true;
  p:=0;

  fp:=ModulePath+'img\';
  fh:=FindFirstFile(PChar(fp+'*.*'),fd);
  if fh=INVALID_HANDLE_VALUE then RaiseLastOSError;
  repeat
    fn:=fd.cFileName;//LowerCase?
    fe:=Copy(fn,Length(fn)-3,4);
    if (fe='.svg') or (fe='.png') then //or (re='.bmp')?
     begin
      d:=TImgInfo.Create;
      f:=TFileStream.Create(fp+fn,fmOpenRead or fmShareDenyWrite);
      try
        q:=f.Size;
        d.p:=p;
        d.q:=q;
        ImgData.CopyFrom(f,q);
        inc(p,q);
      finally
        f.Free;
      end;
      ImgBank.AddObject(fn,d);
     end;
  until not(FindNextFile(fh,fd));
  Windows.FindClose(fh);
end;

function ImgByName(const ImgPath:string):TForwardStream;
var
  i:integer;
  d:TImgInfo;
  p:pointer;
begin

  if ImgBank=nil then ImgsLoadLibrary;//assert done by xxmp.pas XxmProjectLoad!

  i:=ImgBank.IndexOf(ImgPath);
  if i=-1 then Result:=nil else 
   begin
    d:=ImgBank.Objects[i] as TImgInfo;
    p:=ImgData.Memory;
    inc(integer(p),d.p);
    Result:=TForwardStream.Create;
    Result.SetPointer(p,d.q);
   end;
end;

initialization
  //see ImgsLoadLibrary
  ImgData:=nil;
  ImgBank:=nil;
  ImgBankDate:=UTCNow;
end.