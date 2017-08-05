/*
	This script will query the Pending I?O stats
	The aim is to find the sessions/queries that spend time waiting
	hopefully identify specifiv tables.

	$Archive: /SQL/QueryWork/IO_Pending.sql $
	$Revision: 1 $	$Date: 14-05-17 11:42 $
*/
select
	os.scheduler_id
	,os.is_online
	,os.is_idle
	,os.pending_disk_io_count
	,os.active_workers_count
	,ior.io_type
	,ior.io_pending
	,ior.io_pending_ms_ticks

From
	sys.dm_io_Pending_io_requests as ior
	inner join sys.dm_os_schedulers as os
		on ior.scheduler_address = os.scheduler_address