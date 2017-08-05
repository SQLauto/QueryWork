/*
	Script: open transactions with text and plans
	http://www.sqlskills.com/blogs/paul/script-open-transactions-with-text-and-plans/

	$Archive: /SQL/QueryWork/Tran_GetAllOpen.sql $
	$Revision: 1 $	$Date: 15-10-20 17:28 $
*/
Select
	[SessionId]		= s_tst.session_id
	, [LoginName]	= s_es.login_name
	, [Database]	= Db_Name(s_tdt.database_id)
	, [BeginTime]	= s_tdt.database_transaction_begin_time
	, [Durration]	= DateDiff(Millisecond, s_tdt.database_transaction_begin_time, GetDate())
	, [LogBytes]	= s_tdt.database_transaction_log_bytes_used
	, [LogRsvd]		= s_tdt.database_transaction_log_bytes_reserved
	, [LastQry]		= s_est.text
	, [LastQryPlan]	= s_eqp.query_plan
From	sys.dm_tran_database_transactions s_tdt
		Join sys.dm_tran_session_transactions s_tst
			On s_tst.transaction_id = s_tdt.transaction_id
		Join sys.dm_exec_sessions s_es
			On s_es.session_id = s_tst.session_id
		Join sys.dm_exec_connections s_ec
			On s_ec.session_id = s_tst.session_id
		Left Outer Join sys.dm_exec_requests s_er
			On s_er.session_id = s_tst.session_id
		Cross Apply sys.dm_exec_sql_text(s_ec.most_recent_sql_handle) As s_est
		Outer Apply sys.dm_exec_query_plan(s_er.plan_handle) As s_eqp
Order By [BeginTime] Asc;
Go
