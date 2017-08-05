
/*
	This query returns total volume size and total volume free space for every server volume that has a database
	file (.mdf, .ndf, .ldf) for any instance database including system databases (except Resource).
	
	Based on sys.dm_os_volume_stats (Transact-SQL) (SQL2008R2 w/ SP1 and later)
	https://msdn.microsoft.com/en-us/library/hh223223(v=sql.105).aspx

	$Archive: /SQL/QueryWork/Disk_GetSpaceFromDMV_OSVolumeStats.sql $
	$Revision: 2 $	$Date: 17-02-10 10:04 $

*/
/*
	This uses Select Distinct because the dmv is based on db/file and so returns mutliple rows per volume.
	This only returns volumes that have database files (mdf/ndf) of this instance.
	The 1024 multipliers were chosen empirically to give the same disk size/free numbers
	show in windows file explorer.
*/
Select Distinct
	[Server] = ServerProperty('MachineName')	-- prefer over SeverName function because this never returns instance name :)
	, [Instance] = Coalesce(ServerProperty('InstanceName'), 'MSSQL')
	, [MountPoint] = vs.volume_mount_point
	, [Volume] = vs.logical_volume_name
	, [SizeGB] = Cast(vs.total_bytes / (1024.0 * 1024.0 * 1024.0) As Decimal(24, 2))
	, [FreeGB] = Cast(vs.available_bytes / (1024.0 * 1024.0 * 1024.0) As Decimal(24, 2))
	, [PerCentFree] = Cast(Cast(vs.available_bytes / (1024.0 * 1024.0 * 1024.0) As Decimal(24, 2))
					/ Cast(vs.total_bytes / (1024.0 * 1024.0 * 1024.0) As Decimal(24, 2))
					* 100.0 As Decimal(24, 2))
	--, vs.*
FROM sys.master_files AS f
	CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) as vs
	

Return;
