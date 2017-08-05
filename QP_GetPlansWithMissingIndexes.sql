
/*
	From Pragmatic Works - XQuery for DBA
	http://cms.pragmaticworks.com/videos/default.aspx?VidID=b5972928263b463c8b8728fe0542df0c

	Returns query plans that include a Missing index recommendation.
	ordered by use count.

	Lots of other capability in the Webinar.  Pull the columns, order, usage stats etc.
	Programatically.
	$Workfile: Cache_GetPlansWithMissingIndexes.sql $
	$Archive: /SQL/QueryWork/Cache_GetPlansWithMissingIndexes.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/

;With XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
Select
	tp.query_plan
	,cp.usecounts
From
	sys.dm_exec_cached_plans as cp
	outer Apply	sys.dm_exec_query_plan(cp.plan_handle) as tp
Where
	tp.query_plan.exist('//MissingIndex') = 1
Order By
	cp.usecounts desc