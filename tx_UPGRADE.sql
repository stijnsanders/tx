--see tx_so.iss: SQLiteBatch runs this scripts on install, code here should fail safely when already on said version

--v1.2.1

alter table Usr add salt varchar(50) null;
alter table Usl add address varchar(50) null;
alter table Usl add agent varchar(200) null;
alter table Ust add agent varchar(200) null;

--v1.2.3
create index IX_Obj1 on Obj (pid,rlm_id);
create index IX_Tok1 on Tok (obj_id);
create index IX_Ref1 on Ref (obj1_id);
create index IX_Ref2 on Ref (obj2_id);
create index IX_Flt1 on Flt (obj_id);
create index IX_Flg1 on Flg (flt_id,ts);
create unique index IX_Usr1 on Usr (login);
create index IX_Trm1 on Trm (obj_id);

--v1.2.4

alter table Rlm add limit_expression varchar(200) null;

--v1.2.5

-- please see "tx_v1.2.5_collate_nocase.sql"

--v1.3.4
create table Umi (
id integer primary key autoincrement,
usr_id int not null,
obj_id int not null,
constraint FK_Umi_Usr foreign key (usr_id) references Usr (id),
constraint FK_Umi_Obj foreign key (obj_id) references Obj (id)
);
create table Umr (
id integer primary key autoincrement,
usr_id int not null,
rpt_id int not null,
constraint FK_Umr_Usr foreign key (usr_id) references Usr (id),
constraint FK_Umr_Rpt foreign key (rpt_id) references Rpt (id)
);

--v1.4.0
alter table Usr add suspended datetime null;

create table Jrl (
id integer primary key autoincrement,
name varchar(100) not null collate nocase,
granularity int not null,
root_id int null,
system varchar(200) null,
view_expression varchar(200) null,
edit_expression varchar(200) null,
limit_expression varchar(200) null,
c_uid int null,
c_ts datetime null,
m_uid int null,
m_ts datetime null
);

create table Jrt (
id integer primary key autoincrement,
jrl_id int not null,
name varchar(20) not null collate nocase,
icon int not null,
constraint FK_Jrt_Jrl foreign key (jrl_id) references Jrl (id)
);

create table Jrx (
id integer primary key autoincrement,
jrt_id int not null,
uid int not null,
obj_id int not null,
ts datetime not null,
constraint FK_Jrx_Jrt foreign key (jrt_id) references Jrt (id),
constraint FK_Jrx_UsrObj foreign key (uid) references Obj (id),--not Usr!
constraint FK_Jrx_Obj foreign key (obj_id) references Obj (id)
);

create unique index IX_Jrx on Jrx (jrt_id,uid);--actually (jrl_id,uid) but that's indirect over Jrt.jrl.id

create table Jre (
id integer primary key autoincrement,
jrt_id int not null,
uid int not null,
obj_id int not null,
ts datetime not null,
minutes int not null,
c_ts datetime null,
m_ts datetime null,
constraint FK_Jre_Jrt foreign key (jrt_id) references Jrt (id),
constraint FK_Jre_UsrObj foreign key (uid) references Obj (id)--not Usr!
constraint FK_Jre_Obj foreign key (obj_id) references Obj (id),
);

create index IX_Jre on Jre (jrt_id,uid);

insert into TokType (id,pid,icon,name,system,weight) values (7,1,27,'administrator journals','auth.journals',0);
