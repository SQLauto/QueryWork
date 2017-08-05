-- $Workfile: Indexes_MoveSpecifiedToFileGroup.sql $
/*
    This script moves specified indexes from their current location to a new
    location specified in a per-set internal table.
    $Archive: /SQL/QueryWork/Indexes_MoveSpecifiedToFileGroup.sql $
    $Revision: 2 $    $Date: 15-03-25 15:50 $

    Have to account for
        1. Constraints - PK, UQ, Clustered/NonClustered
        2. Indexes - Unique, Clustered/NonClustered
        3. Column Order, ASC/DESC
        4. Included Columns
        5. Filter Clause
        6. Out of Space on target FileGroup
        7. Deadlock
*/
If Object_Id('tempdb..#theIndexes', 'U') Is Not Null
    Drop Table #theIndexes;
Go
Set NoCount On;
Declare
    @cmd				NVarchar(max)
    ,@Cols_Include		NVarchar(max)
    ,@Cols_Key			Nvarchar(max)
    ,@Debug				Int = 1         -- 0 = Execute Silently, 1 = Execute Verbose, 2 = Verbose, What-If
    ,@DestinationFG		NVarchar(256)
    ,@FillFactor		Nvarchar(8)
    ,@FilterDef			Nvarchar(max)
    ,@hasFilter			Bit
    ,@Index				NVarchar(128)
    ,@IndexId			Int
    ,@isPK_Constraint	Int
    ,@isUQ_Constraint	Int
    ,@isUQ_Index		Int
    ,@msg				NVarchar(max)
    ,@NewLine			NChar(1) = NChar(10)
    ,@RetVal			Int
    ,@Schema			NVarchar(128)
    ,@SchemaId			Int
    ,@Tab				NChar(1) = NChar(9)
    ,@Table				NVarchar(128)
    ,@TableId			Int
    ;
Create Table #theIndexes (
    PriKey  Int Identity(1, 1) Primary Key
    , SchemaName Nvarchar(128)
    , TableName  Nvarchar(128)
    , IndexName Nvarchar(128)
    , DestinationFG Nvarchar(256)
    );
    
Declare cIndex Cursor Local Forward_Only For
    Select SchemaName, TableName, IndexName, DestinationFG
        , schema_id(SchemaName)
        , Object_id(SchemaName + N'.' + TableName)
        , case when i.IndexName = 'Heap' and si.index_id is null then 0
                    Else si.Index_id
                    End
        , si.filter_definition
        , Case When si.fill_factor = 0 Then N'90' Else Cast(si.fill_factor as NVarchar(8)) End
        , si.has_filter
        , si.is_unique
        , si.is_primary_key
        , si.is_unique_constraint
    From #theIndexes as i
        left outer join Sys.Indexes as si
            on si.object_Id =  Object_id(SchemaName + N'.' + TableName)
            and si.name = i.IndexName
    ;
    
Insert Into #theIndexes(SchemaName, TableName, IndexName, DestinationFG)
    Values
        ('dbo', 'AlliedDynamicSales', 'PK_AlliedDynamicSales', 'ConSIRN_Data_FG_C')
        , ('dbo', 'AlliedDynamicSales', 'idx_alliedDynamicsales', 'ConSIRN_Index_FG_C')
        , ('dbo', 'AutoGasP50Tran', 'PK_AutoGasP50Tran', 'ConSIRN_Data_FG_C')
        , ('dbo', 'AutoGasP50Tran', 'IX_AutoGasP50Tran_SaleDateTimePanelId', 'ConSIRN_Index_FG_C')
        , ('dbo', 'AutoGasP50Tran', 'IX_AutoGasP50Tran_PanelIdDispenserNumSaleDateTime', 'ConSIRN_Index_FG_C')
        , ('dbo', 'AutoGasP50Tran', 'IX_AutoGasP50Tran_JournalId', 'ConSIRN_Index_FG_C')
        , ('dbo', 'VeederRootJournalRow', 'PK_VeederRootJournalRow', 'ConSIRN_Data_FG_C')
        , ('dbo', 'VeederRootJournalRow', 'IX_VeederRootJournalRow_1', 'ConSIRN_Index_FG_C')
        , ('dbo', 'VeederRootJournalRow', 'IX_VeederRootJournalRow', 'ConSIRN_Index_FG_C')
        --, ('zDBA', 'Jobs2Stop4Backup', 'PK_Jobs2Stop4Backup', 'ConSIRN_Data_FG_C')
        --, ('zDBA', 'Jobs2Stop4Backup', 'Ixu_Jobs2Stop4Backup_DbNameJobName', 'ConSIRN_Index_FG_C')
        ;
--Select * from Sys.indexes as si where si.object_id = object_Id('dbo._TempCumOS', 'U')
        
--Select * From #theIndexes;
Open cIndex;
While 1 = 1
Begin -- Process #theIndexes
    Fetch Next From cIndex Into @Schema, @Table, @Index, @DestinationFG,
        @SchemaId, @TableId, @IndexId, @FilterDef, @FillFactor, @hasFilter, @isUQ_Index, @isPK_Constraint, @isUQ_Constraint
    If @@Fetch_Status != 0 Break;
    Set @cmd = N'Dummy';
    Set @msg = N'Dummy';
    Set @Cols_Include = N'';
    Set @Cols_Key = N'';
    If @Debug > 2 Select @Schema, @SchemaId, @Table, @TableId, @Index, @IndexId, @DestinationFG, @isUQ_Index, @isPK_Constraint, @isUQ_Constraint;
    If @SchemaId is null
        or @TableId is Null
        or @IndexId is Null
    Begin   -- Index does not exist.
        RaisError('%sSchema, Table, or Index does not exist. %s.%s.%s.', 16, 0, @NewLine, @Schema, @Table, @Index);
        --Continue;       -- Skip this one.
    End;       -- Index does not exist.
    If @IndexId = 0
    Begin   -- Process Heap
        If @Debug > 0 RaisError('%sTable %s.%s is a Heap.  The heap will not be moved to %s.  However any other Indxes specified will be processed.', 10, 0, @NewLine, @Schema, @Table, @DestinationFG);
        Continue;
    End;    -- Process Heap
    -- Set up string for and included columns
    Select @Cols_Include = @Cols_Include + sc.name + N', '
    From
		Sys.Index_Columns as sic
		Inner Join Sys.Columns as sc
			on sc.object_id = sic.object_Id
			and sc.column_Id = sic.column_id
	Where
		sic.object_id = @TableId
		and sic.Index_id = @IndexId
		and sic.is_included_column = 1
    If Len(@Cols_Include) > 0
    Begin	-- Finish Include string
		Set @Cols_Include = N'Include (' + SubString(@Cols_Include, 1, Len(@Cols_Include) - 1) + N')'
    End;	-- Finish Include string
    -- Set up the Key Columns for Constraint/Index
    Select @Cols_Key = @Cols_Key
		+ sc.name + Case When sic.is_descending_key = 1 Then N' Desc' Else N' Asc' End
		+ N', '
    From
		Sys.Index_Columns as sic
		Inner Join Sys.Columns as sc
			on sc.object_id = sic.object_Id
			and sc.column_Id = sic.column_id
	Where
		sic.object_id = @TableId
		and sic.Index_id = @IndexId
		and sic.is_included_column = 0
	Order By
		sic.key_ordinal Asc;
	Set @Cols_Key = N'(' + SubString(@Cols_Key, 1, Len(@Cols_Key) - 1) + N')';
	-- Set up Filtered Index Where Clause
	If @hasFilter = 1
	Begin		-- Set up Filter Clause
		Set @FilterDef = N'Where ' + @FilterDef + N''
	End;		-- Set up Filter Clause
	-- Now Process the Create, Drop/Alter depending on what we have
    If @isPK_Constraint > 0 or @isUQ_Constraint > 0		--Primary Key or Unique Constraint
    Begin   -- Prep @cmd for Constraints
        If @Debug > 0 RaisError('%sPrep @cmd for Constraint. %s.%s.%s.  @isPK_Constraint = %d, @isUQ_Constraint = %d', 10, 0, @NewLine, @Schema, @Table, @Index, @isPK_Constraint, @isUQ_Constraint);
        Set @cmd = N'Alter Table ' + quotename(@Schema) + N'.' + quotename(@Table)
					+ N' Drop Constraint ' + quotename(@Index)+ @NewLine;
		Set @cmd = @cmd + N'Alter Table ' + quotename(@Schema) + N'.' + quotename(@Table) + N' Add Constraint ' + quotename(@Index)
			+ Case When @isPK_Constraint = 1 Then N' Primary Key' When @isUQ_Constraint = 1 Then N' Unique' Else N'' End
			+ Case @IndexId When 1 Then ' Clustered' Else N' NonClustered' End + @NewLine;
    End;     -- Prep @cmd for Constraints
    Else Begin  -- Prep @cmd for index
        If @Debug > 0 RaisError('%sPrep @cmd for Index. %s.%s.%s', 10, 0, @NewLine, @Schema, @Table, @Index);
        Set @cmd = N'Create'
			+ Case When @isUQ_Index = 1 Then N' Unique' Else N'' End
			+ Case When @IndexId = 1 Then N' Clustered' Else N' NonClustered' End
			+ N' Index ' + QuoteName(@Index)
			+  N' On ' + quotename(@Schema) + N'.' + Quotename(@Table) + @NewLine;    
    End;  -- Prep @cmd for index
	--Now Build the final command
	Set @cmd = @cmd + @Tab + @Cols_Key
		+ Case When Len(@Cols_Include) > 0 Then @NewLine + @Tab + @Cols_Include Else N'' End
		+ Case When @hasFilter = 1 Then @NewLine + @Tab + @FilterDef Else N'' End
		+ @NewLine + @Tab + N'With (' + Case When @isPK_Constraint = 0 and @isUQ_Constraint = 0 Then N'Sort_in_TempDB = On, Drop_Existing = On,' Else N'' End
		+ N' FillFactor = ' + @FillFactor + N')'
		+ @NewLine + N'On [' + @DestinationFG + N'];'
	If @Debug > 1 Print @cmd;
    -- @cmd must have all required code to move the index/constraint
    Begin Try -- Execute the command
        Set @cmd = coalesce(@cmd, '--Null--');
        If @Debug > 0 RaisError('***** Executing @cmd - %s%s', 10 , 0, @NewLine, @cmd);
        --RaisError('Forced Error', 16, 1);
        If @Debug <= 1 Exec sp_executeSQL @cmd;
        If @Debug > 0 RaisError('***** Completed @cmd', 10 , 0);
    End Try -- Execute the command
    Begin Catch -- Error Processing Command
        Set @cmd = N'@cmd = ' + @NewLine + coalesce(@cmd, '--Null--')
                + @NewLine + N'Processing will continue with next Index.'
                + @NewLine + N'*******************************';
        RaisError(' ****>> Error Processing Command. %s', 10, 0, @cmd);
    End Catch; -- Error Processing Command
End; -- Process #theIndexes
If cursor_status('Local', 'cIndex') > -1 Close cIndex;
If cursor_status('Local', 'cIndex') > -2 Deallocate cIndex;