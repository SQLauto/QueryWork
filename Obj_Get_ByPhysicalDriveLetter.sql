/*
	This script returns all of the database objects that are stored on a designated logical
	volume.
	$Archive: /SQL/QueryWork/Objects_GetByPhysicalDriveLetter.sql $
	$Revision: 2 $	$Date: 14-10-10 15:46 $
	
*/

Declare
	@Drive Nchar(1);


Set @Drive = N'E';

Select
	 [Drive] = SUBSTRING(df.physical_name, 1, 1)
	, [Table] = OBJECT_NAME(pRows.object_id)
	, [Index] = si.Name
	, [I Type] = case si.index_id when 0 then 'H' When 1 then 'C' Else 'N' End
	--, [Tot Pages] = au.total_pages
	, [Tot MB] = au.total_pages / 128
	--, [Used MB] = au.used_pages / 128
	--, [Data MB] = au.data_pages / 128
	, [Num Rows] = pRows.rows
	, [File Group] = fg.name
	, [Logical File] = df.name
	, [Physical File] = df.physical_name
	--, au.allocation_unit_id
	--, au.container_id
	--, [Data Space Id] = fg.data_space_id
	--, p.*
	--, df.*
	--, fg.*
	--, au.*
	--, pRows.*
From
	sys.database_files as df
	inner join sys.filegroups as fg
		on fg.data_space_id = df.data_space_id
	inner join sys.allocation_units as au
		on au.data_space_id = df.data_space_id
	left join sys.partitions as pRows
		on au.type in (1, 3) 
		and au.container_id = pRows.hobt_id
	left join sys.indexes as si
		on si.object_id = pRows.object_id and si.index_id = pRows.index_id
	--inner join sys.dm_db_partition_stats as ps
	
Where 1 = 1
	And 1 = Case when SUBSTRING(df.physical_name, 1, 1) = @Drive then 1
				when coalesce(@Drive, N'') = N'' Then 1
			Else 0
			End
	--And si.index_id in (0, 1)
	And pRows.rows > 1000
	And au.total_pages / 128 > 300
Order By
	[Drive]	
	,[Table]
	,[Index]
	,[File Group]
	,[Tot MB] Desc
	--,[Data MB] Desc
	