/*
	https://www.simple-talk.com/sql/database-administration/exploring-query-plans-in-sql/

	The schema of the QP XML is published at http://schemas.microsoft.com/sqlserver/2004/07/showplan
*/


Select
	qp.query_plan
	, qt.text
From sys.dm_exec_query_stats as qs With (NoLock)
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) as qt
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) as qp
