/*
	This script returns file data for all of the user databases and tempdb
	for the instance.
	$Archive: /SQL/QueryWork/Server_GetDBFileInfo.sql $
	$Revision: 1 $	$Date: 14-09-26 16:17 $

*/

Set NoCount On;

if Object_id('Tempdb..#FileData', 'U') is not null
	Drop Table #FileData;
if Object_id('Tempdb..#FileGroups', 'U') is not null
	Drop Table #FileGroups;
Go

Declare
	@cmd	NVARCHAR(2048)
	,@DB	NVARCHAR(128)
	,@NewLine	NCHAR(1) = NCHAR(13)
	;

Create Table #FileGroups(id INT IDENTITY(1,1)
	,DB	NVARCHAR(128)
	,DataSpaceId INT
	,FGName NVARCHAR(128)
	);

Create Table #FileData(Id INT Identity(1,1)
	, DB			Nvarchar(128)
	, FG			Nvarchar(128)
	, LogicalFile	Nvarchar(128)
	, Drive			NCHAR(1)
	, PhysicalFile	NVARCHAR(256)
	, SQLSize		DECIMAL(18,3)
	, NTFSSize		DECIMAL(18,3)
	, DataSpaceId	INT
	, FileType		NVARCHAR(60)
	, ServerName	NVARCHAR(128)
	, InstanceName	NVARCHAR(128)
	);

Declare c_FG cursor local forward_only for
	select distinct db from #FileData;

Insert #FileData(
		  DB, LogicalFile
		, Drive, PhysicalFile, SQLSize
		, NTFSSize, DataSpaceId, FileType
		, ServerName, InstanceName
		)
Select
	--mf.database_id
	[Database] = DB_NAME(mf.database_id)
	,[Logical File] = mf.name
	,[Drive] = SUBSTRING(mf.physical_name, 1, 1)
	,[Physical File] = mf.physical_name
	--,[Num Pages] = mf.size
	,[SQL Size GB] = CAST(mf.size / (128.0 * 1000.0) as DECIMAL(18,3))
	,[NTFS Size GB] = Cast((CAST(mf.size as DECIMAL(18,3))* 8192)/ (1024.0 * 1000.0 * 1000.0) As Decimal(18,3))
	,mf.data_space_id
	,mf.type_desc
	,CAST(SERVERPROPERTY('MachineName') as NVARCHAR(128))
	,CAST(COALESCE(SERVERPROPERTY('InstanceName'), 'Default') as NVARCHAR(128))
From
	master.sys.master_files as mf
Where 1 = 1
	and (mf.database_id > 4 or mf.database_id = 2)
Order By
	[Database]
	,mf.data_space_id

Open c_FG

While 1 = 1
Begin -- Get File Group Names
	Fetch Next from c_FG into @DB
	If @@FETCH_STATUS != 0 Break;
	Set @cmd = N'Use ' + QUOTENAME(@DB) + N';' + @NewLine
		+ N'Select db_name(), data_space_id, name from sys.data_spaces;'
	Print @cmd;
	Insert Into #FileGroups(
		   DB, DataSpaceId, FGName
			)
		Exec sp_executeSQL @cmd;
End; -- Get File Group Names

Update fd 
	Set FG = case When fd.FileType = 'LOG' then 'T-Logs' Else fg.FGName End
From #FileData as fd
	left join #FileGroups as fg
	on fd.db = fg.db and fd.DataSpaceId = fg.DataSpaceId

--Select * from #FileGroups as fg;
Select
	ServerName, InstanceName
	, DB, FG, LogicalFile
	, Drive, PhysicalFile
	, SQLSize, NTFSSize
From #FileData as fd;
