/*
	Script to find all of the small indexes in a database and rebuild them one by one.
	$Archive: /SQL/QueryWork/Idx_RebuildAllSmallInDatabase.sql $
	$Revision: 15 $	$Date: 17-02-10 10:04 $

*/
Set NoCount On
Declare
	@cmdDelay			Char(10) = N'00:00:00'	-- Delay between successive rebuilds
	, @Debug			Integer = 1				--  0 = Execute Silently, 1 = Execute Verbose, 2 = What if?
	, @FillFactorOverRide NVarchar(3) = N'95'
	, @SchemaFilter		Varchar(20) = 'DBO Only'		-- 'All', 'DBO Only', 'Skip pViews', 'pViews Only'
	, @LimitLower		Integer	= 100			-- Lower limit of # pages reserved
	, @LimitUpper		Integer = -1			-- -1 means No upper limit. 1M pages ~8GB index. (HP - DL380 2X6, 128GB, DASD, SQL2008R2 SE)
	, @Mode				NVarchar(20) = N'ReOrg'	-- Set to Rebuild or ReOrg - -defaults to ReOrganize
	, @MaxDop			Integer = 6				-- Should be 1/2 # Cores max
--	********** End controlling parameters	
	, @cmd				NVarchar(4000)
	, @cntProcessed		Integer
	, @dbName			SysName = Db_Name()
	, @DBId				Integer = Db_Id()
	, @FillFactor		Integer = 0
	, @Index			NVarchar(128)
	, @IndexId			Integer
	, @msg				NVarchar(512)
	, @NewLine			NChar(1) = NChar(13)
	, @NowStr			NVarchar(24) = Convert(Varchar(24), GetDate(), 120)
	, @NumIndexes		Integer
	, @PagesReserved	Integer
	, @PagesUsed		Integer
	, @Schema			NVarchar(128)
	, @SchemaId			Integer
	, @StartTime		DateTime
	, @Tab				NChar(1) = NChar(9)
	, @Table			NVarchar(128)
	;

Raiserror('Running Index Rebuild.  Mode = %s. @debug = %d', 10, 0, @Mode, @Debug) With NoWait;

Declare cIndexes Cursor Local Forward_Only For
	Select
		[TableName] = Object_Name(ps.object_id)
		,[SchemaName] = Schema_Name(so.Schema_id)
		,so.schema_id
		,[IndexName] = Coalesce(si.name, 'Heap')
		,ps.index_id
		,si.fill_factor
		,ps.reserved_page_count
		,ps.used_page_count
	From
		sys.dm_db_partition_stats As ps
		Inner Join sys.objects As so
			On so.object_id = ps.object_id
		Inner Join sys.indexes As si
			On si.object_id = ps.object_id
			And si.index_id = ps.index_id
	Where 1 = 1
		And so.type = 'U'						-- Only user tables
		And so.name Not Like 'zDrop_%'			-- Don't process tables that are proposed for Dropping
		And 1 = Case
					When so.schema_id = Schema_Id('zDrop') Then 0	-- Don't process tables that are proposed for Dropping
					When @SchemaFilter = 'All' Then 1
					When @SchemaFilter = 'pViews Only' And Schema_Name(so.schema_id) = 'pViews' Then 1
					When @SchemaFilter = 'Skip pViews' And Schema_Name(so.schema_id) != 'pViews' Then 1
					When @SchemaFilter = 'DBO Only' And Schema_Name(so.schema_id) = 'DBO' Then 1
					Else 0	-- don't process index
					End
		And 1 = (Case When ps.reserved_page_count >= @LimitLower And ps.reserved_page_count <= @LimitUpper Then 1
				When ps.reserved_page_count >= @LimitLower And @LimitUpper <= 0 Then 1
				Else 0
				End)
		And ps.index_id > 0					-- Don't process heap
	Order By
		--so.create_date Desc,		-- use with pViews to process most recently created tables first
		ps.reserved_page_count Desc
		--[TableName] 
		--,[IndexName]
	;

Open cIndexes;
Set @NumIndexes = @@cursor_rows;
Set @cntProcessed = 0;
Raiserror(N'Rebuilding %d Indexes for Database %s with minimum pages = %d and maximum pages = %d.%s@Schema Filter = "%s". Started @%s'
		, 0, 0, @NumIndexes, @dbName, @LimitLower, @LimitUpper, @NewLine, @SchemaFilter, @NowStr) With NoWait;
While 1 = 1
Begin	-- Process Indexes
	Begin Try
	Fetch Next From cIndexes Into @Table, @Schema, @SchemaId, @Index, @IndexId, @FillFactor, @PagesReserved, @PagesUsed
	If @@FETCH_STATUS != 0 Break;
	Set @cntProcessed += 1;
	If @Mode = N'ReBuild'
	Begin
		Set @cmd = N'Alter Index ' + @Index + N' On ' + QuoteName(@Schema) + N'.' + QuoteName(@Table)
			+ N' ReBuild With (MaxDop = ' + Cast(@MaxDop As NVarchar(4))
			 + ', FillFactor = ' + Coalesce(@FillFactorOverRide, Cast(@FillFactor as NVarchar(4)))
			+ ');';
	End
	Else Begin
		Set @cmd = N'Alter Index ' + @Index + N' On ' + QuoteName(@Schema) + N'.' + QuoteName(@Table) + N' Reorganize;';
	End;
	Set @StartTime = GetDate();
	Set @NowStr = Convert(Varchar(24), @StartTime, 120)
	If @Debug > 0
	Begin
		Raiserror(N'/*%s@Cnt = %d. Time %s. Working on Table = %s.%s, Index = %s.%s%s  Pages Used = %d.  Pages Reserved = %d.*/', 0, 0
			, @NewLine, @cntProcessed, @NowStr, @Schema, @Table, @Index, @NewLine, @Tab, @PagesUsed, @PagesReserved) With NoWait;
		Raiserror(@cmd, 0, 0) With NoWait;
	End
	If @Debug <= 1
	Begin
		Exec sp_executeSQL @cmd;
		-- Refresh the pages used and reserverd.
		Select
			@PagesReserved = ps.reserved_page_count
			,@PagesUsed = ps.used_page_count
		From
			sys.dm_db_partition_stats As ps
			Inner Join sys.objects As so
				On so.object_id = ps.object_id
			Inner Join sys.indexes As si
				On si.object_id = ps.object_id
				And si.index_id = ps.index_id
		Where 1 = 1
			And so.type = 'U'					-- Only user tables
			And so.name = @Table
			And so.schema_id = @SchemaId
			And si.name = @Index
		;
		Set @msg = N'Completed Table = ' + @Table + N', Index = ' + @Index
			+ N' with ' + Cast(@PagesUsed As NVarchar(24)) + N' Pages Used and '
			+ Cast(@PagesReserved As NVarchar(24)) + N' Pages Reserved.' + NChar(10)
			+ N'Started At ' + @NowStr + N'. Executed Rebuild in ' + Cast(DateDiff(ms, @StartTime, GetDate()) As NVarchar(24)) + N' ms;';
		Raiserror(@msg, 0, 0) With NoWait;
		WaitFor Delay @cmdDelay;
	End;
	End Try
	Begin Catch
		If Cursor_Status('local', 'cIndexes') > -1 Close cIndexes;
		If Cursor_Status('local', 'cIndexes') > -2 Deallocate cIndexes;
		Declare @ErrMsg NVarchar(2048) = Error_Message()
			, @ErrNum	Integer = Error_Number()
		Select N'Error Item Data.', [Schema] = @Schema, [Table]= @Table, [Index] = @Index, [Pages Res] = @PagesReserved, [Pages Used] = @PagesUsed, [FillFactor] = @FillFactor;
		Raiserror(N'Error Num = @d.%sError Message =%s%s%sTerminating Maintenance.', 16, 1
			, @ErrNum, @NewLine, @NewLine, @ErrMsg, @NewLine) With NoWait;
		Raiserror('Error Cmd = %s%s', 0, 0, @NewLine, @cmd);
		Break;
	End Catch;
End;	-- Process Indexes
Print @NewLine + N'-----' + @NewLine + 'Processed '
	+ Cast(@cntProcessed As Varchar(24)) + ' Indexes.  Completed @' + Convert(Varchar(24), GetDate(), 120) ;

If Cursor_Status('local', 'cIndexes') > -1 Close cIndexes;
If Cursor_Status('local', 'cIndexes') > -2 Deallocate cIndexes;

Return;


