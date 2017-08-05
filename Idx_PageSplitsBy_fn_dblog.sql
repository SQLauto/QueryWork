
/*
	From Paul Randal (SQlSkills.com) PluralSight training course.
	See Also: Steve Stedman - What is a Page Split - http://stevestedman.com/2015/08/page-split/

	$Archive: /SQL/QueryWork/Idx_PageSplitsBy_fn_dblog.sql $
	$Revision: 3 $	$Date: 15-11-25 16:22 $

	This query searches the existing transaction log of the current database
	and reports stats for page splits.  This can take a long time to run on a database with a
	large log (e.g. ConSIRN).

	It took about 30 seconds to run on production Wilco.

	Note: The results are based on the active portion of the Transaction Log which is constantly changing.  Also, the "active" log
	behavior depends on the database recovery model that is currently in effect.
	So, two consecutive executions are unlikely to produce the same results and there is no way to directly and empirically
	correlate the results between runs unless the test environment is tightly controlled.

	If INDEX_A has a count of 80 in one run and a Count of 70 in the next run then the total page splits could be anywhere
	between 80 and 150 or more depending on how quickly the log segments are cycling, how many insert/updates are performed on the index, etc.

	Perhaps take a "snapshot" every 5 minutes or so saving the data (with datetime).  Then look for frequent flyers, high aggregates etc.

	The DBCC calls give an indication of how much log is in use and how often it changes.
*/
Set NoCount Off;

If Object_Id('tempdb..#theDBCC', 'U') Is Not Null
	Drop Table #theDBCC;
Go
Create Table #theDBCC (
	FileId			Int
	, FileSize		BigInt
	, StartOffset	BigInt
	, FSeqNo		BigInt
	, Status		Int
	, Parity		Int
	, CreateLSN		Decimal(26,0)
	)
Insert #theDBCC
	Exec sp_executeSQL N'Dbcc Loginfo()';
Select StartOffset, FSeqNo, [Run Date] = GetDate()
From #theDBCC Where Status = 2;

Select
	[Index] = l.AllocUnitName
	, [SplitType] = Case l.Context
		When N'LCX_INDEX_LEAF' Then N'Nonclustered'
		When N'LCX_CLUSTERED' Then N'Clustered'
		Else N'Non-Leaf'
		End
	--, [First LSN] =  Min(l.[Current LSN])
	--, [Last LSN] = Max(l.[Current LSN])
	, [SplitCount] = Count(1)
From
	fn_dblog(Null, null) As l
Where
	l.operation = N'LOP_DELETE_SPLIT'
Group By
	l.AllocUnitName
	, l.Context
Order By
	l.AllocUnitName
	, l.Context

Return;
/*
Select Top 100 l.*
From
	fn_dblog(Null, null) As l
*/
/*
SELECT sys.fn_PhysLocFormatter(t.%%physloc%%)	-- %%physloc%% returns bigint.  function turns to file:page:slot
       , t.* 
FROM [dbo].[TestTable] as t
WHERE 1 = 1
	and <other conditions>;
*/