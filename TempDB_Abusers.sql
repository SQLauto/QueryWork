/*
	Investigating Task Space Usage to find TempDB abusers.
	
	$Archive: /SQL/QueryWork/TempDB_Abusers.sql $
	$Revision: 3 $	$Date: 17-02-10 10:04 $

	This query is planned to find sessions that are heavy tempdb users.
	It needs a lot of work to reach that goal.
*/

SELECT
	tsu.session_id
	,tsu.request_id
	--,mg.request_id
	,tsu.exec_context_id
	,mg.dop
	,mg.scheduler_id
	,[Host] = es.host_name
	,[Program]= es.program_name
	,[Login]= es.login_name
	,[User Page Alloc] = tsu.user_objects_alloc_page_count
	,[User Page DeAlloc] = tsu.user_objects_dealloc_page_count
	,[Command]= er.command
	,[Status]= er.status
	,mg.wait_time_ms
	,er.*
	,ot.*
	--,mg.sql_handle
From
	sys.dm_db_task_space_usage as tsu
	inner join sys.dm_exec_sessions as es
		on es.session_id = tsu.session_id
	inner join sys.dm_exec_query_memory_grants as mg
		on mg.session_id = tsu.session_id
		and mg.request_id = tsu.request_id
	inner join sys.dm_os_tasks as ot
		on ot.session_id = tsu.session_id and ot.exec_context_id = tsu.exec_context_id
	left outer join sys.dm_exec_requests as er
		on tsu.session_id = er.session_id and tsu.request_id = er.request_id
Where
	tsu.database_id = db_id('tempdb')
	and tsu.session_id != @@SPID
Order by
	[User Page Alloc]		Desc
	,[User Page DeAlloc]	Desc
	, tsu.session_id
	, tsu.request_id
	, tsu.exec_context_id
;