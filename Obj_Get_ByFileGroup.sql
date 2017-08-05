/*
	Based on Script from
		http://gallery.technet.microsoft.com/scriptcenter/c7483555-cc22-4f6c-b9c4-90811eb3bdb6

	List all Objects and Indexes per Filegroup / Partition and Allocation Type 
	including the allocated data size
	
	Optional parameters (mostly like wild cards)  When Null = All or %
		@FG_Name to find all tables and partitions in a single file group.
		@FileName to find all tables and partitions in a single file
		@TableName to find File/File Group for a table
		@SchemName to find Tables in Schema, File, FileGroup.
	The interaction of the parameters can have unexpected results :)
	
	The first result set is grouped by Object (the table and its indexes) and aggregates the space allocated to all components.
	The second result set lists each index separately.
	

	$Workfile: Obj_Get_ByFileGroup.sql $
	$Archive: /SQL/QueryWork/Obj_Get_ByFileGroup.sql $
	$Revision: 16 $	$Date: 16-04-16 10:46 $

*/
/*
	This query aggregates the used space by [File Group].[schema].[table]
	If a table has multiple components in the same file group they will be aggregated to one row.  So
	even tables with the same parition and index structure may have a different number of rows.
	
	The second query breaks the totals down by individual Index.
*/
--Set Statistics Time On
--Set Statistics IO On

Declare
	@FG_Name		NVarchar(256) = N''
	, @FileName		NVARCHAR(256) = N''
	, @Match		VarChar(8) = 'Both'		-- Exact, Wild Card + Suffix, Wild Card + Prefix, Both
	, @isShowZDrop	Char(1) = 'Y'
	, @SizeCutOffMB	integer = 0		-- Only Show objects > @SizeCutOffMB
	, @TableName	NVARCHAR(256) = N''
	, @TableSchema	NVARCHAR(256) = N''
	, @SchemaId		Integer
	;
Set @SchemaId = Schema_Id(@TableSchema);
Set @TableName = Case When @Match = 'Both' Then '%' + Coalesce(@TableName, N'') + '%'
					When @Match = 'Suffix' Then '%' + Coalesce(@TableName, N'')
					When @Match = 'Prefix' Then Coalesce(@TableName, N'') + '%'
					Else @TableName End;

SELECT
	 [Schema]			= SCH.name
	, [Table]			= OBJ.name
	, [Index]			= Coalesce(Idx.Name, 'Heap')
	, [Type]			= Case Idx.Index_Id When 0 then 'H' When 1 Then 'C' Else 'N' End
	, [Drive]			= UPPER(SUBSTRING(df.physical_name, 1, 1))
	, [Total Size (MB)]	= Sum(AU.total_pages / 128)
	, [Used Size (MB)]	= Sum(AU.used_pages / 128)
	, [Data Size (MB)]	= Sum(AU.data_pages / 128)
	, [File Group]		= DS.name
	, [Logical File]	= df.name
	, [File Name]		= df.physical_name
	                            
FROM sys.data_spaces AS DS 
     INNER JOIN sys.allocation_units AS AU 
         ON DS.data_space_id = AU.data_space_id 
     Inner Join sys.database_files as df
		on df.data_space_id = ds.data_space_id
	 INNER JOIN sys.partitions AS PA 
         ON (AU.type IN (1, 3)  
             AND AU.container_id = PA.hobt_id) 
            OR 
            (AU.type = 2 
             AND AU.container_id = PA.partition_id) 
     INNER JOIN sys.objects AS OBJ 
         ON PA.object_id = OBJ.object_id
         and obj.type = 'U'
     INNER JOIN sys.schemas AS SCH 
         ON OBJ.schema_id = SCH.schema_id 
     LEFT JOIN sys.indexes AS IDX 
         ON PA.object_id = IDX.object_id 
            AND PA.index_id = IDX.index_id
Where 1 = 1
	and AU.total_pages >= @SizeCutOffMB * 128
	and 1 = Case When ds.name like '%' + COALESCE(@FG_Name, N'') + '%' Then 1 Else 0 End
	and 1 = Case When df.name like '%' + COALESCE(@FileName, N'') + '%' Then 1 Else 0 End
	and 1 = Case When Obj.schema_id = @SchemaId And obj.name Like @TableName Then 1 
				When @isShowZDrop = 'Y'  And obj.Schema_id = @SchemaId Then 1
				When @isShowZDrop = 'N' And @SchemaId Is Null Then 1
				Else 0 End
	and 1 = Case When OBJ.name like '%' + COALESCE(@TableName, N'') + '%' Then 1 Else 0 End	
	--and obj.name like 'temp%'
Group By
	DS.name
	, df.name
    , SCH.name 
    , OBJ.name
    , Idx.Name
    , Idx.Index_Id
	, df.physical_name
	, UPPER(SUBSTRING(df.physical_name, 1, 1))
ORDER BY
	 [Total Size (MB)] desc
	, [Schema]
	, [Table]
	, [Logical File]
	, [Drive]
	, [File Group]

Return

SELECT
	[File Group]		= DS.name
	,[File Name]		= df.name
	, [Physical Name]		= df.physical_name
	, [Drive]			= UPPER(SUBSTRING(df.physical_name, 1, 1))
	, [Schema Name]		= SCH.name
	, [Table Name]		= OBJ.name
	, [Index Name]		= coalesce(IDX.name, 'Heap')
	, [Index Type]		= Substring(IDX.type_desc, 1, 1)
	, [Total Size (MB)]	= AU.total_pages / 128
	--, [Used Size (MB)]	= AU.used_pages / 128
	--, [Data Size (MB)]	= AU.data_pages / 128
	--, [Object Type]		= OBJ.type_desc
	--, [Allocation Desc]	= AU.type_desc
FROM sys.data_spaces AS DS 
     INNER JOIN sys.allocation_units AS AU 
         ON DS.data_space_id = AU.data_space_id 
     Inner Join sys.database_files as df
		on df.data_space_id = ds.data_space_id
     INNER JOIN sys.partitions AS PA 
         ON (AU.type IN (1, 3)  
             AND AU.container_id = PA.hobt_id) 
            OR 
            (AU.type = 2 
             AND AU.container_id = PA.partition_id) 
     INNER JOIN sys.objects AS OBJ 
         ON PA.object_id = OBJ.object_id 
     INNER JOIN sys.schemas AS SCH 
         ON OBJ.schema_id = SCH.schema_id 
     LEFT JOIN sys.indexes AS IDX 
         ON PA.object_id = IDX.object_id 
            AND PA.index_id = IDX.index_id
Where 1 = 1
	and AU.total_pages >= @SizeCutOffMB * 128
	and 1 = Case When ds.name like '%' + COALESCE(@FG_Name, N'') + '%' Then 1 Else 0 End
	and 1 = Case When df.name like '%' + COALESCE(@FileName, N'') + '%' Then 1 Else 0 End
	and obj.name not like 'zDrop%'
	and obj.name not like 'z_Drop%'
	and 1 = Case When OBJ.name like '%' + COALESCE(@TableName, N'') + '%' Then 1 Else 0 End	
	and 1 = Case When SCHEMA_ID(@TableSchema) is null Then 1
				 When Obj.schema_id = SCHEMA_ID(@TableSchema) Then 1
				 Else 0 End	

ORDER BY
	[File Group] asc
	, [File Name] asc
 --  	, [Schema Name]
	, [Table Name]	
	, [Drive]		
	, [Index Name]
	, [Total Size (MB)] desc
