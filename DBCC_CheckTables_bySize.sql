/*\
	This script executes DBCC CheckTable and places the
	results in a temp table for analysis.
	$Archive: /SQL/QueryWork/DBCC_CheckTables_bySize.sql $
	$Revision: 2 $	$Date: 15-11-25 16:22 $
*/

If OBJECT_ID('tempdb..#theResults', 'U') is not null
	Drop Table #theResults;
If OBJECT_ID('tempdb..#theInfo', 'U') is not null
	Drop Table #theInfo
Go
Set Nocount On;

Declare
	@debug			Integer = 1			-- 0 = Execute Silently, 1 = Execute Verbose, 2 = What if
	, @BatchNum		Integer	= -1		-- Null means process Batch# = Current DayofWeek, -1 = Process All Batches, 0 - 7 means process that Batch #
	, @is_Exclude_pViews	integer = 1		-- 1 = Exclude pViews Schema
	, @is_Exclude_zDrop	Integer = 1		-- 1 = Exclude zDrop Schema
	, @NumBatches	Integer = 6			-- Number of buckets to divide tables across
	, @PagesMax		Integer = 1000000	-- Maximum Table size in pages (including indexes) to process 1M pages ~5 - 10 minutes.
	, @PagesMin		Integer = 1		-- Minimum Table size in pages (including indexes) to process

	, @cmd			NVarchar(max)	= N''
	, @cnt			Integer			= 0
	, @count		Integer			= 0
	, @cStatus		Integer
	, @Database		NVarchar(128)	= db_name()
	, @Duration		Integer
	, @Pages		Integer
	, @Schema		NVarchar(128)	= N''
	, @StartTime	Datetime
	, @StartTimeStr	NVarchar(24)
	, @Table		NVarchar(128)	= N''
	;

Create Table #theInfo (
	ParentObject	Varchar(128)
	, Object		Varchar(128)
	, Field			Varchar(128)
	, Value			Varchar(128)
	);	
Create Table #theResults(
	Error			Integer
	, Level			Integer
	, State			Integer
	, MessageText	Varchar(500)
	, RepairLevel	Varchar(200)
	, Status		Integer
	, DbId			Integer
	, ObjectId		Integer
	, IndexId		Integer
	, PartitionId	BigInt
	, AllocUnitId	BigInt
	, [File]		Integer
	, Page			Integer
	, Slot			Integer
	, RefFile		Integer
	, RefPage		Integer
	, RefSlot		Integer
	, Allocation	Integer
)
;

Declare cTables Cursor Local Forward_Only For
	With theTables As (
		Select  [theTable] = so.Name
			, [theSchema] = schema_name(so.schema_id)
			, [thePages] = sum(ps.reserved_page_count)
		From Sys.objects as so
			inner join sys.indexes as si
				on si.object_id = so.object_id
			inner join sys.dm_db_partition_Stats as ps
				on ps.object_id = si.object_id
				and ps.index_id = si.index_id
		Where 1 = 1
			and (@is_Exclude_pViews = 1 and so.schema_id != schema_id('pViews'))
			and (@is_Exclude_zDrop = 1 and so.schema_id != schema_id('zDrop'))
			and (@BatchNum < 0
				or (@BatchNum > 0 and so.object_id % @NumBatches = @BatchNum))
		--	and so.name = 'FuelSale_20150920'
		--	and so.schema_id = schema_id('pViews')
		Group By
			so.name
			, so.schema_id
		)
	Select t.theSchema, t.theTable, t.thePages
	From theTables as t
	Where 1 = 1
		and t.thePages >= @PagesMin
		and (t.thePages < @PagesMax
			or @PagesMax <= 0)
	Order By t.thePages desc
	;
If (@BatchNum is Null) or (@BatchNum > 6) Set @BatchNum = datepart(weekday, getdate())
--Capture Database Info from Boot page.
Set @cmd = N'DBCC DBInfo(''' + @Database + N''') With TableResults';
Insert #theInfo
	Exec sp_executeSQL @cmd;

Open cTables
Set @count = @@cursor_rows;
While 1 = 1
Begin	-- Process all tables within size range
	Fetch Next From cTables Into @Schema, @Table, @Pages;
	Set @cStatus = @@fetch_status
	If @cStatus != 0
	Begin
		RaisError('Processed all rows from Cursor.  Status = %d', 0, 0, @cStatus) With NoWait;
		Break;
	End;
	Set @cnt += 1;
	Set @StartTime = getdate();
	Set @StartTimeStr = convert(Nvarchar(24), @StartTime, 121)
	Set @cmd = N'DBCC CheckTable (''' + @Schema + N'.' + @Table + N''') With No_InfoMsgs, All_ErrorMsgs, Data_Purity, TableResults;'
	RaisError('** @cnt = %d of %d. Start Processing @%s.  Processing Table %s.%s with %d pages.', 0, 0, @cnt, @count, @StartTimeStr, @Schema, @Table, @Pages) With NoWait;
	If @Debug <= 1 Insert Into #theResults Exec sp_executeSQL @cmd;
	Set @Duration = datediff(second, @StartTime, getDate());
	RaisError('Processed table in %d seconds', 0, 0, @Duration) With noWait;

End;	-- Process all tables within size range
If cursor_status('local', 'cTables') >= -1 Close cTables;
If cursor_status('local', 'cTables') >= -2 Deallocate cTables;

If Exists (Select * From #theResults where RepairLevel is not null)
Begin
	RaisError('One or More tables have DBCC Errors.  Check the SQL Error Log for Details.', 16, 1) With NoWait;
	Select td.* 
	From #theResults as td
	Where 1 = 1
		and td.RepairLevel is not null;
End;
;

Select td.* 
From #theResults as td
Where 1 = 1;

Select ti.*	--ti.Value
From #theInfo as ti
Where 1 = 1
	--and ti.Field = 'dbi_dbccLastKnownGood';

RaisError('Completed script.', 0, 0) With NoWait;
Return;

