create table Rlm (
id integer primary key autoincrement,
name varchar(200) not null,
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

create table ObjType (
id integer primary key autoincrement,
pid int not null,
icon int not null default(0),
name varchar(200) not null,
system varchar(200) null,
weight int not null,
dft int null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null
);

create table Obj (
id integer primary key autoincrement,
pid int not null,
objtype_id int not null,
name varchar(200) not null,
desc text null,
url varchar(1000) not null,
weight int not null,
rlm_id int not null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null,
constraint FK_Obj_ObjType foreign key (objtype_id) references ObjType (id)
--FK_Obj_Rlm?
);

create table TokType (
id integer primary key autoincrement,
pid int not null,
icon int not null default(0),
name varchar(200) not null,
system varchar(200) null,
weight int not null,
dft int null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null
);

create table Tok (
id integer primary key autoincrement,
obj_id int not null,
toktype_id int not null,
desc text not null,
weight int not null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null,
constraint FK_Tok_Obj foreign key (obj_id) references Obj (id),
constraint FK_Tok_TokType foreign key (toktype_id) references TokType (id)
);

create table RefType (
id integer primary key autoincrement,
pid int not null,
icon int not null default(0),
name varchar(200) not null,
system varchar(200) null,
weight int not null,
dft int null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null
);

create table Ref (
id integer primary key autoincrement,
obj1_id int not null,
obj2_id int not null,
reftype_id int not null,
desc text not null,
weight int not null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null,
constraint FK_Ref_Obj1 foreign key (obj1_id) references Obj (id),
constraint FK_Ref_Obj2 foreign key (obj2_id) references Obj (id),
constraint FK_Ref_RefType foreign key (Reftype_id) references RefType (id)
);

create table Rpt (
id integer primary key autoincrement,
obj_id int not null,
uid int null,
ts datetime not null,
desc text null,
weight int not null,
toktype_id int null,
reftype_id int null,
obj2_id int null,
constraint FK_Rpt_Obj foreign key (obj_id) references Obj (id)
);

create table Usr (
id integer primary key autoincrement,
uid int not null,
login varchar(50) not null,
email varchar(200) not null,
salt varchar(50) not null,
pwd varchar(50) not null,
auth varchar(100) not null,
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null,
constraint FK_Usr_Obj foreign key (uid) references Obj (id)
);

create table Usl (
id integer primary key autoincrement,
usr_id int not null,
address varchar(20) null,
agent varchar(200) null,
c_ts datetime null,
constraint FK_Usl_Usr foreign key (usr_id) references Usr(id)
);

create table Ust (
id integer primary key autoincrement,
usl_id int not null,
seq int not null,
token varchar(50) not null,
address varchar(20) null,
agent varchar(200) null,
c_ts datetime null,
constraint FK_Ust_Usl foreign key (usl_id) references Usl(id)
);

create table Flt (
id integer primary key autoincrement,
obj_id int not null,
name varchar(200) not null,
expression varchar(200) not null,
desc text null,
showgraph int not null default(0),
c_ts datetime null,
c_uid int null,
m_ts datetime null,
m_uid int null,
constraint FK_Flt_Obj foreign key (obj_id) references Obj (id)
);

create table Flg (
id integer primary key autoincrement,
flt_id int not null,
count int not null,
weight int not null,
ts datetime not null,
constraint FK_Flg_Flt foreign key (flt_id) references Flt (id)
);

create index IX_Obj1 on Obj (pid,rlm_id);
create index IX_Tok1 on Tok (obj_id);
create index IX_Ref1 on Ref (obj1_id);
create index IX_Ref2 on Ref (obj2_id);
create index IX_Flt1 on Flt (obj_id);
create index IX_Flg1 on Flg (flt_id,ts);
create unique index IX_Usr1 on Usr (login);


-- Use_Terms

create table Trm (
id integer primary key autoincrement,
domain_id int not null,
obj_id int not null,
term varchar(100) not null
);

create table Trl (
id integer primary key autoincrement,
domain_id int not null,
source varchar(20) not null,
term varchar(100) not null
);

create index IX_Trm1 on Trm (obj_id);


-- Use_ObjTokRefCache

create table ObjTokRefCache (
id int not null,
tokHTML text not null,
refHTML text not null,
constraint PK_ObjTokRefCache primary key (id),
constraint FK_ObjTokRefCache_Obj foreign key (id) references Obj (id)
);


-- Use_ObjHist

create table ObjHist (
id integer primary key autoincrement,
obj_id int not null,
rlm_id int not null,
uid int null,
ts datetime not null,
name varchar(200) not null,
desc text null,
weight int not null
);

create index IX_ObjHist1 on ObjHist (obj_id,ts);


-- Use_ObjPath

create table ObjPath (
--id integer primary key autoincrement,
pid int not null,
oid int not null,
lvl int not null,
constraint PK_ObjPath primary key (pid,oid)--?
constraint FK_ObjPath_Obj1 foreign key (pid) references Obj (id),
constraint FK_ObjPath_Obj2 foreign key (oid) references Obj (id)
);
create index IX_ObjPath1 on ObjPath (pid,oid,lvl);
create index IX_ObjPath2 on ObjPath (oid,pid,lvl);


-- Use_Unread

create table Obx (
id integer primary key autoincrement,
obj_id int not null
--edit type? ts? tok/ref/rpt id?
--constraint FK_Obx_Obj?
);

insert into Obx (obj_id) select id from Obj;

create table Urx (
id integer primary key autoincrement,
uid int not null,
id1 int not null,
id2 int not null,
constraint FK_Urx_Obj foreign key (uid) references Obj (id)
);
create index IX_Urx on Urx (uid,id1,id2);--?

insert into Urx (uid,id1,id2)
select uid,1,(select max(id) as id from Obx) from Usr;


-- default data

--insert into Rlm (id,name,[desc],system) values (0,'default','default realm','default');
insert into Rlm (id,name,[desc],system,view_expression,edit_expression) values (1,'deleted','deleted items','deleted','','ot"administrator"');
insert into Rlm (id,name,[desc],system,view_expression,edit_expression) values (2,'user data','','users','true1','tt"auth.logins"');

insert into ObjType (id,pid,icon,name,system,weight) values (1,0,0,'item','item',0);
insert into ObjType (id,pid,icon,name,system,weight,dft) values (2,0,10,'project','project',-1000,1);
insert into ObjType (id,pid,icon,name,system,weight) values (3,0,20,'user','user',200);
insert into ObjType (id,pid,icon,name,system,weight,dft) values (4,0,17,'user group','usergroup',-800,3);
insert into ObjType (id,pid,icon,name,system,weight) values (5,3,22,'administrator','administrator',200);

insert into TokType (id,pid,icon,name,system,weight) values (1,0,9,'[system tokens]','',0);
insert into TokType (id,pid,icon,name,system,weight) values (2,1,26,'administrator config','auth.config',0);
insert into TokType (id,pid,icon,name,system,weight) values (3,1,27,'administrator logins','auth.logins',0);
insert into TokType (id,pid,icon,name,system,weight) values (4,1,28,'administrator realms','auth.realms',0);
insert into TokType (id,pid,icon,name,system,weight) values (5,1,29,'administrator reports','auth.reports',0);
insert into TokType (id,pid,icon,name,system,weight) values (6,1,42,'wiki domain','wiki.prefix',0);

insert into RefType (pid,icon,name,system,weight) values (0,63,'see also','see-also',0);

insert into Obj (id,pid,objtype_id,name,url,weight,rlm_id) values (1,0,4,'users','',1000,2);
insert into Obj (id,pid,objtype_id,name,url,weight,rlm_id) values (2,1,3,'anonymous user','',-100,2);
--insert into Obj (id,pid,objtype_id,name,url,weight,rlm_id) values (3,1,4,'new users','',-100,0);

insert into Tok (obj_id,toktype_id,[desc],weight) values (2,2,'',0);
insert into Tok (obj_id,toktype_id,[desc],weight) values (2,3,'',0);
insert into Tok (obj_id,toktype_id,[desc],weight) values (2,4,'',0);
insert into Tok (obj_id,toktype_id,[desc],weight) values (2,5,'',0);

insert into Usr (id,uid,login,email,auth,salt,pwd) values (1,2,'anonymous','anonymous','anonymous','','');
