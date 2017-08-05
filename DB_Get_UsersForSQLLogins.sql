/*
	get the Databases and DB User names for SQL Logins
	Uses undocumented sp_msLoginMappings
	Parameters
		@Login
	$Workfile: DB_Get_UsersForSQLLogins.sql $
	$Archive: /SQL/QueryWork/DB_Get_UsersForSQLLogins.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/
create table #tempww (
	LoginName nvarchar(128)
	,DBname nvarchar(128)
	,Username nvarchar(128)
	,AliasName nvarchar(128)
	);

insert into #tempww
	exec master..sp_msloginmappings
;

Select * from #tempww order by dbname, username
drop table #tempww
