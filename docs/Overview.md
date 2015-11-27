# _tx_: An introduction
In a _tree-structure_, each item is stored under a _parent_ item, or is stored in the _root_. The list of an item's parent, the parent's parent, etc. is called the _path_. An item (B) that has another item (A) as a parent, is called a child (A is B's parent: B is A's child).

_tx_ stores _objects_ in a tree-structure. Each object is of an _object type_. The object types are stored in a tree-structure of their own. This way objects with similar object types can easily be specified by child object types.

Each object has a set of _tokens_. Each token is of a _token type_. The token types are stored in a tree-structure of their own.

Each object has a set of _references_ to other objects. Each reference refers to another object, and is of a _reference type_. The reference types are stored in a tree-structure of their own.

A _user_ is a person using _tx_. The user's _login_ is connected to a _user object_.

A user can add _reports_ to objects.

A _filter_ lists objects that comply to a set of criteria. E.g.: objects of a certain type, having a certain token, ...

## Objects

An object ...

* is of a certain object type
* has a name
* has a description
* has a created date and time
* has a last modified date and time
* is either a root object, or has a parent object.
The sequence of the object, the parent object, its parent object, etc. up to a root object is called the path, or the location of the object.
As a consequence an object can have children objects.
* has a weight, used to sort among siblings or in a filter
* (is created by a user)
* (optionally has an URL)

... and can also ...

* have tokens
* have references, or can be referred to
* have reports
* be a user object

## Object types

An object type ...

* has a name
* defines an icon to show with the objects of this object type
* has a created date and time
* has a last modified date and time
* has a weight. This weight is used to sort among sibling object types, and is also used as default weight of new objects of this object type.
* optionally has a default child object type. If a new object is created as a child object of this type, this object type will be proposed as object type for the new object.
* is either a root object type, or has a parent object type. As a consequence an object type can have children object types.
* (optionally has a 'system' tag, available for external use)

## Tokens

A token ...

* is added to an object
* is of a token type
* can have comment
* has a created date and time
* has a last modified date and time
* has a weight, which is added to the object's weight
* (is stored in a certain sequence of tokens, specifid to the object)

## Token types

A token type ...

* has a name
* defines an icon to show with the tokens of this token type
* has a created date and time
* has a last modified date and time
* has a weight. This weight is used to sort among sibling token types, and is also used as default weight of new tokens of this token type.
* is either a root token type, or has a parent token type. As a consequence a token type can have children token types.
* (optionally has a 'system' tag, available for external use)

## References

A reference ...

* is added to an object
* refers to another object
* is of a reference type
* can have a comment
* has a created date and time
* has a last modified date and time
* has a weight, which is used to sort among references of an object, and is added to the object's weight

## Reference types

A reference type ...

* has a name
* defines an icon to show with the references of this reference type
* has a created date and time
* has a last modified date and time
* has a weight. This weight is used to sort among sibling reference types, and is also used as default weight of new references of this reference type.
* is either a root reference type, or has a parent reference type. As a consequence a reference type can have children reference types.
* (optionally has a 'system' tag, available for external use)

## Weight

Objects, object types, token types and reference types are always shown sorted by weight.

The weight of an object, is determined by

* The weight of the object type
* the sum of weight of the token types of the tokens on the object
* the sum of weight of the reference types of the references on the object
* any deviation applied to the specific weight of the object, by editing it

Set the weight of objects and types carefully to assist standard browsing and filtering in showing the most relevant objects first.

Changing the weight of types automatically changes the weight of the objects that are of that type or have tokens or references of that type. Changing an object to another object type also adjusts the object's weight from the old object type to the new object type.

E.g.: Usually folder items are shown before other items. Set the weight of the 'folder object type' to -1000 to have them shown on top.

## Users, accounts

Every user has a user object. _tx_ can use a login/password combination or the NT-Login string to authenticate the current user as one of the users.

Use the accounts list to select an object as a user object, and set it's NT-login or login/password.

When creating objects, tokens or references, the user creating is registered.

## Reports

A user can report on an object. An object has a list of reports.

Use reports to converse about the object, report the progress of the task, discuss the state of the item...

Reports also serve as the object's history. Every new token or reference created also adds to the list of reports. Reports on all objects of a filter can serve as a log what work is done by a group of people, or on a task-group or project.

## Filters

A filter ...

* consists of an expression of one or more elements joined by operators
* selects the objects that comply to the criteria defined by the expression
* can be stored with a name and description, under an object

When browsing to an object, the filters stored under it are displayed with it's tokens, references and children objects.

When opening the main 'filter' page, the filters stored under your user object are displayed. Also all filters stored under objects in the path of your user object are displayed.

If a certain filter is relevant to a group of users, store it under a 'user-group' object for the group of users (e.g.: "tasks for project1").

## Realms

Every object is stored in only one realm. By default all objects are stored in the default realm.

Permission to view or edit objects in a realm is determined by a filter, and if you user object is listed by the filter.

When the total number of objects increases, and some objects have becone less relevant, but are still on the right place in the structure, move them to a separate realm, that is not visible by default. (e.g.: 'done items': tasks that have a 'done' token for some time)

## Terms

The content entered into text fields is searched for terms written in a certain caps style, much like [WikiWikiWeb](http://c2.com/cgi/wiki/wiki?WikiWikiWeb) pages. (The actual pattern used is configured in the `txWikiEngine.xml` file.)

Terms are shown as links in green, and you can link terms to one or more items.
