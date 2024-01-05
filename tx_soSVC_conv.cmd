@echo off
cls
attrib -h rel_2
rmdir rel_2 /s /q
D:\Data\xxm\Delphi\bin32\xxmConv /proto D:\Data\xxm\Delphi\conv\proto_http_svc /src D:\Data\2022\tx\src_2 /x:XxmSourcePath D:\Data\xxm\Delphi "."
mkdir rel_2
attrib +h src_2
attrib +h rel_2
copy src_2\tx.exe rel_2\txSvc.exe
copy sqlite3.dll rel_2\
copy WikiEngine.dll rel_2\
copy txWikiEngine.xml rel_2\
copy txSafeHTML.xml rel_2\
xcopy js rel_2\js\ /s /q
xcopy img\ic*.png rel_2\img\ /q
xcopy img\ic*.svg rel_2\img\ /q
xcopy img\tx_bg.png rel_2\img\ /q
mkdir rel_2\fcount
copy LICENSE rel_2\
copy loading.gif rel_2\
copy favicon.ico rel_2\
copy tx*.txt rel_2\
copy tx*.xml rel_2\ /y
copy tx_UPGRADE.sql rel_2\ /y
copy tx_v1.2.5_collate_nocase.sql rel_2\ /y
copy img_*.png rel_2\
copy img_*.svg rel_2\
copy Maint*.txt rel_2\
copy robots.txt rel_2\
copy D:\Data\2022\TSQLite\SQLiteAdmin.exe rel_2\
copy D:\Data\2022\TSQLite\SQLiteBatch.exe rel_2\
echo DB=tx.db > rel_2\tx.ini
rel_2\SQLiteBatch.exe rel_2\tx.db tx.sql
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "tx_soSVC.iss"
pause
