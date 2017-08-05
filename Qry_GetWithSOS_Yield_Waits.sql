

/*
	Paul Randal
	Identifying queries with SOS_SCHEDULER_YIELD waits
	http://www.sqlskills.com/blogs/paul/identifying-queries-with-sos_scheduler_yield-waits/
	$Archive: /SQL/QueryWork/Qry_GetWithSOS_Yield_Waits.sql $
	$Revision: 1 $	$Date: 16-02-12 16:42 $
*/
Select er.session_id
	, es.program_name
	, est.text
	, er.database_id
	, eqp.query_plan
	, er.cpu_time
From sys.dm_exec_requests As er
	Inner Join sys.dm_exec_sessions As es
		On es.session_id = er.session_id
	OUTER APPLY sys.dm_exec_sql_text (er.sql_handle) As est
	OUTER APPLY sys.dm_exec_query_plan (er.plan_handle) As eqp
Where es.is_user_process = 1
		And er.last_wait_type = N'SOS_SCHEDULER_YIELD'
Order By er.session_id;



Return;
Select	*
From	sys.dm_os_wait_stats As ws;


--Select name From msdb.dbo.sysjobs Where job_id = 0xE102123ABC644045B2ED555A3B94200F

--SQLAgent - TSQL JobStep (Job 0xE102123ABC644045B2ED555A3B94200F : Step 6) -- CLV_LevelA Generate Fuelsale