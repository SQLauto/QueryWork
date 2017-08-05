/*
	This Script determines the space reservered, used, and available for
	one or more tables and related indexes.
	The sggrgated data is correct even if there are multiple filegroup split across multiple files

	Wild cards are supported

	$Archive: /SQL/QueryWork/tbl_SpaceUsedReservedForTableName.sql $
	$Revision: 13 $	$Date: 17-02-10 10:04 $

*/

Declare
	@Switch				Varchar(10)	= 'Both'	-- used to determine how to use table name for comparisons.
												-- Front = @Table + '%', Rear = '%' + @Table, Both = '%' + @Table + '%'
												-- Exact = @Table
	, @Table			Varchar(256) = ''		-- Empty String matches All Tables
	, @Schema			Varchar(256) = ''		-- Empty String matches All Schema
	, @isExcludeSys		Char(1) = 'Y'			-- Exclude sys schema
	, @isExcludezDrop	Char(1) = 'Y'			-- Exclude tables scheduled for drop
	, @isExcludepViews	Char(1) = 'N'			-- Exclude pView tables.
	, @SchemaId			Integer
	;
Set @SchemaId = Schema_Id(@Schema);

Select
	[Database] = Db_Name()
	, [Schema] = Schema_Name(so.schema_id)
	, [Table] = so.Name
	, [Num Files] = Count(*)
	, [rows] = Max(sp.rows)
	, [Reserved Pages] = Max(ps.reserved_page_count)
	, [Reserved MB] = Sum(ps.reserved_page_count / 128)
	, [Free MB] =  Sum((ps.reserved_page_count - ps.used_page_count) / 128)
	, [Used MB] = Sum(ps.used_page_count / 128)
	, [OverFlow MB] = Sum(ps.row_overflow_used_page_count / 128)
	, [Reserved LOB MB] = Sum(ps.lob_reserved_page_count / 128)
	--, ps.*
	--, sp.*
From
	sys.sysfilegroups as sfg
	inner join sys.sysfiles as ssf
		on ssf.groupid = sfg.groupid
	inner join sys.allocation_units as au
		on au.data_space_id = sfg.groupid
		and (au.type = 1 or au.type = 3)
		and au.type > 0
	inner join sys.partitions as sp
		on sp.hobt_id = au.container_id
	inner join sys.objects as so
		on so.object_id = sp.object_id
	inner join sys.indexes as si
		on si.object_id = sp.object_id
		and si.index_id = sp.index_id
	inner join sys.dm_db_partition_Stats as ps
		on ps.object_id = sp.object_id
		and ps.index_id = sp.index_id
Where 1 = 1
	And 1 = Case When @isExcludeSys = 'Y' And so.schema_id = Schema_Id('Sys') Then 0 Else 1 End
	And 1 = Case When @isExcludezDrop = 'Y' And so.schema_id = Schema_Id('zDrop') Then 0 Else 1 End
	And 1 = Case When @isExcludepViews = 'Y' And so.schema_id = Schema_Id('pViews') Then 0 Else 1 End
	and 1 = Case When @SchemaId Is Null Then 1
				 When so.schema_id = @SchemaId Then 1
				 Else 0
				 End
	and 1 = Case 
			When @Switch = 'Both' and (so.Name like '%' + COALESCE(@Table, '') + '%') Then 1
			When @Switch = 'Front' and (so.Name like COALESCE(@Table, '') + '%') Then 1
			When @Switch = 'End' and (so.Name like '%' + COALESCE(@Table, '')) Then 1
			When @Switch = 'Exact' and (so.Name = @Table) Then 1
			Else 0
			End
Group By
	Schema_Name(so.schema_id)
	, so.Name

Order By
--	[Reserved MB] Desc, 
	[Database]
	, [Schema]
	, [Table]

Return;
