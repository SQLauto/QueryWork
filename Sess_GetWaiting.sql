
/*
	Script to find waiting Sessions
*/


Select
	wt.session_id
	,wt.blocking_session_id
	,wt.wait_type
	,wt.wait_duration_ms
	,wt.resource_description
	,wt.resource_address
	--,wt.*
From Sys.dm_os_waiting_tasks as wt