/*
	This script calculates aggregate FileIO stats from data snapshots stored in the
	DBA Info database.

	$Archive: /SQL/zDBA_Info/AnalyzeFileIOStats_Summary.sql $
	$Revision: 1 $	$Date: 14-05-17 11:43 $
*/
If Object_Id('tempdb..#theAggs', 'U') is not null Drop Table #theAggs;
Go

Declare
	@StartDate	DATETIME
	,@EndDate	DateTime
	,@DateRange	INT = 1			-- in days
	;
--Set @EndDate = (Select MAX(SampleTime) from [dbo].[File_IO_Stats_SnapShots]);
Set @EndDate = CAST(N'2014-05-14' as Datetime);
Set @StartDate = DATEADD(dd, - @DateRange, @EndDate);

Select
	--fss.DbId
	[DB Name] = fss.Database_Name
	--,fss.FILE_ID
	,[Logical Name] = mf.name
	,[Drive ] = fss.Drive
	,[Avg StallPerRead] = CAST(Avg(CAST(AvgStallPerRead as FLOAT)) as DECIMAL(18,2))
	,[Stdev StallPerRead] = CAST(stdev(CAST(AvgStallPerRead as FLOAT)) as DECIMAL(18,2))
	,[Max ReadStall_ms] = MAX(ReadStall_ms)
	,[Max AvgStallPerRead] = MAX(AvgStallPerRead)
	,[Avg StallPerWrite ] =  CAST(Avg(CAST(AvgStallPerWrite as FLOAT)) as DECIMAL(18,2))
	,[Stdev StallPerWrite ] =  CAST(Stdev(CAST(AvgStallPerWrite as FLOAT)) as DECIMAL(18,2))
	,[Max AvgStallPerWrite ] = MAX(AvgStallPerWrite)
	,[Max WriteStall_ms] = MAX(WriteStall_ms)
Into #theAggs 
From
	dbo.File_IO_Stats_SnapShots as fss
	inner join master.sys.master_files as mf
		on mf.database_id = fss.dbid
		and mf.file_id = fss.FILE_ID
Where 1 = 1
	and fss.SampleTime >= @StartDate and fss.SampleTime < @EndDate
	and fss.Database_Name not in ('zDBAInfo'
		, 'ReportServer', 'ReportServerTempDb', 'Master', 'Model'
		, 'PI_ProfileStore', 'MultiDispatch', 'Utility'
		)
		--sys.dm_io_virtual_file_stats(null, null) as ivfs
	and fss.file_Id != 2		-- skip log files 
Group By
	--fss.DbId
	fss.Database_Name
	,mf.name
	,fss.FILE_ID
	,fss.Drive
Order By
	--fss.DbId
	fss.Database_Name
	,fss.FILE_ID
	,fss.Drive
Select * From #theAggs;
--Return;

/*
	This query will return some additional counts and ranges based on the rollups calculated before.
*/

Select
	--fss.DbId
	[DB Name] = fss.Database_Name
	--,fss.FILE_ID
	,[Logical Name] = mf.name
	,[Drive] = fss.Drive
	
From
	dbo.File_IO_Stats_SnapShots as fss
	inner join master.sys.master_files as mf
		on mf.database_id = fss.dbid
		and mf.file_id = fss.FILE_ID
Where 1 = 1
	and fss.SampleTime >= @StartDate and fss.SampleTime < @EndDate
	and fss.Database_Name not in ('zDBAInfo'		-- Skip trivial I/O databases
		, 'ReportServer', 'ReportServerTempDb', 'Master', 'Model'
		, 'PI_ProfileStore', 'MultiDispatch', 'Utility'
		)
	and fss.file_Id != 2							-- skip log files
Group By
	--fss.DbId
	fss.Database_Name
	,mf.name
	,fss.FILE_ID
	,fss.Drive