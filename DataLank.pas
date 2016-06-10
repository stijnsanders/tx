unit DataLank;

{

DataLank
  Allows straight-forward (but not perfect) switching of data back-ends
  in projects with limited database requirements.

https://github.com/stijnsanders/DataLank

}

interface

{
uses ADOTools;

type
  TDataConnection = TADOLink;
  TQueryResult = TADOResult;
}

{
uses SQLiteData;

type
  TDataConnection = TSQLiteConnection;
  TQueryResult = TSQLiteStatement;
}

uses LibPQData;

type
  TDataConnection = TPostgresConnection;
  TQueryResult = TPostgresCommand;

function VNow:OleVariant;

implementation

uses SysUtils, Variants;

function VNow:OleVariant;
begin
  Result:=VarFromDateTime(Now);
end;

end.
