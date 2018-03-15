/*
	This script determines which database objects are stored on a particular filegroup
	Note when a FG consists of multiple files then you will see multiple rows per object.
	So far I have not found a way to determine the Rows/Space per file.  Only for FG aggregate
		I assume there is something in the Allocation Unit - Sys.Patition relationship I am missing.
	A new DMV added to SQL2012 may provide the data needed to resolve this issue :)
	Currently commented out the file level code.

	$Workfile: FG_GetObjectsIn.sql $
	$Archive: /SQL/QueryWork/FG_GetObjectsIn.sql $
	$Revision: 25 $	$Date: 9/12/17 11:35a $
	
	Read Uncommitted added becuase frequently I run the script when something is "wrong"
	and that means one or more of the dmvs may have a blocking lock :(
*/
Set Transaction Isolation Level Read Uncommitted;

Declare
	@FileGroupName		varchar(256) = ''
	, @PageLimitLower	INT = 0					-- Only return objects > @PageLimitLower
	, @PageLimitUpper	Int = -1				-- Only return objects < @PageLimitUpper, -1 = Return All
	, @Switch			VARCHAR(10)	= 'Both'	-- used to determine how to use @FileGroupName for comparisons.
												-- Prefix = @FileGroupName + '%', Suffix = '%' + @FileGroupName, Both = '%' + @FileGroupName + '%'
												-- Exact = @FileGroupName
	;

Select
	[File Group] = sfg.groupname
	, [SCHEMA] = SCHEMA_NAME(so.schema_id)
	, [Table] = so.name
	, [Index] = coalesce(si.name, 'Heap')
	, [Type] = Case si.index_id When 0 Then 'H' When 1 Then 'C' Else 'N' End
	, sp.rows
	, [Total Space(MB)] = cast((au.total_pages * 8192.0) / (1024.0 * 1000.0) as DECIMAL(12, 2))
	, [Used Space(MB)] = cast((au.used_pages * 8192.0) / (1024.0 * 1000.0) as DECIMAL(12, 2))
	, [Data Space(MB)] = cast((au.data_pages * 8192.0) / (1024.0 * 1000.0) as DECIMAL(12, 2))
	, au.total_pages
	, so.object_id
	, sp.index_id
	, sp.partition_id
	, au.allocation_unit_id
	--, [Drive] = Substring(ssf.filename, 1, 2)
	--, [FileNameLogical] = ssf.name
	--, [FileNamePhysical] = ssf.filename
	--, sp.hobt_id
	--, ssf.*
	--, sfg.*
	--, au.*
	--, sp.*
From
	sys.sysfilegroups as sfg
	--inner join sys.sysfiles as ssf
	--	on ssf.groupid = sfg.groupid
	inner join sys.allocation_units as au
		on au.data_space_id = sfg.groupid
			and (au.type = 1 or au.type = 3)
	inner join sys.partitions as sp
		on sp.hobt_id = au.container_id
	inner join sys.objects as so
		on so.Object_id = sp.object_id
	inner join sys.indexes as si
		on si.object_id = sp.object_id
		and si.index_id = sp.index_id
Where 1 = 1
	and 1 = Case 
			When @Switch = 'Both' and (sfg.groupname like '%' + COALESCE(@FileGroupName, '') + '%') Then 1
			When @Switch = 'Prefix' and (sfg.groupname like COALESCE(@FileGroupName, '') + '%') Then 1
			When @Switch = 'Sufffix' and (sfg.groupname like '%' + COALESCE(@FileGroupName, '')) Then 1
			When @Switch = 'Exact' and (sfg.groupname = @FileGroupName) Then 1
			Else 0
			End
	and so.type = 'U'
	and COALESCE(au.total_pages, 0) >= @PageLimitLower
	and 1 = case when @PageLimitUpper <= 0  then 1
				when COALESCE(au.total_pages, 0) < @PageLimitUpper then 1
				Else 0
				End
	--and so.name not like 'zDrop_%'
	--and si.index_id <= 1
	--and si.index_id > 1
Order By
	[File Group]
	--, [Total Space(MB)] Desc
	--, [Used Space(MB)] Desc
	, [Schema]
	, [Table]
	--si.name,
	, si.index_id


Set Transaction Isolation Level Read Committed;
Return;
	
-- Return individual index sizes
select
	[Table] = object_name(p.Object_id)
	, [Index] =  Coalesce(si.name, 'Heap')
	, [Num rows] =  p.rows
	, [FileGroup] = fg.name
	--, fg.data_space_id	
	, [Total Space(MB)] = cast((au.total_pages * 8192) / (1024 * 1000) as DECIMAL(12, 0))
	, [Used Space(MB)] = cast((au.used_pages * 8192) / (1024 * 1000) as DECIMAL(12, 0))
	, [Data Space(MB)] = cast((au.data_pages * 8192) / (1024 * 1000) as DECIMAL(12, 0))
from sys.partitions p
	inner join sys.allocation_units As au on au.container_id = p.hobt_id
	inner join sys.filegroups fg on fg.data_space_id = au.data_space_id
	Left Join sys.indexes As si On si.object_id = p.object_id And si.Index_ID = p.index_id
where fg.name like '%'	-- =''
Order By
	[Table]
	