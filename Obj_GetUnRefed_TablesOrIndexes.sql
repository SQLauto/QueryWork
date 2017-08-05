/*
	Inspired By
	Identify Unused SQL Server Tables
	https://www.mssqltips.com/sqlservertip/4191/identify-unused-sql-server-tables/#comments
	$Archive: /SQL/QueryWork/Obj_GetUnRefed_TablesOrIndexes.sql $
	$Revision: 1 $	$Date: 16-05-12 14:11 $

-- Create CTE for the unused tables, which are the tables from the sys.objects and 
-- not in the sys.dm_db_index_usage_stats table
*/

-- Get the Last SQL Service Restart
SELECT sqlserver_start_time From sys.dm_os_sys_info

; With UnUsedTables (oSchema, oName, NumRows, CreatedDate, LastModifiedDate) 
As ( 
	Select Distinct
		[oSchema] = Schema_Name(so.schema_id)
		, [oName] = so.name
		, ps.row_count As NumRows
		, so.create_date As CreatedDate
		, so.modify_date As LastModifiedDate
	From sys.objects As so
		Inner Join sys.dm_db_partition_stats ps
			On ps.object_id = so.object_id
		Left Join sys.dm_db_index_usage_stats As ius
			On ius.object_id = so.object_id
	Where 1 = 1
		And so.type ='U'
		And so.schema_id != Schema_Id('zDrop')
		And so.schema_id != Schema_Id('zDBA')
		And so.schema_id != Schema_Id('pViews')
		And so.name Not Like 'MS%'
		And ius.object_id Is Null
		--And Not Exists (Select object_id  
		--			From sys.dm_db_index_usage_stats
		--			Where object_id = so.object_id )
)
-- Select data from the CTE
Select oSchema, oName, NumRows, CreatedDate, LastModifiedDate
From UnUsedTables
Order By
	oSchema
	, oName

Return;

; With UnUsedIndexes (oSchema, oName, iName, iType, IndexId, NumRows, CreatedDate, LastModifiedDate, NumRefs) 
As ( 
	Select
		[oSchema] = Schema_Name(so.schema_id)
		, [oName] = so.name
		, [iName] = Case When si.Index_id = 0 Then 'Heap' Else si.name End
		, [iType] = Case si.index_id When 0 Then 'H' When 1 Then 'C' Else 'N' End
		, [IndexId] = si.index_id
		, ps.row_count As NumRows
		, so.create_date As CreatedDate
		, so.modify_date As LastModifiedDate
		, [NumRefs] = ius.user_seeks + ius.user_scans + ius.user_lookups
	From sys.objects As so
		Inner Join sys.indexes As si
			On si.object_id = so.object_id
		Inner Join sys.dm_db_partition_stats ps
			On ps.object_id = si.object_id
			And ps.index_id = si.index_id
		Left Join sys.dm_db_index_usage_stats As ius
			On ius.object_id = si.object_id
			And ius.index_id = si.index_id
	Where 1 = 1
		And so.type ='U'
		And so.schema_id != Schema_Id('zDrop')
		And so.schema_id != Schema_Id('zDBA')
		And so.schema_id != Schema_Id('pViews')
		And so.name Not Like 'MS%'
		And (ius.object_id Is Null
			Or ius.user_seeks + ius.user_scans + ius.user_lookups = 0)
		--And Not Exists (Select object_id  
		--			From sys.dm_db_index_usage_stats
		--			Where object_id = so.object_id )
)
-- Select data from the CTE
Select oSchema, oName, iName, iType, NumRows, CreatedDate, LastModifiedDate, NumRefs
From UnUsedIndexes
Order By
	NumRefs Desc
	, oSchema
	, oName
	, IndexId

Return;

Select *
From
	sys.dm_db_index_usage_stats As ius
Where
	ius.object_id = Object_Id('dbo.Site', 'U')


