/*
	This is a collection of snippets to find IMPLICIT Conversions.  None of them is quite right for 
	Various reasons.
	$Archive: $
	$Revision: $	$Date: $

*/


/*

-- (c) https://blog.sqlauthority.com
https://blog.sqlauthority.com/2017/01/29/find-queries-implict-conversion-sql-server-interview-question-week-107/

*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

Select	Top (50)
		'Database Name'		= Db_Name (t.dbid)
	  , 'Query Text'		= t.text
	  , 'Total Worker Time' = qs.total_worker_time
	  , 'Avg Worker Time'	= qs.total_worker_time / qs.execution_count
	  , 'Max Worker Time'	= qs.max_worker_time
	  , 'Avg Elapsed Time'	= qs.total_elapsed_time / qs.execution_count
	  , 'Max Elapsed Time'	= qs.max_elapsed_time
	  , 'Avg Logical Reads' = qs.total_logical_reads / qs.execution_count
	  , 'Max Logical Reads' = qs.max_logical_reads
	  , 'Execution Count'	= qs.execution_count
	  , 'Creation Time'		= qs.creation_time
	  , 'Query Plan'		= qp.query_plan
From
	sys.dm_exec_query_stats As qs With (NoLock)
	Cross Apply sys.dm_exec_sql_text (plan_handle) As t
	Cross Apply sys.dm_exec_query_plan (plan_handle) As qp
Where
	Cast(query_plan As NVARCHAR(Max)) Like ('%CONVERT_IMPLICIT%')
	And	t.dbid = Db_Id ()
Order By qs.total_worker_time Desc
Option (Recompile);

/*

https://www.sqlskills.com/blogs/jonathan/finding-implicit-column-conversions-in-the-plan-cache/
Finding Implicit Column Conversions in the Plan Cache
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
Declare @dbname SYSNAME;
Set @dbname = QuoteName (Db_Name ());

With XmlNamespaces (Default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
Select
	'Statement' = stmt.value ('(@StatementText)[1]', 'varchar(max)')
	, 'pSchema' = object_Schema_name(qp.objectid, qp.dbid)
	, 'Proc' = object_name(qp.objectid, qp.dbid)
	, 'tSchema' = t.value ('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)')
	, 'Table' = t.value ('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)')
	, 'Column' = t.value ('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)')
	, 'ConvertFrom'		= ic.DATA_TYPE
	, 'ConvertFromLength' = ic.CHARACTER_MAXIMUM_LENGTH
	, 'ConvertTo'			= t.value ('(@DataType)[1]', 'varchar(128)')
	, 'ConvertToLength'	= t.value ('(@Length)[1]', 'int')
	, qp.query_plan
From
	sys.dm_exec_cached_plans						 As cp
	Cross Apply sys.dm_exec_query_plan (plan_handle) As qp
	Cross Apply query_plan.nodes ('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') As batch(stmt)
	Cross Apply stmt.nodes ('.//Convert[@Implicit="1"]') As n(t)
	Join INFORMATION_SCHEMA.COLUMNS As ic
		On QuoteName (ic.TABLE_SCHEMA) = t.value ('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]'
												   , 'varchar(128)')
		   And QuoteName (ic.TABLE_NAME) = t.value ('(ScalarOperator/Identifier/ColumnReference/@Table)[1]'
													 , 'varchar(128)')
		   And ic.COLUMN_NAME = t.value ('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)')
Where 1 = 1
	and t.exist ('ScalarOperator/Identifier/ColumnReference[@Database=sql:variable("@dbname")][@Schema!="[sys]"]') = 1
;


/*
	Query Fingerprints and Plan Fingerprints (The Best SQL 2008 Feature That You’ve Never Heard Of)
	https://blogs.msdn.microsoft.com/bartd/2008/09/03/query-fingerprints-and-plan-fingerprints-the-best-sql-2008-feature-that-youve-never-heard-of/
*/
Declare @Database	NVarchar(128) = N'ConSIRN'

Select Top 1000
		query_hash
	  , query_plan_hash
	  , sample_query_text.sample_database_name
	  , sample_query_text.sample_object_name
	  , plan_hash_stats.cached_plan_object_count
	  , plan_hash_stats.execution_count
	  , plan_hash_stats.total_cpu_time_ms
	  , plan_hash_stats.total_elapsed_time_ms
	  , plan_hash_stats.total_logical_reads
	  , plan_hash_stats.total_logical_writes
	  , plan_hash_stats.total_physical_reads
	  , sample_query_text.sample_statement_text
From
	(
		Select
			query_hash
		  , query_plan_hash
		  , [cached_plan_object_count] = Count (*)
		  , [sample_plan_handle]	 = Max (plan_handle)
		  , [execution_count]		 = Sum (execution_count)
		  , [total_cpu_time_ms]		 = Sum (total_worker_time) / 1000
		  , [total_elapsed_time_ms]	 = Sum (total_elapsed_time) / 1000
		  , [total_logical_reads]	 = Sum (total_logical_reads)
		  , [total_logical_writes]	 = Sum (total_logical_writes)
		  , [total_physical_reads]	 = Sum (total_physical_reads)
		From
			sys.dm_exec_query_stats
		Group By
			query_hash
		  , query_plan_hash
	) As plan_hash_stats
	Cross Apply
	(
		Select	Top 1
				sample_sql_handle			  = qs.sql_handle
			  , sample_statement_start_offset = qs.statement_start_offset
			  , sample_statement_end_offset	  = qs.statement_end_offset
			  , sample_database_name		  = Case
													When database_id.value = 32768 Then 'ResourceDb'
													Else Db_Name (Convert (INT, database_id.value))
												End
			  , sample_object_name			  = Object_Name (Convert (INT, object_id.value), Convert (INT, database_id.value))
			  , sample_statement_text		  = Substring (
															  sql.text
															, (qs.statement_start_offset / 2) + 1
															, ((Case qs.statement_end_offset
																	When -1 Then DataLength (sql.text)
																	When 0 Then DataLength (sql.text)
																	Else qs.statement_end_offset
																End - qs.statement_start_offset
															   ) / 2
															  ) + 1
														  )
		From
			sys.dm_exec_sql_text (plan_hash_stats.sample_plan_handle)					 As sql
			Inner Join sys.dm_exec_query_stats											 As qs
				On qs.plan_handle = plan_hash_stats.sample_plan_handle
			Cross Apply sys.dm_exec_plan_attributes (plan_hash_stats.sample_plan_handle) As object_id
			Cross Apply sys.dm_exec_plan_attributes (plan_hash_stats.sample_plan_handle) As database_id
		Where
			object_id.attribute = 'objectid'
			And database_id.attribute = 'dbid'
	) As sample_query_text
Where sample_query_text.sample_database_name = @Database  
Order By	
	 sample_query_text.sample_database_name
	, sample_query_text.sample_object_name
	, plan_hash_stats.total_cpu_time_ms Desc;



