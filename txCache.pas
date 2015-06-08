unit txCache;

interface

type
  TItemCacheNode=class(TObject)
  end;

  TItemCache=class(TObject)
  private
    FItems:array of record
      id:integer;
      n:TItemCacheNode;
    end;
    FSize,FCount:integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add(id:integer;n:TItemCacheNode):TItemCacheNode;
    function Get(id:integer):TItemCacheNode;
    property Item[id:integer]:TItemCacheNode read Get; default;
  end;

  TIndexCache=class(TObject)
  private
    FItems:array of record
      id:integer;
      value:integer;
    end;
    FSize,FCount:integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(id,value:integer);
    function Get(id:integer):integer;
    property Item[id:integer]:integer read Get write Add; default;
  end;

//ATTENTION: not thread-safe, don't use across threads

implementation

{ TItemCache }

constructor TItemCache.Create;
begin
  inherited;
  FSize:=0;
  FCount:=0;
end;

destructor TItemCache.Destroy;
begin
  Clear;
  inherited;
end;

procedure TItemCache.Clear;
var
  i:integer;
begin
  for i:=FCount-1 downto 0 do FItems[i].n.Free;
  FSize:=0;
  SetLength(FItems,FSize);
  FCount:=0;
end;

function TItemCache.Add(id:integer;n:TItemCacheNode):TItemCacheNode;
const
  GrowStep=8;
var
  a,b,c:integer;
begin
  a:=0;
  b:=FCount;
  while (a<b) do //and thus not(FCount=0)
   begin
    c:=a+((b-a-1) div 2);
    if FItems[c].id=id then b:=a else
      if FItems[c].id<id then a:=c+1 else b:=c;
   end;

  if not(FCount=0) and (FItems[a].id=id) then
   begin
    FItems[a].n.Free;
    FItems[a].n:=n;
   end
  else
   begin
    if (FCount=FSize) then
     begin
      inc(FSize,GrowStep);
      SetLength(FItems,FSize);
     end;
    for c:=FCount-1 downto a do FItems[c+1]:=FItems[c];
    FItems[a].id:=id;
    FItems[a].n:=n;
    inc(FCount);
   end;
  Result:=n;
end;

function TItemCache.Get(id:integer):TItemCacheNode;
var
  a,b,c:integer;
begin
  Result:=nil;//default
  a:=0;
  b:=FCount-1;
  while (a<b) and (Result=nil) do
   begin
    c:=a+((b-a) div 2);
    if FItems[a].id=id then Result:=FItems[a].n else
      if FItems[b].id=id then Result:=FItems[b].n else
        if FItems[c].id=id then Result:=FItems[c].n else
          if FItems[c].id<id then a:=c+1 else b:=c-1;
   end;
end;

{ TIndexCache }

constructor TIndexCache.Create;
begin
  inherited;
  FSize:=0;
  FCount:=0;
end;

destructor TIndexCache.Destroy;
begin
  Clear;
  inherited;
end;

procedure TIndexCache.Clear;
begin
  FSize:=0;
  SetLength(FItems,FSize);
  FCount:=0;
end;

procedure TIndexCache.Add(id, value: integer);
const
  GrowStep=8;
var
  a,b,c:integer;
begin
  a:=0;
  b:=FCount;
  while (a<b) do //and thus not(FCount=0)
   begin
    c:=a+((b-a-1) div 2);
    if FItems[c].id=id then b:=a else
      if FItems[c].id<id then a:=c+1 else b:=c;
   end;

  if not(FCount=0) and (FItems[a].id=id) then
    FItems[a].value:=value
  else
   begin
    if (FCount=FSize) then
     begin
      inc(FSize,GrowStep);
      SetLength(FItems,FSize);
     end;
    for c:=FCount-1 downto a do FItems[c+1]:=FItems[c];
    FItems[a].id:=id;
    FItems[a].value:=value;
    inc(FCount);
   end;
end;

function TIndexCache.Get(id: integer): integer;
var
  a,b,c:integer;
begin
  Result:=-1;//default
  a:=0;
  b:=FCount-1;
  while (a<b) and (Result=-1) do
   begin
    c:=a+((b-a) div 2);
    if FItems[a].id=id then Result:=FItems[a].value else
      if FItems[b].id=id then Result:=FItems[b].value else
        if FItems[c].id=id then Result:=FItems[c].value else
          if FItems[c].id<id then a:=c+1 else b:=c-1;
   end;
end;

end.
