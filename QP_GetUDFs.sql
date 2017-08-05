/*
	How to find UDFs causing SQL Server performance issues
	https://www.mssqltips.com/sqlservertip/4100/how-to-find-udfs-causing-sql-server-performance-issues/
	Fikrat Azizov - gives a couple of methods to find UDF's.  This script is one that works on 2005 + and seems
	to be the simplest to use.
	$Archive: /SQL/QueryWork/QP_GetUDFs.sql $
	$Revision: 2 $	$Date: 16-04-16 10:46 $

*/


Select Top 100
	[database] = Db_Name()
	, o.name
	, [TotalWorkerTime] =  qs.total_worker_time / 1000000
	, [TotalElapsedTime_Sec] = qs.total_elapsed_time / 1000000
	, [avg_elapsed_time_Sec] = qs.total_elapsed_time / (1000000 * qs.execution_count)
	, qs.execution_count
	, [Avg_logical_reads] = qs.total_logical_reads / qs.execution_count
	, qs.max_logical_writes
	, [ParentQueryText] = st.text
	, [Query Text] = Substring(st.text, qs.statement_start_offset / 2 + 1
					 , (Case When qs.statement_end_offset = -1 Then Len(Convert(NVarchar(Max), st.text)) * 2
							Else qs.statement_end_offset
					   End - qs.statement_start_offset) / 2)
	, qp.query_plan
	, o.type_desc
From sys.dm_exec_query_stats qs
	Cross Apply sys.dm_exec_sql_text(qs.sql_handle) As st
	Cross Apply sys.dm_exec_query_plan(qs.plan_handle) qp
	Left Join sys.objects o
		On o.object_id = st.objectid
Where 1 = 1
	-- And O.type_desc Like '%Function%'
	 And ( 1 = 0
		Or o.type = 'FN'	-- Scalar function
		Or o.type = 'TF'	-- Table Value Function
		Or o.type = 'IF'	-- Inline Function
		)
Order By qs.total_worker_time Desc;

Return;

/*


How to find UDFs causing SQL Server performance issues
https://www.mssqltips.com/sqlservertip/4100/how-to-find-udfs-causing-sql-server-performance-issues/
Fikrat Azizov
This is from a revised version of the same posting.
*/


Use ConSIRN; 
Begin

Select Top 100
	[Database] = Db_Name()
	, [Total_Worker_Time] = QS.total_worker_time / 1000000
	, [Total_Elapsed_Time_Sec] = QS.total_elapsed_time / 1000000
	, [Avg_Elapsed_Time_Sec] = QS.total_elapsed_time / (1000000 * QS.execution_count)
	, [Exec Cnt] = QS.execution_count
	, [Avg Logical Reads] = QS.total_logical_reads / QS.execution_count
	, [Max Logical Writes] = QS.max_logical_writes
	, [ParentQueryText] = ST.text
	, [Query Text] = Substring(ST.text, QS.statement_start_offset / 2 + 1, (Case When QS.statement_end_offset = -1 Then Len(Convert(NVarchar(Max), ST.text)) * 2
				Else QS.statement_end_offset
				End - QS.statement_start_offset) / 2)
	, [QP] = QP.query_plan
	, [oType] = O.type_desc
From sys.dm_exec_query_stats QS
	Cross Apply sys.dm_exec_sql_text(QS.sql_handle) As ST
	Cross Apply sys.dm_exec_query_plan(QS.plan_handle) QP
	Left Join sys.objects O
		On O.object_id = ST.objectid
Where O.type_desc Like '%Function%'
Order By QS.total_worker_time Desc;
End;