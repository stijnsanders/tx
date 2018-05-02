# Configuring *tx*

Apart from certain switches compiled into the _tx_ binary, (as determined by the `Use_`-constants in `txDefs.pas`) some configuration is stored in local files and in the database.

## tx.ini

* `DB`: Set to the full path to the database file. Ideally the database file is located in a folder that is not accessible by a URL to the web server.
* `AdministratorEmailAddress`: Set to the e-mail address to send administrator messages to.
* `DB_BackupPath`: Set to the full path of a folder where database backup copies are to be stored (see MaintDbb.xxm)
* `AuthKey`: Set to the key to use on automated calls to Maint*.xxm pages, to prevent unauthorised access.

## Setting up the basic data

The default `tx.sql` script provides a default _project_, _item_, _user group_ and _user_ object types. Extend these according to the work you'll be registering with _tx_, e.g.: bugs, issues, feature requests, support tickets, divisions, workgroups, sites... (See also: [Overview](Overview.md).)

## Setting up user accounts and authentication

The default `tx.sql` script provides a default anonymous user object, and the token types _config administrator_ and _logins adminsitrator_. Add a token of each to the anonymous user object. Create a user object for yourself, and also add a token of each type. Open the accounts page: `/Users.xxm`, create an account and link it to your user object. Set your password. Use the logon page: `/Logon.xxm` to log on as yourself. Don't forget to remove the administrator tokens from the anonymous user object. Optionally remove the anonymous user account to require logging on to access the website.

If you will be hosting on Microsoft Windows with IIS and enable integrated security, you can also link user accounts to NT account names by using the _auth_ field.

## Realms

Realms determine which items are visible and editable to which users. New items are created in the same realm as their parent, or the _default_ realm (id 0) on the root level. Users get view and edit permissions determined by wether the user's object is selected by the specified filter. The default `tx.sql` script adds two realms:

* _deleted_ (id 1): used by the item delete page: it offers to move the selected item(s) to the delete realm; use the _advanced delete_ link to the far right to actually fully drop items from the database. By default no-one gets view permissions and only the administrator (a user whose user object is of an object type with the _system_-field set to `administrator`) has edit permissions in case a 'deleted' objects needs to be restored.
* _user data_ (id 2): used to protect the user objects from anonymous and unauthorised users, by giving view permissions to all, but edit permissions only to those with an administrative token (a token of token type with the _system_-field set to `auth.logins`).

Complex filters to determine permissions on realms can potentially slow down performance, especially when opening the website and signing in. See the section _realm permissions_ on the `/Test.xxm` page for an overview of how long it takes to calculate your realm permissions.

## WikiEngine: WikiParseXML, wiki domains

_tx_ uses [WikiEngine](https://sourceforge.net/projects/wikiengine/files/wikiengine/) to parse HTML data and automatically extract specifically capitalised lemma's to display them as a link to either one or more items with the specific term linked to them, or a page that enables you do link one or more items to this term. The WikiParseXML as stored in `txWikiEngine.xml` is used to process HTML and pick-up links and terms to turn them into hyperlinks.

Terms and term links are relative to a _wiki domain_, by default not set to an object (id 0), or any object in the path to the root that has a token of a token type with the _system_-field set to `wiki.prefix`. Links to terms between wiki domains are possible, and are indicated by a red left single angle quotes mark (&lsaquo;).

## Stored filters per interest groups

Filters are a great feature to construct advanced selections of items based on their position in the tree structure or their tokens and references. Filter expressions can be stored on an object, for example while a filter is relevant to a project. The filters page (`/Filter.xxm`) by default displays any stored filters on the objects on the path upward to the root starting from the current user's object. Use this to offer members of a user group a way to quickly gain an overview over the items relevant to them.

## txHomePage.txt

The opening page (`/Default.xxm`) by default uses the `txHomePage.txt` file to determine what to show. It is made up of sections preceded with a line that starts with "`--`" and a keyword:

* `--content`: the following lines of HTML are displayed.
* `--log`: show a list of reports and items based on modified date. Following lines are of the form `keyword=value` with one of these keywords:
  * `filter`: an optional filter of which items to show the log form
  * `anyrealm`: set to `1` to also show items you have edit permissions to (default: only items you have view permissions to)
  * `limit`: set to a number of entries to limit the log display to
  * `asc`: set to `1` to sort ascending (default: sort descending)
* `--list`: show a list of items selected by a filter. Following lines are of the form `keyword=value` with one of these keywords:
  * `filter`: an optional filter of which items to show the log form
  * `anyrealm`: set to `1` to also show items you have edit permissions to (default: only items you have view permissions to)
  * `limit`: set to a number of entries to limit the log display to
  * `asc`: set to `1` to sort ascending (default: sort descending)
* `--query`: perform an SQL query on the database and use the results to construct HTML. the following lines are:
  * an SQL query (use `[[realms]]` to include the dynamic SQL code that enforces the user's realm permissions)
  * an empty line
  * one or more lines of HTML where fields enclosed in double square brackets (`[[field]]`) are replaced by the data in the field.

## Maint*.xxm

Maint*.xxm pages perform housekeeping duties and should be called by an automated schedule of your liking. Since they can potentially perform sensitive operations on the data, it's strongly advised to set up an `AuthKey` value in `tx.ini` to protect against unauthorised access.

* `MaintDbb.xxm`: stores a back-up copy of the SQLite database in the `DB_BackupPath` as configured in `tx.ini`. Ideally scheduled at once a month or once a week. Also schedule an extra job to remove old copies, or move them away to offsite and/or offline storage.
* `MaintFlg.xxm`: performs statistics on the stored filters for the filter graphing feature. Ideally scheduled four times a day or hourly to be able to graph intra-day progression properly.
* `MaintObjTokRefCache.xxm`: resets the cached copies of the tokens and references HTML sections used to speed up rendering of pages. Not intended to be scheduled, normal operation is designed to keep the data up to date when changes are made. Run this job to refresh the cache data.
* `MaintPath.xxm`: rebuilds the object path data used to speed up brach lookups. Not intended to be scheduled, normal operation is designed to keep the data up to date when changes are made. Run this job to rebuild the full-branch index table.
* `MaintRlm.xxm`: switches items to a specified realm listed by a specific filter, e.g. switch items that have been marked done to the _done_ realm after 7 days. Use the `MaintRlm.txt` file by default to determine which items to change to which realm, or define an alternate local file with the `fs` query string parameter. Schedule according to your needs, e.g. daily or weekly.
* `MaintRpt.xxm`: re-orders reports by date. Use this page to move reports on a node to (sub-)nodes according to parts of the date (year, month, day). Useful when a node is used as a log. Schedule according to your settings, e.g. weekly or monthly.
* `MaintTrl.xxm`: re-build the term links index. Normal operation is designed to keep this data up to date. Run this job when the term expressin in the WikiParseXML changes, or important changes are made to _wiki domain_ tokens.
* `MaintUrx.xxm`: clean-up unread markers. To save on storage space, start-stop regions of modification-id's are used to denote which items are unread for each user. By reading unread items in arbitrary order, fragmentation of this data can cause adjacent sections. Normal operation is designed to minimise this effect, but if you find under extensive use the `Urx` table gets very large and has an impact on performance, schedule this job at a regular interval suiting your needs.
