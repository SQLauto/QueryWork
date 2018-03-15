/*
	This script returns various runtime statistics for a specified procedure and the queries
	that are executed by the procedure.
	$Archive: /SQL/QueryWork/QP_Proc_QueryStats.sql $
	$Date: 17-02-10 10:04 $	$Revision: 10 $
	
	This query provides an execution "profile" of a stored procedure.
	The first select returns aggregate data for the procdure from dm_exec_procedure_stats
	The second select returns aggregate data for the queries from dm_exec_query_stats.
	
	This data helps determine where a procedure actually consume resources whether worker time,
	elapsed time, or logical I/O which identifies the areas that are worth investing time to 
	refactor.
	
	This is a second stage tool.  You should already know which procedure you are interested in improving.

	********************************************
	I think this is not quite right.  A procedure may be in the cache more than one time.
		Need to be sure this is handling that correctly.
	Currently ordering on the ckecksum of the Plan Handle as a hash to get the queries associated with a plan
	altogether.

	Finding the worst running query in a stored procedure
	http://www.sqlservercentral.com/blogs/sqlstudies/2015/09/10/finding-the-worst-running-query-in-a-stored-procedure/
	Kenneth provided a key piece for getting the Query Plan for each individual query in the procedure rather than the single 
	monstrosity of the entire procedure.
	********************************************
*/
If Object_id('tempdb..#Plans', 'U') is not null
	Drop Table #Plans;
Go
Set NoCount On;
Set TRANSACTION ISOLATION Level READ Uncommitted;
/*

exec GetLastRawSalesReadingVBApp
exec dbo.GetCustomFormatName

*/
Use Master;
Declare
	@Database			Varchar(50) = 'ClvRawData'
	, @Schema			Varchar(50) = 'dbo'
	, @ProcName			Varchar(128) = 'GetRawPumpGrade'
	, @Blank			NChar(1) = NChar(32)
	, @CR				NChar(1) = NChar(13)
	, @LF				NChar(1) = NChar(10)
	, @strNow			Varchar(24) = ''
	, @ObjectString		Varchar(256)
	, @Pipe				NChar(1) = NChar(Ascii('|'))
	, @ProcPlanHandle	Varbinary(64)
	, @ProcSQLHandle	Varbinary(64)
	, @RowCount			Integer
	, @Tab				NChar(1) = NChar(9)
	;
Create Table #Plans (PlanHandle Varbinary(64));

If Db_Id(@Database) Is Null Set @Database = Db_Name();
If Len(@schema) = 0 Set @Schema = 'dbo';
If Len(@ProcName) = 0
Begin
	Raiserror('Procedure Name must be specified.', 0, 0) With Nowait;
	Return;
End;
Set @ObjectString = @Database + '.' + @Schema + '.' + @ProcName;
If object_schema_name(Object_Id(@ObjectString, 'P'), Db_Id(@Database)) Is Null
Begin
	Raiserror('Procedure %s.%s.%s does not exist.', 0, 0, @Database, @Schema, @ProcName) With Nowait;
	Return;
End;
Set @strNow = Convert(varchar(24), GetDate(), 120);
Insert #Plans(PlanHandle)
	Select ps.plan_handle
	From
		sys.dm_exec_procedure_stats As ps
	Where 1 = 1
		And ps.database_id = Db_Id(@Database)
		And ps.object_id = Object_Id(@ObjectString, 'P')
	Union All
	Select ps.sql_handle
	From
		sys.dm_exec_procedure_stats As ps
	Where 1 = 1
		And ps.database_id = Db_Id(@Database)
		And ps.object_id = Object_Id(@ObjectString, 'P')
	;

Set @RowCount = @@RowCount
If @RowCount <= 0
Begin
	RaisError('Procedure %s.%s.%s not found in procedure cache', 0, 0, @Database, @Schema, @ProcName);
	Return;
End;
Raiserror('#Plans built. %d rows found', 0, 0, @RowCount) With NoWait;
Select
	[Plan Handle Hash]			= CHECKSUM(ps.plan_handle)
	, [Run Cnt]					= ps.execution_count
	, [Last Run]				= ps.last_execution_time
	--, [Cached Time]				= ps.cached_time
	, [Time In Cache (Hr)]		= Case When ps.cached_time < DateAdd(dd, -60, GetDate()) Then Cast(999999.999 As Decimal(14,3))
									Else Cast(DateDiff(ss, ps.cached_time, GetDate()) / 3600.0 As Decimal(14,3))
									End
	, [Max Worker Time (ms)]	= ps.max_worker_time / 1000
	, [Avg Worker Time (ms)]	= Case When ps.execution_count = 0 Then 0
							Else (ps.total_worker_time / 1000) / ps.execution_count
							End
	, [Max Elapsed Time (ms)]	= ps.max_elapsed_time / 1000
	, [Avg Elapsed Time (ms)]	= Case When ps.execution_count = 0 Then 0
							Else (ps.total_elapsed_time / 1000) / ps.execution_count
							End
	, [Max Logical Read]		= ps.max_logical_reads
	, [Avg Logical Read]		= Case When ps.execution_count = 0 Then 0
							Else (ps.total_logical_reads) / ps.execution_count
							End							
	, [Max Physical Read]		= ps.max_Physical_reads
	, [Avg Physical Read]		= Case When ps.execution_count = 0 Then 0
							Else (ps.total_Physical_reads) / ps.execution_count
							End
	, [Max Rows]				= Cast(Null As BigInt)
	, [Avg Rows]				= Cast(Null As BigInt)
	, [Query Text]				= Cast(N'Starting execution data for Procedure = ' + @Schema + N'.' + @ProcName As NVarchar(256))
    , [QryPlan]					= Coalesce(qp.query_plan, N'Not Available')

	--, [Tot Worker Time (ms)]	= ps.total_worker_time / 1000
	--, [Min Worker Time (ms)]	= ps.min_worker_time / 1000
	--, [Tot Elapsed Time (ms)]	= ps.total_elapsed_time / 1000
	--, [Min Elapsed Time (ms)]	= ps.min_elapsed_time / 1000
	--, [Tot Logical Read]		= ps.total_logical_reads
	--, [Min Logical Read]		= ps.min_logical_reads
	--, [Tot Physical Read]		= ps.total_Physical_reads
	--, [Min Physical Read]		= ps.min_Physical_reads
	--, [Tot Rows]				= Cast(Null As BigInt)
	--, [Min Rows]				= Cast(Null As BigInt)
	, [Qry Start]				= 0
From
	sys.dm_exec_procedure_stats As ps
	inner join #plans as p
		on p.PlanHandle = ps.plan_handle
	Cross Apply sys.dm_exec_query_plan(ps.plan_handle) As qp	
Where 1 = 1
--/*
Union All
Select
	[Plan Handle Hash]			= CHECKSUM(qs.plan_handle)
	, [Run Cnt]					= qs.execution_count
	, [Last Run]				= qs.last_execution_time
	--, [Cached Time]				= qs.creation_time
	, [Time In Cache (Hr)]		= Case When qs.creation_time < DateAdd(dd, -60, GetDate()) Then Cast(999999.999 As Decimal(14,3))
									Else Cast(DateDiff(ss, qs.creation_time, GetDate()) / 3600.0 As Decimal(14,3))
									End
	, [Max Worker Time (ms)]	= qs.max_worker_time / 1000
	, [Avg Worker Time (ms)]	= Case When qs.execution_count = 0 Then 0
							Else (qs.total_worker_time / 1000) / qs.execution_count
							End
	, [Max Elapsed Time (ms)]	= qs.max_elapsed_time / 1000
	, [Avg Elapsed Time (ms)]	= Case When qs.execution_count = 0 Then 0
							Else (qs.total_elapsed_time / 1000) / qs.execution_count
							End
	, [Max Logical Read]		= qs.max_logical_reads
	, [Avg Logical Read]		= Case When qs.execution_count = 0 Then 0
							Else (qs.total_logical_reads) / qs.execution_count
							End
	, [Max Physical Read]		= qs.max_Physical_reads
	, [Avg Physical Read]		= Case When qs.execution_count = 0 Then 0
							Else (qs.total_Physical_reads) / qs.execution_count
							End
	, [Max Rows]				= qs.max_rows
	, [Avg Rows]				= Case When qs.execution_count = 0 Then 0
							Else (qs.total_rows) / qs.execution_count
							End
	, [Query Text] = Replace(Replace(Replace(Cast(Substring(Substring(qt.text,qs.statement_start_offset/2 + 1, 
                 (CASE WHEN qs.statement_end_offset = -1 
                       THEN LEN(CONVERT(nvarchar(max), qt.text)) * 2 
                       ELSE qs.statement_end_offset end -
                            qs.statement_start_offset
                 )/2), 1, 256) As Varchar(256))
				 , @LF, ' '), @CR, ' '), @Tab, ' ')
    , [QryPlan] = Cast(qp.query_plan As Xml)-- qp.query_plan

	--, [Tot Worker Time (ms)]	= qs.total_worker_time / 1000
	--, [Min Worker Time (ms)]	= qs.min_worker_time / 1000
	--, [Tot Elapsed Time (ms)]	= qs.total_elapsed_time / 1000
	--, [Min Elapsed Time (ms)]	= qs.min_elapsed_time / 1000
	--, [Tot Logical Read]		= qs.total_logical_reads
	--, [Min Logical Read]		= qs.min_logical_reads
	--, [Tot Physical Read]		= qs.total_Physical_reads
	--, [Min Physical Read]		= qs.min_Physical_reads
	--, [Tot Rows]				= qs.total_rows
	--, [Min Rows]				= qs.min_rows
	, [Qry Start]				= qs.statement_start_offset
From
	sys.dm_exec_query_stats As qs
	inner join #Plans as p
		on p.PlanHandle = qs.plan_handle
	Cross Apply sys.dm_exec_sql_text(qs.sql_handle) As qt
	Cross Apply sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) As qp
Where 1 = 1

Order By
	[Plan Handle Hash]
	, [Qry Start]
;
--*/

Set TRANSACTION ISOLATION Level READ Committed;