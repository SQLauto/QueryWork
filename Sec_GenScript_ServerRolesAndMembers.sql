
/*
	Retrieving SQL Server Server Roles for Disaster Recovery
	http://www.mssqltips.com/sqlservertip/2288/retrieving-sql-server-server-roles-for-disaster-recovery/
	This script generates scripts to create Roles, users, etc.
	$Archive: /SQL/QueryWork/Sec_GenScript_ServerRolesAndMembers.sql $
	$Date: 15-03-25 15:49 $	$Revision: 1 $

	sqlcmd -E -S <ServerName> -i script_create_roles.sql -o recovery_create_server_roles.sql

*/
SET NOCOUNT ON;
If Object_Id('tempDb..#theCmd', 'U') is not null
	Drop Table #theCmd;
Go

Create Table #theCmd (prikey int identity(1,1) Primary key clustered
	, cmd varchar(4000)
	);
	
Declare @RunDate	Varchar(24)
	, @ServerName	Varchar(50)
	, @InstanceName	Varchar(50)
	, @SQLVersion	Varchar(50)
	, @NewLine		Char(1) = Char(10)
	;
Set @RunDate = convert(varchar(24), GetDate(), 121)
Set @ServerName = Cast(@@ServerName as Varchar(50))
Set @InstanceName = Coalesce(Cast(ServerProperty('InstanceName') as Varchar(128)), 'Default')
Set @SQLVersion = SubString(Cast(ServerProperty('ProductVersion') As Varchar(10))
				, 1
				, CharIndex('.', Cast(ServerProperty('ProductVersion') As Varchar(10)), 1) - 1
				)
	;
Insert #theCmd (cmd)
	Select '-- Run Date = ' + @RunDate + @NewLine
		+ '-- Server Name = ' + @ServerName + '; Instance =  ' + @InstanceName
		+ '; SQL Version = ' + @SQLVersion
	Union All
	Select '-- This script was generated for the purpose of restoring SQL Logins to correct Server Roles' + @NewLine
		+ '-- for disaster recovery or to migrate to a new server.'
	Union All
	Select '-- First Generate SQL to create all User Defined Server Roles'
If cast(@SQLVersion as int) <= 10
	Insert #theCmd(cmd)
		Select '-- No T-SQL Generated for User Defined Server Roles.  SQL Version is prior to SQL2012 (i.e., SQL Version < 11).' + @NewLine
		+ '-- Capability to create User defined Server Roles added with SQL2012';
Else Begin	-- SQL 2012+
	Insert #theCmd(cmd)
		Select  '--	Generating T-SQL to create User Defined Server Roles. (SQL2012+)'
	Insert #theCmd(cmd)
		Select		-- Generate T-SQL to create the User Defined Role
		'IF NOT EXISTS(SELECT name 
		FROM sys.server_principals 
		WHERE type = ''R'' AND name=''' + [name] + ''') 
		CREATE SERVER ROLE [' + [name] + '];'
	FROM sys.server_principals
	WHERE  1 = 1
		And type = 'R'
		AND principal_id > 10;		-- filter out fixed server roles like BulkAdmin
	If @@RowCount = 0
	Begin	-- No user defined Server roles
		Insert #theCmd(cmd)
			Select  '--	No User Defined Server Roles on this server.';		
	End;	-- No user defined Server roles
End	-- SQL 2012+

/*
	This portion generates T-SQL to add server logins to the correct server roles.
*/
Insert #theCmd(cmd)
	Select  '-- Next Generate T-SQL to add Server Logins to Server Roles.';

Insert #theCmd(cmd)
	Select 'EXEC sp_addsrvrolemember @loginame = ''' + p.[name]
		+ ''', @rolename = ''' + r.[name] + ''';'
	FROM
		sys.server_principals AS p
		Inner JOIN sys.server_role_members AS srm
			ON p.principal_id = srm.member_principal_id
		Inner JOIN sys.server_principals AS r
			ON srm.role_principal_id = r.principal_id
	WHERE p.[name] <> 'sa';					-- sa is already member of SysAdmin fixed role.  no need to add to others.

Select cmd from #theCmd;	