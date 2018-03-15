/*
	This script gets the row count and approximate space used/reserved for
	all indexes of the specified table(s).
	The table name can be a wild card
	Also returns the physical Files and File Groups
	Note: SQL DMVs already aggregate the counts and sizes when a FG has multiple files.
		Don't sum() them per file group.
		- This returns a row per Allocation unit.  An index may and often does require multiple AU so
			you will see multiple rows that are essential duplicates.
			since this is just a diagnostic for personal use I left this unchanged in the interest of
			capturing the FG and physcial file name.

	$Archive: /SQL/QueryWork/tbl_GetSpaceUsedByIndexes.sql $
	$Revision: 10 $	$Date: 18-02-02 16:14 $
*/

If Object_Id('tempdb.dbo.#theTables', 'U') Is Not Null
	Drop Table #theTables
Go
Set NoCount On;
Create Table #theTables(tId Integer);
Declare
	@Schema				Varchar(50)		= ''
	, @Table			Varchar(128)	= ''
	, @Match			Varchar(50)		= 'Both'	-- Exact Table Name or Wild card on Both ends, Prefix end, Suffix end
	, @MinSize				Int	= -1			-- Minimum size filter in MB
	, @is_Include_sys		Int = 0
	, @is_Include_pViews	Int = 1		--1
	, @is_Include_zDrop		Int = 0

	, @DatabaseName		Varchar(128)
	, @DatabaseId		Integer
	, @Now				DateTime		= GetDate()
	, @RowCount			Integer
	, @SchemaId			Integer
	, @TableId			Integer
	;
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
;With theTables as(
	Select
		so.object_id
		, [TableName] = so.name
		, [SchemaName] =  Schema_Name(so.schema_id)
		, so.create_date
		, so.modify_date
		--,so.*
	From sys.objects as so
		Inner Join #theTables As t
			On t.tid = so.object_id
	Where 1 = 1
	--	Order By [TableName]
	)
Select
	tt.SchemaName
	, tt.TableName
	, [IndexName]		= coalesce(si.name, 'Heap')
	, [Drive]			= substring(ssf.filename, 1, 1)
	, [Type]			= case si.index_id when 0 then 'Heap' when 1 then 'Clustered' else 'Index' end
	, [Reserved(MB)]	= CAST((ps.reserved_page_count) / 128.0 as DECIMAL(12,2))
	, [Used(MB)]		= CAST((ps.used_page_count) / 128.0 as DECIMAL(12,2))	-- 8192.0/ (1024.0 * 1024.0) = 1/128.0
	, [Free(MB)]		= CAST(((ps.reserved_page_count) / 128.0) - ((ps.used_page_count) / 128.0) as DECIMAL(12,2))
	, [Rows]			= (ps.row_count)
	, [FileName]		= ssf.filename
	, [FileGroup]		= sfg.groupname
	, [CreatedOn]		= tt.create_date
	, [LastModified]	= tt.modify_date
	, ips.index_depth
	, ips.index_level
	, si.index_id
From theTables as tt
	inner join sys.dm_db_partition_stats as ps
		on tt.object_id = ps.object_id
	inner join sys.indexes as si
		on si.object_id = tt.object_id 
		and si.index_id = ps.index_id
	inner join sys.partitions as sp
		on sp.partition_Id = ps.partition_id
	inner join sys.allocation_units as au
		on (au.type in (1, 3) and au.Container_id = sp.hobt_id)
		or (au.Type = 2 and au.Container_id = sp.partition_id)
	Inner join sys.sysfilegroups as sfg
		on au.data_space_id = sfg.groupid
	inner join sys.sysfiles as ssf
		on ssf.groupid = sfg.groupid
	Inner Join sys.dm_db_index_physical_stats(DB_ID(), Null, Null, Null, 'Sampled') as ips
		on si.object_id = ips.object_id and si.index_id = ips.index_id
Where 1 = 1
	--and si.index_id <= 1		-- just look at the table
	--and ps.row_count = 0		-- empty tables
	And (ps.reserved_page_count) / 128 >= @MinSize

Order By
	 [Used(MB)] Desc, 	-- = sum(ps.used_page_count) / 128
	tt.SchemaName
	, tt.TableName
	, si.index_id --[IndexName]
	--, [Rows]
Return;	