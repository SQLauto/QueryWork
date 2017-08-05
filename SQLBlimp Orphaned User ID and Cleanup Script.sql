/* ----------------------------------------------------------------
-- The SQLBlimp Orphaned User ID and SQL Logins Cleanup Script
-- Version 1.0
-- By John F. Tamburo 2016-06-16
-- Feel free to use this - Freely given to the SQL community
-- SQL 2008 and Newer.
----------------------------------------------------------------
$Archive: /SQL/QueryWork/SQLBlimp Orphaned User ID and Cleanup Script.sql $
$Revision: 2 $	$Date: 16-07-18 14:48 $

SQL Authentication Via AD Groups Part III: What About Orphaned Users?
http://www.sqlservercentral.com/articles/Security/142831/
*/
Set NoCount On;
Declare	@ctr NVarchar(Max) = ''
  , @AcctName sysname = '';
Declare	@OrphanDropSQL NVarchar(Max) = ''
  , @X Int = 1;

-- Create a table to store xp_logininfo commands
-- We have to individually execute them in case 
-- a Windows login no longer exists in AD

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
	  UserName NVarchar(128)
	, Type NVarchar(128)
	, Privilege NVarchar(128)
	, [Mapped Login Name] NVarchar(128)
	, [Permission Path] NVarchar(128)
	, RowID Int Identity(1, 1)
	);

-- Jeff Moden: I got rid of the RBAR!  Be Proud!
Set @X = 1;

While @X = 1
Begin
	Select Top 1
			@ctr = CommandToRun
	From	#ExecuteQueue
	Order By RowID;
	If @@RowCount = 0
		Set @X = 0;
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
				Insert	Into #LoginsList (UserName, Type, Privilege, [Mapped Login Name], [Permission Path])
				Select	@AcctName AccountName, 'user', 'DELETED Windows User', @AcctName MappedLogin,
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

-- Add SID and SQL Logins 
Insert	Into #LoginsList (UserName, Type, Privilege, [Mapped Login Name], [Permission Path], sid)
Select	name AccountName, 'user', 'user', name MappedLogin, name PermissionPath, sid
From	sys.server_principals
Where	1 = 1
		And (type = 'S'		     -- SQL Server Logins
			 And name Not Like '%##%'
			) -- Eliminate Microsoft 
		Or (type In ('U', 'G')) -- Capture SID for AD Users and Groups
Order By name;

--assign a row ID

Print 'Drop all windows logins where the Windows user has been deleted.';
--Drop all windows logins where the Windows user has been deleted.
Set @X = 1;

While @X = 1
Begin
	Select Top 1
			@OrphanDropSQL = 'DROP LOGIN [' + UserName + '];'
	From	#LoginsList
	Where	Privilege = 'DELETED Windows User'
	Order By RowID;
	If @@RowCount = 0
		Set @X = 0;
	Else
	Begin
		Print @OrphanDropSQL;
		--exec(@OrphanDropSQL);
		With	CTE
				  As (Select Top 1
								RowID
					  From		#LoginsList
					  Where		Privilege = 'DELETED Windows User'
					  Order By	RowID
					 )
			Delete	From CTE;
	End;
End;



-- now let's search the databases for orphans

Create Table #OrphansList (
	  DBName sysname
	, UserName NVarchar(128)
	, SID Varbinary(85)
	, RowID Int Identity(1, 1)
	);

-- Create a table to hold the users of each database.
Create Table #DB_Users (
	  DBName sysname
	, UserName sysname
	, LoginType sysname
	, sid Varbinary(85)
	);


Insert	#DB_Users
		Exec sys.sp_MSforeachdb '
use [?]
if ''?'' not in (''msdb'',''model'') -- do not bother with system databases; delete line if you do want to bother.
BEGIN
SELECT ''?'' AS DB_Name,
ISNULL(case prin.name when ''dbo'' then (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') else prin.name end,'''') AS UserName,
prin.type_desc AS LoginType,[sid]
FROM sys.database_principals prin
LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
WHERE prin.sid IS NOT NULL 
and prin.sid NOT IN (0x00) 
and prin.is_fixed_role <> 1 
AND prin.name is not null
AND prin.name NOT LIKE ''##%''
END
';
--select * from #DB_Users;

Print 'Drop those orphan DB Users!';

Insert	Into #OrphansList
Select	A.DBName As [Database Name], A.UserName As UserName, A.sid
From	#DB_Users A
Where	1 = 1
		And A.LoginType != 'database_role'
--and A.LoginType != 'windows_group' -- groups no logins???
		And A.UserName Not Like 'MS_%' -- no internal users
		And Not Exists ( Select	1
						 From	#LoginsList B
						 Where	A.sid = B.sid );

--select * from #OrphansList;
Set @X = 1;

While @X = 1
Begin
	Select Top 1
			@OrphanDropSQL = 'Use [' + DBName + ']
	IF EXISTS(select 1 from[' + DBName + '].[sys].[schemas] where [name] = ''' + UserName + ''')
		DROP SCHEMA [' + UserName + '];
	DROP USER [' + UserName + '];'
	From	#OrphansList
	Order By RowID;

	If @@RowCount = 0
		Set @X = 0;
	Else
	Begin
		Print @OrphanDropSQL;
		--exec(@OrphanDropSQL);
		With	CTE
				  As (Select Top 1
								DBName, UserName, SID
					  From		#OrphansList
					  Order By	RowID
					 )
			Delete	From CTE;
	End;
End;

Drop Table #OrphansList;
Drop Table #DB_Users;
Drop Table #ExecuteQueue;
Drop Table #LoginsList;


