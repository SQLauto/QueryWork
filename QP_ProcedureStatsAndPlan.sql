/*

	BOL Documentation on sys.dm_exec_procedure_stats is incorrect.
	Check MSDN on line.  http://msdn.microsoft.com/en-us/library/cc280701(v=sql.105).aspx

	There should be a way to turn this into a good filter for finding procedures that need
	work.

	$Archive: /SQL/QueryWork/QP_ProcedureStatsAndPlan.sql $
	$Revision: 6 $	$Date: 18-02-16 15:51 $
*/
Declare
	@DbName					Nvarchar(128) = N'%'
	, @ProcName				NVarchar(128) = N'%'
	, @ProcSchema			NVarchar(128) = N'%'
	, @fltAvgLogicalReads	Int = 1000			-- Lower Limit 
	, @fltAvgPhysicalReads	Int = 1000			-- Lower Limit 
	, @fltAvgWorkerTime		Int = 100			-- Lower Limit Milliseconds
	, @fltAvgElapsedTime	Int = 100			-- Lower Limit Milliseconds

; With raw as (
	select
		[Database] =  case when ps.database_id = 32767 then 'Resource'
						else DB_NAME(ps.database_id)
						End
		, [ObjName] = case when ps.database_id = 32767 then 'Resource'
						else OBJECT_NAME(ps.object_id, ps.database_id)
						End
		, [ObjSchema] = Object_SCHEMA_NAME(ps.object_id, ps.database_id)
		--, [ObjId] = CAST(ps.database_id as VARCHAR(5)) + '-' + CAST(ps.object_id as VARCHAR(10))
		, [Type] = Case ps.type When 'P' Then 'SQL Proc' When 'PC' Then 'Clr Proc' When 'X' Then 'Ext Proc' Else 'Unk' End
		, [cached_time] = ps.cached_time
		, [last_execution_time] = ps.last_execution_time
		, [sql_handle] = ps.sql_handle
		, [plan_handle] = ps.plan_handle
		, [execution_count] = ps.execution_count
		, [AvgPhyReads] = Case when ps.execution_count = 0 then 0
							else CAST(CAST(ps.total_physical_reads as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
							end
		, [total_physical_reads] = ps.total_physical_reads
		, [max_physical_reads] = ps.max_physical_reads
		, [AvgLogicalReads] = Case When ps.Execution_count = 0 Then 0
						Else CAST(CAST(ps.total_logical_reads as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
						End
		, [total_logical_reads] = ps.total_logical_reads
		, [max_logical_reads] = ps.max_logical_reads
		, [max_worker_time] = Cast(ps.max_worker_time / 1000.0 as Decimal(20, 2))
		, [min_worker_time] = Cast(ps.min_worker_time / 1000.0 as Decimal(20, 2))
		, [last_worker_time] = Cast(ps.last_worker_time / 1000.0 as Decimal(20, 2))
		, [total_worker_time] = Cast(ps.[total_worker_time] / 1000.0 as Decimal(20, 2))
		, [AvgWorkerTime] = Case When ps.execution_count = 0 Then Cast (0 as Decimal(24, 0))
							Else CAST(CAST(ps.total_worker_time as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
							end / 1000.0
		, [AvgElapsedTime] =  Case when ps.execution_count = 0 then CAST(0 as DECIMAL(24,0))
							else CAST(CAST(ps.total_elapsed_time as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
							end / 1000.0
		, [max_elapsed_time] = Cast(ps.max_elapsed_time / 1000.0 as Decimal(20, 2))
		, [total_elapsed_time] = Cast(ps.total_elapsed_time / 1000.0 as Decimal(20, 2))
		--, [sql_handle] = ps.sql_handle
		--, [plan_handle] = ps.plan_handle
		--, ps.*
	From
		sys.dm_exec_procedure_stats as ps
	Where 1 = 1
	and (
		-- [Avg Logical Reads]
		Case When ps.Execution_count = 0 Then 0
						Else CAST(CAST(ps.total_logical_reads as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
						End
			> @fltAvgLogicalReads
		-- [Avg Phy Reads] 
		or Case when ps.execution_count = 0 then 0
							else CAST(CAST(ps.total_physical_reads as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
							end
			> @fltAvgPhysicalReads
		-- [Avg Worker Time] 
		or Case When ps.execution_count = 0 Then Cast (0 as Decimal(24, 0))
							Else CAST(CAST(ps.total_worker_time as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
							end / 1000.0
			> @fltAvgWorkerTime
		-- [Avg Elapsed Time(ms)]
		or Case when ps.execution_count = 0 then CAST(0 as DECIMAL(24,0))
							else CAST(CAST(ps.total_elapsed_time as FLOAT) / CAST(ps.execution_count as FLOAT) as DECIMAL(24,0))
							end / 1000.0
			> @fltAvgElapsedTime 
		)
	)
Select r.[Database]
  , r.ObjName
  , r.Type
  , [PlanHandle] = r.plan_handle
  , [Hours in Cache] = Cast(Cast(DateDiff(second, r.cached_time, getDate()) as Decimal(18, 4)) / 3600.0 as decimal(18,2))
  , [Last Exec Time] = r.last_execution_time
  , [Exec Count] = r.execution_count
  --, [AvgPhyReads] = Cast(r.AvgPhyReads as decimal(18,2))
  --, [Total Physical Reads] = r.total_physical_reads
  --, [Max Physical Reads] = r.max_physical_reads
  , [Avg Logical Reads] = r.AvgLogicalReads
  , [Total Logical Reads] = r.total_logical_reads
  , [Max Logical Reads] = r.max_logical_reads
  --, r.max_worker_time
  --, r.min_worker_time
  --, r.AvgWorkerTime
  --, r.last_worker_time
  --, r.total_worker_time
  , [Avg Elapsed Time (ms)] = Cast(r.AvgElapsedTime as decimal(18,2))
  , [Max Elapsed Time (ms)] = Cast(r.max_elapsed_time as decimal(18,2))
  , [Total Elapsed Time (ms)] = Cast(r.total_elapsed_time as decimal(18,2))
  , [Stmt] = st.text
  , [QryPlan] = qp.query_plan
  , [SQLHandle] = r.sql_handle
From raw as r
	CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) As st 
	CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) As qp 
Where 1 = 1
	and r.[Database] not in ('distribution', 'master', 'model', 'msdb', 'resource')
	and r.[Database] like @DBName
	and r.[ObjSchema] like @ProcSchema
	and r.ObjName like @ProcName
	-- This condition finds queries that have a Total time >> Average for several attributes
	--and(
	--	 r.max_logical_reads > 2 * r.AvgLogicalReads
	--	 or r.max_physical_reads > 2 * r.AvgPhyReads
	--	 or r.max_worker_time > 2 * r.AvgWorkerTime
	--	 or r.max_elapsed_time > 2 * r.AvgElapsedTime
	--	)
order by
	r.[Database]
	, r.ObjName
	, r.max_logical_reads Desc
	, r.execution_count Desc
	, r.AvgLogicalReads Desc
	, r.last_execution_time desc
	, r.cached_time desc