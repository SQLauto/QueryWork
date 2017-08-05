Set xact_abort off;
Set nocount on;
/*
Query accounts, domain groups, And members who have admin membership
http://www.sqlservercentral.com/articles/Security/76919/
Eric Russell

	The following script returns accounts, domain groups, And domain group members who have been
	granted or inherited membership in a SQL Server fixed admin role. The system view master.sys.server_principals
	won’t reveal what domain accounts are members of a domain group, so this script leverages the system stored
	procedure xp_logininfo to expand the result.

	Modified From original to return all server principals And their roles.
	$Archive: /SQL/QueryWork/Security_ServerPrincipalsAndRoles.sql $
	$Revision: 1 $	$Date: 14-11-28 16:20 $
*/
If Object_Id ('tempdb..#Principals', 'U') Is Not Null
	Drop Table #Principals;
If Object_Id ('tempdb..#admin_groups', 'U') Is Not Null
	Drop Table #admin_groups;
If Object_Id ('tempdb..#logininfo', 'U') Is Not Null
	Drop Table #logininfo;
Go

Create Table #Principals (
	  Primary key (principal_type, principal_name, member_name)
	, principal_type Varchar(180) Not Null
	, principal_name Varchar(180) Not Null
	, member_name Varchar(180) Not Null
	, create_date DATETIME Null
	, modify_date DATETIME Null
	, role_desc Varchar(180) Null
	, logininfo_note Varchar(8000) Null
	);
Create Table #admin_groups (
	  Primary key (group_type, group_name)
	, group_type Varchar(180) Not Null
	, group_name Varchar(180) Not Null
	);
Create Table #logininfo (
	  Primary key (account_name, permission_path)
	, account_name Varchar(180) Not Null
	, type Varchar(180) Null
	, privilege Varchar(180) Null
	, mapped_login_name Varchar(180) Null
	, permission_path Varchar(180) Not Null
	);

declare
	@group_type Varchar(180)
	, @group_name Varchar(180);
-- Insert all accounts And groups into result:
Insert into #principals(principal_type, principal_name, member_name, create_date, modify_date, role_desc, logininfo_note)
	Select
		 type_desc
		, name
		, '-'
		, create_date
		, modify_date
		, (
		  Case is_srvrolemember('sysadmin',name) When 1 Then 'SysAdmin_' Else '' End
		  + Case is_srvrolemember('securityadmin',name) When 1 Then 'SecurityAdmin_' Else '' End
		  + Case is_srvrolemember('serveradmin',name) When 1 Then 'ServerAdmin_' Else '' End
		  + Case is_srvrolemember('setupadmin',name) When 1 Then 'SetupAdmin_' Else '' End  
		  + Case is_srvrolemember('processadmin',name) When 1 Then 'ProcessAdmin_' Else '' End  
		  + Case is_srvrolemember('diskadmin',name) When 1 Then 'DiskAdmin_' Else '' End  
		  + Case is_srvrolemember('dbcreator',name) When 1 Then 'DBCreator_' Else '' End  
		  + Case is_srvrolemember('bulkadmin',name) When 1 Then 'BulkAdmin_' Else '' End 
		  + Case is_srvrolemember('Public',name) When 1 Then 'Public_' Else '' End
		 )
		 ,Null
	From sys.server_principals As sp
	Where 1 = 1
		And sp.type_desc in ('SQL_LOGIN', 'WINDOWS_GROUP', 'WINDOWS_LOGIN')
	;

-- For each domain group with admin privilages,
-- Insert one record for each of it's member accounts into the result:
Set @group_type = '*';
Set @group_name = '*';

While @group_name Is Not Null
Begin	-- Group Name Not Null
	Set @group_type = Null;
	Set @group_name = Null;
	Select top 1 @group_type = principal_type, @group_name = principal_name
	From #principals
	Where principal_type in ('windows_group')
		And member_name = '-'      
		And role_desc Is Not Null
		And principal_name Not in (Select group_name From #admin_groups);
	If @group_name Is Not Null
	Begin	-- Found a Windows Group
		-- Call xp_logininfo to return all domain accounts belonging to group:
		Insert #admin_groups values (@group_type, @group_name);
		Begin try
			Delete From #logininfo;
			Insert into #logininfo
			Exec master..xp_logininfo @group_name,'members';
			-- Update number of members for group to logininfo_note:
			update #principals
			Set logininfo_note = 'xp_logininfo returned '+cast(@@rowcount As Varchar(9))+' members.'
			Where principal_type in ('windows_group')
				And principal_name = @group_name
				And member_name = '-';   
		End try
		Begin catch
			-- If an error occurred, Then update it to logininfo_note, And Then continue:
			update #principals
			Set logininfo_note = 'xp_logininfo returned error '+cast(error_number() As Varchar(9))
			Where principal_type in ('windows_group')
			And principal_name = @group_name
			And member_name = '-';
		End catch
		-- For each group member, Insert a record into the result:
		Insert into #principals
		Select
			@group_type
			, @group_name
			, account_name
			, Null
			, Null
			, (Select role_desc
				From #principals
				Where principal_type = @group_type
					And principal_name = @group_name
					And member_name = '-')
			, Null
		From #logininfo;
		-- For each group member that Is a group,
		-- Insert a record of type 'WINDOWS_GROUP' into the result:
		Insert into #principals
			Select
				'WINDOWS_GROUP'
				, account_name
				, '-'
				, Null
				, Null
				, (Select role_desc
					From #principals
					Where principal_type = @group_type
						And principal_name = @group_name
						And member_name = '-')
				, Null As logininfo_note
			From #logininfo
			Where type = 'group'
				And Not Exists
					(Select 1
					From #principals
					Where principal_type = 'WINDOWS_GROUP' And principal_name = account_name And member_name = '-'
					);
	End;	-- Found a Windows Group
End;	-- Group Name Not Null

-- Return result of only those accounts, groups, And members who have an admin role:
Select
	principal_type
	, principal_name
	, member_name
	, role_desc
	, logininfo_note
	, create_date
	, modify_date
From #principals
Where role_desc Is Not Null
Order By principal_type, principal_name, member_name;