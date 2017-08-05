/*
Jonathan Kehayias
Finding what queries in the plan cache use a specific index
https://www.sqlskills.com/blogs/jonathan/finding-what-queries-in-the-plan-cache-use-a-specific-index/

	$Archive: /SQL/QueryWork/QP_SpecifiedIndex.sql $
	$Revision: 1 $	$Date: 16-01-13 15:57 $
*/


Set TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
DECLARE @IndexName AS NVARCHAR(128) = 'PK_Panel';

-- Make sure the name passed is appropriately quoted 
-- Handle the case where the left or right was quoted manually but not the opposite side 
IF LEFT(@IndexName, 1) = '[' SET @IndexName = Replace(@IndexName, '[', ''); 
IF RIGHT(@IndexName, 1) = ']' SET @IndexName = Replace(@IndexName, ']', '');
Set @IndexName = QuoteName(@IndexName);


-- Dig into the plan cache and find all plans using this index 
;
With XmlNamespaces (Default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')    
Select
	[SQL_Text] = stmt.value('(@StatementText)[1]', 'varchar(max)')
	, [DatabaseName] = obj.value('(@Database)[1]', 'varchar(128)')
	, [SchemaName] = obj.value('(@Schema)[1]', 'varchar(128)')
	, [TableName] = obj.value('(@Table)[1]', 'varchar(128)')
	, [IndexName] = obj.value('(@Index)[1]', 'varchar(128)')
	, [IndexKind] = obj.value('(@IndexKind)[1]', 'varchar(128)')
	, cp.cacheobjtype
	, cp.objtype
	, [ObjName] = Coalesce(Object_Name(qp.objectid, qp.dbId), 'Null')
	, [PlanHandle] = cp.plan_handle
	, [QueryPlan] = qp.query_plan
From sys.dm_exec_cached_plans As cp
		Cross Apply sys.dm_exec_query_plan(cp.plan_handle) As qp
		Cross Apply query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') As batch (stmt)
		Cross Apply stmt.nodes('.//IndexScan/Object[@Index=sql:variable("@IndexName")]') As idx (obj)
Option (MaxDop 4, Recompile);