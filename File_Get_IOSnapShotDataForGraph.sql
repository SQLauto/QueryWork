/*
	This query will pull aggregated and raw data from the File IO stats Snap shots
	so the data can be plotted.

	$Archive: /SQL/QueryWork/File_IO_QuerySnapShotDataForGraph.sql $
	$Revision: 3 $	$Date: 14-06-04 14:51 $
*/
Declare
	@StartDate	DATETIME
	,@EndDate	DateTime
	,@DateRange	INT = 1			-- in days
	;
Set @EndDate = (Select MAX(SampleTime) from [dbo].[File_IO_Stats_SnapShots]);
Set @EndDate = CAST(N'2014-05-15' as Datetime);
Set @StartDate = DATEADD(dd, - @DateRange, @EndDate);

Select
	--fss.DbId
	fss.Database_Name
	,fss.FILE_ID
	--,mf.name
	, [Drive] = fss.Drive
	, fss.SampleTime
	, fss.AvgStallPerRead
	, fss.AvgStallPerWrite
	, fss.AvgReadsPerSec
	, fss.AvgWritesPerSec
	
From
	dbo.File_IO_Stats_SnapShots as fss
	inner join master.sys.master_files as mf
		on mf.database_id = fss.dbid
		and mf.file_id = fss.FILE_ID
Where 1 = 1
	--and fss.SampleTime >= @StartDate and fss.SampleTime < @EndDate
	and fss.Database_Name not in ('zDBAInfo'
		, 'ReportServer', 'ReportServerTempDb', 'Master', 'Model'
		, 'PI_ProfileStore', 'MultiDispatch', 'Utility'
		)
		--sys.dm_io_virtual_file_stats(null, null) as ivfs
	and fss.file_Id != 2		-- skip log files
	and fss.AvgStallPerRead > 25
	and fss.drive = 'E'
Order By
	fss.drive asc
	,fss.SampleTime asc
	,fss.Database_Name
	
