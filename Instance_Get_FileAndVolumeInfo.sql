/*
	This script returns size information for files in the current instance
	and all of the disks in use by the current instance.
	
	$Archive: /SQL/QueryWork/File_Get_VolumeInfo.sql $
	$Revision: 3 $	$Date: 15-04-30 15:23 $
*/

SELECT
	--f.database_id
	db.name
	,f.physical_name
	, [FileSizeMB] = CAST((CAST(f.size as DECIMAL(18,3)) / 128.0) / 1000.0 as DECIMAL(8,2))
	--, f.file_id
	, [VolMountPoint]  = vs.volume_mount_point
	, [VolSizeGB] = CAST(CAST(total_bytes as DECIMAL(18,3)) / (1024.0 * 1024.0 * 1024.0) as DECIMAL(8,2))
	, [VolAvailGB] = CAST(CAST(available_bytes as DECIMAL(18,3)) / (1024.0 * 1024.0 * 1024.0) as DECIMAL(8,2))
FROM sys.master_files AS f
	inner join sys.databases as db
		on db.database_id = f.database_id
	CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) as vs
Where 1 = 1
	--and vs.volume_mount_point like '%E%'
Order By
	[VolMountPoint]
	,db.Name
	,f.file_id
