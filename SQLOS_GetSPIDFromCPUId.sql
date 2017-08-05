/*

	Tracking down CPU spikes using process explorer and DMVs
	http://www.sqlservercentral.com/blogs/ctrl-alt-geek/2014/10/15/tracking-down-cpu-spikes-using-process-explorer-and-dmvs/

	$Archive: /SQL/QueryWork/SQLOS_GetSPIDFromCPUId.sql $
	$Revision: 1 $	$Date: 14-10-31 9:03 $

	Using process explorer this way I found that CPU usage was jumping up and down but there were two CPUs that were
	sitting at 100% consistently. Armed with the ids I hit SQL Server and some DMVs.
	Using sys.dm_os_schedulers with the ids of the two rogue CPUs gave me the scheduler addresses
	Putting the scheduler addresses into sys.dm_os_workers gave me task addresses.
	And finally putting the task addresses into sys.dm_os_tasks gave me the session ids
*/

Declare @CPUId	int

select
	s.cpu_id,
	w.[state],
	t.session_id 
from sys.dm_os_schedulers s
left join sys.dm_os_workers w
	on s.scheduler_address = w.scheduler_address
left join sys.dm_os_tasks t
	on w.task_address = t.task_address
where
	--s.cpu_id in ([id1],[id2],...)
	s.cpu_id = @CPUId
and w.[state] = 'RUNNING'
