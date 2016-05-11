unit DataLank;

{

DataLank
  Allows straight-forward (but not perfect) switching of data back-ends
  in projects with limited database requirements.

https://github.com/stijnsanders/DataLank

}

interface

uses SQLiteData;

type
  TDataConnection = TSQLiteConnection;
  TQueryResult = TSQLiteStatement;

function VNow:OleVariant;

implementation

uses SysUtils, Variants;

function VNow:OleVariant;
begin
  Result:=VarFromDateTime(Now);
end;

end.
