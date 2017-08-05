/*
	Trying to get a list of Tasks/Queries that are waiting for 
	I/O and determine which objects, disks are the hold up.
*/

Select	wt.session_id
	  , [Wait (ms)] = wt.wait_duration_ms
	  , wt.wait_type
	  , ot.task_state
	  --, wt.resource_description
	  , [DB Name] = Db_Name(Cast(ParseName(Replace(wt.resource_description, ':', '.'), 3) As Int))
	  , [FileId] = ParseName(Replace(wt.resource_description, ':', '.'), 2)
	  , [PageId] = ParseName(Replace(wt.resource_description, ':', '.'), 1)
	  , ot.pending_io_count
	  , ot.pending_io_byte_average
	  , ot.pending_io_byte_count
	  , wt.exec_context_id
	  , ot.exec_context_id
	  , [Blocker Context] = Coalesce(wt.blocking_exec_context_id, 0)
	  , Blocker = Coalesce(wt.blocking_session_id, 0)
	  , ot.request_id
	  , ot.scheduler_id
From	sys.dm_os_waiting_tasks As wt
		Inner Join sys.dm_os_tasks As ot
			On ot.session_id = wt.session_id
Where	1 = 1
		And wt.wait_type Like 'PAGEIOLATCH_%'
Order By Blocker Desc
	  , [Wait (ms)];

Return;


