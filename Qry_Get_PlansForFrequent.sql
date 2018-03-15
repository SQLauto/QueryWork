/*
	Based on ; Three More Tricky Tempdb Lessons http://michaeljswart.com/2013/09/three-more-tricky-tempdb-lessons/

	$Workfile: Qry_Get_PlansForFrequent.sql $
	$Archive: /SQL/QueryWork/Qry_Get_PlansForFrequent.sql $
	$Revision: 3 $	$Date: 18-01-06 17:33 $

	Really need to review the purpose of this query.  I am not sure what michael is trying to find.  <2018-01-05>
*/


With frequentSprocs As (
	Select Top 10
		[memory objects] = Count (1)
	  , cp.plan_handle
	From
		sys.dm_exec_cached_plans As cp
		Cross Apply sys.dm_exec_cached_plan_dependent_objects (cp.plan_handle) As do
		Join sys.dm_os_memory_objects As mo
			On do.memory_object_address = mo.memory_object_address
	Where objtype = 'Proc'
	Group By cp.plan_handle
	Order By 1 Desc
)
Select fs.*, qp.query_plan
From frequentSprocs As fs
	Cross Apply sys.dm_exec_query_plan (fs.plan_handle) As qp
Option (Recompile);
