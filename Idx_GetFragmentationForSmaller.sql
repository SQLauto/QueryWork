-- $Workfile: Indexes_GetFragmentationForSmaller.sql $
/*
	Indexes_GetFragmentationForSmaller.sql
	This script uses DMVs to determine the fragementation level of the small to medium size indexes in the
	current database.
	The Size Limit is based on the # used pages and controled by @PageCountLower and @PageCountUpper.
	The DMV mode is controlled by @Mode which can be set to 'Limited', 'Detailed', Null;  Caution: Detailed or Null may reqauire a long time and impact performance

	$Workfile: Indexes_GetFragmentationForSmaller.sql $
	$Archive: /SQL/QueryWork/Indexes_GetFragmentationForSmaller.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/

If object_id('tempdb..#theData', 'U') is not null Drop Table #theData;
Go

Declare
	@DbId				Int
	, @TableId			BigInt
	, @IndexId			Int
	, @PartitionId		BigInt
	, @Mode				VARCHAR(20)
	, @PageCountLower	INT
	, @PageCountUpper	Int

Declare @theIndexes table (objectId INT, indexid int, partitionid Bigint);

Declare cIndex Cursor Local Forward_only For
	Select objectid, indexid, partitionid
	From
		@theIndexes
	;

Create Table #theData(database_id INT,
	object_id	INT
	,index_id	INT
	,partition_number	INT
	,index_type_desc	VARCHAR(50)
	,alloc_unit_type_desc	VARCHAR(50)
	,index_depth	INT
	,index_level	INT
	,avg_fragmentation_in_percent	FLOAT
	,fragment_count	INT
	,avg_fragment_size_in_pages	FLOAT
	,page_count	INT
	,avg_page_space_used_in_percent	FLOAT
	,record_count	INT
	,ghost_record_count	INT
	,version_ghost_record_count	INT
	,min_record_size_in_bytes	INT
	,max_record_size_in_bytes	INT
	,avg_record_size_in_bytes	FLOAT
	,forwarded_record_count	INT
	,compressed_page_count INT
	);

Set @DBId = db_Id();
Set @Mode = 'Limited';
--Set @Mode = 'Detailed';
Set @PageCountLower	= 100;
Set @PageCountUpper	= 50000;

Insert into @theIndexes (objectId, indexid, partitionid)
	Select
		o.object_id
		,si.index_id
		,ddps.partition_id
		--,ddps.used_page_count
		--,o.name
		--,si.name
		--,*		
	From sys.dm_db_partition_stats as ddps
		inner join sys.objects as o
			on o.object_id = ddps.object_id
			and o.type in ('U')
		inner join sys.indexes as si
			on si.object_id = ddps.object_id
			and si.index_id = ddps.index_id
	Where 1 = 1
		and ddps.used_page_count > @PageCountLower
		and ddps.used_page_count < @PageCountUpper
		and ddps.index_id > 0	-- no need to process heap partitions
	order by
		o.name
		,si.index_id

Open cIndex;

While 1 = 1
Begin
	Fetch Next From cIndex into @TableId, @IndexId, @PartitionId
	If @@FETCH_STATUS != 0 Break;
	Insert Into #theData(
		database_id	,object_id ,index_id, partition_number, index_type_desc	
		,alloc_unit_type_desc, index_depth, index_level, avg_fragmentation_in_percent	
		,fragment_count, avg_fragment_size_in_pages, page_count, avg_page_space_used_in_percent	
		,record_count, ghost_record_count, version_ghost_record_count, min_record_size_in_bytes	
		,max_record_size_in_bytes, avg_record_size_in_bytes, forwarded_record_count, compressed_page_count
		)
	Select
		database_id	,object_id ,index_id, partition_number, index_type_desc	
		,alloc_unit_type_desc, index_depth, index_level, avg_fragmentation_in_percent	
		,fragment_count, avg_fragment_size_in_pages, page_count, avg_page_space_used_in_percent	
		,record_count, ghost_record_count, version_ghost_record_count, min_record_size_in_bytes	
		,max_record_size_in_bytes, avg_record_size_in_bytes, forwarded_record_count, compressed_page_count
	From
		sys.dm_db_index_physical_stats (@DbId, @TableId, @IndexId, Null, @Mode) as ips
	Where 1 = 1

End;
If cursor_status('Local', 'cIndex') > -1 Close cIndex;
If cursor_status('Local', 'cIndex') > -2 DeAllocate cIndex;


Select
	[Table] = object_name(td.object_id)
	,[Index] = si.name
	,td.page_count
	,td.avg_fragmentation_in_percent
	,td.avg_page_space_used_in_percent
	,td.fragment_count
	,td.fragment_count
	,td.*
From
	#theData as td
	inner join sys.indexes as si
		on si.object_id = td.object_id and si.index_id = td.index_id
Where 1 = 1
	and td.index_id > 0
	and td.alloc_unit_type_desc = 'IN_ROW_DATA'