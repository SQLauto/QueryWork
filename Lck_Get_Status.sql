
/*
	Script to return current locks
	
	$Workfile: LockStatus_Get.sql $
	$Archive: /SQL/QueryWork/LockStatus_Get.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/


Select
	[Res Type] = dtl.resource_type
	,[SPID] = dtl.request_session_id
	,[Req Mode] = dtl.request_mode
	,[Req Type] = dtl.request_type
	,[Req Status] = dtl.request_status
	,[Res SubType] = dtl.resource_subtype
	,[Entity Id] = Case dtl.resource_type	-- can be an object ID, Hobt ID, or an Allocation Unit ID
					When 'OBJECT' Then object_name(dtl.resource_associated_entity_id, dtl.resource_database_id)
					Else cast(dtl.resource_associated_entity_id as NVARCHAR(35))
					End
	,[Res Partition] = dtl.resource_lock_partition
	,[DB] = db_name(dtl.resource_database_id)
	,dtl.resource_description
	,dtl.resource_associated_entity_id
	--,dtl.request_reference_count
	--,dtl.request_lifetime
	--,dtl.request_exec_context_id
	--,dtl.request_request_id
	--,dtl.request_owner_type
	--,dtl.request_owner_id
	--,dtl.request_owner_guid
	--,dtl.request_owner_lockspace_id
	--,dtl.lock_owner_address
	--,dtl.*
From
	sys.dm_tran_locks as dtl
Where 1 = 1
	and dtl.resource_type != 'DATABASE'





