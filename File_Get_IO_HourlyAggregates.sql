
If Object_Id('tempdb..#theHourly', 'U') Is Not Null
Begin
	Drop Table #theHourly;
End;
Go
Declare
	@DateEnd		DateTime
	, @DateStart	DateTime

If @DateStart Is Null
Begin
	Set @DateStart = DATEADD(day, DATEDIFF(day, '20150101', GetDate()) - 1, '20150101 00:00')	-- Default is 00:00 yesterday to report yesterday's stats.
End;
If @DateEnd Is Null
Begin
	Set @DateEnd = DateAdd(Day, 1, @DateStart);			-- default to 1 day of data
End;
Create Table #theHourly(	
	DBName					Varchar(128) Not Null
	, LogicalFile			Varchar(128) Not Null
	, SampleHour			DateTime Not Null
	, Drive					Char(1) Not Null
	, S_Dur					Int
	, S_Reads				BigInt
	, S_ReadsPerSec			Decimal(18,2)
	, S_BytesRead			BigInt
	, S_BytesReadPerSec		Decimal(18,2)
	, S_ReadStall_ms		BigInt
	, S_ReadStall_msPerSec	Decimal(18,2)
	, S_Writes				BigInt
	, S_WritesPerSec		Decimal(18,2)
	, S_BytesWritten		BigInt
	, S_BytesWrittenPerSec	Decimal(18,2)
	, S_WriteStall_ms		BigInt
	, S_WriteStall_msPerSec	Decimal(18,2)
	, rn					BigInt
	, Primary Key Clustered (DBName, LogicalFile, SampleHour)
	)
;With trows As (
	Select
		rds.DBName
		, rds.LogicalFile
		, rds.SampleTime
		, rds.Drive
		, rds.NumReads
		, rds.NumBytesRead
		, rds.ReadStall_ms
		, rds.NumWrites
		, rds.NumBytesWritten
		, rds.WriteStall_ms
		, [rn] = Row_Number() Over (Partition By rds.DBName, rds.LogicalFile Order By rds.DBName, rds.LogicalFile, rds.SampleTime Asc)
	From
		dbo.File_IO_RawDataSnapShot As rds
	Where 1 = 1
		And rds.SampleTime Between DateAdd(Hour, -1, @DateStart) And @DateEnd	-- Backup one hour so the first hour has data.
		And DatePart(Minute, rds.SampleTime) = 00								-- Only look at samples taken on the hour.
	)
Insert Into #theHourly(
	DBName, LogicalFile, SampleHour, Drive, S_Dur
	, S_Reads, S_ReadsPerSec, S_BytesRead			
	, S_BytesReadPerSec, S_ReadStall_ms, S_ReadStall_msPerSec	
	, S_Writes, S_WritesPerSec, S_BytesWritten		
	, S_BytesWrittenPerSec, S_WriteStall_ms, S_WriteStall_msPerSec
	, rn
	)
	Select [Database] = cur.DBName
		 , [LogicalFile] = cur.LogicalFile
		-- , [Curr_SampleTime] = cur.SampleTime
		 , [Sample_Hour] = DateAdd(Hour, DATEDIFF(Hour, '20150101', cur.SampleTime), '20150101 00:00')
		 , [Drive] = cur.Drive
		 , [S_Dur] = DateDiff(Second, prev.SampleTime, cur.SampleTime)
		 , [S_Reads] = cur.NumReads - prev.NumReads
		 , [S_ReadsPerSec] = Cast(Cast((cur.NumReads - prev.NumReads) As Real) / Cast(DateDiff(Second, prev.SampleTime, cur.SampleTime) As Real) As Decimal(18, 2))
		 , [S_BytesRead] = cur.NumBytesRead - prev.NumBytesRead
		 , [S_BytesReadPerSec] = Cast(Cast((cur.NumBytesRead - prev.NumBytesRead) As Real) / Cast(DateDiff(Second, prev.SampleTime, cur.SampleTime) As Real) As Decimal(18, 2))
		 , [S_ReadStall_ms] = cur.ReadStall_ms - prev.ReadStall_ms
		 , [S_ReadStall_msPerSec] = Cast(Cast((cur.ReadStall_ms - prev.ReadStall_ms) As Real) / Cast(DateDiff(Second, prev.SampleTime, cur.SampleTime) As Real) As Decimal(18, 2))
		 , [S_Writes] = cur.NumWrites - prev.NumWrites
		 , [S_WritesPerSec] = Cast(Cast((cur.NumWrites - prev.NumWrites) As Real) / Cast(DateDiff(Second, prev.SampleTime, cur.SampleTime) As Real) As Decimal(18, 2))
		 , [S_BytesWritten] = cur.NumBytesWritten - prev.NumBytesWritten
		 , [S_BytesWrittenPerSec] = Cast(Cast((cur.NumBytesWritten - prev.NumBytesWritten) As Real) / Cast(DateDiff(Second, prev.SampleTime, cur.SampleTime) As Real) As Decimal(18, 2))
		 , [S_WriteStall_ms] = cur.WriteStall_ms - prev.WriteStall_ms
		 , [S_WriteStall_msPerSec] = Cast(Cast((cur.WriteStall_ms - prev.WriteStall_ms) As Real) / Cast(DateDiff(Second, prev.SampleTime, cur.SampleTime) As Real) As Decimal(18, 2))
		 , [Cur Row] = cur.rn
	From trows As cur
		Left Outer Join trows As prev
			 On cur.rn = prev.rn + 1
			 And cur.DBName = prev.DBName
			 And cur.LogicalFile = prev.LogicalFile
	Where 1 = 1
		--And 
	Order By
		cur.dbName
		, cur.LogicalFile
		, cur.SampleTime
	;

-- Summarize Daily data
Select
	th.DBName
	, th.LogicalFile
	, th.Drive
	, [Sample_Day] = Convert(Varchar(10), Min(th.SampleHour), 112)
	, [Avg_Dur_Sec] = Cast(Avg(th.S_Dur) As Decimal(18, 0))
	, [TotalReadsPerDay] = Sum(th.S_Reads)
	, [Max_ReadsPerHr] = Max(th.S_Reads)
	, [Avg_ReadsPerSec] = Cast(Sum(th.S_Reads) / 86400.0 As Decimal(18, 0))
	, [StDev_ReadsPerSec] = Cast(Cast(StDev(th.S_Reads) As Decimal(18, 0)) / Cast(Avg(th.S_Dur) As Decimal(18, 0)) As Decimal(18, 0))
	, [TotalWritesPerDay] = Sum(th.S_Writes)
	, [Max_WritesPerHr] = Max(th.S_Writes)
	, [Avg_WritesPerHr] = Avg(th.S_Writes)
From #theHourly As th
Where th.rn > 1
Group By
	th.DBName
	, th.LogicalFile
	, th.Drive