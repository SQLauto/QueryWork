
/*
	
	Understanding GRANT, DENY, and REVOKE in SQL Server
	https://www.mssqltips.com/sqlservertip/2894/understanding-grant-deny-and-revoke-in-sql-server/?utm_source=dailynewsletter&utm_medium=email&utm_content=headline&utm_campaign=20170504
	$Archive: /SQL/QueryWork/Sec_ObjectPermissions_Get.sql $
	$Revision: 1 $	$Date: 17-05-06 11:36 $

*/

Declare @ObjName	SysName = N'Fuel'
Select
	dp.class_desc
	, [Schema] = s.name
	, [Object] = o.name
	, dp.permission_name
	, dp.state_desc
	, [User] = prin.name
From
	sys.database_permissions As dp
	Join sys.database_principals As prin
		On dp.grantee_principal_id = prin.principal_id
	Join sys.objects As o
		On dp.major_id = o.object_id
	Join sys.schemas As s
		On o.schema_id = s.schema_id
Where 1 = 1
	And o.name Like '%' + @ObjName + '%'
	And dp.class_desc = 'OBJECT_OR_COLUMN'
Union All
Select
	dp.class_desc
  , [Schema] = s.name
  , [Object] = '-----'
  , dp.permission_name
  , dp.state_desc
  , [User] = prin.name
	From
	sys.database_permissions As dp
		Join sys.database_principals As prin
			On dp.grantee_principal_id = prin.principal_id
		Join sys.schemas As s
			On dp.major_id = s.schema_id
	Where	dp.class_desc = 'SCHEMA';