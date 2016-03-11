--v1.2.5
--prior versions did not have 'collate nocase' on 'name' columns and sorted items case-sensitive.
--use this script on an existing database to enable case-insensitive sorting, as this does not require other code changes.
-- BACK-UP FIRST (MaintDBB.xxm)
-- USE A TRANSACTION (SQLiteBatch.exe -T)

create table ObjX (
id integer primary key autoincrement,
pid int not null,
objtype_id int not null,
name varchar(200) not null collate nocase,
desc text null,
url varchar(1000) not null,
weight int not null,
rlm_id int not null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null,
constraint FK_Obj_ObjType foreign key (objtype_id) references ObjType (id)
);
insert into ObjX select * from Obj;
drop table Obj;
alter table ObjX rename to Obj;

create table ObjTypeX (
id integer primary key autoincrement,
pid int not null,
icon int not null default(0),
name varchar(200) not null collate nocase,
system varchar(200) null,
weight int not null,
dft int null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null
);

insert into ObjTypeX select * from ObjType;
drop table ObjType;
alter table ObjTypeX rename to ObjType;

create table RlmX (
id integer primary key autoincrement,
name varchar(200) not null collate nocase,
desc text not null,
system varchar(200) null,
view_expression varchar(200) null,
edit_expression varchar(200) null,
limit_expression varchar(200) null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null
);

insert into RlmX select * from Rlm;
drop table Rlm;
alter table RlmX rename to Rlm;

create table TokTypeX (
id integer primary key autoincrement,
pid int not null,
icon int not null default(0),
name varchar(200) not null collate nocase,
system varchar(200) null,
weight int not null,
dft int null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null
);

insert into TokTypeX select * from TokType;
drop table TokType;
alter table TokTypeX rename to TokType;

create table RefTypeX (
id integer primary key autoincrement,
pid int not null,
icon int not null default(0),
name varchar(200) not null collate nocase,
system varchar(200) null,
weight int not null,
dft int null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null
);

insert into RefTypeX select * from RefType;
drop table RefType;
alter table RefTypeX rename to RefType;

create table FltX (
id integer primary key autoincrement,
obj_id int not null,
name varchar(200) not null collate nocase,
expression varchar(200) not null,
desc text null,
showgraph int not null default(0),
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null,
constraint FK_Flt_Obj foreign key (obj_id) references Obj (id)
);

insert into FltX select * from Flt;
drop table Flt;
alter table FltX rename to Flt;
