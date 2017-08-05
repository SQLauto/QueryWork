/*

	SQL Server Plan Cache: The Junk Drawer for Your Queries
	http://sqlmag.com/database-performance-tuning/sql-server-plan-cache-junk-drawer-your-queries?utm_content=buffera7f3a&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer

	$Workfile: QueryPlanCache_MiscScripts.sql $
	$Archive: /SQL/QueryWork/QueryPlanCache_MiscScripts.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $
*/

-- Listing 1: Query to Find Single-Use Plans
SELECT
	text
	, cp.objtype
	, cp.size_in_bytes
FROM
	sys.dm_exec_cached_plans AS cp
	CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
WHERE
	cp.cacheobjtype = N'Compiled Plan'
	AND cp.objtype IN (N'Adhoc', N'Prepared')
	AND cp.usecounts = 1
ORDER BY
	cp.size_in_bytes DESC
OPTION
	(RECOMPILE)
;

Return;

-- Listing 2: Script to Find Plans with Missing Indexes
;
WITH XMLNAMESPACES(DEFAULT
	N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
	SELECT
			dec.usecounts
			, dec.refcounts
			, dec.objtype
			, dec.cacheobjtype
			, des.dbid
			, des.text
			, deq.query_plan
		FROM
			sys.dm_exec_cached_plans AS dec
			CROSS APPLY sys.dm_exec_sql_text(dec.plan_handle) AS des
			CROSS APPLY sys.dm_exec_query_plan(dec.plan_handle) AS deq
		WHERE
			deq.query_plan.exist(N'/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup') <> 0
		ORDER BY
			dec.usecounts DESC

--Listing 3: Script to Find Plans with Implicit Conversion Warnings
;
WITH XMLNAMESPACES(DEFAULT
	N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
	SELECT
		cp.query_hash
		, cp.query_plan_hash
		, ConvertIssue = operators.value('@ConvertIssue', 'nvarchar(250)')
		, Expression = operators.value('@Expression', 'nvarchar(250)')
		, qp.query_plan
	FROM
		sys.dm_exec_query_stats cp
		CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
		CROSS APPLY query_plan.nodes('//Warnings/PlanAffectingConvert') rel (operators)

--Listing 4: Script to Find Plans with Key Lookup and Clustered Index Seek Operators

;
WITH XMLNAMESPACES(DEFAULT
	N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
	SELECT
		cp.query_hash
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
	FROM
		sys.dm_exec_query_stats cp
		CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
		CROSS APPLY query_plan.nodes('//RelOp') rel (operators)

-- Listing 6: Code to Group by the Query Hashes

SELECT
	count(*) AS [Count]
	, query_stats.query_hash
	, query_stats.statement_text AS [Text]
FROM
	(SELECT
		QS.*
		,[statement_text] = substring(ST.text, (QS.statement_start_offset / 2) + 1,
					((case statement_end_offset
						WHEN -1 THEN datalength(ST.text)
						ELSE QS.statement_end_offset
						END - QS.statement_start_offset) / 2) + 1)
	FROM
		sys.dm_exec_query_stats AS QS
		CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) AS ST
	) AS query_stats
GROUP BY
	query_stats.query_hash
	, query_stats.statement_text
ORDER BY
	1 DESC









