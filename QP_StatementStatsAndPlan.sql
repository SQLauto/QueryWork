/*
	This will query for individual SQL Statements (including batch summary data) but not stored procedures.
	Looking for top runners, long runners, etc.
	The query takes awhile to run (several minutes)
	$Archive: /SQL/QueryWork/QP_StatementStatsAndPlan.sql $
	$Date: 15-11-25 16:22 $	$Revision: 3 $
*/
Declare
	@fltExecutionCount	Int	= 100	-- Lower limit
	, @DaysBack		Int = 3		-- Number of days to go back for search
	, @Now				Datetime = GetDate()
	, @WindowStart		Datetime
	, @WindowEnd		Datetime
	;
Set @WindowStart = DateAdd(day, -@DaysBack, @Now);
Set @WindowEnd = @Now;

Select Top 20
	[Hours In Cache] = DateDiff(Hour, qs.creation_time, getdate())
	, [Lst Exec] = qs.last_execution_time
	, [Total Exec] = qs.execution_count
	, [Exec/Hour] = Case When DateDiff(hh, qs.creation_time, GetDate()) = 0 Then qs.execution_count
					Else qs.execution_count / DateDiff(hour, qs.creation_time, GetDate())
					End
	, [Avg WorkT(ms)] = Cast((qs.total_worker_time / 1000.0) / qs.execution_count As Decimal(18, 2))
	, [Avg Dur(ms)] = Cast((qs.total_elapsed_time / 1000.0) / qs.execution_count As Decimal(18, 2))
	, [Avg LReads] = qs.total_logical_reads / qs.execution_count
	, [Avg PReads] = qs.total_physical_reads / qs.execution_count
	, [Avg RowCnt] = qs.total_rows / qs.execution_count
	, [Lst Dur(ms)] = qs.last_elapsed_time / 1000
	, [Lst LReads] = qs.last_logical_reads
	, [Lst PReads] = qs.last_physical_reads
	, [Lst RowCnt] = qs.last_rows
	, [Lst WorkT(ms)] = qs.last_worker_time / 1000
	, [Tot Dur(ms)] = qs.total_elapsed_time / 1000
	, [Tot LReads] = qs.total_logical_reads
	, [Tot PReads] = qs.total_physical_reads
	, [Tot RowCnt] = qs.total_rows
	, [Max WorkT(ms)] = qs.max_worker_time / 1000
	, [Max Dur(ms)] = qs.max_elapsed_time / 1000
	, [Max LReads] = qs.max_logical_reads
	, [Max PReads] = qs.max_physical_reads
	, [Max RowCnt] = qs.max_rows
	, [TSQL] = SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,
				((CASE statement_end_offset 
					WHEN -1 THEN DATALENGTH(ST.text)
					ELSE QS.statement_end_offset END 
				- QS.statement_start_offset)/2) + 1)
	, [Plan] = qp.query_plan
	, qs.plan_generation_num
	, qs.plan_handle
	, qs.query_hash
	, qs.query_plan_hash
From sys.dm_exec_query_stats as qs
	CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST
	Cross Apply sys.dm_exec_query_plan(qs.Plan_Handle) as QP
Where 1 = 1
	And qs.execution_count > @fltExecutionCount
	And qs.creation_time >= @WindowStart
	And qs.creation_time <= @WindowEnd
Order By
	-- [A LReads] Desc
	--[Exec Cnt] Desc
	[Exec/Hour] Desc

Return;

-- Adapted from BOL
SELECT TOP 5
	[Query Hash] = query_stats.query_hash
	, [Num] = count(*)
	, [Avg CPU Time(ms)] = SUM(query_stats.total_worker_time / 1000) / SUM(query_stats.execution_count)
	, [Avg LReads] = Sum(query_stats.total_logical_reads) / SUM(query_stats.execution_count)
	, [Max LReads] = Max(query_stats.total_logical_reads)
	, [Tot Exec Cnt] = Sum(query_stats.execution_count)
	, [Statement Text] =  MIN(query_stats.TSQL)
FROM 
    (SELECT
		QS.*
		, [TSQL] = SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,
				((CASE statement_end_offset 
					WHEN -1 THEN DATALENGTH(ST.text)
					ELSE QS.statement_end_offset END 
					- QS.statement_start_offset)/2) + 1)
     FROM sys.dm_exec_query_stats AS QS
		CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST
	) As query_stats
GROUP BY query_stats.query_hash
ORDER BY 
	[Avg CPU Time(ms)] DESC;
Return

-- This Query returns 

;With theQueries As(
	Select Top 100
		q.query_hash
		, [AvgElapsedtime] = q.total_elapsed_time / 1000
		, q.sql_handle
		, q.statement_end_offset
		, q.statement_start_offset
		, q.plan_handle
		, q.query_plan_hash
	From sys.dm_exec_query_stats AS q With (NoLock)
	Where
		q.execution_count = 1
	Order By
		[AvgElapsedtime] Desc
	)
	Select
		qs.total_physical_reads
		,qs.total_elapsed_time / 1000
		, [TSQL] = SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,
					((CASE statement_end_offset 
						WHEN -1 THEN DATALENGTH(ST.text)
						ELSE QS.statement_end_offset END 
						- QS.statement_start_offset)/2) + 1)
	From sys.dm_exec_query_stats AS qs
		CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as st
	Where
		--qs.query_hash = 0xBC3F2457E0958E3B
		qs.execution_count = 1



	