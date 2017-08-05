/*
	Based on ; Three More Tricky Tempdb Lessons http://michaeljswart.com/2013/09/three-more-tricky-tempdb-lessons/

	$Workfile: Query_Get_PlansForFrequent.sql $
	$Archive: /SQL/QueryWork/Query_Get_PlansForFrequent.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $
*/


with frequentSprocs as 
(
    select top 10 count(1) as [memory objects], cp.plan_handle from sys.dm_exec_cached_plans cp
    cross apply sys.dm_exec_cached_plan_dependent_objects(cp.plan_handle) do
    join sys.dm_os_memory_objects mo
        on do.memory_object_address = mo.memory_object_address
    where objtype = 'Proc'
    group by cp.plan_handle
    order by 1 desc
)
select fs.*, qp.query_plan
from frequentSprocs fs
cross apply sys.dm_exec_query_plan(fs.plan_handle) qp
option (recompile)
