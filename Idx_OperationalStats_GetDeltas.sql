
/*
	This Script is in development status.
	The plan is to have a process that pulls select metrics from the Index Operational Stats DMV.

	$Archive: /SQL/QueryWork/Index_OperationalStats_GetDeltas.sql $
	$Revision: 1 $	$Date: 14-10-31 9:03 $
*/

Declare
	@DbId			INT
	, @IndexId		INT
	, @IndexName	NVARCHAR(128)
	, @Mode			NVARCHAR(20) = N'Limited'
	, @PartitionNum	INT
	, @SchemaId		INT
	, @SchemaName	NVARCHAR(128)
	, @TableId		INT
	, @TableName	NVARCHAR(128)
	;

Set @DbId = db_id();
Set @SchemaName = N'dbo';
Set @TableName = N'BOLDelivery';
Set @TableId = object_id(@SchemaName + N'.' + @TableName, 'U');
Set @PartitionNum = Null;
Set @Mode = N'Limited'		-- N'Detailed', N'Sampled', N'Limited', Null

Select
	[Database] = DB_NAME(@DbId)
	,[Table] = @TableName
	,[Index] = si.name	
	, ios.leaf_insert_count
	, ios.leaf_delete_count
	, ios.leaf_update_count
	, ios.leaf_ghost_count
	, ios.nonleaf_insert_count
	, ios.nonleaf_delete_count
	, ios.nonleaf_update_count
	, ios.leaf_allocation_count
	, ios.nonleaf_allocation_count
	, ios.leaf_page_merge_count
	, ios.nonleaf_page_merge_count
	, ios.range_scan_count
	, ios.singleton_lookup_count
	, ios.forwarded_fetch_count
	, ios.row_lock_count
	, ios.row_lock_wait_count
	, ios.row_lock_wait_in_ms
	, ios.page_lock_count
	, ios.page_lock_wait_count
	, ios.page_lock_wait_in_ms
	, ios.index_lock_promotion_attempt_count
	, ios.index_lock_promotion_count
	, ios.page_latch_wait_count
	, ios.page_latch_wait_in_ms
	, ios.page_io_latch_wait_count
	, ios.page_io_latch_wait_in_ms
	, ios.tree_page_latch_wait_count
	, ios.tree_page_latch_wait_in_ms
	, ios.tree_page_io_latch_wait_count
	, ios.tree_page_io_latch_wait_in_ms
From
	--sys.dm_db_index_physical_stats(@DbId, @TableId, @IndexId, @PartitionNum, @Mode) as ips
	--sys.dm_db_index_usage_stats as ius	-- view so use the where clause.
	sys.dm_db_index_operational_stats(@DbId, @TableId, @IndexId, @PartitionNum) as ios
	inner join sys.indexes as si
		on si.object_id = @TableId
		and si.index_id = ios.index_id

