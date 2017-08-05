/*
	Find large partitions with size and FileGroup.

	$Workfile: Partitions_Get_LargeWithFileGroup.sql $
	$Archive: /SQL/QueryWork/Partitions_Get_LargeWithFileGroup.sql $
	$Revision: 5 $	$Date: 14-09-09 11:02 $

*/
Declare
	@ObjType	NVarchar(20)	= Null		-- Heap, Clustered, NonClustered, Null = All
	,@FGName	Nvarchar(128)	= N'%'		-- Wild Card name.
	,@TableName	NVarchar(128)	= Null		-- Table Name, WildCard.  Null = All
	;

Set @ObjType	= N'%';						-- Heap, Clustered, NonClustered, WildCard
Set @FGName		= N'%';						-- File Group Name, WildCard.
Set @TableName	= N'%';						-- Table Name, WildCard.
Set @TableName	= N'FuelVolume_20140511';						-- Table Name, WildCard.

Select
	[Table] = so.name
	,[Index] = Coalesce(si.name, 'Heap')
	,[IndexType] = Coalesce(Substring(si.type_desc, 1, 1), 'X')
	,[File Group] = fg.name
	--,sps.reserved_page_count
	,[Unused Space(MB)] = cast(sps.reserved_page_count * (8192.0/(1024.0 * 1024.0)) as int)
								-  cast(sps.used_page_count * (8192.0/(1024.0 * 1024.0)) as int)
	,[Reserved (MB)] = cast(sps.reserved_page_count * (8192.0/(1024.0 * 1024.0)) as int)
	--,sps.used_page_count
	,[Used (MB)] = cast(sps.used_page_count * (8192.0/(1024.0 * 1024.0)) as int)
	,[Rows] = sps.row_count
	,sps.partition_id
	--,au.data_space_id
From
	sys.dm_db_partition_stats as sps
	inner join sys.objects as so
		on so.object_id = sps.object_id
	inner join sys.indexes as si
		on si.index_id = sps.index_id and si.object_id = sps.object_id
	inner join sys.allocation_units as au
		on sps.partition_id = au.container_id --and au.type = 2		-- Row data
	inner join sys.filegroups as fg
		on fg.data_space_id = au.data_space_id
Where 1 = 1
	and sps.reserved_page_count > 50000
	and 1 = Case when si.type_Desc like Coalesce(@ObjType, '%') Then 1			-- HEAP, CLUSTERED, NONCLUSTERED, or All
					Else 0
					End
	and 1 = Case When fg.name  like Coalesce(@FGName, '%') Then 1
					Else 0
					End
	and 1 = Case When so.name like Coalesce(@TableName, '%') Then 1
					Else 0
					End
Order By
	--sps.reserved_page_count desc
	sps.reserved_page_count desc
	,so.name