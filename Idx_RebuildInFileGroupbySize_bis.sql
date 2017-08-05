/*
	Script to find all of the small indexes in a database and rebuild them one by one.
	$Archive: /SQL/QueryWork/Idx_RebuildInFileGroupbySize_bis.sql $
	$Revision: 3 $	$Date: 16-01-15 13:15 $

*/
Set NoCount On;
Set DeadLock_Priority Low;

Declare
	@Debug					Integer	= 1				-- 0 = Execute Silently, 1 = Execute Verbose, 2 = What If
	, @FileGroupName		NVarChar(128) = N'ConSIRN_Data_FG_B'	--'Primary'
	, @LimitLower			Integer	= 100000		-- Don't process indexs with fewer pages
	, @LimitUpper			Integer = 500000		-- Don't process indexes with more pages. -1 = no uppper limit
	, @FillFactorDefault	NVarChar(3) = '90'
	, @MaxDop				Integer = ((Select cpu_count From sys.dm_os_sys_info) / 2 ) - 1	--  Default to 1 less than cores in a processor
	, @Delay				Char(10) = '00:00:01'
	, @isIgnorepViews		Integer = 1			-- 1 = don't process schema pViews, 0 = do process schema pViews
	, @isIgnorezDrop		Integer = 1			-- 1 = don't process schema zDrop, 0 = do process schema zDrop

--	********************* No options to edit past here.
	, @cmd					NVarChar(4000)
	, @cntIndexes			Integer = 0
	, @cntProcessed			Integer	= 0
	, @DBName				SysName = db_name()
	, @FillFactor			Integer
	, @Index				NVarChar(128)
	, @IndexId				Integer
	, @msg					NVarChar(512)
	, @NewLine				NChar(1) = NChar(10)
	, @NowStr				NVarchar(24) = convert(VARCHAR(24), getdate(), 120)
	, @PagesReserved		Integer
	, @PagesUsed			Integer
	, @Schema				Sysname
	, @StartTime			Datetime
	, @StartTimeStr			NVarChar(24)
	, @Tab					NChar(1) = NChar(9)
	, @Table				NVarChar(128)
	, @ErrorMessage			NVarChar(4000)
	, @ErrorNumber			Integer
	, @ErrorSeverity		Integer
	, @ErrorState			Integer
	, @ErrorLine			Integer
	, @ErrorProcedure		NVarChar(200)
	;

If @MaxDop < 0 Set @MaxDop = 1;
RaisError('Running Index Rebuild with @debug = %d, @MaxDop = %d', 10, 0, @debug, @MaxDop) With NoWait;

Declare cIndexes Cursor Local Static Forward_only For
	Select
		[Schema] = SCHEMA_NAME(so.schema_id)
		, [Table] = OBJECT_NAME(ps.object_id)
		, [Index] = coalesce(si.name, 'Heap')
		, ps.index_id
		, si.fill_factor
		, ps.reserved_page_count
		, ps.used_page_count
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
		and so.name Not like 'sys%'			-- Don't process sysdiagrams, etc.
		and (@isIgnorezDrop = 0
			or (@isIgnorezDrop = 1 and so.schema_id != coalesce(schema_id('zDrop'), -1)))
		and (@isIgnorepViews = 0
			or (@isIgnorepViews = 1 and so.schema_id != coalesce(schema_id('pViews'), -1)))
		and fg.name like '%' + Coalesce(@FileGroupName, '') + '%'
		and ps.reserved_page_count >= @LimitLower
		and (@LimitUpper <= 0
			Or (@LimitUpper > 0 and ps.reserved_page_count <= @LimitUpper))
		and ps.index_id > 0					-- Don't process heap
	Order By
		[Schema]
		, [Table] 
		,[Index]
	;

Open cIndexes;
Set @cntIndexes = @@CURSOR_ROWS;
Set @cntProcessed = 0;
Set @StartTimeStr = convert(VARCHAR(24), getdate(), 120);
Set @msg = N'Rebuilding %d Indexes for Database %s'
		+ Coalesce(N' FileGroup = *' + @FileGroupName + N'*', N'')
		+ ' with minimum pages = %d,  maximum pages = %d.  Started @%s';
RaisError(@msg, 0, 0, @cntIndexes, @DbName, @LimitLower, @LimitUpper, @StartTimeStr) with NoWait;

While 1 = 1
Begin	-- Process Indexes
	Fetch Next From cIndexes Into @Schema, @Table, @Index, @IndexId, @FillFactor, @PagesReserved, @PagesUsed
	If @@FETCH_STATUS != 0 Break;
	Set @cntProcessed += 1;
	Set @cmd = N'Alter Index ' + @Index + N' On ' + @Table + N' ReBuild With (MaxDop = ' + cast(@MaxDop as NVarchar(4))
			+ N', FillFactor = ' + 
			Case When coalesce(@FillFactor, 0) <= 0 then @FillFactorDefault
				else Cast(@FillFactor as NVarChar(3))
				End
			+ ');';
	If @Debug > 0
	Begin
		RaisError(N'%s@Cnt = %d. Working on Table = %s.%s, Index = %s.%s%s  Pages Used = %d.  Pages Reserved = %d.', 0, 0
			, @NewLine, @cntProcessed, @Schema, @Table, @Index, @NewLine, @Tab, @PagesUsed, @PagesReserved) With NoWait;
		RaisError(@cmd, 0, 0) With NoWait;
	End
	Begin Try	-- Catch Errors on index rebuild
	If @Debug <= 1
	Begin	-- Run the index rebuild
		Set @StartTime = Getdate();
		Exec sp_executeSQL @cmd;
		Set @msg = N'Table = ' + @Table + N', Index = ' + @Index
			+ N' with ' + Cast(@PagesUsed as NVarChar(24)) + N' Pages Used and '
			+ Cast(@PagesReserved as NVarChar(24)) + N' Pages Reserved.' + NChar(10)
			+ N'Executed Rebuild in ' + cast(DateDiff(ms, @StartTime, getdate()) as NVarChar(24)) + N' ms;';
		RaisError(@msg, 0, 0) with NoWait;
		WaitFor Delay @Delay;
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
			RaisError(@ErrorMessage, 0, 0, @ErrorNumber) with NoWait;
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

