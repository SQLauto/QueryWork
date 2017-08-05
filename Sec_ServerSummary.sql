/*------------------------------------------------------------
	-- The SQLBlimp AD Access Identification Script
	-- By John F. Tamburo 2016-01-06
	-- Feel free to use this - Freely given to the SQL community
	http://www.sqlservercentral.com/articles/Active+Directory/135710/
------------------------------------------------------------
	$Archive: /SQL/QueryWork/Sec_ServerSummary.sql $
	$Revision: 1 $	$Date: 16-03-07 9:03 $
*/
Set NoCount On;
Declare	@ctr NVarchar(Max) = ''
  , @AcctName sysname = '';

-- Create a table to store xp_logininfo commands
-- We have to individually execute them in case the login no longer exists

Create Table #ExecuteQueue (
	  AcctName sysname
	, CommandToRun NVarchar(Max)
	);

-- Create a command list for windows-based SQL Logins
Insert	Into #ExecuteQueue (AcctName, CommandToRun)
		Select	name,
				Convert(NVarchar(Max), 'INSERT INTO #LoginsList EXEC xp_logininfo ''' + name
				+ ''', ''all''; --insert group information' + Char(13) + Char(10)
				+ Case When type = 'G'
					   Then ' INSERT INTO #LoginsList EXEC xp_logininfo  ''' + name
							+ ''', ''members''; --insert member information' + Char(13) + Char(10)
					   Else '-- ' + RTrim(name) + ' IS NOT A GROUP BABY!' + Char(13) + Char(10)
				  End) As CMD_TO_RUN
		From	sys.server_principals
		Where	1 = 1
				And type In ('U', 'G')    -- *Windows* Users and Groups.
				And name Not Like '%##%' -- Eliminate Microsoft 
				And name Not Like 'NT SERVICE\%' -- xp_logininfo does not work with NT SERVICE accounts
		Order By name, type_desc;

-- Create the table that the commands above will fill.
Create Table #LoginsList (
	  [Account Name] NVarchar(128)
	, Type NVarchar(128)
	, Privilege NVarchar(128)
	, [Mapped Login Name] NVarchar(128)
	, [Permission Path] NVarchar(128)
	);

-- Jeff Moden: Please forgive me for the RBAR! (:-D)
Declare cur Cursor
For
Select	AcctName, CommandToRun
From	#ExecuteQueue;

Open cur;
Fetch Next From cur Into @AcctName, @ctr;
While @@Fetch_Status = 0
Begin
	Begin Try
		Print @ctr;
		Exec sys.sp_executesql @ctr;
	End Try
	Begin Catch
		Print Error_Message() + Char(13) + Char(10);
		If Error_Message() Like '%0x534%' -- Windows SQL Login no longer in AD
			
		Begin
			Print '0x534 Logic';
			Insert	Into #LoginsList ([Account Name], Type, Privilege, [Mapped Login Name], [Permission Path])
					Select	@AcctName AccountName, 'DELETED Windows User', 'user', @AcctName MappedLogin,
							@AcctName PermissionPath;	
		End;
		Else
			Print Error_Message();
	End Catch;
	Fetch Next From cur Into @AcctName, @ctr;
	Print '-------------------------------';
End;

-- Clean up cursor 
Close cur;
Deallocate cur;

-- Add SQL Logins to the result
Insert	Into #LoginsList ([Account Name], Type, Privilege, [Mapped Login Name], [Permission Path])
		Select	name AccountName, 'user', 'user', name MappedLogin, name PermissionPath
		From	sys.server_principals
		Where	1 = 1
				And (type = 'S'		     -- SQL Server Logins only
				And name Not Like '%##%'
				) -- Eliminate Microsoft 
				Or (type In ('U', 'G')
				And name Like 'NT SERVICE\%'
				) -- capture NT Service information
		Order By name;

-- Get Server Roles into the mix
-- Add column to table
Alter Table #LoginsList Add Server_Roles NVarchar(Max);

-- Fill column with server roles
Update	LL
Set		Server_Roles = IsNull(Stuff((Select	', ' + Convert(Varchar(500), role.name)
									 From	sys.server_role_members
											Join sys.server_principals As role
												On role_principal_id = role.principal_id
											Join sys.server_principals As member
												On member_principal_id = member.principal_id
									 Where	member.name = (Case	When [Permission Path] Is Not Null
																Then [Permission Path]
																Else [Account Name]
														   End)	
									For
									 Xml Path('')
									), 1, 1, ''), 'public')
From	#LoginsList LL;

-- Create a table to hold the users of each database.
Create Table #DB_Users (
	  DBName sysname
	, UserName sysname
	, LoginType sysname
	, AssociatedRole Varchar(Max)
	, create_date DateTime
	, modify_date DateTime
	);

-- Iterate the each database for its users and store them in the table.
Insert	#DB_Users
		Exec sys.sp_MSforeachdb '
use [?]
SELECT ''?'' AS DB_Name,
ISNULL(case prin.name when ''dbo'' then prin.name + '' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end,'''') AS UserName,
prin.type_desc AS LoginType,
isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,create_date,modify_date
FROM sys.database_principals prin
LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
WHERE prin.sid IS NOT NULL 
and prin.sid NOT IN (0x00) 
and prin.is_fixed_role <> 1 
AND prin.name is not null
AND prin.name NOT LIKE ''##%''';

-- Refine the user permissions into a concatenated field by DB and user
Select	user1.DBName, user1.UserName, user1.LoginType, user1.create_date, user1.modify_date,
		Stuff((Select	', ' + Convert(Varchar(500), user2.AssociatedRole)
			   From		#DB_Users user2
			   Where	user1.DBName = user2.DBName
						And user1.UserName = user2.UserName	
			  For
			   Xml Path('')
			  ), 1, 1, '') As Permissions_user
Into	#UserPermissions
From	#DB_Users user1
Where	user1.LoginType != 'DATABASE_ROLE'
Group By user1.DBName, user1.UserName, user1.LoginType, user1.create_date, user1.modify_date
Order By user1.DBName, user1.UserName;

-- Report out the results
Select 
	Distinct
		LL.[Account Name], @@ServerName As [Database Server], UP.DBName As [Database Name], UP.LoginType
	--,LL.Privilege
		, LL.Server_Roles, LL.[Permission Path], UP.Permissions_user As [User Privileges]
From	#LoginsList LL
		Left Join #UserPermissions UP
			On LL.[Permission Path] = UP.UserName -- Comment out the where clause to see all logins that have no database users
-- and their server roles.
-- where exists(select 1 from #LoginsList U2 where U2.[Account Name] = UP.[UserName])
Order By LL.[Account Name], UP.DBName;

-- Clean up my mess
Drop Table #ExecuteQueue;
Drop Table #LoginsList;
Drop Table #DB_Users;
Drop Table #UserPermissions;