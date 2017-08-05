/*
	This script returns the Server Principals and the
	Server Permissions granted to those principals.

	$Archive: /SQL/QueryWork/Security_PrincipalsAndPermissions.sql $
	$Revision: 1 $	$Date: 14-09-12 17:13 $
	
*/
select 
	[Login]	= prin.name
	,prin.type_desc
	,perm.class_desc
	,perm.permission_name
	,perm.state_desc
	,[Grantor] = grantor.name
	--,perm.*
from
	sys.server_permissions as perm
inner join sys.server_principals as prin
	on prin.principal_id = perm.grantee_principal_id
inner join sys.server_principals as grantor
	on grantor.principal_id = perm.grantor_principal_id

Return;

/*
--	http://msdn.microsoft.com/en-us/library/ms190369(v=sql.105).aspx
	Returns the "permissions source" or "Permission Path" for a login.
	e.g. for a user it might show a windows security group
*/

exec xp_LoginInfo 'Simmons\rh001'

/*
Troubleshooting specific Login Failed error messages
http://blogs.msdn.com/b/sqlserverfaq/archive/2010/10/27/troubleshooting-specific-login-failed-error-messages.aspx
How It Works: SQL Server 2005 SP2 Security Ring Buffer - RING_BUFFER_SECURITY_ERROR
http://blogs.msdn.com/b/psssql/archive/2008/03/24/how-it-works-sql-server-2005-sp2-security-ring-buffer-ring-buffer-security-error.aspx
*/
SELECT	CONVERT (VARCHAR(30), GETDATE(), 121) as runtime
	  , DATEADD(ms, (a.[Record Time] - sys.ms_ticks), GETDATE()) as [Notification_Time]
	  , a.*
	  , sys.ms_ticks AS [Current Time]
FROM	(SELECT	x.value('(//Record/Error/ErrorCode)[1]', 'varchar(30)') AS [ErrorCode]
			  , x.value('(//Record/Error/CallingAPIName)[1]', 'varchar(255)') AS [CallingAPIName]
			  , x.value('(//Record/Error/APIName)[1]', 'varchar(255)') AS [APIName]
			  , x.value('(//Record/Error/SPID)[1]', 'int') AS [SPID]
			  , x.value('(//Record/@id)[1]', 'bigint') AS [Record Id]
			  , x.value('(//Record/@type)[1]', 'varchar(30)') AS [Type]
			  , x.value('(//Record/@time)[1]', 'bigint') AS [Record Time]
		 FROM	(SELECT	CAST (record as XML)
				 FROM	sys.dm_os_ring_buffers
				 WHERE	ring_buffer_type = 'RING_BUFFER_SECURITY_ERROR'
				) AS R (x)
		) a
		CROSS JOIN sys.dm_os_sys_info sys
ORDER BY a.[Record Time] ASC
