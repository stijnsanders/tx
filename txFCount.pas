unit txFCount;

interface

uses Windows, Graphics, SQLiteData;

type
  TFilterGraph=class(TObject)
  private
    FBitmap:TBitmap;
    FPosition,FOrigin,FLegendY:integer;
    FScale:real;
  public
    MaxVal,MinVal:integer;
    constructor Create;
    destructor Destroy; override;
    procedure Start(SizeX,SizeY,Origin,Increments:integer;Scale:real);
    function Save:string;
    function StartPosition(Lbl:string):boolean;
    procedure SecondLabel(Lbl:string);
    procedure VerticalIncrement;
    procedure AddFilter(q:TSQLiteStatement;clr:integer);
    procedure AddFilterLegend(name:string;clr:integer);
    function Unique:cardinal;
  end;

implementation

uses SysUtils, JPEG, txSession;

{ TFilterGraph }

constructor TFilterGraph.Create;
begin
  inherited Create;
  FBitmap:=TBitmap.Create;
  FBitmap.PixelFormat:=pf32Bit;
end;

destructor TFilterGraph.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

const
  BorderColor=$333333;
  IncrementColor=$CCCCCC;
  MarginLeft=25;
  MarginLeftText=10;
  MarginLeftLine=4;
  MarginRight=0;
  MarginTop=0;
  MarginBottom=25;
  PositionWidth=12;
  LegendSize=10;
  LegendMarginX=4;
  LegendMarginY=2;

procedure TFilterGraph.Start(SizeX,SizeY,Origin,Increments:integer;Scale:real);
var
  i,y:integer;
  ts:TSize;
  s:string;
begin
  inherited Create;
  FPosition:=-1;
  FLegendY:=MarginTop+LegendMarginY;
  FOrigin:=Origin;
  FBitmap.Width:=SizeX;
  FBitmap.Height:=SizeY;
  FScale:=Scale;
  MaxVal:=0;
  MinVal:=0;
  if FScale=0 then FScale:=1;
  //assert filled white (clear?)
  with FBitmap.Canvas do
   begin
    Lock;
    try
      Font.Name:='Tahoma';
      Font.Size:=7;
      Font.Color:=clBlack;
      Brush.Style:=bsClear;
      Pen.Color:=BorderColor;
      Pen.Style:=psSolid;
      Pen.Width:=1;
      MoveTo(MarginLeft,MarginTop);
      LineTo(MarginLeft,SizeY-MarginBottom+1);
      if Increments=0 then
       begin
        y:=SizeY-MarginBottom-Round(FOrigin/FScale);
        if (y>=MarginTop) and (y<=SizeY-MarginBottom) then
         begin
          MoveTo(MarginLeft-MarginLeftLine,y);
          LineTo(SizeX-MarginRight+1,y);
         end;
       end
      else
       begin
        i:=FOrigin mod Increments;
        y:=SizeY-MarginBottom-Round(i/Scale);
        while y>=MarginTop do
         begin
          s:=IntToStr(i-FOrigin);
          ts:=TextExtent(s);
          TextOut(MarginLeftText-(ts.cx div 2),y-(ts.cy div 2),s);
          Pen.Color:=BorderColor;
          MoveTo(MarginLeft-MarginLeftLine,y);
          LineTo(MarginLeft,y);
          if not(i=FOrigin) then Pen.Color:=IncrementColor;
          MoveTo(MarginLeft+1,y);
          LineTo(SizeX-MarginRight+1,y);
          inc(i,Increments);
          y:=SizeY-MarginBottom-Round(i/Scale);
         end;
       end;
    finally
      Unlock;
    end;
   end;
end;

var
  FCountIndex:integer;

function TFilterGraph.Save: string;
var
  j:TJPEGImage;
begin
  j:=TJPEGImage.Create;
  try
    J.CompressionQuality:=100;//??
    j.Smoothing:=false;
    j.Assign(FBitmap);
    j.ProgressiveEncoding:=false;
    j.Compress;
    //ForceDirectories?
    Result:=ModulePath+'\fcount\'+Format('%.3d',[InterlockedIncrement(FCountIndex) mod 1000])+'.jpg';
    j.SaveToFile(Result);
  finally
    j.Free;
  end;
end;

function TFilterGraph.StartPosition(Lbl: string): boolean;
var
  ts:TSize;
  sx:integer;
begin
  sx:=FBitmap.Width;
  inc(FPosition);
  Result:=(FPosition+1)*PositionWidth < sx-MarginLeft-MarginRight-2;
  if Result then with FBitmap.Canvas do
   begin
    Lock;
    try
      Font.Color:=clBlack;
      Brush.Style:=bsClear;
      ts:=TextExtent(Lbl);
      TextOut(sx-MarginLeftText-FPosition*PositionWidth+4-
        (ts.cx div 2),FBitmap.Height-MarginBottom+2,Lbl);
    finally
      Unlock;
    end;
   end;
end;

procedure TFilterGraph.SecondLabel(Lbl: string);
begin
  with FBitmap.Canvas do
   begin
    Lock;
    try
      Font.Color:=clBlack;
      Brush.Style:=bsClear;
      TextOut(FBitmap.Width-MarginLeftText-FPosition*PositionWidth,
        FBitmap.Height-MarginBottom+12,Lbl);
    finally
      Unlock;
    end;
   end;
end;

procedure TFilterGraph.VerticalIncrement;
var
  x:integer;
begin
  with FBitmap.Canvas do
   begin
    Lock;
    try
      Pen.Color:=IncrementColor;
      x:=FBitmap.Width-MarginLeftText-FPosition*PositionWidth+3;
      MoveTo(x,MarginTop);
      LineTo(x,FBitmap.Height-MarginBottom);
    finally
      Unlock;
    end;
   end;
end;

procedure TFilterGraph.AddFilter(q: TSQLiteStatement; clr: integer);
var
  a,b,c,d,x,y:integer;
begin
  //TODO: transparancy?
  x:=FBitmap.Width-MarginRight-(FPosition+1)*PositionWidth;
  y:=FBitmap.Height-MarginBottom;
  with FBitmap.Canvas do
   begin
    Lock;
    try
      Pen.Color:=clr;
      while q.Read do
       begin
        a:=q.GetInt('Open');
        b:=q.GetInt('Low');
        c:=q.GetInt('High');
        d:=q.GetInt('Close');

        if a<MinVal then MinVal:=a;
        if b<MinVal then MinVal:=b;
        if c<MinVal then MinVal:=c;
        if d<MinVal then MinVal:=d;
        if a>MaxVal then MaxVal:=a;
        if b>MaxVal then MaxVal:=b;
        if c>MaxVal then MaxVal:=c;
        if d>MaxVal then MaxVal:=d;

        a:=Round((a+FOrigin)/FScale);
        b:=Round((b+FOrigin)/FScale);
        c:=Round((c+FOrigin)/FScale);
        d:=Round((d+FOrigin)/FScale);
        if b<c then
         begin
          MoveTo(x+4,y-c);LineTo(x+4,y-b+1);
          MoveTo(x+5,y-c);LineTo(x+5,y-b+1);
          MoveTo(x+6,y-c);LineTo(x+6,y-b+1);
         end
        else
         begin
          MoveTo(x+4,y-b);LineTo(x+4,y-c+1);
          MoveTo(x+5,y-b);LineTo(x+5,y-c+1);
          MoveTo(x+6,y-b);LineTo(x+6,y-c+1);
         end;
        MoveTo(x+1,y-a);LineTo(x+4,y-a);
        MoveTo(x+7,y-d);LineTo(x+10,y-d);

       end;
    finally
      Unlock;
    end;
   end;
end;

procedure TFilterGraph.AddFilterLegend(name: string; clr: integer);
begin
  with FBitmap.Canvas do
   begin
    Lock;
    try
      Pen.Color:=clBlack;
      Pen.Style:=psSolid;
      Brush.Style:=bsSolid;
      Brush.Color:=clr;
      Rectangle(MarginLeft+LegendMarginX,FLegendY,MarginLeft+LegendMarginX+LegendSize,FLegendY+LegendSize);
      Font.Color:=clBlack;
      Brush.Style:=bsClear;
      TextOut(MarginLeft+LegendSize+LegendMarginX+2,FLegendY-1,name);
    finally
      UnLock;
    end;
    inc(FLegendY,LegendSize+LegendMarginY);
   end;
end;

function TFilterGraph.Unique:cardinal;
begin
  Result:=GetTickCount;//Random?
end;

initialization
  FCountIndex:=-1;
end.
