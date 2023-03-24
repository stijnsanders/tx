@echo off
cls
attrib -h rel_1
rmdir rel_1 /s /q
D:\Data\xxm\Delphi\bin\xxmConv /proto D:\Data\xxm\Delphi\conv\proto_http_localOnly /src D:\Data\2022\tx\src_1 /x:XxmSourcePath D:\Data\xxm\Delphi "."
mkdir rel_1
attrib +h src_1
attrib +h rel_1
copy src_1\tx.exe rel_1\
copy sqlite3.dll rel_1\
copy WikiEngine.dll rel_1\
copy txWikiEngine.xml rel_1\
copy txSafeHTML.xml rel_1\
xcopy js rel_1\js\ /s /q
xcopy img\ic*.svg rel_1\img\ /q
mkdir rel_1\fcount
copy LICENSE rel_1\
copy loading.gif rel_1\
copy favicon.ico rel_1\
copy tx*.txt rel_1\
copy tx*.xml rel_1\ /y
copy tx_UPGRADE.sql rel_1\ /y
copy tx_v1.2.5_collate_nocase.sql rel_1\ /y
copy img_*.svg rel_1\
copy Maint*.txt rel_1\
copy robots.txt rel_1\
copy D:\Data\2022\TSQLite\SQLiteAdmin.exe rel_1\
copy D:\Data\2022\TSQLite\SQLiteBatch.exe rel_1\
echo DB=tx.db > rel_1\tx.ini
rel_1\SQLiteBatch.exe rel_1\tx.db tx.sql
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "tx_so.iss"
pause
