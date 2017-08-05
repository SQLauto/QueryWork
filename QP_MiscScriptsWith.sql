
/*
	This reference has examples of QP Cache queries to find a number of problems including
	Implicit Conversions, Lookups, Missing Indexes, and Similar Queries.
	SQL Server Plan Cache: The Junk Drawer for Your Queries
	http://sqlmag.com/database-performance-tuning/sql-server-plan-cache-junk-drawer-your-queries?utm_content=buffera7f3a&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer
	
	Note: The "Default" key word is indicated as an Error in SSMS but it seems to run fine :)G
	$Archive: /SQL/QueryWork/QP_MiscScriptsWith.sql $
	$Revision: 1 $	$Date: 14-11-28 16:20 $

*/
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
	SELECT cp.query_hash
		, cp.query_plan_hash
		, PhysicalOperator = operators.value('@PhysicalOp', 'nvarchar(50)')
		, LogicalOp = operators.value('@LogicalOp', 'nvarchar(50)')
		, AvgRowSize = operators.value('@AvgRowSize', 'nvarchar(50)')
		, EstimateCPU = operators.value('@EstimateCPU', 'nvarchar(50)')
		, EstimateIO = operators.value('@EstimateIO', 'nvarchar(50)')
		, EstimateRebinds = operators.value('@EstimateRebinds', 'nvarchar(50)')
		, EstimateRewinds = operators.value('@EstimateRewinds', 'nvarchar(50)')
		, EstimateRows = operators.value('@EstimateRows', 'nvarchar(50)')
		, Parallel = operators.value('@Parallel', 'nvarchar(50)')
		, NodeId = operators.value('@NodeId', 'nvarchar(50)')
		, EstimatedTotalSubtreeCost = operators.value('@EstimatedTotalSubtreeCost', 'nvarchar(50)')
	FROM sys.dm_exec_query_stats As cp
		CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) As qp
		CROSS APPLY query_plan.nodes('//RelOp') rel (operators);


-- Find Implicit Conversion warnings.
Return;
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
	 SELECT	cp.query_hash
		  , cp.query_plan_hash
		  , ConvertIssue = operators.value('@ConvertIssue', 'nvarchar(250)')
		  , Expression = operators.value('@Expression', 'nvarchar(250)')
		  , qp.query_plan
	 FROM sys.dm_exec_query_stats as cp
			CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) as qp
			CROSS APPLY query_plan.nodes('//Warnings/PlanAffectingConvert') rel (operators)

-- Find Queries with similar plans or similar text :)
Return;
SELECT [Count] = COUNT(*)
	  , query_stats.query_hash
	  , [Text] = query_stats.statement_text
FROM (SELECT QS.*
			  , SUBSTRING(ST.text, (QS.statement_start_offset / 2) + 1,
						  ((CASE statement_end_offset
							  WHEN -1 THEN DATALENGTH(ST.text)
							  ELSE QS.statement_end_offset
							END - QS.statement_start_offset) / 2) + 1) AS statement_text
		 FROM sys.dm_exec_query_stats AS QS
				CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) AS ST
		) AS query_stats
GROUP BY query_stats.query_hash
	  , query_stats.statement_text
ORDER BY 1 DESC