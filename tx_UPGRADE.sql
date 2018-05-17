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
