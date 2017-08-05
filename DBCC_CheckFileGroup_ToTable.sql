/*\
	This script executes DBCC CheckFileGroup and places the
	results in a temp table for analysis.
	$Archive: /SQL/QueryWork/DBCC_CheckFileGroup_ToTable.sql $
	$Revision: 1 $	$Date: 15-10-20 17:28 $
*/

If OBJECT_ID('tempdb..#theResults', 'U') is not null
	Drop Table #theResults;
If OBJECT_ID('tempdb..#theInfo', 'U') is not null
	Drop Table #theInfo
Go

Declare
	@cmd			NVarchar(max)	= N''
	, @Database		NVarchar(128)	= db_name()
	, @FileGroup	NVarchar(128)	= N'ConSIRN_Index_FG_B'
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
Create Table #theInfo (
	ParentObject	Varchar(128)
	, Object		Varchar(128)
	, Field			Varchar(128)
	, Value			Varchar(128)
	);
Set @cmd = N'DBCC DBInfo(''' + @Database + N''') With TableResults';
Insert #theInfo
	Exec sp_executeSQL @cmd;
Select ti.*	--ti.Value
From #theInfo as ti
Where 1 = 1
	and ti.Field = 'dbi_dbccLastKnownGood';
Return
Set @cmd = N'DBCC CheckFileGroup (' + @FileGroup + N') With TableResults;'
Insert Into #theResults
	Exec sp_executeSQL @cmd;

Select td.* 
-- Delete td
From #theResults as td
Where 1 = 1
	and td.MessageText like '%IX_QuietBusyPoint_%'
	--and (td.MessageText like 'There are 0 rows in 0 pages for object "%'
	--	or td.MessageText like 'Cannot process rowset ID %')
;


DBCC TraceON (3604, 01)
DBCC CheckFileGroup ('ConSIRN_Index_FG_B')-- does not change last good
DBCC CheckAlloc()		-- 11 Minutes -- Updates Last Good in DBInfo

DBCC CheckCatalog()		-- 4 seconds -- does not change last good
