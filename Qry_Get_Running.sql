/*
	Start of a query to find currently running requests that have
	Been running a long time and have a long estitmated time remmaing.
	
	This does not find Sessions that do not have an active request and apparently
	a transaction roll-back is not a "Request"

	$Workfile: Query_Get_Running.sql $
	$Archive: /SQL/QueryWork/Query_Get_Running.sql $
	$Revision: 4 $	$Date: 14-11-28 16:19 $
*/
Use Master;
-- This CTE needs to change to insert to a temp table/table variable.
;With FirstLook As(
	Select
		er.session_id
		,er.Request_id
		,er.wait_type
		,er.wait_time
		,er.last_wait_type
		,er.wait_resource
		,er.blocking_session_id
		,er.percent_complete
		,er.cpu_time
		,er.total_elapsed_time
		,er.reads
		,er.writes
		,er.start_time
		--,er.command
		,er.database_id
	FROM sys.dm_exec_requests as er	
	)
SELECT
	er.session_id
	,er.Request_id
	,er.status
	,[Blockers] = N'Was ' + CONVERT(NVARCHAR(20), fl.blocking_session_id) + N'. Now is ' + CONVERT(NVARCHAR(20), er.blocking_session_id)
	--,es.host_name
	--,es.login_name
	,[Curr Wait] = N'Was ' + fl.wait_type + N'.  Now is ' + er.wait_type
	,[TotalWait] = er.wait_time
	,[WaitTime Delta] = er.wait_time - fl.wait_time
	,[Last Wait] = N'Was ' + fl.last_wait_type + N'.  Now was ' + er.last_wait_type
	,er.wait_resource
	, [Resource] = Case When fl.wait_resource = er.wait_resource Then 'Same' Else 'Diff' End
	,fl.percent_complete
	,er.percent_complete
	,er.estimated_completion_time
	,[CPU Delta] = er.cpu_time - fl.cpu_time
	,er.cpu_time
	,er.total_elapsed_time
	,er.reads
	,[Reads Delta] = er.reads - fl.reads
	,er.writes
	,[Writes Delta]  = er.writes - fl.writes
	,er.start_time
	,er.command
	,er.database_id
	,er.row_count
	,er.sql_handle
	,er.statement_end_offset
	,er.statement_start_offset
FROM sys.dm_exec_requests as er
	left join FirstLook as fl		-- may also need Wait resource in the join condition.
		on fl.session_id = er.session_id and fl.request_id = er.request_id
WHERE 1 = 1
	and er.session_id > 50
	
-- Kill 85