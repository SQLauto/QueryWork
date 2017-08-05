Select
	'sessions'  = 0 -- Count(*)
	, es.host_name
	, es.host_process_id
	, es.program_name
	, 'database_name' = '' -- Db_Name(s.database_id)
	--, s.
	, ec.
From sys.dm_exec_sessions As es
	Inner Join sys.dm_exec_connections As ec
		On ec.session_id = es.session_id
Where es.is_user_process = 1
-- Group By es.host_name, es.host_process_id, es.program_name--, database_id
Order By --'sessions' Desc;
	es.host_name, es.host_process_id, es.program_name--, database_id