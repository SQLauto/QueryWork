/*
	Ghost Record related queries
	Main query is still WIP.
	<RBH> 20170623
	$Archive: $
	$Revision: $	$Date: $
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

Declare
	@Schema			Varchar(50)		= ''
	, @Table		Varchar(128)	= ''
	, @Match		Varchar(50)		= 'Both'	-- Exact Table Name or Wild card on Both ends, Prefix end, Suffix end
	, @dbId			Integer
	, @SchemaId		Integer
	, @TableId		Integer
	, @IndexId		Integer
	, @PartitionId	Integer
	;
Set @dbid = db_id();
Set @SchemaId = Schema_Id(@Schema);
If @Match = 'Exact'
	Set @TableId = object_id(@Schema + N'.' + @Table, 'U');
Else Begin
	Set @Table = Case @Match
					When 'Both' Then '%' + @Table + '%'
					When 'Suffix' Then @Table + '%'
					When 'Prefix' Then '%' + @Table
					Else '%'
					End;
	Set @TableId = object_id('dbo.TicketHistoryDetail', 'U');
End;
--Set @tableId = Null;
set @indexId = null;
Set @partitionId = Null;
Select
	[Table] = object_name(os.object_Id)
	, [Index] = si.name
	, os.index_id
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