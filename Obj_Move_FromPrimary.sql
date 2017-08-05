
/*

	This script generates (and optionally executes) dynamic SQL to move tables and indexes
	from the Primary File Group to a Data or Index file group.
	Assumptions:
		1. Data file group with name of form "<databasename>_Data_FG_A"
		2. Index file group with name of form "<databasename>_Index_FG_A"

	Notes:
	Heaps are not moved.
	TextImage is not modified and Blobs are not moved.
	Min/Max page limits are implemented to help control how much work is actually attempted.
	This is a maintenance window task.  Locking/Blocking are not considered.

	$Archive: /SQL/QueryWork/Obj_MoveFromPrimary.sql $
	$Date: 15-11-25 16:22 $	$Revision: 3 $
*/

Declare @debug		int				= 2			-- 0 = Execute Silently, 1 = Execute Verbose, 2 = What If
	, @PagesMax		Integer			= -1		-- Upper limit.  Don't process indexes greate than @PagesMax.  -1 = no limit.
	, @PagesMin		Integer			= 1			-- Lower limit.  Don't process indexes less than @PagesMin
	, @FileGroupData	NVarchar(128) = '_Data_FG_A'
	, @FileGroupIndex	NVarchar(128) = '_Index_FG_A'
	, @NumFileGroups	Integer		= 1			-- For Rotating File groups based on Object Id
	, @Delay		NChar(8)		= N'00:00:05'

	, @cmd			NVarchar(max)	= N''
	, @cnt			Integer			= 0
	, @colKey		NVarchar(max)	= N''
	, @colInc		NVarChar(max)	= N''
	, @Database		NVarchar(128)	= DB_Name()
	, @FileGroup	NVarchar(128)	= N''
	, @FillFactor	NVarchar(5)		= N''
	, @Index		NVarchar(128)
	, @IndexId		Integer
	, @isClustered	Integer			= 0
	, @isPK			Integer			= 0
	, @isUnqConstraint	Integer		= 0
	, @isUnqIndex	Integer			= 0
	, @OnClause		NVarchar(128)
	, @Pages		Integer			= 0
	, @msg			NVarchar(max)	= N''
	, @NewLine		NChar(1)		= NChar(10)
	, @Schema		NVarchar(50)
	, @Tab			NChar(1)		= NChar(9)
	, @Table		NVarchar(128)
	, @TableId		Integer
	, @WithClause	NVarchar(128)
	;

Set @FileGroupData = @Database + @FileGroupData;
Set @FileGroupIndex = @Database + @FileGroupIndex;
Declare cIndexes Cursor Local Forward_Only For
	Select
		[Table] = so.name
		, [TableId] = so.object_id
		, [Schema] = SCHEMA_NAME(so.schema_id)
		, [Index] = si.name
		, [IndexId] = si.index_id
		, [Current_FG] = ds.name
		, [Pages] = au.total_pages
		, [isClustered] = case When si.index_id = 1 Then 1 Else 0 End
		, [isPK] = si.is_primary_key
		, [isUnqConstraint] = si.is_unique_constraint
		, [isUnqIndex] = si.is_unique
		, [FillFactor] = cast((Case When si.fill_factor = 0 Then 90 Else si.fill_factor end) as NVarchar(5))
	From sys.indexes as si With (ReadUncommitted)
		inner join sys.objects as so With (ReadUncommitted)
			on so.object_id = si.object_id
		inner join sys.data_spaces as ds With (ReadUncommitted)
			on ds.data_space_id = si.data_space_id
		inner join sys.partitions as sp With (ReadUncommitted)
			on sp.object_id = si.object_id
			and sp.index_id = si.index_id
		inner join sys.allocation_units as au With (ReadUncommitted)
			on au.container_id = sp.partition_id
	Where 1 = 1
		and si.index_id > 0					-- skip Heaps
		and so.is_ms_shipped = 0
		And ds.name = 'Primary'				-- Just look at indexes on Primary
		and au.type_desc = 'IN_ROW_DATA'	-- skip Blobs
		and au.total_pages > @PagesMin
		and (@PagesMax <= 0  Or au.total_pages <= @PagesMax)
	Order By
		[Table]
		, si.index_id
	;
Open cIndexes;
While 1 = 1
Begin	-- Process all indexes
	Set @cnt += 1;
	Fetch Next From cIndexes Into @Table, @TableId, @Schema, @Index, @IndexId, @FileGroup, @Pages
								, @isClustered, @isPK, @isUnqConstraint, @isUnqIndex, @FillFactor;
	If @@FETCH_STATUS != 0
	Begin	-- All indexes processed
		Set @cnt -= 1;
		Raiserror ('--%sExit with @@Fetch_Status != 0.  Processed %d items.', 0, 0, @Tab, @cnt) With NoWait;
		Break;
	End;	-- All indexes processed
	-- Set up various standard clauses of the create index statement
	If @NumFileGroups > 1
	Begin
		Set @FileGroupData = Substring(@FileGroupData, 1, Len(@FileGroupData) - 1) + NChar(Ascii('A') + @TableId % @NumFileGroups);
		Set @FileGroupIndex = Substring(@FileGroupIndex, 1, Len(@FileGroupIndex) - 1) + NChar(Ascii('A') + @TableId % @NumFileGroups);
	End;
	If @IndexId = 1 And @FileGroupData = @FileGroup
		Or @IndexId > 1 And @FileGroupIndex = @FileGroup
	Begin
		Raiserror('Table %s, Index %s is on the correct File Group.', 0, 0, @Table, @Index) With NoWait;
		Continue;		-- Skip to next item
	End;
	If @Debug > 0
		RaisError('%s--******%s--Processing Item #%d. Total Pages = %d. Table = %s; Index = %s', 0, 0, @NewLine, @NewLine, @cnt, @Pages, @Table, @Index) With NoWait;
	Set @WithClause = N'With (Drop_Existing = On, FillFactor = ' + @FillFactor + N')';
	Set @OnClause = N'On [' + Case When @isClustered = 1 Then @FileGroupData Else @FileGroupIndex End + N']';
	Set @colInc = N'';
	Set @colKey = N'';
	Select @colKey = @colKey + QUOTENAME(sc.name) + Case When ic.is_descending_key = 1 Then ' Desc' Else ' ASC' End + N', '
	From
		sys.index_columns as ic With (ReadUncommitted)
		inner join sys.columns as sc With (ReadUncommitted)
			on sc.object_id = ic.object_id
			and sc.column_id = ic.column_id
	Where
		ic.index_id = @IndexId
		and ic.object_id = @TableId
		and ic.is_included_column = 0
	Order By
		ic.key_ordinal asc
	;
	If Len(@colKey) > 0 Set @colKey = @Tab + N' (' + substring(@colKey, 1, len(@colKey) - 1) + N')'
	Else Set @colKey = N'';

	Select @colInc = @colInc + QUOTENAME(sc.name) + Case When ic.is_descending_key = 1 Then ' Desc' Else '' End + N', '
	From
		sys.index_columns as ic With (ReadUncommitted)
		inner join sys.columns as sc With (ReadUncommitted)
			on sc.object_id = ic.object_id
			and sc.column_id = ic.column_id
	Where
		ic.index_id = @IndexId
		and ic.object_id = @TableId
		and ic.is_included_column = 1
	Order By
		ic.key_ordinal asc
	;
	If Len(@colInc) > 0 Set @colInc = @Tab + N'Include (' + substring(@colInc, 1, len(@colInc) - 1) + N')'
	Else Set @colInc = N'';
	If @debug > 1
	Begin
		Print N'--With = ' + @WithClause;
		Print N'--On = ' + @OnClause;
		Print N'--Key Columns = ' + @colKey;
		Print N'--Include Columns = ' + coalesce(@colInc, 'NULL');
		Print N'';
	End;
	-- Now start on the create index statement
	-- Check for Primary Key
	If @isPK = 1
	Begin
		If @isClustered = 1 Set @cmd = N'Create Unique Clustered'
		Else Set @cmd = 'Create Unique NonClustered';
	End
	-- Check for Clustered Index
	Else If @isClustered = 1
	Begin
		If @isUnqIndex = 1 Set @cmd = N'Create Unique Clustered'
		Else Set @cmd = N'Create Clustered';
	End
	-- Check for Unique Constraint
	Else If @isUnqConstraint = 1 Or @isUnqIndex = 1
	Begin
		Set @cmd = N'Create Unique NonClustered';
	End
	-- Process normal nonclustered index
	Else Set @cmd = N'Create NonClustered'
	;

	-- Build the whole commmand
	Set @cmd = @cmd + N' Index ' + @Index + N' On ' + Quotename(@Schema) + N'.' + QuoteName(@Table) + @NewLIne
		+ @colKey + @NewLine + Case When len(@colInc) > 1 Then @colInc + @NewLine Else N'' End
		+ @WithClause + @NewLine
		+ @OnClause
		+ N';'
	If @debug <= 1 Set @cmd = N'WaitFor Delay N''' + @Delay + N''';' + @Newline + @cmd;
	Set @cmd = N'Print GetDate();' + @NewLine
			+ @cmd + @NewLine + 'RaisError(''Processed Item # = ' + cast(@cnt as NvarChar(5)) +  '; @Table = ' + @Table + ', @Index = ' + @Index + '.'', 0, 0) With NoWait;'
			+ @NewLine + N'Print GetDate();';
	If @debug > 0 Print @cmd;
	If @debug <= 1
	Begin
		Exec sp_executeSQL @cmd;
		WaitFor Delay @Delay;
	End;
End;	-- Process all indexes

If CURSOR_STATUS('local', 'cIndexes') >= -1 Close cIndexes;
If CURSOR_STATUS('local', 'cIndexes') >= -2 Deallocate cIndexes;