/*
	This script returns basic index usage data for all tables in the current database
	or for a single table in the current database, or for tables matching a particular name pattern
	
	$Workfile: Idx_Get_UsageForTable.sql $
	$Archive: /SQL/QueryWork/Idx_Get_UsageForTable.sql $
	$Revision: 24 $	$Date: 9/12/17 11:35a $

*/
If Object_Id('tempdb.dbo.#theTables', 'U') Is Not Null
	Drop Table #theTables
Go
Set NoCount On;
Set Transaction Isolation Level Read Uncommitted;

Create Table #theTables(tId Integer);
Declare
	 @Schema				VARCHAR(50)		= 'dbo'	--
	, @Table				VARCHAR(128)	= ''
	, @Match				VARCHAR(50)		= 'Both'	-- Exact Table Name or Wild card on Both ends, Prefix end, Suffix end
	, @is_Include_sys		Integer = 0
	, @is_Include_pViews	Integer = 1
	, @is_Include_zDrop		Integer = 0
	, @LookupCutOff			Integer = -1

	, @DatabaseId			INTEGER = Db_Id()
	, @DatabaseName			VARCHAR(128) = db_name()
	, @RowCount				INTEGER
	, @Now					DATETIME		= GetDate()
	, @SchemaId				INTEGER			= Null
	, @TableId				INTEGER			= Null
	;

Set @SchemaId = Coalesce(Schema_Id(@Schema), 'dbo');
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

Select
	[Schema] = Schema_Name(so.schema_id)
	, [Table Name] = OBJECT_NAME(si.object_id)
	, [Index Name] = coalesce(si.name, 'Heap')
	, [Index Type] = SUBSTRING(coalesce(si.type_desc, 'X'), 1, 1)
	, [User Seeks] = Coalesce(ius.user_seeks, 0)
	, [Last Seek Desc] = Case
					When ius.last_user_seek is null then 'Never'
					When datediff(dd, ius.last_user_seek, @Now) <= 1 Then 'Current'
					When datediff(dd, ius.last_user_seek, @Now) <= 7 Then 'This Week'
					When datediff(dd, ius.last_user_seek, @Now) <= 30 Then 'This Mnth'
					When datediff(dd, ius.last_user_seek, @Now) <= 90 Then 'This Qtr'
					Else 'very Old'
					End
	, [User Lookups] = Coalesce(ius.user_lookups, 0)
	, [Last Lookup Desc] = Case
					When ius.last_user_lookup is null then 'Never'
					When datediff(dd, ius.last_user_lookup, @Now) <= 1 Then 'Current'
					When datediff(dd, ius.last_user_lookup, @Now) <= 7 Then 'This Week'
					When datediff(dd, ius.last_user_lookup, @Now) <= 30 Then 'This Mnth'
					When datediff(dd, ius.last_user_lookup, @Now) <= 90 Then 'This Qtr'
					Else 'very Old'
					End
	, [User Scans] = Coalesce(ius.user_scans, 0)
	, [Last Scan Desc] = Case
					When ius.last_user_scan is null then 'Never'
					When datediff(dd, ius.last_user_scan, @Now) <= 1 Then 'Current'
					When datediff(dd, ius.last_user_scan, @Now) <= 7 Then 'This Week'
					When datediff(dd, ius.last_user_scan, @Now) <= 30 Then 'This Mnth'
					When datediff(dd, ius.last_user_scan, @Now) <= 90 Then 'This Qtr'
					Else 'very Old'
					End
	, [User Updates] = Coalesce(ius.user_updates, 0)
	--, [Last Lookup] = ius.last_user_lookup
	--, [Last Scan] = ius.last_user_scan
	--, [Last Seek] = ius.last_user_seek
	--, [Last Update] = ius.last_user_update
	, [Res MB] = cast(ps.reserved_page_count / 128.0 as decimal(18,3))
	--, [Used MB] = cast(ps.used_page_count / 128.0 as decimal(18,3))
	, [Rows] = Coalesce(ps.row_count, 0)
	, [Date]	= @Now
	, [Server]	= @@ServerName
	, [Database] = @DatabaseName
	--, [Partition Id] = ps.partition_id
	--, [Partition Num] = ps.partition_number
	--, [Index Id]	= si.index_id
	--,ius.*
	--,si.*
From
	sys.indexes as si
	inner join sys.objects as so
		on so.object_id = si.object_id
	Inner Join #theTables As t
		On t.tId = so.object_id
	inner join sys.dm_db_partition_stats as ps
		on ps.object_id = si.object_id and ps.index_id = si.index_id
	left outer join sys.dm_db_index_usage_stats as ius
		on si.object_id = ius.object_id
			and si.index_id = ius.index_id
			and ius.database_id = @DatabaseId
Where 1 = 1
	And so.is_ms_shipped = 0
	--and cast(ps.used_page_count / 128.0 as decimal(18,3)) > 100
	And 1 =  Case When @LookUpCutOff < 0 then 1
				When (ius.user_lookups <= @LookupCutOff and ius.user_scans <= @LookupCutOff and ius.user_seeks <= @LookupCutOff ) Then 1
				Else 0
				End
	--and so.type = 'U'
	--and ius.database_id = @DatabaseId
Order By
	[Schema]
	, [Table Name]
	--, [Index Type]
	--, [Index Name]
	, [Res MB] Desc
	, ius.User_Lookups desc
	--, ius.user_seeks desc
	--, ius.user_lookups
	--, ius.user_scans

Return;

/*
Exec sp_rename @objName = '<table>.<index>', @newname = '<newIndexName>', @objType = 'Index'

Select @@TranCount
--	Commit

*/