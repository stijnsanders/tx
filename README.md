# tx
_tx_ started as a tool to keep track of things. From there it evolved into a new take on data, categorisation, oversight, structure, registration, evaluation...

## A bit of history
This project started in 2005 in an attempt to replace a set of task lists in use up till then, in form of either text or spreadsheet, and offer a database of tasks that also stores their history, state and structure. Of paramount importance in a task system is that is balances input and output: adding tasks should be easy, allowed always and anywhere; existing tasks should easily be queried, categorized, filtered, modified, listed, summerized, ordered, etc.


## What's it do

Items are stored in a parent-child relationship to form a tree structure. Each item is of an item type, which themselves also exhibit a parent-child relationship to form a tree structure. (e.g. task, idea, project, user, user group, department)

Items have none or more tokens. Tokens are of a token type, also in a tree structure. Use tokens to track state changes of the item. (e.g. resolved, need-feedback)

Items have none or more references to other items. References are of a reference type, also in a tree structure. (e.g. see-also, assigned-to, member-of)

Items have none or more reports, where additional information or progress of the task at hand can be reported.

Filters can list items that have specific types, tokens or references. By combining criteria filters can get complex to select very specific items. Filters can be used to list items, view a limited tree of items or to render a summary of items.

If _tx_ is used in a multi-user environment, each user is also represented as an item.

Filters can be stored onto an item. Filters stored onto an item on the path of the user's item are shown on the 'Filters' opening page.

Each item has a weight, that is based on the weight of item types, token types and reference types used by the item, its tokens and references. When displaying a list of items, they are sored by weight first, then alphabetically.

And there are many other useful features too numerous to list here, but all geared towards creating a rich environment to store the information about the work in progress.

## The Name

Since it started as a thing to keep track of work done, it was called "cover your tracks", which was shortened to "trax" and later further condensed to "tx".

## Where do I start?

[install](docs/INSTALL.md)

//TODO: download page of pre-built binaries
