unit txFilter;

interface

uses SysUtils, txDefs;

type
  TtxFilterIDType=(dtNumber,dtSystem,dtSubQuery,dtEnvironment);
  TtxFilterOperator=(
    foAnd,foOr,foAndNot,foOrNot,
	//add new here above
	fo_Unknown);

  TtxFilterAction=(

    faChild,faObj,faObjType,faTokType,faRefType,faBackRef,
    faCreated,faTokCreated,faRefCreated,faBackRefCreated,
    faRecentObj,faRecentTok,faRecentRef,faRecentBackRef,
    faFilter,faParent,faPath,faPathObjType,faPathTokType,faPathRefType,

    faSearch,faSearchReports,faSearchName,faName,faDesc,faTerm,
	faAlwaysTrue,faAlwaysFalse,faExtra,faSQL,faRealm,faUnread,

    //add new here above
    fa_Unknown
  );

const
  txFilterActionItemType:array[TtxFilterAction] of TtxItemType=(

    itObj,itObj,itObjType,itTokType,itRefType,itObj,
    itObj,itObj,itObj,itObj,
    itObj,itTokType,itRefType,itObj,
    itFilter,itObj,itObj,itObjType,itTokType,itRefType,

	itObj,itObj,itObj,itObj,itObj,itObj,
	it_Unknown,it_Unknown,it_Unknown,it_Unknown,itRealm,it_Unknown,

    //add new here above
    it_Unknown
  );

  txFilterOperatorChar:array[TtxFilterOperator] of char=('+','.','/',',',#0);
  txFilterOperatorSQL:array[TtxFilterOperator] of string=('AND','OR','AND NOT','OR NOT','');

  txFilterActionNameCount=88;
  txFilterActionName:array[0..txFilterActionNameCount-1] of record
    a:TtxFilterAction;
    n:string;
  end=(
    //(a:;n:''),

    (a:faChild               ;n:'c'),
    (a:faObj                 ;n:'i'),
    (a:faObj                 ;n:'o'),
    (a:faObjType             ;n:'ot'),
    (a:faTokType             ;n:'tt'),
    (a:faRefType             ;n:'rt'),
    (a:faBackRef             ;n:'rx'),
    (a:faCreated             ;n:'uc'),
    (a:faTokCreated          ;n:'ut'),
    (a:faRefCreated          ;n:'ur'),
    (a:faBackRefCreated      ;n:'urx'),
    (a:faRecentObj           ;n:'ir'),
    (a:faRecentTok           ;n:'ttr'),
    (a:faRecentRef           ;n:'rtr'),
    (a:faRecentBackRef       ;n:'rxr'),

    (a:faExtra               ;n:'x'),
    (a:faSQL                 ;n:'s'),
    (a:faAlwaysTrue          ;n:'a'),
    (a:faAlwaysFalse         ;n:'n'),
    (a:faAlwaysTrue          ;n:'at'),
    (a:faAlwaysFalse         ;n:'af'),
    (a:faFilter              ;n:'f'),
    (a:faParent              ;n:'p'),
    (a:faPath                ;n:'pi'),
    (a:faPathObjType         ;n:'po'),
    (a:faPathObjType         ;n:'pot'),
    (a:faPathTokType         ;n:'pt'),
    (a:faPathTokType         ;n:'ptt'),
    (a:faPathRefType         ;n:'pr'),
    (a:faPathRefType         ;n:'prt'),

    (a:faSearch              ;n:'search'),
    (a:faSearchReports       ;n:'rsearch'),
    (a:faSearchName          ;n:'nsearch'),
    (a:faName                ;n:'name'),
	(a:faDesc                ;n:'desc'),
	(a:faTerm                ;n:'term'),
    (a:faAlwaysTrue          ;n:'true'),
    (a:faAlwaysFalse         ;n:'false'),
    (a:faFilter              ;n:'filter'),
    (a:faRealm               ;n:'rlm'),
    (a:faUnread              ;n:'u'),
    (a:faSQL                 ;n:'sql'),
    (a:faExtra               ;n:'extra'),
    (a:faExtra               ;n:'param'),

    (a:faChild               ;n:'child'),
    (a:faChild               ;n:'children'),
    (a:faParent              ;n:'parent'),
    (a:faPath                ;n:'path'),
    (a:faObj                 ;n:'item'),
    (a:faObj                 ;n:'obj'),
    (a:faObjType             ;n:'objtype'),
    (a:faTokType             ;n:'toktype'),
    (a:faRefType             ;n:'reftype'),
    (a:faBackRef             ;n:'backref'),
    (a:faRecentObj           ;n:'recentobj'),
    (a:faRecentTok           ;n:'recenttok'),
    (a:faRecentRef           ;n:'recentref'),
    (a:faRecentBackRef       ;n:'recentbackref'),
    (a:faPathObjType         ;n:'parentobjtype'),
    (a:faPathTokType         ;n:'parenttoktype'),
    (a:faPathRefType         ;n:'parentreftype'),
    (a:faObj                 ;n:'object'),
    (a:faObjType             ;n:'objecttype'),
    (a:faTokType             ;n:'tokentype'),
    (a:faRefType             ;n:'referencetype'),
    (a:faBackRef             ;n:'backreference'),
    (a:faCreated             ;n:'created'),
    (a:faRecentObj           ;n:'recentobject'),
    (a:faRecentTok           ;n:'recenttoken'),
    (a:faRecentRef           ;n:'recentreference'),
    (a:faRecentBackRef       ;n:'recentbackreference'),
    (a:faPath                ;n:'parentitem'),
    (a:faPath                ;n:'parentobject'),
    (a:faPathObjType         ;n:'parentobjecttype'),
    (a:faPathTokType         ;n:'parenttokentype'),
    (a:faPathRefType         ;n:'parentreferencetype'),
    (a:faRealm               ;n:'realm'),
    (a:faUnread              ;n:'unread'),
    (a:faAlwaysTrue          ;n:'alwaystrue'),
    (a:faAlwaysFalse         ;n:'alwaysfalse'),
	(a:faDesc                ;n:'description'),
    (a:faSearchName          ;n:'namesearch'),
    (a:faSearchName          ;n:'searchname'),
    (a:faSearchReports       ;n:'reportsearch'),
    (a:faSearchReports       ;n:'reportssearch'),
    (a:faSearchReports       ;n:'searchreport'),
    (a:faSearchReports       ;n:'searchreports'),

    //add new here above

    (a:fa_Unknown;n:'')
  );

type
  TtxFilterEnvVar=(
    feMe,
	feUs,
	feThis,
	feParent,
    //add new here above
    fe_Unknown
  );

const
  txFilterEnvVarName:array[TtxFilterEnvVar] of string=(
    'me',
	'us',
	'this',
	'parent',
    //add new here above
    ''
  );

type

  TtxFilterElement=record
    ParaOpen,ParaClose,Idx1,Idx2,Idx3:integer;
    Action:TtxFilterAction;
    IDType:TtxFilterIDType;
    ID:string;
    Descending,Prefetch:boolean;//flags
    Parameters:string;
    Operator:TtxFilterOperator;
  end;

  TtxFilter=class(TObject)
  private
    Ex:string;
    El:array of TtxFilterElement;
    FRaiseParseError:boolean;
    FParseError:string;
    function GetCount:integer;
    procedure SetEx(AEx:string);
    function GetElement(Idx:integer):TtxFilterElement;
  public
    constructor Create;
    destructor Destroy; override;
    property FilterExpression:string read Ex write SetEx;
    property Count:integer read GetCount;
    property Item[Idx:integer]:TtxFilterElement read GetElement; default;
    property RaiseParseError:boolean read FRaiseParseError write FRaiseParseError;
    property ParseError:string read FParseError;
    class function GetActionItemType(Action:string):TtxItemType;
    class function GetFilterEnvVar(EnvVarName:string):TtxFilterEnvVar;
  end;

  EtxFilterParseError=class(Exception);

implementation

{ TtxFilter }

constructor TtxFilter.Create;
begin
  inherited Create;
  FRaiseParseError:=false;//default?
  FParseError:='';
end;

destructor TtxFilter.Destroy;
begin
  SetLength(El,0);
  inherited;
end;

class function TtxFilter.GetActionItemType(Action: string): TtxItemType;
var
  i:integer;
begin
  i:=0;
  //LowerCase?
  while not(txFilterActionName[i].n=Action) and
    not(txFilterActionName[i].a=fa_Unknown) do inc(i);
  if txFilterActionName[i].a=fa_Unknown then Result:=it_Unknown else
    Result:=txFilterActionItemType[txFilterActionName[i].a];
end;

class function TtxFilter.GetFilterEnvVar(EnvVarName:string):TtxFilterEnvVar;
begin
  Result:=TtxFilterEnvVar(0);
  while (Result<fe_Unknown) and not(txFilterEnvVarName[Result]=EnvVarName) do inc(Result);
end;

function TtxFilter.GetCount: integer;
begin
  Result:=Length(El);
end;

function TtxFilter.GetElement(Idx: integer): TtxFilterElement;
begin
  Result:=El[Idx];
end;

procedure TtxFilter.SetEx(AEx: string);
var
  e,i,j,k,l,gPara:integer;
  s:string;
  b:boolean;
  x:^TtxFilterElement;

  procedure SkipWhiteSpace;
  begin
    while (i<=l) and (Ex[i] in [#0..#32]) do inc(i);
  end;
  procedure Error(Msg: string);
  begin
    if FRaiseParseError then raise EtxFilterParseError.Create(Msg);
    if FParseError='' then FParseError:=Msg else
      FParseError:=FParseError+#13#10+Msg;
  end;

begin
  Ex:=AEx;
  e:=0;
  gPara:=0;
  i:=1;
  l:=Length(Ex);
  while (i<=l) do
   begin
    SetLength(El,e+1);
    x:=@El[e];
    inc(e);

    //TODO: comment?

    //open para's
    x.Idx1:=i;
    x.ParaOpen:=0;
    b:=true;
    while (i<=l) and b do
      case Ex[i] of
        #0..#32:inc(i);//skip whitespace
        '(':
         begin
          inc(x.ParaOpen);
          inc(gPara);
          inc(i);
         end;
        else
          b:=false;
      end;

    //action
    j:=i;
    while (i<=l) and (Ex[i] in ['A'..'Z','a'..'z']) do inc(i);
    s:=Copy(Ex,j,i-j);
    SkipWhiteSpace;
    j:=0;
    while not(txFilterActionName[j].n=s) and
      not(txFilterActionName[j].a=fa_Unknown) do inc(j);
    if txFilterActionName[j].a=fa_Unknown then Error('Unknown action "'+s+'"');
    x.Action:=txFilterActionName[j].a;

    //id
    if (i<=l) then
     begin
      case Ex[i] of
        '{':
          begin
            X.IDType:=dtSubQuery;
            inc(i);
            j:=i;
			k:=1;
            while (i<=l) and not(k=0) do
			 begin
			  case Ex[i] of
			   '{':inc(k);
			   '}':dec(k);
			   '"':while (i<=l) and not(Ex[i]='"') do inc(i);
			  end;
			  inc(i);
			 end;
            x.ID:=Copy(Ex,j,i-j-1);
          end;
        '"':
          begin
            x.IDType:=dtSystem;
            inc(i);
            j:=i;
            while (i<=l) and not(Ex[i]='"') do inc(i);
            x.ID:=Copy(Ex,j,i-j);
            while (i<l) and (Ex[i]='"') and (Ex[i+1]='"') do
             begin
              inc(i,2);
              j:=i;
              while (i<=l) and not(Ex[i]='"') do inc(i);
              x.ID:=x.ID+'"'+Copy(Ex,j,i-j);
             end;
            inc(i);
          end;
        '''':
          begin
            x.IDType:=dtNumber;
            inc(i);
            j:=i;
            while (i<=l) and not(Ex[i]='''') do inc(i);
            x.ID:=Copy(Ex,j,i-j);
            inc(i);
            while (i<=l) and (Ex[i]='''') do
             begin
              j:=i;
              while (i<=l) and not(Ex[i]='''') do inc(i);
              x.ID:=x.ID+''''+Copy(Ex,j,i-j);
              inc(i);
             end;
          end;
        '$':
          begin
            X.IDType:=dtEnvironment;
            inc(i);
            j:=i;
            while (i<=l) and (Ex[i] in ['0'..'9','-','A'..'Z','a'..'z']) do inc(i);
            x.ID:=Copy(Ex,j,i-j);
          end;
        else
          begin
            x.IDType:=dtNumber;
            j:=i;
            while (i<=l) and (Ex[i] in ['0'..'9','-','A'..'Z','a'..'z']) do inc(i);
            x.ID:=Copy(Ex,j,i-j);
          end;
      end;
     end;

    //flags, set defaults first
    x.Descending:=false;
    x.Prefetch:=false;
    b:=true;
    while (i<=l) and b do
     begin
      case Ex[i] of
        #0..#32:;//skip whitespace

        '*':x.Descending:=true;
        '!':x.Prefetch:=true;
        //more?

        else b:=false;
      end;
      if b then inc(i);
     end;

    //parameters
    if (i<=l) and (Ex[i]='[') then
     begin
       inc(i);
       j:=i;
       while (i<=l) and not(Ex[i]=']') do inc(i);
       x.Parameters:=Copy(Ex,j,i-j);
       inc(i);
     end;

    //close para's
    x.Idx2:=i;
    x.ParaClose:=0;
    b:=true;
    while (i<=l) and b do
      case Ex[i] of
        #0..#32:inc(i);//skip whitespace
        ')':
         begin
          inc(x.ParaClose);
          if gPara=0 then Error('More paranthesis closed than opened.');
          dec(gPara);
          inc(i);
         end;
        else
          b:=false;
      end;

    //operator
    if (i<=l) then
     begin
	  x.Operator:=TtxFilterOperator(0);
	  while not(x.Operator=fo_Unknown) and not(Ex[i]=txFilterOperatorChar[x.Operator]) do inc(x.Operator);
	  if x.Operator=fo_Unknown then Error('Unknown operator "'+Ex[i]+'"');
      inc(i);
     end
    else
      x.Operator:=foAnd;//foTrailing? fo_Unknown?

    x.Idx3:=i;
   end;

  if gPara>0 then Error('More parenthesis opened than closed.');
end;

end.
