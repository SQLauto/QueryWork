-- $Workfile: File_ShrinkByIncrement.sql $
/*
	$Archive: /SQL/QueryWork/File_ShrinkByIncrement.sql $
	$Revision: 16 $	$Date: 16-05-12 14:11 $
	
	Shrink the designated logical file to specified target size
	in small increments. (recommended  start at 10MB until performance is validated).
	The script loops until a designated stop condition is met and delays for a
	set period of time after each shrink operation.
	BTW, be sure to consider index maintenance issues.
	
	Stop Conditions:
	Time > @EndTime
		The script calculates a stop time according to which line is commented.
		For example, the default is to run until 2AM tomorrow.  Another option is current time + X hours.
	Target Size Reached  @TargetSizeMB
	
*/
Set NoCount On;
Set Deadlock_priority Low;		-- Choose this process as victim in event of a deadlock.
Declare
	@LogicalFile			NVarchar(128) = N''
	, @TargetSizeMB			Int = -1
	, @debug				int = 1					-- 0 = Execute Silently, 1 = Execute Verbose, 2 = What If
	, @Delay				Char(8) = '00:00:02'	-- Delay between shrink passes
	, @EndTime				DateTime = Null			-- Stop date
	, @ShrinkIncrementMB	int = 1000

	, @cmd					NVarchar(2000)
	, @cnt					Int = 0
	, @cntConsecutiveDeadLock	INT = 0
	, @cntTotalDeadLock		Int = 0
	, @CurrentSizeMB		Int = -1
	, @database				NVarchar(128) = Db_Name()
	, @duration				Int						-- used to calculate timing stats
	, @NewLine				NChar(1) = NCHAR(10)
	, @StartTime			Datetime = GETDATE()
	, @ErrorMessage			NVarchar(4000)
	, @ErrorNumber			Int
	, @ErrorSeverity		Int
	, @ErrorState			Int
	, @ErrorLine			INT
	, @ErrorProcedure		NVarchar(200)
	;

-- If not specified then run until 06:00 tomorrow.
If @EndTime Is Null Set @EndTime = DateAdd(hh, 6, DateAdd(dd, 1, DateDiff(dd, 0, @StartTime )));

/*
	Page Size = 8192 X 128 = 1MB (1,048,576 bytes).
	Windows Explorer File Properties dialog Size = 583,144,570,880 Size on Disk = 583,144,570,880
	Windows Explorer directory listing = 569477102KB (This is size on disk / 1024)
	Shrink File Dialog - allocated = 556130MB, Available = 253868.56MB, Minimum = 302262MB
		Allocated = Windows explorer Size on Disk / (1024 * 1024)
	sp_helpfile, Size = 569477120 KB (/1024 = 556130MB)
	sys.database_files Size = 71184640 (/128 = 556130)
	sys.master_files Size = 71184640 (/128 = 556130)
*/

Select @CurrentSizeMB = Coalesce(df.Size / 128, 0)
From sys.database_files As df
Where df.name = @LogicalFile

If ( 
	@CurrentSizeMB Is null
	Or @CurrentSizeMB < @TargetSizeMB - @ShrinkIncrementMB
	)
Begin
	Raiserror('Must specify valid Logical File and valid Target Size. Database = %s, Logical File = %s, Target Size = %d, Current Size = %d', 16, 1
			, @Database, @LogicalFile, @TargetSizeMB, @CurrentSizeMB) With NoWait;
	Return;
End;
	
Set @cmd = CONVERT(Nvarchar(24), @EndTime, 120)
Print @StartTime;
RaisError ('Starting Shrink Process for %s Logical File %s.%sTarget Size (MB) = %d.  Increment (MB) = %d, @EndTime = %s, @debug = %d, @Delay = %s'
			, 0, 0, @Database, @LogicalFile, @NewLine, @TargetSizeMB, @ShrinkIncrementMB, @cmd, @debug, @Delay) with NoWait;

While (@CurrentSizeMB >= (@TargetSizeMB + @ShrinkIncrementMB))
		and (@StartTime < @EndTime)
Begin		-- Shrink by a small increment, sleep, do-it again.
	Set @StartTime = GETDATE();
	-- Check for Backup in progress.  Shrink not allowed.
	If Exists (SELECT r.session_id as SPID
			FROM sys.dm_exec_requests as r
				CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) as a 
			WHERE 
				r.command in ('BACKUP DATABASE','RESTORE DATABASE')
				and r.database_id = db_id()
			)
	Begin	-- Can't shrink while backup is in progress
		Set @cmd = convert(Nvarchar(24), @StartTime, 120);
		RaisError('Backup in Progress.  Sleep and try again. Current Time = %s', 0, 0, @cmd) with noWait;
		WaitFor Delay '00:01:00';		-- Wait for one minute.
		Continue;						-- Then try again.
	End;	-- Can't shrink while backup is in progress

	RaisError('Starting Shrink. CurrentSize (MB) = %d. Count = %d', 0, 0, @CurrentSizeMB, @cnt) With NoWait;
	Set @cnt = @cnt + 1;
	--  Calculate New logical file size in MB
	Set @CurrentSizeMB = @CurrentSizeMB - @ShrinkIncrementMB
	set @cmd = N'DBCC SHRINKFILE (N''' + @LogicalFile + N''', '
				+ cast((@CurrentSizeMB) as NVarchar(24))
				+ N') With No_InfoMsgs;';
	If @debug > 0
	Begin
		Print @StartTime;
		PRINT @cmd;
	End
	
	if @debug <= 1
	Begin	-- Do the Shrink
	Begin Try
		Exec sp_ExecuteSQL @cmd;
		Set @duration = datediff(ms, @StartTime, GETDATE());
		Set @cntConsecutiveDeadLock = 0;		-- 
		RaisError('Completed %dMB shrink in %d ms. Count = %d', 0, 0, @ShrinkIncrementMB, @duration, @cnt) With NoWait;
		WaitFor Delay @Delay;
	End Try	-- Do the Shrink
	Begin Catch
		SELECT 
			@ErrorMessage = ERROR_MESSAGE()
			,@ErrorNumber = ERROR_NUMBER()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()
			,@ErrorLine = ERROR_LINE()
			,@ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-')
			;

		If @@TranCount > 0 RollBack;
		If(
			@ErrorNumber = 1205	-- Deadlock
			or @ErrorNumber = 3635	-- An error occurred while processing '%ls' metadata for database
			or @ErrorNumber = 5231	-- Object ID %ld (object '%.*ls'): A deadlock occurred while trying to lock this object for checking
			--or @ErrorNumber = 5252	-- File ID %d of database ID %d cannot be shrunk to the expected size. The high concurrent workload is leading to too many deadlocks
			--or @ErrorNumber = 17888	-- All schedulers on Node %d appear deadlocked due to a large number of worker 
			)
		Begin
			Set @cntConsecutiveDeadLock = @cntConsecutiveDeadLock + 1;
			Set @cntTotalDeadLock = @cntTotalDeadLock + 1;
			Set @ErrorMessage = 'Deadlock occured during shrink. @ErrorNumber = %d.  Consecutive Deadlock count = %d' + @NewLine + @ErrorMessage;
			RaisError(@ErrorMessage, 10, 1, @ErrorNumber, @cntConsecutiveDeadLock) with NoWait;
			If @cntConsecutiveDeadLock < 5
				or @cntTotalDeadLock < 20
			Continue;			-- tolerate some deadlocks.
		End;
		-- Either too many deadlocks or unexpected error;
		Set @ErrorMessage = 'Terminating shrink. @ErrorNumber = %d.  Consecutive Deadlock count = %d. Total Deadlock Count = %d.' + @NewLine + @ErrorMessage;
		RaisError(@ErrorMessage, 16, 1, @ErrorNumber, @cntConsecutiveDeadLock, @cntTotalDeadLock) with NoWait;
		Return;
	End Catch;
	End;	-- Do the Shrink

	if @debug > 1 break;		-- For testing just do one pass.  Fails if Backup in progress :)
End;		-- Shrink by a small increment, sleep, do-it again.
Set @CurrentSizeMB = @CurrentSizeMB - @ShrinkIncrementMB;
RaisError('Next Starting Size = %d; Target Size = %d', 0, 0, @CurrentSizeMB, @TargetSizeMB) With NoWait;
Return;


/*
	Looking for good code to determine actual pages in use to calculate
	the Target Size as something like PagesInUse + 10% + Increment.
*/

Select
--	Object_Id(ps.object_id)
--	, ps.index_id
	 Sum(au.total_pages)
	, Sum(ps.reserved_page_count)
	, Sum(au.used_pages)
	, Sum(ps.used_page_count)
	
--	, * 
	--au.data_space_id	
	--, (SUM(au.Total_pages) / 128)
	--, (SUM(au.used_pages) / 128)
	--, ((SUM(au.Total_pages) - SUM(au.used_pages)) / 128)
	
From Sys.allocation_units as au
	inner join sys.partitions as sp on sp.hobt_id = au.container_id
	inner join sys.dm_db_partition_stats as ps
		on ps.partition_id = sp.partition_id
Where 1 = 1
-- Group By au.data_space_id


