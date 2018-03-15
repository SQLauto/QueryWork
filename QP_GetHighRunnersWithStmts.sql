/*
	This query returns stats related to stored procedure execution.

	Results are not reliable at this time <20180126) RBH
	
	$Archive: /SQL/QueryWork/QP_GetHighRunnersWithStmts.sql $
	$Date: 16-02-12 16:43 $	$Revision: 2 $

	The query uses a CTE to capture the Top N procedures from sys.dm_exec_procedure_stats (ps) by a selected filter
		(e.g. Elapsed time, Logical Reads)
	ps.SQL_handle is used to join on sys.dm_exec_Query_stats to capture data for each query in the procedure.
	A single procedure may have more than one entry in Procedure_stats representing different execution plans (e.g. multiple .Plan Handles)
	but they will all have the same SQL_Handle so the query stats have to join on both values.

*/

Declare
	@debug			Int = 0
	, @NumProcs		Int = 10
	;

;With topProcs (DB, ProcType, ProcSchema, ProcName, ExecCnt, MinutesInCache, SecSinceLastExec
			, AvgLReads, MaxLReads, AvgDur_ms, MaxDur_ms, AvgCPU_ms, MaxCPU_ms
			, TotalCPU_ms, LastDur_ms, TotalDur_ms, AvgpReads, MaxpReads, TotlReads
			, TotpReads, TotWrkTime_ms, SQLHandle, PlanHandle
			)
	As(
	Select Top 10	--(@NumProcs)
		[DB] = Case when ps.database_id = 32767 then N'Resource' Else DB_name(ps.database_id) End
		, [ProcType] = ps.type
		, [ProcSchema] = object_schema_name(ps.object_id, ps.database_id)
		, [ProcName] = object_name(ps.object_id, ps.database_id)
		, [ExecCnt] = ps.execution_count
		, [MinutesInCache] = DateDiff(minute, ps.cached_time, GETDATE())
		, [SecSinceLastExec] = DateDiff(second, ps.last_execution_time, getDate())
		, [AvgLReads] = Case When ps.execution_count = 0 Then 0 Else ps.total_logical_reads / ps.execution_count End
		, [MaxLReads] = ps.max_logical_reads
		, [AvgDur_ms] = Case When ps.execution_count = 0 Then 0 Else ((ps.total_elapsed_time / 1000) / ps.execution_count)  End
		, [MaxDur_ms] = ps.max_elapsed_time / 1000
		, [AvgCPU_ms] = Case When ps.execution_count = 0 Then 0 Else ((ps.total_worker_time / 1000) / ps.execution_count) End
		, [MaxCPU_ms] = ps.max_worker_time / 1000
		, [TotalCPU_ms] =  ps.total_worker_time / 1000
		, [LastDur_ms] = ps.last_elapsed_time / 1000
		, [TotalDur_ms] = ps.total_elapsed_time / 1000
		, [AvgpReads] = Case When ps.execution_count = 0 Then 0 Else (ps.total_physical_reads / ps.execution_count) End
		, [MaxpReads] = ps.max_physical_reads
		, [TotlReads] = ps.total_logical_reads
		, [TotpReads] = ps.total_physical_reads
		, [TotWrkTime_ms] = ps.total_worker_time / 1000
		, [SQLHandle] = ps.sql_handle	-- use to access sys.dm_exec_query_stats to find stats for queries that are part of a procedure
		, [PlanHandle] = ps.plan_handle	-- use to access sys.dm_exec_cached_plans to get QueryPlan
	From sys.dm_exec_procedure_stats as ps
	Where
		1 = 1
		and ps.database_id != 32767
		--and (@TotElapsedTime = 0
		--	Or ps.total_elapsed_time > @TotElapsedTime
		--	)
	Order By
		[AvgLReads] desc,
		[MaxLReads] desc
	)
Select --Top 100
	[DBName] = tp.DB
	, [ProcName] = tp.ProcName
	, [ProcExecCnt] = tp.ExecCnt
	, [QryExecCnt] = qs.execution_count
	, [qs.query_hash] = qs.query_hash
	, [qs.query_plan_hash] = qs.query_plan_hash
	, [qs.plan_handle] = qs.plan_handle
	, [ProcTotLReads] = tp.TotlReads
	, [ProcTotDur(ms)]	= tp.TotalDur_ms
	, [MaxDur(ms)]	= tp.MaxDur_ms
	, [QryAvgLReads] = Case When qs.execution_count = 0 Then 0 Else qs.total_logical_reads / qs.execution_count End
	, [QryTotLReads] = qs.total_logical_reads
	, [StmtText] = Replace(Replace(Replace(
					SUBSTRING(ST.text
					, (QS.statement_start_offset/2) + 1
					, ((CASE statement_end_offset WHEN -1 THEN DATALENGTH(ST.text) ELSE QS.statement_end_offset END 
						- QS.statement_start_offset)/2) + 1)
						, NChar(9), N'<T>'), NChar(10), N'<CR>'), NChar(11), N'<LF>')
From
	topProcs as tp
	inner join sys.dm_exec_query_stats as qs
		on qs.sql_handle = tp.SQLHandle
		and qs.plan_handle = tp.PlanHandle
	CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST
Order By
	[ProcName]
	, qs.query_hash
	, [QryAvgLReads] Desc
	

/*

	, [Q_AvgLReads] = Case When qs.execution_count = 0 Then 0 Else qs.total_logical_reads / qs.execution_count End
	, [Q_MaxLReads] = qs.max_logical_reads
	, qs.execution_count
	, qs.statement_start_offset
	, qs.statement_end_offset
		--, qs.sql_handle


*/