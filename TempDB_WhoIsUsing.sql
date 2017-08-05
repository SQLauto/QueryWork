
/*
	SQL SERVER – Who is Consuming my TempDB Now?
	http://blog.sqlauthority.com/2015/01/23/sql-server-who-is-consuming-my-tempdb-now/

*/


SELECT
	-- [DB_ID] = st.dbid , 
   [DBName] = DB_NAME(st.dbid)
 -- , [ModuleObjectId] = st.objectid
  , [ObjectName] = object_Name(st.Objectid, st.dbId)
  , [Query_Text] = SUBSTRING(st.TEXT, er.statement_start_offset / 2 + 1,
			  (CASE	WHEN er.statement_end_offset = -1
					THEN LEN(CONVERT(NVARCHAR(MAX), st.TEXT)) * 2
					ELSE er.statement_end_offset
			   END - er.statement_start_offset) / 2)
  , tu.session_id
  , tu.request_id
  , tu.exec_context_id
  , [OutStanding_user_objects_page_counts] = (tu.user_objects_alloc_page_count
	 - tu.user_objects_dealloc_page_count)
  , [OutStanding_internal_objects_page_counts] = (tu.internal_objects_alloc_page_count - tu.internal_objects_dealloc_page_count)
  , er.start_time
  , er.command
  , er.open_transaction_count
  , er.percent_complete
  , er.estimated_completion_time
  , er.cpu_time
  , er.total_elapsed_time
  , er.reads
  , er.writes
  , er.logical_reads
  , er.granted_query_memory
  , es.HOST_NAME
  , es.login_name
  , es.program_name
FROM
	sys.dm_db_task_space_usage tu
	INNER JOIN sys.dm_exec_requests er
		ON tu.session_id = er.session_id
			AND tu.request_id = er.request_id
	INNER JOIN sys.dm_exec_sessions es
		ON tu.session_id = es.session_id
	CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE 1 = 1
	and (tu.internal_objects_alloc_page_count + tu.user_objects_alloc_page_count) > 0
	and tu.session_id != @@SPID
ORDER BY
	(tu.user_objects_alloc_page_count - tu.user_objects_dealloc_page_count)
		+ (tu.internal_objects_alloc_page_count - tu.internal_objects_dealloc_page_count) DESC