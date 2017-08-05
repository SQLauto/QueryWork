/*

	$Workfile: PerfMon_GetBatchRequestsPerSecond.sql $
	$Archive: /SQL/QueryWork/PerfMon_GetBatchRequestsPerSecond.sql $
	$Revision: 3 $	$Date: 14-12-12 16:26 $

	I am not sure where this originated.  It is definitely not something I started
	from scratch.

*/
select
	[Batch Requests/sec] =  t1.cntr_value 
    , [SQL Compilations/sec] = t2.cntr_value
    , [plan_reuse] = Cast((t1.cntr_value*1.0-t2.cntr_value*1.0)/t1.cntr_value*100 as decimal(15,2))
from 
    sys.dm_os_performance_counters t1,
    sys.dm_os_performance_counters t2
where 
    t1.counter_name='Batch Requests/sec' and
    t2.counter_name='SQL Compilations/sec'
/*
Batch Requests/sec	SQL Compilations/sec	plan_reuse
457318579	            330044171	        27.83
457326827	            330047923	        27.83
457365142	            330066754	        27.83
*/