/*
	Script to find all of the small indexes in a database and rebuild them one by one.
	$Archive: /SQL/QueryWork/Indexes_RebuildInFileGroupbySize.sql $
	$Revision: 1 $	$Date: 14-10-31 9:03 $

*/
Set NoCount On;
Set DeadLock_Priority Low;

Declare
	@cmd				NVARCHAR(4000)
	,@cmdDelay			Char(10)
	,@cntProcessed		Int
	,@DBId				INT
	,@Debug				Int
	,@FileGroupName		Nvarchar(128)
	,@FillFactor		Int
	,@FillFactorDefault NVARCHAR(3)
	,@Index				NVARCHAR(128)
	,@IndexId			INT
	,@LimitLower		INTEGER
	,@LimitUpper		INTEGER
	,@msg				Nvarchar(512)
	,@NewLine			NChar(1)	= NChar(13)
	,@PagesReserved		Int
	,@PagesUsed			Int
	,@StartTime			Datetime
	,@Table				NVARCHAR(128)
	,@ErrorMessage		NVARCHAR(4000)
	,@ErrorNumber		INT
	,@ErrorSeverity		INT
	,@ErrorState		INT
	,@ErrorLine			INT
	,@ErrorProcedure	NVARCHAR(200)
	;
/*
	File Group Primary processed -
		59 indexes between 10 and 1000 pages in 21 minutes.
		27 indexes between 1000 and 5000 pages in 10 minutes
		16 indexes between 5000 and 10000 pages ~ 20 minutes (10 to 35 seconds each 1 = 58 and 1 = 126 seconds)
		
		25 indexes between 10000 and 25000 pages in 27 minutes. 7 to 90 seconds most around 40 - 60
		17 indexes between 25000 and 50000 pages in 40 minutes. 40 to 200 seconds most around 100
		20 indexes between 50000 and 100000 pages in ?? minutes. ?? to ??? seconds most around ??
	
*/
Set @LimitLower	= 100;				--100;
Set	@LimitUpper = 10000;			--50000;			-- -1 is no limit
Set @FillFactorDefault = N'90';
Set @DbId = db_id();
Set @FileGroupName = N'Primary';
--Set @FileGroupName = N'ClearViewGraph';
--Set @FileGroupName = N'TSCI';
Set @Debug = 1;			-- 0 = Execute Silent, 1 = Verbose, 2 = No Execute
--Set @Debug = 1;
Set @cmdDelay = N'00:00:05';

Declare cIndexes Cursor Local Forward_only For
	Select
		[TableName] = object_name(ps.object_id)
		,[IndexName] = coalesce(si.name, 'Heap')
		,ps.index_id
		,si.fill_factor
		,ps.reserved_page_count
		,ps.used_page_count
	From
		sys.dm_db_partition_stats as ps
		inner join sys.objects as so
			on so.object_id = ps.object_id
		inner join sys.indexes as si
			on si.object_id = ps.object_id
			and si.index_id = ps.index_id
		inner join sys.filegroups as fg
			on si.data_space_id = fg.data_space_id
	Where 1 = 1
		and so.type = 'U'					-- Only user tables
		and so.name Not like 'zDrop_%'		-- Don't process tables that are proposed for Dropping
		and so.name Not like 'sys%'			-- Don't process sysdiagrams, etc.
		and  1 = case 
					when LEN(@FileGroupName) = 0 then 1
					when fg.name like ('%' + @FileGroupName + '%') then 1
					Else 0
					End
		and ps.reserved_page_count >= @LimitLower
		and 1 = (Case when @LimitUpper <= 0 then 1
				when ps.reserved_page_count <= @LimitUpper then 1
				else 0
				End)
		and ps.index_id > 0					-- Don't process heap
	Order By
		[TableName] 
		,[IndexName]
	;

Set @msg = N'Rebuilding Indexes for Database ' + db_name()
		+ case when LEN(@FileGroupName) > 0 then N' FileGroup ' + @FileGroupName else N'' end
		+ ' with minimum pages = ' + Cast(@LimitLower as varchar(24))
		+ ' maximum pages = ' + Cast(@LimitUpper as varchar(24))
		+ N'.  Started @' + convert(VARCHAR(24), getdate(), 120);
RaisError(@msg, 1, 1) with NoWait;

Open cIndexes;
Set @cntProcessed = 0;
While 1 = 1
Begin	-- Process Indexes
	Fetch Next From cIndexes Into @Table, @Index, @IndexId, @FillFactor, @PagesReserved, @PagesUsed
	If @@FETCH_STATUS != 0 Break;
	Set @cntProcessed += 1;
	Set @cmd = N'Alter Index ' + @Index + N' On ' + @Table + N' ReBuild With (MaxDop = 1, FillFactor = ' + 
		Case When coalesce(@FillFactor, 0) <= 0 then @FillFactorDefault
			else Cast(@FillFactor as NVarchar(3))
			End
		+ ');';
	If @Debug > 0
	Begin
		Set @msg =  N'Table = ' + @Table + N', Index = ' + @Index
				+ N' with ' + Cast(@PagesUsed as nvarchar(24)) + N' Pages Used and '
				+ Cast(@PagesReserved as nvarchar(24)) + N' Pages Reserved.';
		Print @msg;
		Print @cmd;
	End
	Begin Try	-- Catch Errors on index rebuild
	If @Debug <= 1
	Begin	-- Run the index rebuild
		Set @StartTime = Getdate();
		Exec sp_executeSQL @cmd;
		Set @msg = N'Table = ' + @Table + N', Index = ' + @Index
			+ N' with ' + Cast(@PagesUsed as nvarchar(24)) + N' Pages Used and '
			+ Cast(@PagesReserved as nvarchar(24)) + N' Pages Reserved.' + NChar(10)
			+ N'Executed Rebuild in ' + cast(DateDiff(ms, @StartTime, getdate()) as nvarchar(24)) + N' ms;';
		RaisError(@msg, 1, 1) with NoWait;
		WaitFor Delay @cmdDelay;
	End;	-- Run the index rebuild
	End Try	-- Catch Errors on index rebuild
	Begin Catch	-- Catch Errors on index rebuild
		SELECT 
			@ErrorMessage = ERROR_MESSAGE()
			,@ErrorNumber = ERROR_NUMBER()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()
			,@ErrorLine = ERROR_LINE()
			,@ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-')
			;
		If @@TranCount > 0 RollBack;
		If @ErrorNumber = 1205	-- Deadlock
		Begin	-- Deadlock Just skip to next index 
			Set @ErrorMessage = 'Deadlock occured during Rebuild. @ErrorNumber = %d.' + @ErrorMessage;
			RaisError(@ErrorMessage, 10, 1, @ErrorNumber) with NoWait;
			Continue;			-- Get next index
		End;	-- Deadlock Just skip to next index 
		Select @table, @index, @PagesReserved, @PagesUsed, @FillFactor;
		Set @msg = Error_Message();
		RaisError(@msg, @ErrorSeverity, 1) with NoWait;	-- rethrow the error and exit
		Break;
	End Catch;	-- Catch Errors on index rebuild
End;	-- Process Indexes
Print 'Processed ' + cast(@cntProcessed as VARCHAR(24)) + ' Indexes.  Completed @' + convert(VARCHAR(24), getdate(), 120) ;

If cursor_status('local', 'cIndexes') > -1 Close cIndexes;
If cursor_status('local', 'cIndexes') > -2 Deallocate cIndexes;

Return;

