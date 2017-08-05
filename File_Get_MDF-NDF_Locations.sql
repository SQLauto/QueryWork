/*
	This Script returns all of the primary and secondary
	data files for a server including the file size in GB
	and the O/S Drive letter where the file is stored.
	
	$Workfile: File_Get_MDF-NDF_Locations.sql $
	$Archive: /SQL/QueryWork/File_Get_MDF-NDF_Locations.sql $
	$Revision: 7 $	$Date: 17-05-12 16:30 $

*/


Select
	-- Keep the first 7 items in order to work with server inventory spreadsheets
	[Server] = ServerProperty('MachineName')	-- prefer over SeverName function because this never returns instance name :)
	, [Instance] = Coalesce(ServerProperty('InstanceName'), 'MSSQL')
	, [Database] = db.name
	, [Logical File] = mf.name
	, [Physical File] = mf.physical_name
	, [Drive] = substring(mf.physical_name, 1, 2)
	, [Size (GB)] = Case When (mf.size / (128 * 1000) < 1) Then 1 Else (mf.size / (128 * 1000)) End
	-- Keep the first 7 items in order to work with server inventory spreadsheets

	, [Type] = mf.type_desc
	, [Growth Type] = Case When mf.is_percent_growth = 1 Then 'Percent' Else 'Fixed' End
	, [Growth (MB)] = mf.growth / 128
	, [Max Size (MB)] = mf.max_size / 128
	, [File State] = mf.state_desc
	--, mf.*
From
	sys.databases as db
	inner join sys.master_files as mf
		on mf.database_id = db.database_id
Where 1 = 1
	--and	mf.file_id != 2
	--and substring(mf.physical_name, 1, 2) = 'C:'
	and (db.database_id > 4
		Or db.name = 'tempdb')
Order By
	Case When mf.type_desc = 'Log' Then 2 Else 1 End
	, db.name
	, [Logical File]
	, [Size (GB)] desc