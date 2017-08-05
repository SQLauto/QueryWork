
/*
	Querying Information from the Plan Cache, Simplified
	http://www.scarydba.com/2012/07/02/querying-data-from-the-plan-cache/
*/

With XmlNamespaces(Default N'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),  QueryPlans 
As  ( 
Select  RelOp.pln.value(N'@StatementOptmEarlyAbortReason', N'varchar(50)') As TerminationReason, 
        RelOp.pln.value(N'@StatementOptmLevel', N'varchar(50)') As OptimizationLevel, 
        --dest.text, 
        Substring(dest.text, (deqs.statement_start_offset / 2) + 1, 
                  (deqs.statement_end_offset - deqs.statement_start_offset) 
                  / 2 + 1) As StatementText, 
        deqp.query_plan, 
        deqp.dbid, 
        deqs.execution_count, 
        deqs.total_elapsed_time, 
        deqs.total_logical_reads, 
        deqs.total_logical_writes 
From    sys.dm_exec_query_stats As deqs 
        Cross Apply sys.dm_exec_sql_text(deqs.sql_handle) As dest 
        Cross Apply sys.dm_exec_query_plan(deqs.plan_handle) As deqp 
        Cross Apply deqp.query_plan.nodes(N'//StmtSimple') RelOp (pln) 
Where   deqs.statement_end_offset > -1        
)   
Select  Db_Name(qp.dbid), 
        * 
From    QueryPlans As qp 
Where   qp.TerminationReason = 'Timeout'
Order By qp.execution_count Desc;

Return;


Select	Db_Name(detqp.dbid)
	  , Substring(dest.text, (deqs.statement_start_offset / 2) + 1,
				  (Case deqs.statement_end_offset
					 When -1 Then DataLength(dest.text)
					 Else deqs.statement_end_offset
				   End - deqs.statement_start_offset) / 2 + 1) As StatementText
	  , Cast(detqp.query_plan As Xml)
	  , deqs.execution_count
	  , deqs.total_elapsed_time
	  , deqs.total_logical_reads
	  , deqs.total_logical_writes
From sys.dm_exec_query_stats As deqs
	Cross Apply sys.dm_exec_text_query_plan(deqs.plan_handle, deqs.statement_start_offset, deqs.statement_end_offset) As detqp
	Cross Apply sys.dm_exec_sql_text(deqs.sql_handle) As dest
Where detqp.query_plan Like '%StatementOptmEarlyAbortReason="TimeOut"%';
