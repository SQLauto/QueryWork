
/*
	Main Reference is Jonathan Kehayias Rambling DBA Blog.
	Digging into the SQL Plan Cache: Finding Missing Indexes
		 - http://sqlblog.com/blogs/jonathan_kehayias/archive/2009/07/27/digging-into-the-sql-plan-cache-finding-missing-indexes.aspx

	Additional references.
	Schema for Showplan Schema
		- http://schemas.microsoft.com/sqlserver/2004/07/showplan/
	Get all SQL Statements with missing indexes and their cached query plans
		- http://gallery.technet.microsoft.com/scriptcenter/Get-all-SQL-Statements-9af68abc

	$Workfile: Query_GetPlanWithMissingIndexes.sql $
	$Archive: /SQL/QueryWork/Query_GetPlanWithMissingIndexes.sql $
	$Revision: 3 $	$Date: 14-05-02 16:11 $
*/
If object_id('tempdb..#MissingIndexInfo ', 'U') is not null
	DROP TABLE #MissingIndexInfo 
Go


;WITH XMLNAMESPACES  
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
    
SELECT
	[TableName] = n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)') + '.'
		+ n.value('(//MissingIndex/@Schema)[1]', 'VARCHAR(128)') + '.'
		+ n.value('(//MissingIndex/@Table)[1]', 'VARCHAR(128)')
	, [impact] = n.value('(//MissingIndexGroup/@Impact)[1]', 'FLOAT')
	, [database_id] = DB_ID(REPLACE(REPLACE(n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)'),'[',''),']','')) 
	, [OBJECT_ID] = OBJECT_ID(n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)') + '.' 
		+ n.value('(//MissingIndex/@Schema)[1]', 'VARCHAR(128)') + '.' 
		+ n.value('(//MissingIndex/@Table)[1]', 'VARCHAR(128)')) 
	, [equality_columns] = (SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', ' 
			FROM n.nodes('//ColumnGroup') AS t(cg) 
			CROSS APPLY cg.nodes('Column') AS r(c) 
			WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'EQUALITY' 
			FOR  XML PATH('') 
		) 
	, [inequality_columns] =  (SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', ' 
			FROM n.nodes('//ColumnGroup') AS t(cg) 
			CROSS APPLY cg.nodes('Column') AS r(c) 
			WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'INEQUALITY' 
			FOR  XML PATH('') 
		) 
	, [include_columns] = (SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', ' 
			FROM n.nodes('//ColumnGroup') AS t(cg) 
			CROSS APPLY cg.nodes('Column') AS r(c) 
			WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'INCLUDE' 
			FOR  XML PATH('') 
		)
	, [sql_text] = n.value('(@StatementText)[1]', 'VARCHAR(4000)')
	, [Plan] = query_plan
INTO #MissingIndexInfo 
FROM  
( 
   SELECT query_plan 
   FROM (    
           SELECT DISTINCT plan_handle 
           FROM sys.dm_exec_query_stats WITH(NOLOCK)  
         ) AS qs 
       OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp     
   WHERE tp.query_plan.exist('//MissingIndex')=1 
) AS tab (query_plan) 
CROSS APPLY query_plan.nodes('//StmtSimple') AS q(n) 
WHERE n.exist('QueryPlan/MissingIndexes') = 1 

-- Trim trailing comma from lists 
UPDATE #MissingIndexInfo 
SET equality_columns = LEFT(equality_columns,LEN(equality_columns)-1), 
   inequality_columns = LEFT(inequality_columns,LEN(inequality_columns)-1), 
   include_columns = LEFT(include_columns,LEN(include_columns)-1) 
    
SELECT * 
FROM #MissingIndexInfo
order by
	[TableName]
	, [impact] Desc
