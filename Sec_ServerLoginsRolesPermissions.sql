/*
	Server level permissions for SQL Server 2005 and SQL Server 2008
	K. Brian Kelly
	http://www.mssqltips.com/sqlservertip/1714/server-level-permissions-for-sql-server-2005-and-sql-server-2008/

	A quick and easy script you can use to see what permissions are assigned at the server level is the following
	It uses the sys.server_permissions catalog view joined against the sys.server_principals catalog view to pull
	back all the server-level permissions belonging to SQL Server logins, Windows user logins, and Windows group logins:
	Modified to return Login's Fixed Server Role if assigned.

	$Archive: /SQL/QueryWork/Security_ServerLoginsRolesPermissions.sql $
	$Revision: 1 $	$Date: 14-11-28 16:20 $
*/


SELECT
	[server_principal] = sp.name
	, [principal_type] = sp.type_desc
	, [permission_name] = srvperm.permission_name
	, [state_desc] = srvperm.state_desc
	, [Server Role] = COALESCE(sr.name, 'Null - Assume Public')
FROM sys.server_permissions as srvperm
	INNER JOIN sys.server_principals as sp
		ON srvperm.grantee_principal_id = sp.principal_id
	left join sys.server_role_members as rm
		on rm.member_principal_id = sp.principal_id
	left join sys.server_principals as sr
		on sr.principal_id = rm.role_principal_id
WHERE sp.type IN ('S', 'U', 'G')
ORDER BY
	server_principal
	, permission_name; 
