/*
	SQL Server High CPU Find Query
	http://www.sqlservercentral.com/scripts/Performance/166763/?utm_source=SSC&utm_medium=pubemail
	$Archive: /SQL/QueryWork/Qry_Get_TopDurationCounts.sql $
	$Revision: 1 $	$Date: 18-01-06 17:32 $

	This query returns query text and stats for the top queries for a specific database based on various attributes.

	What does it mean that there are multiple qs.query_plan_hash rows per ?
	Is it valid to aggregate them by qs.plan_handle?

*/
Declare @DbName NVarchar(50) =  N'Wilco'
	, @debug	Int	= 0
	, @Cr		NChar(1) = NChar(13)
	, @Lf		NChar(1) = NChar(10)
	, @Tab		NChar(1) = NChar(9)
	, @Cr_Rep	NChar(4) = N' <R '
	, @Lf_Rep	NChar(4) = N' <L '
	, @Tab_Rep	NChar(4) = N' ->'
	;

Select Top 200
	[Database] = Db_Name (db.DatabaseID)
	, [Total Worker Sec] = Sum( Convert (NUMERIC(10, 2), Convert (NUMERIC, (total_worker_time)) / 1000000))
	, [Exec Cnt] = Sum(qs.execution_count)
	, [Avg Worker Sec] = Cast(Avg(Convert (NUMERIC(10, 2), (Convert (NUMERIC, (total_worker_time)) / qs.execution_count) / 1000000)) as Decimal(20, 3))
	, [Min Worker Sec]  = Min(Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.min_worker_time)) / 1000000))
	, [Max Worker Sec] = Max(Convert (NUMERIC(20, 5), Convert (NUMERIC(20, 5), (qs.max_worker_time)) / 1000000))
	, [Max Duration(sec)]  = Max(Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.max_elapsed_time)) / 1000000))
	, [Last Run Time] = Max(qs.last_execution_time)
	, [Last pReads] = Max(qs.last_physical_reads)
	, [Last Worker Sec] = Max(Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.last_worker_time)) / 1000000))
	, [Last Duration(sec)] = Max(Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.last_elapsed_time)) / 1000000))
	, [Query]  = Replace(Replace(Replace(q.text,  @Cr,  @Cr_Rep), @Lf, @Lf_Rep), @Tab, @Tab_Rep)
	, [QP Handle] = qs.plan_handle
	, [QP Hash Cnt] = Count(qs.query_plan_hash)
	--, [Qry Hash #] = ROW_NUMBER() Over (partition by qs.plan_handle order by qs.plan_handle)
From
	sys.dm_exec_query_stats As qs
	Cross Apply(Select DatabaseID = Convert (INT, value)
				From sys.dm_exec_plan_attributes (qs.plan_handle)
				Where attribute = N'dbid'
				) As db
	Cross Apply sys.dm_exec_sql_text (plan_handle) As q
Where Db_Name (db.DatabaseID) = @DbName
Group By
	DB_NAME(db.DatabaseId)
	, q.text
	, qs.plan_handle
	, qs.last_physical_reads
	, Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.last_worker_time)) / 1000000)
	, Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.last_elapsed_time)) / 1000000)
Order By
	[Avg Worker Sec] Desc
	-- [Exec Cnt] Desc
	-- [QP Handle]
	;
Return;

/*
	This is approximately the original query which can return multiple rows per Query Plan.
*/
Select Top 200
	[DatabaseName]	  = Db_Name (db.DatabaseID)
	, [CPU_Time_sn]		  = Convert (NUMERIC(10, 2), Convert (NUMERIC, (total_worker_time)) / 1000000)
	, qs.execution_count
	, [AVG_Time]		  = Convert (NUMERIC(10, 2), (Convert (NUMERIC, (total_worker_time)) / qs.execution_count) / 1000000)
	, [last_worker_time]  = Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.last_worker_time)) / 1000000)
	, [min_worker_time]	  = Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.min_worker_time)) / 1000000)
	, [max_worker_time]	  = Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.max_worker_time)) / 1000000)
	, [last_elapsed_time] = Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.last_elapsed_time)) / 1000000)
	, [max_elapsed_time] = Convert (NUMERIC(10, 2), Convert (NUMERIC, (qs.max_elapsed_time)) / 1000000)
	, qs.last_physical_reads
	, qs.last_execution_time
	, [Query]  = Replace(Replace(Replace(q.text,  @Cr,  @Cr_Rep), @Lf, @Lf_Rep), @Tab, @Tab_Rep)
	, [QP Handle] = qs.plan_handle
	, [QP Hash] = qs.query_plan_hash
From
	sys.dm_exec_query_stats As qs
	Cross Apply (Select DatabaseID = Convert (INT, value)
				From sys.dm_exec_plan_attributes (qs.plan_handle)
				Where attribute = N'dbid') As db
	Cross Apply sys.dm_exec_sql_text (plan_handle) As q
Where Db_Name (db.DatabaseId) = @DbName
Order By AVG_Time Desc;