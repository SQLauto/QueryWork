/*

	Adapted From Identifying and Solving Index Scan Problems
	https://www.simple-talk.com/sql/performance/identifying-and-solving-index-scan-problems/?utm_source=simpletalk&utm_medium=pubemail&utm_content=indexscanproblems-20150330&utm_campaign=sql&utm_term=simpletalkmain

	This query shows every lock in <name> database, including the name of the index that owns the locked
	object. You can notice in the index_name column in the image below that a single insert locked keys and pages in
	all the indexes of the table, because all of them need to receive the new row. Almost the same happens with
	updates, but only the indexes that contain the changed fields are affected.

	The query is substantially modified from above. See BOL for descriptions of the various DMV's.
	$Archive: /SQL/QueryWork/Lck_GetCurrentForDB.sql $
	$Date: 15-11-25 16:22 $	$Revision: 2 $

*/
Set Transaction Isolation Level Read Uncommitted;

Select
	[Res Type] = tl.resource_type
	, [Req Mode] = tl.request_mode
	, [Req Status] = tl.request_status
	, [Req SPID] = tl.request_session_id
	, [Object Name] = Case When tl.resource_type = 'Object' Then coalesce(so.name, 'N/A')
					Else coalesce(object_name(si.object_id), 'N/A')
					End
	, [Index Name] = coalesce(si.name, 'N/A')
	, [Blocking Sess] = wt.blocking_session_id
	, [Database] = db_name(tl.resource_database_id)
	, [Res SubType] = tl.resource_subtype
	, [Res Assoc Entity Id] = tl.resource_associated_entity_id
	--, 
From
	sys.dm_tran_locks as tl With (NoLock)
	Left Outer Join sys.dm_os_waiting_tasks as wt With (NoLock)
		on wt.resource_address = tl.lock_owner_address
	Left Outer Join sys.partitions as hobt With (NoLock)
		on hobt.hobt_id = tl.resource_associated_entity_id
	Left Outer Join sys.allocation_units as au With (NoLock)
		on au.allocation_unit_id = tl.resource_associated_entity_id
	Left Outer Join sys.indexes as si With (NoLock)
		on si.object_id = hobt.object_id
		   and si.index_id = hobt.index_id
	Left Outer Join sys.objects as so With (NoLock)
		on so.object_Id = tl.resource_associated_entity_id
Where 1 = 1
	and tl.resource_type != 'Database'
	and tl.resource_type != 'MetaData'
	and tl.request_session_id != @@SPID
	and db_name(resource_database_id) = 'ConSIRN'
	--and tl.request_session_id = 124
	--and (si.name like '%dispenser%' or so.name = 'DispenserSales')
Order By
	--tl.request_session_id,
	[Req Status],	-- = tl.request_status
	[Blocking Sess] Desc,	-- = wt.blocking_session_id
	[Object Name],		-- = coalesce(so.name, 'N/A'),
	[Index Name]		-- = coalesce(si.name, 'N/A')