# Configuring *tx*

## tx.ini

* `DB`: Set to the full path to the database file. Ideally the database file is located in a folder that is not accessible by a URL to the web server.
* `AdministratorEmailAddress`: Set to the e-mail address to send administrator messages to.
* `DB_BackupPath`: Set to the full path of a folder where database backup copies are to be stored (see MaintDbb.xxm)
* `AuthKey`: Set to the key to use on automated calls to Maint*.xxm pages, to prevent unauthorised access.

## Setting up the basic data

The default `tx.sql` script provides a default _project_, _item_, _user group_ and _user_ object types. Extend these according to the work you'll be registering with _tx_, e.g.: bugs, issues, feature requests, support tickets, divisions, workgroups, sites...

## Setting up user accounts and authentication

The default `tx.sql` script provides a default anonymous user object, and the token types _config administrator_ and _logins adminsitrator_. Add a token of each to the anonymous user object. Create a user object for yourself, and also add a token of each type. Open the accounts page: `/Users.xxm`, create an account and link it to your user object. Set your password. Use the logon page: `/Logon.xxm` to log on as yourself. Don't forget to remove the administrator tokens from the anonymous user object. Optionally remove the anonymous user account to require logging on to access the website.

If you will be hosting on Microsoft Windows with IIS and enable integrated security, you can also link user accounts to NT account names by using the _auth_ field.

## txHomePage.txt

Customize the home page, for example with a suitable welcome message.

//TODO: txHomePage sections manual

## Stored filters per interest groups

//TODO: write about storing filters on user groups

## Maint*.xxm

Maint*.xxm pages perform housekeeping duties and should be called by an automated schedule of your liking. Since they can potentially perform sensitive operations on the data, it's strongly advised to set up an `AuthKey` value in `tx.ini` to protect against unauthorised access.

* `MaintDbb.xxm`: stores a back-up copy of the SQLite database in the `DB_BackupPath` as configured in `tx.ini`; ideally scheduled at once a month or once a week. Also schedule an extra job to remove old copies, or move them away to offsite and/or offline storage.
* `MaintFlg.xxm`: performs statistics on the stored filters for the filter graphing feature. Ideally scheduled four times a day or hourly to be able to graph intra-day progression properly.
* `MaintObjTokRefCache.xxm`: resets the cached copies of the tokens and references HTML sections used to speed up rendering of pages. Not intended to be scheduled, normal operation is designed to keep the data up to date when changes are made. Run this job to refresh the cache data.
* `MaintPath.xxm`: rebuilds the object path data used to speed up brach lookups. Not intended to be scheduled, normal operation is designed to keep the data up to date when changes are made. Run this job to rebuild the full-branch index table.
* `MaintRlm.xxm`: switches items to a specified realm listed by a specific filter, e.g. switch items that have been marked done to the _done_ realm after 7 days. Use the `MaintRlm.txt` file by default to determine which items to change to which realm, or define an alternate local file with the `fs` query string parameter. Schedule according to your needs, e.g. daily or weekly.
* `MaintRpt.xxm`: re-orders reports by date. Use this page to move reports on a node to (sub-)nodes according to parts of the date (year, month, day). Useful when a node is used as a log. Schedule according to your settings, e.g. weekly or monthly.
* `MaintTrl.xxm`: re-build the term links index. Normal operation is designed to keep this data up to date. Run this job when the term expressin in the WikiParseXML changes, or important changes are made to _wiki domain_ tokens.
* `MaintUrx.xxm`: clean-up unread markers. To save on storage space, start-stop regions of modification-id's are used to denote which items are unread for each user. By reading unread items in arbitrary order, fragmentation of this data can cause adjacent sections. Normal operation is designed to minimise this effect, but if you find under extensive use the `Urx` table gets very large and has an impact on performance, schedule this job at a regular interval suiting your needs.
