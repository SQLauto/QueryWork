/*
	This Script provides an overview of the File Groups and Files for the
	Current database.
	
	Note the file sizes are very close to the same as the file size reported by Windows Explore GUI.
	The differences are in the 4 digit and are not significant for < 1000GB.
	
	The Allocation unit sizes are also very close to those reported by SQL GUI (Shrink File)
	
	This script only works for the "current" database because sys.allocation_units is a database
	specific table.

	$Workfile: FG_Get_SummaryData.sql $
	$Archive: /SQL/QueryWork/FG_Get_SummaryData.sql $
	$Revision: 4 $	$Date: 17-02-10 10:04 $

*/

;With theFiles as (
	Select
		[DBName]			= db_name(mf.database_id)
		, [FGName]			= ds.name
		, [LogicalName]		= mf.name
		, [FileType]		= Case mf.type When 0 Then 'Rows' When 1 then 'Log' When 4 Then 'FullText' Else 'Unk' End
		, [FileSizeGB]		= cast((mf.size * 8192.0)/ (1024.0 * 1000.0 * 1000.0) as decimal(10,3))
		, [Drive]			= substring(mf.physical_name, 1, 1)
		, [DriveSize]		= Cast(vs.total_bytes / (1024.0 * 1024.0 * 1024.0) as Decimal(10,1))
		, [DriveFree]		= Cast(vs.available_bytes / (1024.0 * 1024.0 * 1024.0) as Decimal(10,1))
		, [FileName]		= mf.physical_name
		, [data_space_id]	= mf.data_space_id
		--,mf.*
		--,ds.*
	From
		sys.master_files as mf With (NoLock)
		inner join sys.data_spaces as ds With (NoLock)
			on ds.data_space_id = mf.data_space_id
		Cross Apply sys.dm_os_volume_stats(mf.database_id, mf.file_id) as vs
	Where 1 = 1
		and mf.database_Id = db_id()
	)

Select
	  [DBName]		= tf.DBName
	, [FGName]		= tf.FGName
	, [Drive]		= tf.Drive
	, [DriveSize]	= tf.DriveSize
	, [DriveFree]	= tf.DriveFree
	, [FileSizeGB]	= tf.FileSizeGB
	, [FG_AllocGB]	= Cast(Sum((au.total_pages * 8192) / (1024.0 * 1024.0 * 1024.0)) as Decimal(12, 3))
	, [FG_FreeGB]		= (tf.FileSizeGB) - Cast(Sum((au.total_pages * 8192) / (1024.0 * 1024.0 * 1024.0)) as Decimal(12, 3))
	, [LogicalName]	= tf.LogicalName
	, [FileName]	= tf.FileName
	, [FileType]	= tf.FileType
From
	theFiles as tf
		inner join sys.allocation_units as au With (NoLock)
			on au.data_space_id = tf.data_space_id
Group By
	[DBName]		
	, [FGName]		
	, [LogicalName]	
	, [FileType]	
	, [FileSizeGB]	
	, [Drive]		
	, [DriveSize]	
	, [DriveFree]	
	, [FileName]	
	--, [data_space_id]

Order By
	--[FGName],
	[Drive]