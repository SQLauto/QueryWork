/*
	This script is loosely based on this article
	Disk Space Monitoring: How To - http://sqlmag.com/blog/disk-space-monitoring-how

	Note: The space available and total space numbers are approximate.  Windows
	returns slightly different numbers in the Windows Explore GUI and the Computer Management Storage GUI also
	reports slightly different numbers
	For Example:
							D:Size	D:Free	E:Size	E:Free		
	Windows Explorer		49.9	43.0	799		288
	Computer Management		50.00	43.08	799.87	288.54
	SQL Server Functions	51.196	44.115	819.069	295.469
	$Workfile: Disk_GetSpaceAvailable.sql $
	$Archive: /SQL/QueryWork/Disk_GetSpaceAvailable.sql $
	$Revision: 3 $	$Date: 15-03-25 15:50 $

*/
Use Master
Declare @Adjustment	Decimal(24, 2) = 1024.0
If object_id ('tempdb..#junk', 'U') is not null
	Drop Table #junk
Create Table #junk (Drive Char(1), MB_Free Integer);
Truncate Table #Junk;
Insert Into #junk
	Exec xp_fixedDrives

--Select Drive, MB_Free, MB_Free / 1024 From #Junk

Select distinct	-- Distinct used to select one row of pre-aggregaed data for each volume on the server
	@@servername
	, j.Drive
	, [Volume] = vs.volume_mount_point
	, [VolumeSizeGB] = cast((vs.total_bytes / (@Adjustment *1000.0 * 1000)) as Decimal(12, 2))
	--, [Vs Total] = vs.total_bytes / @Adjustment
	--, [Vs Free] = vs.available_bytes / @Adjustment
	, [VolumeAvailableGB] = cast((vs.available_bytes / (@Adjustment * 1000 * 1000)) as Decimal(12, 2))
	, [XP Free] = Cast(j.MB_Free / @Adjustment As Decimal(24, 2))
	, [Diff] = Cast((vs.available_bytes / (@Adjustment * 1000.0 * 1000.0))- (j.MB_Free / 1000.0) As Decimal(24, 2))
	, [% vs] = Cast(Cast((vs.available_bytes / (@Adjustment * 1000.0 * 1000.0))- (j.MB_Free / 1000.0) As Decimal(24, 2))
				 / cast((vs.available_bytes / (@Adjustment * 1000.0 * 1000.0)) as Decimal(12, 2)) * 100.0 As Decimal(12, 2))
	--, [VolumeSizeBytes] = vs.total_bytes
	--, [VolumeAvailableBytes] = vs.available_bytes
	--, [File Size MB]	= cast((Cast(mf.size as Decimal(24, 2)) * 8192 / (1024.0 * 1000.0)) as Decimal(24, 2))
	--, [Database] = db_name(mf.database_id)
	--, [LogicalFName] = mf.name
	--, mf.*
	--, vs.*
--	Select *
From
	sys.master_files as mf
	cross apply sys.dm_os_volume_stats(mf.database_id, mf.file_id) as vs
	inner join #junk as j
		on j.Drive = substring(vs.volume_mount_point, 1, 1)
Where 1 = 1
	--and mf.database_id = db_id()
Order By
	[Volume] Asc
