/*
	Concept based on excerpts from: Different techniques to identify blocking in SQL Server
	https://www.mssqltips.com/sqlservertip/2732/different-techniques-to-identify-blocking-in-sql-server/

	$Archive: /SQL/QueryWork/Lck_Overview.sql $
	$Revision: 1 $	$Date: 16-05-12 14:11 $

*/
/*
-- To View Blocked Process
Select  er.session_id
	, er.blocking_session_id
	, er.wait_time
	, er.wait_type
	, er.last_wait_type
	, er.wait_resource
	, er.transaction_isolation_level
	, er.lock_timeout
FROM sys.dm_exec_requests As er
WHERE blocking_session_id <> 0
*/

/*
--	To View current locks awaiting conversion
	The value of CONVERT means that the requestor has been granted a request but is waiting to upgrade to the initial request to be granted.
	For a specific database
*/

Declare
	@DBName	Varchar(50) = ''
	
Select	
	tl.request_session_id
	, tl.request_status
	, tl.request_mode
	, [Res DBName] = Db_Name(tl.resource_database_id)
	, tl.resource_type
	, tl.resource_subtype
	, tl.resource_associated_entity_id
	, [ObjName] = Case tl.resource_type
			When 'Object' Then Object_Name(tl.resource_associated_entity_id, tl.resource_database_id)
			When 'Database' Then 'N/A'
			Else 'Unk'
			End
	, tl.resource_description
From sys.dm_tran_locks As tl
	--Left Join sys.partitions As sp
	--	On sp.hobt_id = tl.resource_associated_entity_id
	Left Join sys.dm_os_waiting_tasks As wt
		On wt.resource_address = tl.lock_owner_address
Where 1 = 1
	--And tl.request_status = 'CONVERT'
	--And tl.request_status != 'Grant'


/*
	Execute the following to view wait stats for all block processes on SQL Server:
*/

Select
	wt.session_id
	, wt.wait_duration_ms
	, wt.wait_type
	, wt.blocking_session_id
	, wt.resource_description
	, [ProgramName] = Case When es.program_name Like 'SQL Agent Job%'
					Then es.program_name					
					Else es.program_name
					End
	, st.text
	, st.dbid
	, es.cpu_time
	, es.memory_usage
From sys.dm_os_waiting_tasks As wt
	Inner Join sys.dm_exec_sessions As es
		On wt.session_id = es.session_id
	Inner Join sys.dm_exec_requests As er
		On es.session_id = er.session_id
	Outer Apply sys.dm_exec_sql_text(er.sql_handle) As st
Where es.is_user_process = 1;