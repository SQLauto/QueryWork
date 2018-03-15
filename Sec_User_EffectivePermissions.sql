-- $Workfile: Sec_User_EffectivePermissions.sql $
/*
	Description:
	   Get Effective Permissions for a specific user in the current database.

	This will not produce results for a Windows Group becuase it can not be impersonated using Execute As User.

	$Archive: /SQL/QueryWork/Sec_User_EffectivePermissions.sql $
	$Date: 15-06-11 12:47 $	$Revision: 3 $

*/
Set NoCount On;
Declare
	@UserName	NVARCHAR(128)
		-- = N'LinkedServer'
		-- = N'WAYNE\Svc-Dal-EScanner'
		= N'WAYNE\Ray.Pirouzian'
	, @isLogin	NCHAR(1) = N'Y'			-- Y = Login name, N = database user name
	;
If @isLogin = N'N'
	Execute As User = @UserName
Else
	Execute As Login = @UserName

-- Determine effective permissions of @UserName on Server and for this database
Select [DbName] = Db_Name(), db.entity_name, db.subentity_name, db.permission_name
From fn_my_permissions(null, 'Database') as db
Union All
Select Db_Name(), db.entity_name, db.subentity_name, db.permission_name
From fn_my_permissions(null, 'Server') as db
order by
	db.entity_name
	, db.subentity_name
	, db.permission_name
;

-- I'm not sure what these really mean :)
Select
	[DbName] = Db_Name()
	, [User Name] = ut.name
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
	[DbName] = Db_Name()
	, [Login Name] = lt.name
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

Execute As Login = N'WAYNE\Ray.Pirouzian'
Select * From sys.Login_Token;
Revert;

