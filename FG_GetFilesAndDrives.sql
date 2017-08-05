/*
	$Workfile: FG_GetFilesAndDrives.sql $
	
	List all File Groups in current Database with the files and drives.

	$Archive: /SQL/QueryWork/FG_GetFilesAndDrives.sql $
	$Revision: 4 $	$Date: 17-02-10 10:04 $

*/

Select
	[Server] = @@ServerName
	, [Database] = Db_Name()
	, [File Group] = Coalesce(fg.name, 'N/A')
	, [Logical File] = df.name
	, [Drive] = SUBSTRING(df.physical_name, 1, 1)
	, [File Name] = df.physical_name
	, [File Size MB] = CAST(df.size / 128.0 as DECIMAL(12, 0))
	, [File Free Space MB] = CAST(df.size / 128.0 as DECIMAL(12, 0)) - Cast(FileProperty(df.name, 'SpaceUsed')  / 128.0 As Decimal(12, 0))
	, [File Percent Free] = 100.0 - Cast((Cast(FileProperty(df.name, 'SpaceUsed')  / 128.0 As Decimal(12, 0))) / (Cast(df.size / 128.0 as DECIMAL(12, 0))) * 100.0 As Decimal(5, 0))
	--, [Read Only] = Case When df.is_read_only = 1 Then 'Y' Else 'N' End
	--, [Default] = Case When Coalesce(fg.is_default, 0) = 1 Then 'Y' Else 'N' End
	--, df.type
	--, df.file_id
From
	sys.database_files as df
	Left Join sys.filegroups as fg
		on df.data_space_id = fg.data_space_id
Where 1 = 1
Order By
	[Server]
	, [Database]
	, Case When df.file_id = 1 Then 1 When df.file_id = 2 Then 2 Else 3 End
	, [File Group]
	, [Logical File]



