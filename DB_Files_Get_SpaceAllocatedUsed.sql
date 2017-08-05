/*
	This script is the start of a consistent way to determine
	
	Space Allocated, Used, and Available within a database.
	
/*
	Size does matter: 10 ways to reduce the database size and improve performance in SQL Server
	http://aboutsqlserver.com/2014/12/02/size-does-matter-10-ways-to-reduce-the-database-size-and-improve-performance-in-sql-server/

	This query determines the space used in a file and the current size of the file
	
	$Archive: /SQL/QueryWork/DB_Files_Get_SpaceAllocatedUsed.sql $
	$Date: 17-02-10 10:04 $	$Revision: 4 $	
*/
*/

Select
	[Type] = f.type_desc
	, [Database] = Db_Name(f.database_id)
    , [FileGroup] = fg.name	-- Coalesce(fg.name, 'LogFile')
    , [FileName] = f.name
    , [Path] = f.physical_name
    --, [FileSizePages] = f.size
    --, [FileSizeBytes] = Cast(f.size as BigInt) * 8192	-- This = Value in Windows Explorer File Properties Dialog.
    , [FileSizeGB] = Cast(Cast(Cast(f.size as BigInt) * 8192 As Decimal(24,2)) / (1024 * 1024 * 1024) As Decimal(24,2))	-- This = Value in Windows Explorer File Properties Dialog.
    , [FreeSpaceGB] = Cast(Cast(f.size - convert(int,fileproperty(f.name,'SpaceUsed')) As Decimal(24, 2)) * 8192.0 / (1024 * 1024 * 1024) As Decimal(24,2))
    --, [SpaceUsedProperty-Pages] = fileproperty(f.name,'SpaceUsed')
	, [SortKey] = f.type
From 
    --master.sys.database_files As f		
	master.sys.master_files As f
    left outer join sys.filegroups As fg		--Database specific :(
		On f.data_space_id = fg.data_space_id
Where 1 = 1
	-- And f.database_id = Db_Id('ConSIRN')
Order By
	[Database]
	, f.type
	, Case When f.name = 'Primary' Then 1 Else 2 End
	, [FileGroup]
	 
Return;

/*
	This section looks at the object level
*/
Select
     [Object] = object_name (sp.object_id)
    , [Index Name] = coalesce(si.name, 'Heap')
    , [FileGroup] = ds.name
    ,  [FileName] = df.name
    --, au.allocation_unit_id
    --, au.type
    --, [FileSizeMB] = Cast(df.size / 128.0 as Decimal(12,3))
	--, df.data_space_id
    --, sp.object_id
    
from
	sys.database_files as df
	inner join sys.allocation_units as au
		on au.data_space_id = df.data_space_id
	inner join sys.data_spaces as ds
		on ds.data_space_id = df.data_space_id
	LEFT join sys.Partitions as sp
		on au.Container_Id = Case au.Type
				when 1 then sp.Hobt_Id
				when 2 then sp.partition_id	-- LOB Data
				when 3 then sp.Hobt_Id
				else au.Container_Id
				End
	Left Join sys.indexes as si
		on si.index_id = sp.index_id
		and si.object_id = sp.object_id
Where
	df.File_id = 1
Order By
	[Object]
	, [Index Name]
	--, sp.index_id
	--, au.type
	--,au.allocation_unit_id

Return;
Exec sp_helpfile

