/*
	Index_Get_PhysicalStatsForTable.sql
	Based on various refereneces including BOL.
	Must include database name and table name
	May include other values such as Index name and partition Id
	Caution, this query can be very intensive if the target table is large.
	
	$Workfile: Idx_Get_PhysicalStatsForTable.sql $
	$Archive: /SQL/QueryWork/Idx_Get_PhysicalStatsForTable.sql $
	$Revision: 14 $	$Date: 17-02-10 10:04 $

*/
Declare
	 @SchemaName	Varchar(128) = 'dbo'
	, @TableName	varchar(128) = ''
	, @IndexName	Varchar(128) = ''
	, @Mode			Varchar(20) = 'Limited'	-- Limited, Sampled, Detailed


	, @IndexId		Int = Null					-- Null = Show Data for all indexes
	, @PartitionId	int = Null					-- Null = Show data for all Partitions
	, @DbId			int = db_id()
	, @TableId		int
	;

If Len(@SchemaName ) < 2 Set @SchemaName = 'dbo'
Set @TableId = Object_Id(@SchemaName + '.' + @TableName, 'U')
If @DbId is null
	or @TableId is null
Begin
	RaisError('Both DB and Table must be specified', 10, 0) With NoWait;
	Return;
End

If @IndexName is not null
Begin	-- Find the index
	Select @IndexId = si.index_id
	From sys.indexes as si
	Where
		si.object_id = @TableId
		and si.name = @IndexName
End;	-- Find the index

Select
	[Table Name]	= OBJECT_NAME(si.object_id)
	,[Index Name]	= si.name
	--,[IndexId]	= ips.index_id
	,[Index Type]	= subString(ips.index_type_desc, 1, 1)
	,Depth			= ips.index_depth												-- Limited
	,Level			= ips.index_level												-- Limited
	,Avg_Space_Used = cast(ips.avg_page_space_used_in_percent as decimal(12, 2))	-- !Limited, Sampled
	,[Frag_%]		= cast(ips.avg_fragmentation_in_percent as decimal(12, 2))		-- Limited, Null for Heap when Mode = Sampled
	,Frag_Cnt		= ips.fragment_count											-- Limited, Null for Heap when Mode = Sampled
	,Avg_Frag_Size	= cast(ips.avg_fragment_size_in_pages as decimal(12, 2))		-- Limited
	,Page_Cnt		= ips.page_count												-- Limited
	,Res_Pg_Cnt		= ps.in_row_reserved_page_count									-- Limited
	,Used_Pg_Cnt	= ps.in_row_used_page_count										-- Limited
	,Tot_Res_Pg_Cnt = ps.reserved_page_count										-- Limited
	,Tot_Used_Pg_Cnt = ps.used_page_count											-- Limited
	,Part_Num		= ips.partition_number											-- Limited
	,Ghost_Cnt		= ips.ghost_record_count										-- !Limited, Sampled
	,Fwded_Cnt		= ips.forwarded_record_count									-- !Limited, Sampled
	,Ver_Ghost_Cnt	= ips.version_ghost_record_count								-- !Limited, Sampled
	,Min_Rec_Size	= ips.min_record_size_in_bytes									-- !Limited, Sampled
	,Max_Rec_Size	= ips.max_record_size_in_bytes									-- !Limited, Sampled
	,Avg_Rec_Size	= ips.avg_record_size_in_bytes									-- !Limited, Sampled
	--,ips.*
	--, si.*
From
	sys.dm_db_index_physical_stats (@DbId, @TableId, @IndexId, @PartitionId, @Mode) as ips
	inner join sys.indexes as si
		on si.object_id = ips.object_id and si.index_id = ips.index_id
	inner join sys.dm_db_partition_stats as ps
		on ps.object_id = si.object_id
		and ps.index_id = si.index_id
		and ps.partition_number = ips.partition_number
Order By
	[Table Name]
	, [Index Type]
	, [Index Name]
	;

Select
     StatsName = st.name
    ,LastUpdated = STATS_DATE(object_id, st.stats_id)
    ,st.*
FROM sys.stats as st
WHERE object_id = @TableId
	;

Set @TableName = @SchemaName + '.' + @TableName
DBCC Show_Statistics(@TableName, @IndexName)