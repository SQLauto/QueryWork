/* ------------------------------------------------------------
-- The SQLBlimp AD Access Identification Script Version 2.5
-- By John F. Tamburo 2016-06-30
-- Feel free to use this - Freely given to the SQL community
SQL Authentication Via AD Groups Part III: What About Orphaned Users?
http://www.sqlservercentral.com/articles/Security/142831/
------------------------------------------------------------
$Archive: /SQL/QueryWork/SQLBlimp Access Audit Script V2.5 2016-06-30.sql $
$Revision: 2 $	$Date: 16-07-18 14:48 $

*/
Set NoCount On;
Declare	@ctr NVarchar(Max) = ''
  , @AcctName sysname = ''
  , @x Int = 1;

-- Create a table to store xp_logininfo commands
-- We have to individually execute them in case the login no longer exists

Create Table #ExecuteQueue (
	  AcctName sysname
	, CommandToRun NVarchar(Max)
	, RowID Int Identity(1, 1)
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

-- Jeff Moden: I got rid of the cursor!  Be Proud!  
-- I couldn't get rid of the loop since I have to error handle each SQL command for accurate results. :(
Set @x = 1;

While @x = 1
Begin
	Select Top 1
			@ctr = CommandToRun
	From	#ExecuteQueue
	Order By RowID;
	If @@RowCount = 0
		Set @x = 0;
	Else
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
				Select	@AcctName AccountName, 'WINDOWS_USER', 'DELETED Windows User', @AcctName MappedLogin,
						@AcctName PermissionPath;
			End;
			Else
				Print Error_Message();
		End Catch;
		With	CTE
				  As (Select Top 1
								RowID
					  From		#ExecuteQueue
					  Order By	RowID
					 )
			Delete	From CTE;
	End;
	Print '-------------------------------';
End;


--add SID
Alter Table #LoginsList Add sid Varbinary(85);

-- Add SQL Logins to the result
Insert	Into #LoginsList ([Account Name], Type, Privilege, [Mapped Login Name], [Permission Path], sid)
Select	name AccountName, (Case When type = 'S' Then 'SQL_USER'
								  When type = 'U' Then 'WINDOWS_USER'
								  When type = 'G' Then 'WINDOWS_GROUP'
								  Else '?WTF'
							 End), 'user', name MappedLogin, name PermissionPath, sid
From	sys.server_principals
Where	1 = 1
		And (type = 'S'		     -- SQL Server Logins only
			 And name Not Like '%##%'
			) -- Eliminate Microsoft 
		Or (type In ('U', 'G') /*and [name] like 'NT SERVICE\%'*/) -- capture NT Service information
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
	, sid Varbinary(85)
	);

-- Iterate the each database for its users and store them in the table.
Insert	#DB_Users
		Exec sys.sp_MSforeachdb '
use [?]
SELECT ''?'' AS DB_Name,
ISNULL(case prin.name when ''dbo'' then (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') else prin.name end,'''') AS UserName,
prin.type_desc AS LoginType,
isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,create_date,modify_date, [sid]
FROM sys.database_principals prin
LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
WHERE prin.sid IS NOT NULL 
and prin.sid NOT IN (0x00) 
and prin.is_fixed_role <> 1 
AND prin.name is not null
AND prin.name NOT LIKE ''##%''';

-- Refine the user permissions into a concatenated field by DB and user
Select	user1.DBName, user1.UserName, user1.sid, user1.LoginType, user1.create_date, user1.modify_date,
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
Group By user1.DBName, user1.UserName, user1.sid, user1.LoginType, user1.create_date, user1.modify_date
Order By user1.DBName, user1.UserName;

-- Report out the results
With	CTE
		  As (Select 
	Distinct			LL.[Account Name], LL.sid, @@ServerName As [Database Server],
						(Case When UP.DBName Is Null Then '[none]'
							  Else UP.DBName
						 End) As [Database Name], (Case	When LL.Type = 'user' Then 'WINDOWS_USER'
														Else LL.Type
												   End) As LoginType, LL.Privilege, LL.Server_Roles,
						LL.[Permission Path], UP.Permissions_user As [User Privileges]
			  From		#LoginsList LL
						Left Join #UserPermissions UU
							On LL.[Account Name] = UU.UserName
						Left Join #UserPermissions UP
							On (LL.sid = UP.sid
								Or ((LL.sid Is Null)
									And LL.[Permission Path] = UP.UserName
								   )
							   )
-- Comment out the where clause to see all logins that have no database users
-- and their server roles.
-- where exists(select 1 from #LoginsList U2 where U2.[sid] = UP.[sid])
			  Union All
-- orphaned users
			  Select	A.UserName As [Account Name], A.sid, @@ServerName As [Database Server],
						A.DBName As [Database Name], A.LoginType, 'ORPHANED USER NO LOGIN' As Privilege,
						'NONE' As Server_Roles, Null As [Permission Path], Null As [User Privileges]
			  From		#DB_Users A
			  Where		1 = 1
						And A.LoginType != 'database_role'
--and A.LoginType != 'windows_group' -- groups no logins???
						And A.UserName Not Like 'MS_%' -- no internal users
						And Not Exists ( Select	1
										 From	#LoginsList B
										 Where	A.sid = B.sid )
			 )
	Select 
	Distinct
			*
	From	CTE
	Where	1 = 1
--and [LoginType] != 'Windows_Group'
--and [sid] is not null
			And (CTE.[Permission Path] Is Not Null
				 Or (CTE.[Permission Path] Is Null
					 And CTE.Privilege Like 'orphan%'
					)
				)
	Order By CTE.[Account Name], CTE.sid, CTE.[Database Name];

-- Clean up my mess
Drop Table #ExecuteQueue;
Drop Table #LoginsList;
Drop Table #DB_Users;
Drop Table #UserPermissions;


