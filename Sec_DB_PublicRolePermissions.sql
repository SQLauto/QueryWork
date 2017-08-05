/*
The Public Role – a potential high risk security concern for DBAs - See more at: http://www.sswug.org/articles/memberarticle.aspx?id=68403#sthash.N8kghp5j.dpuf
-- See more at: http://www.sswug.org/articles/memberarticle.aspx?id=68403#sthash.N8kghp5j.dpuf

	$Archive: /SQL/QueryWork/Security_DB_PublicRolePermissions.sql $
	$Revision: 1 $	$Date: 14-11-28 16:20 $

*/
USE ConSIRN
-- Specify database name

GO


;WITH PublicRoleDBPermissions AS 
	(SELECT
		[PermissionType] = p.state_desc
		, [PermissionName] = p.permission_name
		, [DatabaseRole] = USER_NAME(p.grantee_principal_id)
		, [ObjectName] = CASE p.class
				WHEN 0 THEN 'Database::' + DB_NAME()
				WHEN 1 THEN OBJECT_NAME(major_id)
				WHEN 3 THEN 'Schema::' + SCHEMA_NAME(p.major_id)
				END
	FROM sys.database_permissions as p
	WHERE p.class IN (0, 1, 3)
		AND p.minor_id = 0
	)
SELECT	p.PermissionType
		, p.PermissionName
		, p.DatabaseRole
		, [ObjectSchema] = SCHEMA_NAME(so.schema_id)
		, p.ObjectName
		, [ObjectType] = so.type_desc
		, p.PermissionType + ' ' + PermissionName + ' ON '
		+ QUOTENAME(SCHEMA_NAME(so.schema_id)) + '.'
		+ QUOTENAME(p.ObjectName) + ' TO ' + QUOTENAME(p.DatabaseRole) AS GrantPermissionTSQL
		, 'REVOKE' + ' ' + p.PermissionName + ' ON '
		+ QUOTENAME(SCHEMA_NAME(so.schema_id)) + '.'
		+ QUOTENAME(p.ObjectName) + ' TO ' + QUOTENAME(p.DatabaseRole) AS RevokePermissionTSQL
FROM	PublicRoleDBPermissions as p
		JOIN sys.objects as so
			ON so.name = p.ObjectName
				AND OBJECTPROPERTY(so.object_id, 'IsMSShipped') = 0
WHERE 1 = 1
	and p.DatabaseRole = 'Public'
	and p.PermissionName != 'Execute'
ORDER BY p.DatabaseRole ASC
	, p.PermissionName
	, p.ObjectName ASC
	, ObjectType ASC

 

 Return
 /*
 Select * From sys.server_principals as sp
 Where	1 = 1
	and (sp.name = N'BuiltIn\Administrators'
		or sp.name like N'%Admin%')
*/