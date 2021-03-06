/*
	Get-UserPermisionsForObject

	$Workfile: $
	$Archive: $
	$Revision: $	$Date: $

*/

Select
	sp.name
	,perms.class_desc
	,perms.permission_name
	,prin.name
	,prin.type_desc
	--,perms.grantee_principal_id
	,perms.state_desc

From
	sys.procedures as sp
	inner join sys.database_permissions as perms
		on perms.major_id = sp.object_id and perms.class > 0
	inner join sys.database_principals as prin
		on prin.principal_id = perms.grantee_principal_id
Where 1 = 1
	and sp.type = 'P'
	and sp.is_ms_shipped = 0
