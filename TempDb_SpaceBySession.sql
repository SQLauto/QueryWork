/*
	Microsoft SQL Server – TempDB usage per active session
	http://www.citagus.com/citagus/blog/tempdb-usage-per-active-session/
	With substantial modifications

	$Archive: /SQL/QueryWork/TempDb_SpaceBySession.sql $
	$Revision: 3 $	$Date: 17-02-10 10:04 $

	This Query returns data for all of the current sessions 
	returned data is TempDB page usage plus some session data such as the command, host, program, etc.
	
	
*/


;
WITH task_space_usage(session_id, requst_id, user_alloc_pages, user_dealloc_pages, sys_alloc_pages, sys_dealloc_pages)
	AS (
    -- SUM alloc/delloc pages
	SELECT
		session_id
		, request_id
		, SUM(user_objects_alloc_page_count)
		, SUM(user_objects_dealloc_page_count)
		, SUM(internal_objects_alloc_page_count)
		, SUM(internal_objects_dealloc_page_count)
	FROM
		sys.dm_db_task_space_usage WITH (NOLOCK)
	WHERE
		session_id <> @@SPID
	GROUP BY
		session_id
		, request_id
	)
SELECT
	tsu.session_id
	, [Total Alloc(MB)] = Cast((tsu.user_alloc_pages * 1.0 / 128.0 ) + (tsu.sys_alloc_pages * 1.0 / 128.0 )as decimal(12,2))
	, [CPU Time(ms)] = er.cpu_time
	, [Total Time(ms)] = er.total_elapsed_time
	, [Command] = er.command
	, [Program] = es.program_name
	, [Login] = es.login_name
	, [Host] = es.host_name
	, [user object alloc (MB)] = Cast(tsu.user_alloc_pages * 1.0 / 128.0 as decimal(12,2))
	, [user object dealloc (MB)] = Cast(tsu.user_dealloc_pages * 1.0 / 128.0as decimal(12,2))
	, [int object alloc (MB)] = Cast(tsu.sys_alloc_pages * 1.0 / 128.0 as decimal(12,2))
	, [int object dealloc (MB)] = Cast(tsu.sys_dealloc_pages * 1.0 / 128.0 as decimal(12,2))
	, st.text
	
--Extract statement from sql text
	, [statement text] = ISNULL(NULLIF(SUBSTRING(st.text, er.statement_start_offset / 2,
							CASE WHEN er.statement_end_offset < er.statement_start_offset THEN 0
								ELSE (er.statement_end_offset - er.statement_start_offset) / 2
								END), ''
							), st.text)
  , [Query Plan] = qp.query_plan
-- Select *
FROM
	task_space_usage AS tsu
	INNER JOIN sys.dm_exec_requests as er
		ON tsu.session_id = er.session_id
		AND tsu.requst_id = er.request_id
	Inner Join sys.dm_exec_sessions as es
		on es.session_id = tsu.session_id
	OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
	OUTER APPLY sys.dm_exec_query_plan(er.plan_handle) AS qp
Where 1 = 1
	And es.is_user_process = 1		-- just user sessions
	--And (st.text IS NOT NULL
	--	Or qp.query_plan IS NOT Null)
ORDER BY
	[Total Alloc(MB)] DESC
