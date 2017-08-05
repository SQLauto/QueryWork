/*
	$Archive: /SQL/QueryWork/DBCC_CheckFileGroup_ToTable_A.sql $
	$Revision: 1 $	$Date: 16-01-05 14:41 $
*/
--DBCC TraceOn (3604, 1)
-- DBCC CheckCatalog (ConSIRN)
--	DBCC CheckAlloc (ConSIRN) With No_InfoMsgs, All_ErrorMsgs, TableResults
If OBJECT_ID('tempdb..#theResults', 'U') is not null Drop Table #theResults;
If object_id ('tempdb..#theInfo', 'U') is not null Drop Table #theInfo;
Go

Declare
	@cmd			NVarchar(Max)
	, @Duration		Integer
	, @FileGroup	NVarchar(128) = N'Primary'
	, @StartTime	Datetime = GetDate()
	;

Create Table #theInfo (
	ParentObject	Varchar(128)
	, Object		Varchar(128)
	, Field			Varchar(128)
	, Value			Varchar(128)
	)
	;

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
Set @cmd = N'dbcc dbinfo with TableResults'
Insert #theInfo Exec sp_ExecuteSQL @cmd;

Set @cmd = N'DBCC CheckFileGroup (''' + @FileGroup + ''') With No_InfoMsgs, All_ErrorMsgs, TableResults'
Insert #theResults Exec sp_ExecuteSQL @cmd;
Set @Duration = datediff(second, @StartTime, getdate());
RaisError('Completed in %d seconds.', 0, 0 , @Duration) With NoWait;

Select r.* From #theResults as r;

Select i.* From #theInfo as i
Where 1 = 1
	 and i.Field = 'dbi_dbccLastKnownGood'
Order By
	i.object
	, i.Field

--	