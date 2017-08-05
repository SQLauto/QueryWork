/*
	Return the Index names, ids, and columns for specified table
	$Archive: /SQL/QueryWork/tbl_GetIndexDefinitions.sql $
	$Date: 15-09-04 15:55 $	$Revision: 2 $
*/
If Object_Id('tempdb..#theIndexes', 'U') Is Not Null
	Drop Table #theIndexes;
Go

Declare	@debug	Int = 1
  , @Col_Key	NVarchar(Max)
  , @Col_Inc	NVarchar(Max)
  , @Index		NVarchar(128)
  , @IndexId	Int
  , @IndexType	Int
  , @Schema		NVarchar(50) = N''
  , @Table		NVarchar(128) = N''
  , @TableId	Int
  ;
Create Table #theIndexes(s_name NVarchar(128), t_name NVarchar(128), i_name NVarchar(128), i_type Int, k_col NVarchar(Max), i_col NVarchar(Max)
	);

If Len(@Schema) = 0 Set @Schema = 'dbo';
If Len(@Table) > 0
	Set @TableId = OBJECT_ID(@Schema + '.' + @Table, 'U')
Else
	Set @TableId = Null;

Declare cIndex cursor Local Forward_Only For
	Select [Index_Id] = si.index_id
		, [Index_Name] = Case When si.index_id = 0 Then 'HEAP' Else si.name end
		, [Index_Type] = si.Type
		, [Schema] = Schema_Name(so.schema_id)
		, [Table] = so.name
		, [TableId] = so.object_id
	From sys.indexes As si
		Inner Join sys.objects As so
			On so.object_id = si.object_id
	Where 1 = 1
		And 1 = Case When @TableId Is Null Then 1
				When si.object_id = @TableId Then 1
				Else 0
				End
		And so.type In ('U', 'V')
	Order By so.name, si.type, si.index_id
	;
Open cIndex;
While 1 = 1
Begin	-- Process all indexes
	Fetch Next From cIndex Into @IndexId, @Index, @IndexType, @Schema, @Table, @TableId;
	If @@Fetch_Status != 0 Break;

	Set @Col_Key = N'';
	Select @Col_Key = @Col_Key + c.name + N', '
	From sys.index_columns As ic
		Inner Join sys.columns As c
			On c.object_id = ic.object_id
			And c.column_id = ic.column_id
	Where ic.object_id = @TableId
		And ic.index_id = @IndexId
		And ic.is_included_column = 0

	Set @Col_Inc = N'';
	Select @Col_Inc = @Col_Inc + c.name + N', '
	From sys.index_columns As ic
		Inner Join sys.columns As c
			On c.object_id = ic.object_id
			And c.column_id = ic.column_id
	Where ic.object_id = @TableId
		And ic.index_id = @IndexId
		And ic.is_included_column = 1
	Order By
		c.name
	;
	Insert #theIndexes(s_name, t_name, i_name, i_type, k_col, i_col)
		Select
			@Schema
			, @Table
			, @Index
			, @IndexType
			, Case When Len(@Col_Key) > 1 Then Substring(@Col_Key, 1, Len(@Col_Key) - 1) Else @Col_Key End
			, Case When Len(@Col_Inc) > 1 Then Substring(@Col_Inc, 1, Len(@Col_Inc) - 1) Else @Col_Inc End;

End; -- Process All Indexes
If Cursor_Status('local', 'cIndex') >= -1 Close cIndex;
If Cursor_Status('local', 'cIndex') >= -2 Deallocate cIndex;

Select
	[Schema]			= i.s_name
	, [Table]			= i.t_name
	, [Index]			= i.i_name
	, [Index Type]		= Case i.i_type When 0 Then 'H'  When 1 Then 'C' Else 'N' End
	, [Key Columns]		= i.k_col
	, [Include Columns]	= i.i_col
From #theIndexes As i
Order By
	s_name
	, t_name
	, i_type
	, i_name;