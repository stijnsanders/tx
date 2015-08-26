# Installing *tx* from scratch

## Prerequisites

* [xxm](sourceforge.net/projects/xxm/files/): download the Windows binaries, extract and install a handler of your choice. (Or use xxmHttp, see below.)
* [SQLite](https://www.sqlite.org/download.html): download the pre-compiled binary 32-bits Windows dynamic-link library.
* [WikiEngine](https://sourceforge.net/projects/wikiengine/files/wikiengine/): download `WikiEngine.dll` and register it with `regsvr32.exe`.
* [jQuery](http://jquery.com/download/): a version of jQuery is included in the source code
* [TSQLite](http://github.com/stijnsanders/TSQLite): a version of TSQLiteDatabase is included in the source code
* [TimyMCE](http://www.tinymce.com/download/): a version of TinyMCE is included in the source code

## Step by Step

Create a folder `tx` to store the *tx* source (or checkout with git).

Create a file `tx.ini` and write this line:

    DB=tx.db

(Optionally create a separate directory to hold the database file(s), ideally outside of the folders accessible via web hosting, and specify the (relative) path accordingly.)

Use SQLiteAdmin and `tx.sql` to create the `tx.db` file.

Download [xxm](sourceforge.net/projects/xxm/files/) and install a handler of your choice. Register `tx.xxl` with the xxm handler. (The file itself does not exist yet, it will be compiled based on `Web.xxmp`.) If you don't want to use already present web-hosting software, extract `xxmHttp.exe` and create the required `xxm.xml` to register the `tx.xxl` module (see an example [here](http://xxm.sourceforge.net/install.html#xxmxml)).

Navigate a browser to the URL of the tx project, e.g. `http://localhost:8080/tx/`

Configure the tx installation to your needs, see [Configure](Configure.md)
