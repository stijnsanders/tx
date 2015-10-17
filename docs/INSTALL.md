# Installing *tx* from scratch

Follow this guide to start with _tx_ using the source code. There is also [a ready-made binary for Windows available here](http://yoy.be/tx.html) that enables you to use _tx_ with default settings and configuration. Use this to set up a _tx_ database to your needs, but when setting up a multi-user environment, or completing the full configuration, or especially when you want to have a peek under the hood, it's strongly advised to build `tx.xxl` from the source code using this guide.

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
