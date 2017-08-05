/*
	This script returns various runtime statistics for a specified procedure and the queries
	that are executed by the procedure.
	$Archive: /SQL/QueryWork/QP_Batch_QueryStats.sql $
	$Date: 15-08-21 14:25 $	$Revision: 2 $
	
	This query provides an execution "profile" of a Batch based on the provided PlanHandle or SQLHandle.
	The first select returns aggregate data for the batch from 
	The second select returns aggregate data for the queries from dm_exec_query_stats.
	
	This data helps determine where a procedure actually consume resources whether worker time,
	elapsed time, or logical I/O which identifies the areas that are worth investing time to 
	refactor.
	
	This is a second stage tool.  You should already know which procedure you are interested in improving.
*/
--Use Master;
Declare
	@Database			Varchar(50)
	;

If db_id(@Database) Is Null Set @Database = Db_Name();

Select
	[Run Cnt]					= qs.execution_count
	, [Last Run]				= qs.last_execution_time
	, [Cached Time]				= qs.creation_time
	, [Time In Cache (Hr)]		= Case When qs.creation_time < DateAdd(dd, -60, GetDate()) Then Cast(999999.999 As Decimal(14,3))
									Else Cast(DateDiff(ss, qs.creation_time, GetDate()) / 3600.0 As Decimal(14,3))
									End
	, [Tot Worker Time (ms)]	= qs.total_worker_time / 1000
	, [Max Worker Time (ms)]	= qs.max_worker_time / 1000
	, [Min Worker Time (ms)]	= qs.min_worker_time / 1000
	, [Avg Worker Time (ms)]	= Case When qs.execution_count = 0 Then 0
							Else (qs.total_worker_time / 1000) / qs.execution_count
							End
	, [Tot Elapsed Time (ms)]	= qs.total_elapsed_time / 1000
	, [Max Elapsed Time (ms)]	= qs.max_elapsed_time / 1000
	, [Min Elapsed Time (ms)]	= qs.min_elapsed_time / 1000
	, [Avg Elapsed Time (ms)]	= Case When qs.execution_count = 0 Then 0
							Else (qs.total_elapsed_time / 1000) / qs.execution_count
							End
	, [Tot Logical Read]		= qs.total_logical_reads
	, [Max Logical Read]		= qs.max_logical_reads
	, [Min Logical Read]		= qs.min_logical_reads
	, [Avg Logical Read]		= Case When qs.execution_count = 0 Then 0
							Else (qs.total_logical_reads) / qs.execution_count
							End
	, [Tot Rows]				= qs.total_rows
	, [Max Rows]				= qs.max_rows
	, [Min Rows]				= qs.min_rows
	, [Avg Rows]				= Case When qs.execution_count = 0 Then 0
							Else (qs.total_rows) / qs.execution_count
							End
	, [Query Text] = Substring(Substring(qt.text,qs.statement_start_offset/2 + 1, 
                 (CASE WHEN qs.statement_end_offset = -1 
                       THEN LEN(CONVERT(nvarchar(max), qt.text)) * 2 
                       ELSE qs.statement_end_offset end -
                            qs.statement_start_offset
                 )/2
             ), 1, 256)
    , [QryPlan] = Cast(Null	As Xml)-- qp.query_plan
From
	sys.dm_exec_query_stats As qs
	Cross Apply sys.dm_exec_sql_text(qs.sql_handle) As qt
	--Cross Apply sys.dm_exec_query_plan(qs.plan_handle) As qp
Where 1 = 1
Order By
	[Run Cnt] Desc
	-- [Avg Logical Read] Desc
	-- [Avg Worker Time (ms)]

Return;

	
	
Select  * 
From sys.dm_exec_cached_plans As decp
	Cross Apply sys.dm_exec_query_plan(decp.plan_handle)
Where 1 = 1
	And decp.objtype = 'Adhoc'
	And decp.refcounts > 2
	And decp.size_in_bytes > 200

