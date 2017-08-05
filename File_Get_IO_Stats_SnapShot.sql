/*
	This script captures a snap shot of  disk file I/O
	The sample duration is set by the @Delay parameter.
	Aggregate and average values are calcuated for each file
	The @DBName parameter can be used to select a single database, otherwise all user dbs and tempdb
	The @Drive parameter can be used to choose a single volume.
	
	
	$Workfile: File_Get_IO_Stats_SnapShot.sql $
	$Archive: /SQL/QueryWork/File_Get_IO_Stats_SnapShot.sql $
	$Revision: 8 $	$Date: 15-11-25 16:22 $

*/
If OBJECT_ID('tempdb..#DataStart', 'U') is not null
	Drop Table #DataStart;
Go
Set NoCount On;

Declare
	@Delay		Nchar(9)
	, @DbName	Nvarchar(50)
	, @Drive	NChar(1)
	, @FileName	Nvarchar(128)
	;
Set @Delay = N'00:00:30';
Set @DbName = Null;		-- Null gets all user dbs + TempDB
Set @Drive = Null;		-- Data for all Disks


create Table #DataStart (
	database_id				int
	,file_id				int
	,sampleMs				int
	,num_of_reads			BigInt
	,num_of_bytes_read		BigInt
	,io_stall_read_ms		BigInt
	,num_of_writes			BigInt
	,num_of_bytes_written	BigInt
	,io_stall_write_ms		BigInt
	,size_on_disk_bytes		BigInt
	);

Insert Into #DataStart(
		database_id, file_id, sampleMs
		,num_of_reads, num_of_bytes_read, io_stall_read_ms
		,num_of_writes, num_of_bytes_written, io_stall_write_ms
		,size_on_disk_bytes
	)
	Select
		ivfs.database_id, ivfs.file_id, ivfs.sample_ms
		,ivfs.num_of_reads, ivfs.num_of_bytes_read, ivfs.io_stall_read_ms
		,ivfs.num_of_writes, ivfs.num_of_bytes_written, ivfs.io_stall_write_ms
		,ivfs.size_on_disk_bytes
	From
		sys.dm_io_virtual_file_stats(null, null) as ivfs
	;
WaitFor Delay @Delay;

;With
	DataEnd As(
	Select
		ivfs.database_id, ivfs.file_id, ivfs.sample_ms
		,ivfs.num_of_reads, ivfs.num_of_bytes_read, ivfs.io_stall_read_ms
		,ivfs.num_of_writes, ivfs.num_of_bytes_written, ivfs.io_stall_write_ms
		,ivfs.size_on_disk_bytes
	From
		sys.dm_io_virtual_file_stats(null, null) as ivfs
	)
Select
	[Drive] = subString(mf.physical_name, 1, 1)
	,[Database_Name] = db.name
	,[Logical_FName] = mf.name
	,[Avg Stall(MS)/Read] = Case when (de.num_of_reads - ds.num_of_reads) = 0 then 0
					else (de.io_stall_read_ms - ds.io_stall_read_ms) / (de.num_of_reads - ds.num_of_reads)
					end
	,[Read Bytes/Sec] = ((de.num_of_bytes_read - ds.num_of_bytes_read) / (de.sample_ms - ds.sampleMs)) * 1000.0
	,[Reads/Sec] = CAST((CAST((de.num_of_reads - ds.num_of_reads) as FLOAT) / Cast((de.sample_ms - ds.sampleMs) as FLOAT)) * 1000.0 as DECIMAL(18,2))
	,[Avg Bytes/Read] = Case when (de.num_of_reads - ds.num_of_reads) = 0 then 0
						Else (de.num_of_bytes_read - ds.num_of_bytes_read) / (de.num_of_reads - ds.num_of_reads)
						End
	,[Avg Stall(MS)/Write] = Case When (de.num_of_writes - ds.num_of_writes) = 0 Then 0
						Else (de.io_stall_write_ms - ds.io_stall_write_ms) / (de.num_of_writes - ds.num_of_writes)
						end
	,[Write Bytes/Sec] = ((de.num_of_bytes_written - ds.num_of_bytes_written) / (de.sample_ms - ds.sampleMs)) * 1000.0
	,[Writes/Sec] = CAST((CAST((de.num_of_writes - ds.num_of_writes) as Float) / Cast((de.sample_ms - ds.sampleMs) as Float)) * 1000.0 as DECIMAL(18,2))
	,[Avg Bytes/Write] = Case when (de.num_of_writes - ds.num_of_writes) = 0 then 0
						Else (de.num_of_bytes_written - ds.num_of_bytes_written) / (de.num_of_writes - ds.num_of_writes)
						End
	,[File_Id] = mf.file_id
	,[DE_SampleTime] = GETDATE()
	,[DurationMs] = de.sample_ms - ds.sampleMs
	--,[Num Reads] = de.num_of_reads - ds.num_of_reads
	--,[Num Bytes Read] = de.num_of_bytes_read - ds.num_of_bytes_read
	--,[Read Stall(ms)] = de.io_stall_read_ms - ds.io_stall_read_ms
	--,[Num Writes] = de.num_of_writes - ds.num_of_writes
	--,[Num Bytes Written] = de.num_of_bytes_written - ds.num_of_bytes_written
	--,[Write Stall(ms)] = de.io_stall_write_ms - ds.io_stall_write_ms
	--,[physical_name] = mf.physical_name
	--,[DE_num_of_reads] = de.num_of_reads
	--,[DS_num_of_reads] = ds.num_of_reads
	--,[DE_num_of_bytes_read] = de.num_of_bytes_read
	--,[DS_num_of_bytes_read] = ds.num_of_bytes_read
	--,[DE_io_stall_read_ms] = de.io_stall_read_ms
	--,[DS_io_stall_read_ms] = ds.io_stall_read_ms
	--,[DE_num_of_writes] = de.num_of_writes
	--,[DS_num_of_writes] = ds.num_of_writes
	--,[DE_num_of_bytes_written] = de.num_of_bytes_written
	--,[DS_num_of_bytes_written] = ds.num_of_bytes_written
	--,[DE_io_stall_write_ms] = de.io_stall_write_ms
	--,[DS_io_stall_write_ms] = ds.io_stall_write_ms
	--,[Curr_size_bytes] = de.size_on_disk_bytes
	--,[delta_size_bytes] = de.size_on_disk_bytes - ds.size_on_disk_bytes
From
	#DataStart as ds
		inner join DataEnd as de
			on ds.database_id = de.database_id
			and ds.file_id = de.file_id
	Inner join sys.master_files as mf
		on mf.database_id = ds.database_id
			and mf.file_id = ds.file_id
	inner join sys.databases as db
		on db.database_id = ds.database_id
Where 1 = 1
	and 1 = case when ((DB_ID(@DbName) is not null) and (ds.database_id) = DB_ID(@DbName))
					then 1		-- check for single database specified.
				when ((DB_ID(@DbName) is null) and (ds.database_id = 2)) then 1 -- TempDB
				When ((DB_ID(@DbName) is null) and (ds.database_id > 4)) then 1 -- All User DBs
				else 0		-- other wise skip it.
				End
	and 1 = Case When @Drive is null Then 1
				When @Drive = subString(mf.physical_name, 1, 1) Then 1
				Else 0
				End
Order By
	[Drive]
	,Case when db_name(ds.database_id) = 'tempdb' then 0 else 1 end
	--,[Drive]
	,[Database_Name]
	,[Logical_FName]
;
Return;
