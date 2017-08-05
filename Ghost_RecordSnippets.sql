/*
	Ghost Record related queries and information

	http://blogs.msdn.com/b/sqljourney/archive/2012/07/28/an-in-depth-look-at-ghost-records-in-sql-server.aspx
	The ghost record(s) presence is registered in:

		The record itself 
		The Page on which the record has been ghosted 
		The PFS for that page (for details on PFS, see Paul Randal’s blog here) http://blogs.msdn.com/b/sqlserverstorageengine/archive/2006/07/08/under-the-covers-gam-sgam-and-pfs-pages.aspx
		The DBTABLE structure for the corresponding database. 
	You can view the DBTABLE structure by using the DBCC DBTABLE command (make sure you have TF 3604 turned on).
	
	*** The following generates A LOT of SQL ERROR LOG entries.  Don't let it run more than 3 or 4 minutes.
	Enable Trace Flag 662 (prints detailed information about the work done by the ghost cleanup task
	when it runs next), and 3605 (directs the output of TF 662 to the SQL errorlog).
	 Please do this during off hours




*/

/*
-- Determine if Ghost record process is running.
If object_id ('tempdb..#myexecrequests', 'U') is not null
	Drop Table #myexecrequests;
Go

SELECT * INTO #myexecrequests FROM sys.dm_exec_requests WHERE 1 = 0;

SET NOCOUNT ON;

DECLARE @a INT
SELECT @a = 0; 
WHILE (@a < 1) 
BEGIN
	INSERT INTO #myexecrequests SELECT * FROM sys.dm_exec_requests WHERE command LIKE '%ghost%'
	SELECT @a = COUNT (*) FROM #myexecrequests
END;

SELECT * FROM #myexecrequests;
Return;

*/

/*
	DBCC TraceStatus	-- Check current Status of trace flags

	DBCC TraceOn(661, 1)	-- Disable Ghost Record Cleanup Process
	DBCC TraceOn(662, 3605, 1)	-- Enable Detailed Ghost Record Logging to SQL Error Log
*/

Declare @dbId	int
	,@tableId	int
	,@indexId	int
	,@partitionId	int
Set @dbid = db_id();
Set @tableId = Null;
set @tableId = object_id('dbo.FuelSale', 'U');
set @indexId = null;
Set @partitionId = Null;
Select
	db_name()
	,[Table] = object_name(os.object_Id)
	,[Index] = si.name
	, os.index_id
	--, os.
	,os.leaf_allocation_count
	,os.leaf_ghost_count
	,os.*
from
	sys.dm_db_index_operational_stats (@dbId, @tableId, @indexId, @partitionId) as os
		inner join sys.indexes as si
			on si.object_id = os.object_id and si.index_id = os.index_id
Where 1 = 1
Order by
	[Table]

--	449664
--	Alter Index PK_FuelSale on FuelSale ReOrganize
--	
--	Alter Index All on FuelSale ReOrganize	-- Started at 2014-03-31 T 1815

/*Index						index_id		leaf_allocation_count	leaf_ghost_count
Ix_FuelSale_CluIndex			1				10339836				1772617716
PK_FuelSale						13				2810888					1772615000
IX_FuelSale_PanelID_ReadingDate	14				4984191					1772607006
*/
/*	-- after two hours of Index ReOrg
Index						index_id		leaf_allocation_count	leaf_ghost_count
Ix_FuelSale_CluIndex			1				10339836				1773895000
PK_FuelSale						13				2810888					1773895000
IX_FuelSale_PanelID_ReadingDate	14				4984191					1773887006

*/