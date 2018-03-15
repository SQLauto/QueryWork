/*
	Reducing Offline Index Rebuild and Table Locking Time in SQL Server
	http://aboutsqlserver.com/2014/09/23/reducing-offline-index-rebuild-and-table-locking-time-in-sql-server/
	
	This finds the number of pages currently Cached for a specified index.
	The article discusses getting the data for an index "Pre-Fetched" prior to 
	Rebuilding or Reorganizing to reduce the duration of the Schema Modification Lock.

	$Archive: /SQL/QueryWork/Idx_GetNumberCachedPages.sql $
	$Date: 17-11-18 10:00 $	$Revision: 2 $
*/

Declare
	@IndexName NVarchar(128)
	, @TableName	NVarchar(128)
	;
Set @TableName = N'';
Set @IndexName = N'';
select
	i.name
  , au.type_desc
  , [Cached Pages] = count(*)
from
	sys.dm_os_buffer_descriptors As bd with (nolock)
	join sys.allocation_units As au with (nolock)
		on bd.allocation_unit_id = au.allocation_unit_id
	join sys.partitions As p with (nolock)
		on (au.type in (1, 3) and au.container_id = p.hobt_id)
		or (au.type = 2 and au.container_id = p.partition_id)
	join sys.indexes As i with (nolock)
		on p.object_id = i.object_id
		and p.index_id = i.index_id
where
	bd.database_id = db_id()
	and p.object_id = object_id(@TableName)
	--and p.index_id = 1 -- ID of the index
	and i.name = @IndexName
group by
	i.name
  , au.type_desc