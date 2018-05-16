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
