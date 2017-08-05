/*
	Want to write a query that will find long running requests
	and help determine whether they are making progress
	$Workfile: Blocking_Get_WaitingProcess.sql $
	$Archive: /SQL/QueryWork/Blocking_Get_WaitingProcess.sql $
	$Revision: 4 $	$Date: 14-03-11 9:43 $

	
*/

Select
	[SPID] = es.session_id
	,es.nt_user_name
	,[Blocker] = er.blocking_session_id
	,[ReId] = er.request_id
	,[Rows] = er.row_count
	,[EstComp] = er.estimated_completion_time
	,er.last_wait_type
	,er.reads
	,er.writes
	,er.logical_reads
	,er.wait_type
	,er.wait_resource
	,er.wait_time
	--,es.*
From sys.dm_exec_sessions as es
	left outer join sys.dm_exec_requests as er
		on er.session_id = es.session_id
where 1 = 1
	and es.session_id > 50
	--and es.nt_user_name = 'rh001'


Return;

--	Kill xx with statusonly

DBCC Opentran with tableResults

/*


*/