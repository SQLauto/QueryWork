
/*
	This script retrieves missing index information for a particular Database
	and ranks the data for evaluation.
	If a table name pattern is specified then data for the matching table names is returned
	The CTE is used to identify the set of tables that have at least one missing index
	that should make a significant improvement.
	The main query returns all of the missing index information for each of the tables in the set.
	The query also returns some basic stats about the table, e.g, NumRows, ResMB, UsedMB.
	
	$Workfile: Idx_Get_MissingForTable.sql $
	$Archive: /SQL/QueryWork/Idx_Get_MissingForTable.sql $
	$Revision: 22 $	$Date: 17-02-10 10:04 $

*/
If Object_Id('tempdb.dbo.#theTables', 'U') Is Not Null
	Drop Table #theTables
Go
Set NoCount On;
Set Transaction Isolation Level Read Uncommitted;

Create Table #theTables(tId Integer);
Declare
	@Schema				Varchar(50)		= 'dbo'
	, @Table			Varchar(128)	= ''
	, @Match			Varchar(50)		= 'Both'	-- Exact Table Name or Wild card on Both ends, Prefix end, Suffix end
	, @is_Include_sys		Int = 0
	, @is_Include_pViews	Int = 1
	, @is_Include_zDrop		Int = 0
	, @DatabaseName		Varchar(128)
	, @DatabaseId		Integer
	, @CostThreshold	Integer			= 100		-- calculated cost must exceed (don't set to  0 :)
	, @Now				DateTime		= GetDate()
	, @RowCount			Integer
	, @SchemaId			Integer
	, @SeekThreshold	Integer			= 100		-- user seeks for recommended index must exceed
	, @TableId			Integer
	;

Set @DatabaseName = db_name();
Set @DatabaseId = Db_Id();
Set @SchemaId = Schema_Id(@Schema);
If @Match = 'Exact'
Begin
	Insert #theTables(tId) (Select so.object_id From sys.objects As so Where name = @Table And schema_id = Schema_Id(@Schema));
	Set @RowCount = @@RowCount;
End
Else
Begin
	Set @Table = Case @Match When 'Both' Then '%' + @Table + '%'
							When 'Suffix' Then @Table + '%'
							When 'Prefix' Then '%' + @Table
							Else '%'
							End;
	Insert #theTables(tId)
		Select so.object_id
		From sys.objects As so
		Where 1 = 1
			And 1 = Case
						When (@is_Include_sys = 0 And so.schema_id = Schema_Id('sys')) Then 0
						When (@is_Include_pViews = 0 And so.schema_id = Schema_Id('pViews')) Then 0
						When (@is_Include_zDrop = 0 And so.schema_id = Schema_Id('zDrop')) Then 0
						When so.name Like @Table And @SchemaId Is Null Then 1
						When so.name Like @Table And so.schema_id = @SchemaId Then 1
						Else 0
					End 
	Set @RowCount = @@RowCount;
End
If @RowCount <= 0
Begin	-- No objects match
	Print 'No objects match criteria.';
	Return;
End;	-- No objects match

-- Identity data for top row of spreadsheet
Select[RunDate]	= @Now
	, [Server]	= @@ServerName
	, [Database] = @DatabaseName
	;
-- The data
;With theTables (databaseId, tableId, schemaId) as 
	(Select Distinct		-- CTE just needs to return each unique DB_id/Table_Id combination
		mid.database_id
		, mid.object_id
		, so.schema_id
	From
		#theTables As tt
		Inner Join sys.dm_db_missing_index_details as mid
			On tt.tid = mid.object_id
		inner join sys.dm_db_missing_index_groups as mig
			on mig.index_handle = mid.index_handle
		inner join sys.dm_db_missing_index_group_stats as migs
			on migs.group_handle = mig.index_group_handle
		inner join sys.objects as so
			on so.OBJECT_ID = mid.object_id
	Where 1 = 1
		And (migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) > @CostThreshold
	)	-- End of theTables
Select
	[Schema] = Schema_Name(t.schemaId)
	, [Table Name] = OBJECT_NAME(mid.object_id, mid.database_id)
	, [Log10 Raw Cost] = cast(log10(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) as Decimal(20, 2))
	, [Cooked Cost] = cast(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) / @CostThreshold as Decimal(20, 0))
	, [User Seeks] = migs.user_seeks
	, [Equal Col] = Replace(Replace(mid.equality_columns, '[', ''), ']', '')
	, [InEql Col] = Replace(Replace(mid.inequality_columns, '[', ''), ']', '')
	, [Include] = Replace(Replace(mid.included_columns, '[', ''), ']', '')
	, [User Cost] = cast(migs.avg_total_user_cost as Decimal(20, 0))
--	, [DB Name] = DB_NAME(mid.database_id)
	, [Num Rows] = ps.row_count
	, [Res MB] = cast(ps.reserved_page_count / 128.0 as decimal(18,1))
	, [Used MB] = cast(ps.used_page_count / 128.0 as decimal(18,1))
	, [RawCost] = cast(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) as Decimal(20, 0))
	, [User Impact] = migs.avg_user_impact
	, [Compiles] = migs.unique_compiles
	, [Last Seek] = migs.last_user_seek
	, [Last Scan] = migs.last_user_scan
	, [User Scans] = migs.user_scans
From
	sys.dm_db_missing_index_details as mid
	inner join theTables as t
		on t.databaseId = mid.database_id and t.tableId = mid.object_id
	inner join sys.dm_db_missing_index_groups as mig
		on mig.index_handle = mid.index_handle
	inner join sys.dm_db_missing_index_group_stats as migs
		on migs.group_handle = mig.index_group_handle
	inner join sys.dm_db_partition_stats as ps
		on ps.object_id = mid.object_id and ps.index_id <= 1	-- get the Heap or Clusterd Index row
Where 1 = 1
	and mid.database_id = DB_ID(@DatabaseName)
	and (migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) >= @CostThreshold
	And migs.user_seeks >= @SeekThreshold
Order By
	[Schema],
	[Table Name],
	mid.equality_columns,
	mid.inequality_columns,
	[Cooked Cost] Desc


Return;

