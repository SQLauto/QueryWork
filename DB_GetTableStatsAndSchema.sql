/*

	This script returns row size stats for a specified table (index)
	Table Name, #Rows, Primary Key Columns, Primary Key Size,
	Clustered Index Key columns, and size
	The results provide a "quick" overview of what is important in a database
	from the aspect of table size, granularity, etc.
	Row Size (Fixed size, variable size, Null map, )
	$Archive: /SQL/QueryWork/DB_GetTableStatsAndSchema.sql $
	$Revision: 1 $	$Date: 16-01-05 14:41 $

*/
If Object_Id('tempdb..#tData', 'U') Is Not Null
	Drop Table #tData;
Go
Set NoCount On;

Declare
	@Schema				Sysname = N''
	, @Table			Sysname = N''
	-- **************************************
	, @debug			Integer = 1		-- 0 Execute Silently, 1 = Execute Verbose, 2 = Very Verbose
	, @cmd				NVarchar(max)
	, @ColsPK			Varchar(512)
	, @ColsCI			Varchar(512)
	, @NumVarCols		Integer
	, @PriKey			Integer
	, @SizeCI			Integer
	, @SizePK			Integer
	, @SizeColsFixed	Integer
	, @SizeColsVarMax	Integer
	, @NumNullCols		Integer
	, @SizeAllIndex		Integer
	, @tSchema			Sysname = N''
	, @tName			Sysname = N''
	, @tId				Integer
	, @tNum				Integer

Create Table #tData(PriKey Integer Identity(1, 1)
	, tSchema			SysName
	, tName				SysName
	, tId				Integer
	, tRows				BigInt
	, tTotPages			Int
	, SizeRow			As SizeColsFixed + SizeColsVarMax + SizeNullMap + 4 -- Calculation per BOL
	, SizeAllIndex		Integer
	, SizeTotPerRow		As SizeColsFixed + SizeColsVarMax + SizeNullMap + 4 + SizeAllIndex
	, tNumIndexes		Integer
	, tNumColumns		Integer
	, Has_ClusteredIx	Char(1)
	, Has_UnqCluIx		Char(1)
	, Has_PK			Char(1)
	, Has_ClusteredPK	Char(1)
	, Has_UnqConstraint	Char(1)
	, Pk_Columns		Varchar(512)
	, CI_Columns		Varchar(512)
	, PKId				Integer
	, UnqConstId		Integer
	, SizeClusterKey	Integer
	, SizeColsFixed		Integer
	, SizeColsVarMax	Integer
	, SizeNullMap		Integer
	);

Insert #tData(tSchema, tName, tId, tRows, tTotPages, tNumIndexes, tNumColumns
	, Has_ClusteredIx, Has_UnqCluIx, Has_Pk, Has_UnqConstraint, Has_ClusteredPK, PKId, UnqConstId
	)
	Select Schema_Name(so.schema_id)
		, so.name
		, so.object_id
		, sp.rows
		, (Select Sum(au.total_pages)
			From sys.allocation_units As au 
				Inner Join sys.partitions As sp1
					On au.container_id = sp1.hobt_id Or au.container_id = sp1.partition_id
			Where sp1.object_id = so.object_id)
		, (Select Count(*) From Sys.Indexes As si Where si.object_id = so.object_id)
		, (Select Count(*) From sys.Columns As sc Where sc.object_id = so.object_id)
		, Case When objectproperty(so.Object_id, 'TableHasClustIndex') = 1 Then 'Y' Else 'N' End
		, Case When Coalesce(IndexProperty(so.object_id, si.name, 'IsUnique'), 0) = 1 Then 'Y' Else 'N' End
		, Case When objectproperty(so.Object_id, 'TableHasPrimaryKey') = 1 Then 'Y' Else 'N' End
		, Case When objectproperty(so.Object_id, 'TableHasUniqueCnst') = 1 Then 'Y' Else 'N' End
		, Case When objectproperty(sPK.Object_id, 'CnstIsClustKey') = 1 Then 'Y' Else 'N' End
		, Coalesce(sPK.object_id, Null)
		, (Select Top 1 x.object_id From sys.objects As x Where x.parent_object_id = so.object_id And x.type = 'UQ')
	From
		sys.objects As so
		Inner Join sys.indexes As si
			On si.object_id = so.object_id
			And si.index_id <= 1
		Inner Join sys.partitions As sp
			On sp.object_id = so.object_id
		Left Join sys.objects As sPk
			On sPK.parent_object_id = so.object_id
			And sPK.Type = 'PK'
	Where
		so.type = 'U'
		And sp.index_id <= 1		-- heap or clustered index only.
		And so.schema_id != Coalesce(Schema_Id('zDrop'), -1)
		And so.is_ms_shipped = 0
	Order By
		Schema_Name(so.schema_id)
		, so.name
	;
If @debug > 1 Select * From #tData;
Declare tCursor Cursor Local Static Forward_Only For
	Select PriKey, tSchema, tName, tId From #tData;
Open tCursor;
Set @tNum = @@Cursor_Rows;

While 1 = 1
Begin	-- Process Tables
	Fetch Next From tCursor Into @PriKey, @tSchema, @tName, @tId;
	If @@Fetch_Status != 0 Break;
	Raiserror('Processing %s.%s', 0, 0, @tSchema, @tName) With NoWait;
	Begin	-- Init counters
		Set @ColsPK = N'';
		Set @ColsCI = N'';
		Set @NumNullCols = 0;
		Set @NumVarCols = 0;
		Set @SizeCI = 0;
		Set @SizeColsFixed = 0;
		Set @SizeColsVarMax = 0;
		Set @SizeAllIndex = 0;
	End;	-- Init counters
	Begin	-- GetColumn sizes and counts
		Select
			@SizeColsFixed = @SizeColsFixed + Case
						When st.name In ('VarBinary', 'Varchar', 'NVarchar', 'Text', 'Image', 'SQLVariant')
						Then 0 Else sc.max_length End
			, @SizeColsVarMax = @SizeColsVarMax + Case
						When st.name In ('VarBinary', 'Varchar', 'NVarchar', 'Text', 'Image', 'SQLVariant')
						Then sc.max_length Else 0 End
			, @NumNullCols = @NumNullCols + Case When sc.is_nullable = 1 Then 1 Else 0 End
			, @NumVarCols = @NumVarCols + Case
						When st.name In ('VarBinary', 'Varchar', 'NVarchar', 'Text', 'Image', 'SQLVariant')
						Then 1 Else 0 End
		From Sys.objects As so
			Inner Join sys.columns As sc
				On sc.object_id = so.object_id
			Inner Join sys.types As st
				On st.user_type_id = sc.user_type_id
		Where
			so.object_id = @tId
			;
	End;	-- GetColumn sizes
	Begin	-- Capture PK Columns
		Select @ColsPK = @ColsPK + sc.name + N', '
			, @SizePK = @SizePK + sc.max_length
		From sys.indexes As si
			Inner Join sys.index_columns As ic
				On si.index_id = ic.index_id
				And si.object_id = ic.object_id
			Inner Join sys.columns As sc
				On ic.Object_id = sc.object_id
				And ic.column_id = sc.column_Id
			Inner Join sys.types As st
				On st.user_type_id = sc.user_type_id
		Where
			si.object_id = @tId
			And si.is_primary_key = 1
		Order By
			ic.index_column_id Asc
		;
		If Len(@ColsPK) > 0 Set @ColsPk = Substring(@ColsPK, 1, Len(@ColsPK) - 1) Else Set @ColsPK = '<<No PK>>';
	End	-- Capture PK Columns	
	Begin	-- Get Clustering Key columns and size	
		Select @ColsCI = @ColsCI + sc.name + N', '
			, @SizeCI = @SizeCI + sc.max_length
		From sys.indexes As si
			Inner Join sys.index_columns As ic
				On si.index_id = ic.index_id
				And si.object_id = ic.object_id
			Inner Join sys.columns As sc
				On ic.Object_id = sc.object_id
				And ic.column_id = sc.column_Id
			Inner Join sys.types As st
				On st.user_type_id = sc.user_type_id
		Where
			si.object_id = @tId
			And si.index_id = 1
		Order By
			ic.index_column_id Asc
		;
		If Len(@ColsCI) > 0 Set @ColsCI = Substring(@ColsCI, 1, Len(@ColsCI) - 1) Else Set @ColsCI = '<<No Clustered Index>>';
		If Exists(Select 1 From #tData Where tId = @tId And Has_UnqCluIx = 'N') Set @SizeCI += 4;	-- Adjust for uniquifier
		Set @SizeCI = Coalesce(@SizeCI, 0)

	End;	-- Get Clustering Key columns and size
	Begin	-- Calculate aggregate size of all indexes.
		Select @SizeAllIndex = @SizeAllIndex + sc.max_length + @SizeCI
		From Sys.indexes As si
			Inner Join sys.Index_columns As ic
				On ic.object_id = si.object_id
				And ic.index_id = si.index_id
			Inner Join sys.columns As sc
				On sc.object_id = si.object_id
				And sc.column_id = ic.column_id
		Where
			si.object_id = @tId
			And si.index_id > 1
	End;	-- Calculate aggregate size of all indexes.
	Begin	-- Update calculated values
		Update #tData Set
			PK_Columns			= @ColsPK
			, CI_Columns		= @ColsCI
			, SizeColsFixed		= @SizeColsFixed
			, SizeColsVarMax	= @SizeColsVarMax + 2 + ( 2 * @NumVarCols)	-- Calculation per BOL
			, SizeClusterKey	= @SizeCI
			, SizeNullMap		= 2 + ((@NumNullCols + 7) / 8)				-- Calculation per BOL
			, SizeAllIndex		= @SizeAllIndex
		Where tId = @tId;
	End;	-- Update calculated values
End;	-- Process Tables

If Cursor_Status('local', 'tCursor') >= -1 Close tCursor;
If Cursor_Status('local', 'tCursor') >= -2 Deallocate tCursor;



Select	-- PriKey,
	[Server] = @@ServerName
	, [Database] = Db_Name()
	, tSchema, tName--, tId
	, tRows
	, [TotSize MB] = Cast( tTotPages / 128.0 As Decimal(12, 2))
	, tNumIndexes, tNumColumns, SizeTotPerRow
	, Has_PK, Has_ClusteredPK, [Primary Key] = Pk_Columns
	, Has_ClusteredIx, Has_UnqCluIx
	, [Clustered Index Columns] = Case When Has_ClusteredPK = 'Y' Then 'Same as PK' Else CI_Columns End
	, Has_UnqConstraint
	, SizeClusterKey, SizeColsFixed, SizeColsVarMax, SizeNullMap, SizeRow, SizeAllIndex
	--, PKId, UnqConstId
From #tData;