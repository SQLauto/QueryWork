/*
	This query returns stats related to stored procedure execution.
	
	$Archive: /SQL/QueryWork/QP_GetHighRunnersWithStmts.sql $
	$Date: 16-02-12 16:43 $	$Revision: 2 $
*/

Declare
	@TotElapsedTime	Integer = 1000 
	;

;With topProcs (DB, ProcType, ProcSchema, ProcName
			, ExecCnt, SecSinceLastExec, AvgLReads, MaxLReads
			, AvgDurMs, MaxDurMs, AvgCPUMs, MaxCPUMs
			, SQLHandle, PlanHandle 
			)
	As(
	Select Top 100
		[DB] = Case when ps.database_id = 32767 then N'Resource' Else DB_name(ps.database_id) End
		, [ProcType] = ps.type
		, [ProcSchema] = object_schema_name(ps.object_id, ps.database_id)
		, [ProcName] = object_name(ps.object_id, ps.database_id)
		, [ExecCnt] = ps.execution_count
		, [SecSinceLastExec] = DateDiff(ss, ps.last_execution_time, getDate())
		, [AvgLReads] = Case When ps.execution_count = 0 Then 0 Else ps.total_logical_reads / ps.execution_count End
		, [MaxLReads] = ps.max_logical_reads
		, [AvgDur] = Case When ps.execution_count = 0 Then 0 Else (ps.total_elapsed_time / ps.execution_count) / 1000 End
		, [MaxDur] = ps.max_elapsed_time / 1000
		, [AvgCPUTime] = Case When ps.execution_count = 0 Then 0 Else (ps.total_worker_time / ps.execution_count) / 1000 End
		, [MaxCPUTime] = ps.max_worker_time / 1000
		--, [LastDur] = Cast(ps.last_elapsed_time / (1000.0 * 1000.0) as Decimal(24, 3))
		--, [TotalCPU] =  Cast(ps.total_worker_time / (1000.0 * 1000.0) as Decimal(24, 3))
		--, [TotalDur)] = Cast(ps.total_elapsed_time / (1000.0 * 1000.0) as Decimal(24, 3))
		--, [AvgPReads] = CAST( Case When ps.execution_count = 0 Then 0 Else Cast(ps.total_physical_reads as Decimal(24, 3)) / ps.execution_count End as Decimal(24, 1))
		--, ps.max_physical_reads
		--, ps.total_logical_reads
		--, ps.total_physical_reads
		--, ps.total_worker_time
		--, [MinutesInCache] = DateDiff(mi, ps.cached_time, GETDATE())
		, ps.sql_handle	-- use to access sys.dm_exec_query_stats to find stats for queries that are part of a procedure
		, ps.plan_handle	-- use to access sys.dm_exec_cached_plans to get QueryPlan
	From sys.dm_exec_procedure_stats as ps
	Where
		1 = 1
		and ps.database_id != 32767
		and (@TotElapsedTime = 0
			Or ps.total_elapsed_time > @TotElapsedTime
			)
	Order By
		[AvgLReads] desc,
		[MaxLReads] desc
	)
Select --Top 100
	tp.DB
	, tp.ProcName
	, [ProcExecCnt] = tp.ExecCnt
	, [ProcAvgLReads] = tp.AvgLReads
	, [StmtExecCnt] = qs.execution_count
	, [AvgDur(ms)]	= tp.AvgDurMs
	, [MaxDur(ms)]	= tp.MaxDurMs
	, [AvgCPU(ms)]	= tp.AvgCPUMs
	, [MaxCPU(ms)]	= tp.MaxCPUMs
	, [QueryAvgLReads] = Case When qs.execution_count = 0 Then 0 Else qs.total_logical_reads / qs.execution_count End
	, [StmtText] = SUBSTRING(ST.text
					, (QS.statement_start_offset/2) + 1
					, ((CASE statement_end_offset WHEN -1 THEN DATALENGTH(ST.text) ELSE QS.statement_end_offset END 
						- QS.statement_start_offset)/2) + 1)
From
	topProcs as tp
	inner join sys.dm_exec_query_stats as qs
		on qs.sql_handle = tp.SQLHandle
	CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST
Order By
	[AvgDur(ms)] Desc,
	tp.ProcName
	,[QueryAvgLReads] Desc
	

/*

	, [Q_AvgLReads] = Case When qs.execution_count = 0 Then 0 Else qs.total_logical_reads / qs.execution_count End
	, [Q_MaxLReads] = qs.max_logical_reads
	, qs.execution_count
	, qs.statement_start_offset
	, qs.statement_end_offset
		--, qs.sql_handle


*/
