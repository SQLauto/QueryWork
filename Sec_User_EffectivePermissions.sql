-- $Workfile: Sec_User_EffectivePermissions.sql $
/*
	Description:
	   Get Effective Permissions for a specific user in the current database

	$Archive: /SQL/QueryWork/Sec_User_EffectivePermissions.sql $
	$Date: 15-06-11 12:47 $	$Revision: 3 $

*/

Declare
	@db_User	NVARCHAR(128)
	-- = N'SIMMONS\da_SQLDBATools'
	-- = N'Simmons\fs1328'
	-- = N'Simmons\sm001'
	-- = N'rherring'
	= N'Wayne\carly.wang'


	;
-- Determine effective permissions of 
Execute As user = @db_User;

Select db.entity_name, db.subentity_name, db.permission_name
From fn_my_permissions(null, 'Database') as db
Union All
Select db.entity_name, db.subentity_name, db.permission_name
From fn_my_permissions(null, 'Server') as db
order by
	db.entity_name
	, db.subentity_name
	, db.permission_name
;
Select
	[User Name] = ut.name
	, [User Type] = ut.type
	, [User Usage] = ut.usage
	, [Def Schema] = dp.default_schema_name
	, [Principal Type] = dp.type_desc
	, [Principal Name] = dp.name
	--, dp.*
From sys.User_Token as ut
	left join sys.database_principals as dp
		on dp.principal_id = ut.principal_id
;
Select
	[Login Name] = lt.name
	, [Login Usage] = lt.usage
	, [Login Type] = lt.type
	, [Principal Name] = sp.name
	, [Principal Type] = sp.type_desc
	--, sp.*
From sys.Login_Token as lt
	left join sys.server_principals as sp
		on sp.principal_id = lt.principal_id
Revert;
Return;

EXEC sp_change_users_login 'Report'

