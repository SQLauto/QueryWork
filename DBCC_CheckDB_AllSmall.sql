/*
	This script determines the databases that DBCC CheckDB can complete in a "reasonable" amount of time, generates
	code for the CheckDB statement, and optionally executes the query.

	$Archive: /SQL/QueryWork/DBCC_CheckDB_AllSmall.sql $
	$Revision: 4 $	$Date: 16-05-12 14:11 $
*/
Use tempdb;
Go
If OBJECT_ID('tempdb..#theDBs', 'U') is not null drop Table #theDBs;
If OBJECT_ID('tempdb..#theResults', 'U') is not null drop Table #theResults;
Go
Set NoCount ON;

Declare
	@cmd			NVarchar(Max)
	, @dbccRes		Varchar(500)
	, @debug		Integer = 1
	, @hRes			Integer
	, @MaintStop	Datetime
	, @NewLine		NChar(1) = NChar(10)
	, @Now			Datetime
	, @PageLimit	Integer = 5000000	-- -1 means No upper limit. 1M pages ~8GB database.  CheckDB typically runs in < 20 minuets (HP - DL380 2X6, 128GB, DASD, SQL2008R2 SE)
	, @thisDB		Sysname
Create Table #theDBs (dbName SysName, dbPages Integer, Start Datetime, Duration Integer, dbStatus Char(2));
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
);

;With theDbs As (
	Select 
		[Name] = db.name
		--, mf.name
		, [Pages] = Sum(mf.size)
	From
		sys.databases As db
		Inner Join sys.master_files As mf
			On mf.database_id = db.database_id
	Where 1 = 1
		And db.name != 'TempDB'
	Group By
		db.name
	)
	
Insert Into #theDBs(dbName, dbPages, dbStatus)
	Select db.Name, db.Pages, 'U'
	From
		theDbs As db
	Where
		1 = Case When @PageLimit < 0 Then 1 When db.Pages <= @PageLimit Then 1 Else 0 End

Select * From #theDBs;

Declare tDB Cursor Local Forward_Only For
	Select dbName From #theDBs;

Open tDB;
While 1 = 1
Begin -- Process databases
	Fetch Next From tDB into @thisDB;
	If @@FETCH_STATUS != 0 Break;
	Set @Now = GETDATE();
	If @MaintStop is not null and @MaintStop < @Now
	Begin
		RaisError('Maintenance Period complete with work remaining', 0, 0) With NoWait;
		Break;
	End;
	Set @cmd = N'DBCC CheckDB(''' + @thisDB + N''') with TableResults;' + @NewLine
	
	If @debug > 0 RaisError('%sStarting Command = %s%s', 0, 0, @NewLine, @NewLine, @cmd) With NoWait;
	Update #theDBs Set Start = @Now Where dbName = @thisDB;
	If @debug <= 1
	Begin
		Truncate Table #theResults;
		Insert #theResults Exec @hRes = sp_executeSQL @cmd;
		Set @dbccRes = (Select Top 1 MessageText From #theResults Where Error = 8989 and MessageText like '%' + @thisDB + '%')
		If @dbccRes like 'CHECKDB found 0 allocation%'
			Update #theDbs set dbStatus = 'G' Where dbName = @thisDB;
		Else Begin
			RaisError('Something is wrong with %s', 0, 0, @thisDB);
			Update #theDbs set dbStatus = 'B' Where dbName = @thisDB;
			Select * From #theResults;
		End;
	End
	Update #theDBs Set Duration = DateDiff(second, @Now, GetDate()) Where dbName = @thisDB;
	RaisError('Completed database %s.', 0, 0, @thisDB);
	
End; -- Process databases

If CURSOR_STATUS('Local', 'tDB') > -1 Close tDB;
If CURSOR_STATUS('Local', 'tDB') > -2 Deallocate tDB;

Select * From #theDBs;
