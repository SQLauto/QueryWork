/*
	This script looks for database objects whose the name matches a specified search
	Pattern and drops those objects.
	Typically the objects were previously renamed to match the pattern and then left
	for a period of time.  This is to ensure the object is not used in the applications.
	
	The objects to drop have names in the form
		zDrop_<original_name>_YYYYMMDD
	where YYYYMMDD is the date the object was renamed in preparation for dropping it.
	Cutoff Date is compared to this YYYYMMDD to determine if the object can be dropped.
	
	The default setup will drop objects that were renamed more than 60 days ago.
	
	Note: the DDL actions are logged to Sim_ObjHist.Utlity.dbo.Sim_ObjectHistory using a stored procedure.
	Sim_ObjHist is a local linked server pointing to the Utility Database.
	$Workfile: Dupes_DropByNamePatternAndDate.sql $
	$Archive: /SQL/QueryWork/Dupes_DropByNamePatternAndDate.sql $
	$Revision: 4 $	$Date: 14-05-21 9:01 $

*/
Print 'Check for Return Dummy ;)'
Return	-- Don't execute Accidentally :)

Declare
	@DaysToKeep		Int					-- Number of days to allow renamed object to "Age" before it's dropped.
	,@DBName		Nvarchar(128)
	,@DDL_Op		NVARCHAR(20)
	,@Debug			int
	,@NamePattern	Nvarchar(50)
	,@Now			DateTime
	,@ObjId			Int
	,@ObjName		Nvarchar(128)
	,@ObjType		Nvarchar(4)
	,@ObjTypeDesc	Nvarchar(20)
	,@ObjSchema		Nvarchar(128)
	,@OpStr			Nvarchar(50)
	,@strCmd		Nvarchar(max)
	,@strComment	Nvarchar(256)
	,@strCutOffDate	CHAR(8)
	,@TableName		Nvarchar(256)
	,@User			Nvarchar(128)
	;
Set @DaysToKeep = 60;
Set @NamePattern = N'zDrop_%';
Set @Now = getdate();
Set @strCutOffDate = replace(convert(CHAR(12), dateadd(dd, -@DaysToKeep, @Now), 121), '-', '');	-- YYYYMMDD
Set @User = suser_sname();
Set @DBName = db_name();
Set @strCmd = N'';
Set @Debug = 1;
Set @Debug = 2;
Declare oCursor Cursor Local Forward_Only For
	Select
		so.name
		,coalesce(object_name(so.parent_object_id), '')
		,so.type
		,case so.type
			When 'C'	Then 'Constraint'
			When 'D'	Then 'Constraint'
			When 'F'	Then 'Constraint'
			When 'FN'	Then 'Function'
			When 'IF'	Then 'Function'
			When 'P'	Then 'Procedure'
			When 'TF'	Then 'Function'
			When 'TR'	Then 'Trigger'
			When 'U'	Then 'Table'
			When 'UQ'	Then 'Constraint'
			When 'V'	Then 'View'
			Else 'Object'
			End
		,so.object_id
		,sc.name
	From
		sys.objects as so
		inner join sys.schemas as sc
			on sc.schema_id = so.schema_id
	Where 1 = 1
		and cast(substring(so.name, len(so.name) - 7, 8) as INT) <= cast(@strCutOffDate as int)
		--and so.type in ('FN', 'IF', 'P','TF', 'TR', 'U','V')
		and so.type in ('P', 'U','V')	-- For now only Procedures, Tables, and Views
		and so.name like @NamePattern
	Order By
		so.type
		,so.name
	;
Open oCursor;
--	Begin Transaction;
--	RollBack Transaction;
--	Commit Transaction;
While 1 = 1
Begin	-- Process Cursor data
	Fetch Next From oCursor Into @ObjName, @TableName, @ObjType, @ObjTypeDesc, @ObjId, @ObjSchema
	If @@fetch_status != 0 Break;
	--Print @ObjName + N', ' + @ObjType + N' - ' + Cast(@ObjId as Nvarchar(20));
	Set @strCmd = Case @ObjType
					--When 'C' Then 'Alter Table ' + @ObjSchema + '.' + @TableName + ' Drop Constraint ' + @ObjName		-- Check Constraint
					--When 'D' Then 'Alter Table ' + @ObjSchema + '.' + @TableName + ' Drop Constraint ' + @ObjName		-- Default Constraint
					--When 'F' Then 'Alter Table ' + @ObjSchema + '.' + @TableName + ' Drop Constraint ' + @ObjName		-- Foreign Key Constraint
					--When 'FN' Then 'Drop Function ' + @ObjSchema + '.' + @ObjName
					--When 'IF' Then 'Drop Function ' + @ObjSchema + '.' + @ObjName
					When 'P' Then 'Drop Procedure ' + @ObjSchema + '.' + @ObjName
					--When 'PK' Then 'Alter Table ' + @TableName + ' Drop Constraint '	-- Primary Key Constraint
					--When 'TF' Then 'Drop Function ' + @ObjSchema + '.' + @ObjName
					--When 'TR' Then 'Drop Trigger ' + @ObjSchema + '.' + @ObjName
					When 'U' Then 'Drop Table ' + @ObjSchema + '.' + @ObjName
					--When 'UQ' Then 'Alter Table ' + @ObjSchema + '.' + @TableName + ' Drop Constraint ' + @ObjName	-- Unique Constraint
					When 'V' Then 'Drop View ' + @ObjSchema + '.' + @ObjName
					Else 'Unk Object Type'	-- Force Syntax error
					End
	;
	Set @DDL_Op = substring(@strCmd, 1, charindex(' ', @strCmd, 1));
	If @Debug > 0 Print @strCmd;
	If @Debug <= 1 exec sp_executeSQL @strCmd;
	
	-- Log Action to DBA Object History Log
	Set @strComment = 'Drop_DuplicateObjects script.  Day Cutoff = '
			+ convert(varchar(12), dateadd(dd, -@DaysToKeep, @Now), 120)
			+ '; @strCmd = ' + @strCmd;
	If @debug <= 1
	Begin
		EXEC Sim_ObjHist.Utility.dbo.Sim_ObjectHistoryInsert @DBName = @DBName, @ObjName = @ObjName
			, @ObjType = @ObjTypeDesc, @DDL_Op = @DDL_Op, @OpDate = @Now, @OpUser = @User
			, @OpComment = @strComment, @ObjId = @ObjId;
	End;
	Else Begin
		 print 'Logged: ' + @strComment;
	End;
End;	-- Process Cursor data

If cursor_status('Local', 'oCursor') > -1 Close oCursor;
If cursor_status('Local', 'oCursor') > -2 DeAllocate oCursor;

Return
/*
Exec Sim_ObjHist.Utility.dbo.Sim_ObjectHistory_GetLast10  -- Review last 10 entries to log.

*/