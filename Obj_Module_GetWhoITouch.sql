/*
	This script returns a list of database user objects and all of the objects that each object reference.
	Also, any Objects that don't reference anything in the database and any objects that reference non-existant
	database objects.

	$Archive: /SQL/QueryWork/Obj_Module_GetWhoITouch.sql $
	$Revision: 2 $	$Date: 17-03-03 15:49 $
*/

Set NoCount On;

If Cursor_Status('Local', 'cModules') >= -1 Close cModules;
If Cursor_Status('Local', 'cModules') >= -2 Deallocate cModules;
If Object_Id('tempdb..#badMods', 'U') Is Not Null Drop Table #badMods;
If Object_Id('tempdb..#objTypes', 'U') Is Not Null Drop Table #objTypes;
If Object_Id('tempdb..#theRefs', 'U') Is Not Null Drop Table #theRefs;

Go
Create Table #theRefs(Id	Integer Identity(1, 1) Primary Key Clustered
	, ModId			Integer
	, ModSchema		Varchar(128)
	, ModName		Varchar(128)
	, ModType		Char(8)
	, RefId			Integer
    , RefType		Char(8)
	, RefSchema		Varchar(128)
	, Refname		Varchar(128)
	, RefMinorName	Varchar(128)
	, isAmbiguous	Char(1)
	, isSchemaQual	Char(1)
	, RefClass		Varchar(128)
	);
Create Table #badMods(Id	Integer Identity(1, 1) Primary Key Clustered
	, ModId			Integer
	, ModSchema		Varchar(128)
	, ModName		Varchar(128)
	, ModType		Char(8)
	, ErrNum		Integer
	, ErrMsg		Varchar(4000)
	);
Create Table #objTypes (id	Integer Identity(1, 1) Primary Key Clustered, objType NChar(2), objCode NChar(8));
Go

Declare
	@debug			Integer = 1				-- 0 = Silent, 1 = verbose, 2 = What if
	, @isExcludePViews	Char(1) = 'Y'		-- Y = exclude pViews schema objects
	, @TgtSchema		SysName
						= N'dbo'		-- ensure proper schema if specifying an object
	, @TgtName			SysName			-- If object_Id(@tgtSchema.@TgtName) is not null then only search for items that touch that object, otherwise do all objects
					 = N''
--		No changeable parameters after this point.
	, @cnt			Integer = 0
	, @isAmbiguous	Integer
	, @IsContinue	Char(1) = 'N'
	, @ModId		Integer
	, @ModSchema	Varchar(128)
	, @ModName		Varchar(128)
	, @ModType		Char(4)
	, @NewLine		NChar(1) = NChar(10)
	, @RefClass		Varchar(128)
	, @RefId		Integer
	, @RefMinorName	Varchar(128)
	, @RefName		Varchar(128)
	, @RefSchema	Varchar(128)
	, @Tab			NChar(1) = NChar(9)
	;
	
Insert Into #objTypes(objType, objCode)
	Values ('AF', 'CLR-Func'), ('F', 'FKey'), ('FN', 'Func-Sc')
			, ('FS', 'CLR-Func'), ('FT', 'CLR-Func'), ('IF', 'Func-IL')
			, ('P', 'Proc'), ('PC', 'CLR-Proc'), ('TA', 'CLR-Trig')
			, ('TF', 'Func-Tab'), ('TR', 'Trig'), ('U', 'Table')
			, ('V', 'View'), ('X', 'XProc')
		;
Declare cModules Cursor Local Static Forward_Only For
	Select so.object_Id, Schema_Name(so.schema_id), so.name, ot.objCode
	From sys.objects As so
		Inner Join #objTypes As ot
			On ot.objType = so.Type Collate SQL_Latin1_General_CP1_CI_AS
	Where 1 = 1
		And (ObjectProperty(so.object_id, 'IsExecuted') = 1
			Or ObjectProperty(so.Object_id, 'IsForeignKey') = 1
			)
		And ObjectProperty(so.object_id, 'IsMSShipped') = 0		-- ONLY user objects
		And so.Schema_id Not In (Schema_Id('zDrop'),  Schema_Id('zDBA'))
		And 1 = Case When @isExcludePViews = 'Y' And so.schema_id = Schema_Id('pViews') Then 0 Else 1 End
		And 1 = Case When Object_Id(@TgtSchema + '.' + @TgtName) Is Null Then 1			-- When Specific Object not indentified, do all
					When so.object_id = Object_Id(@TgtSchema + '.' + @TgtName) Then 1	-- Matches the Specified Object, process it
					Else 0
					End
	;

Truncate Table #theRefs;
Open cModules;
While 1 = 1
Begin	-- process modules
	Fetch Next From cModules Into @ModId, @ModSchema, @ModName, @ModType
	If @@Fetch_Status != 0
	Begin	-- End of Modules
		Break;
	End;	-- End of Modules
	Set @cnt += 1;
	If @Debug > 1 Raiserror('count = %6d, ModType = %s, ModSchema = %s, ModName = %-50s, ModId = %d.', 0, 0, @cnt, @ModType, @ModSchema, @ModName, @ModId)
	Begin Try
		If @debug >= 1 Raiserror('Count = %4d. Processing %s Module %s.%s', 0, 0, @cnt, @ModType, @ModSchema, @ModName) With NoWait;
		Insert #theRefs(ModId, ModSchema, ModName, ModType
				, RefId, RefType, RefSchema, Refname, RefMinorName, isAmbiguous, isSchemaQual, RefClass)
			Select @ModId, @ModSchema, @ModName, @ModType, re.referenced_id, ot.objCode
				, Coalesce(re.referenced_schema_name, Schema_Name(so.schema_id))
				, re.referenced_entity_name, re.referenced_minor_name
				, Case When re.is_ambiguous = 1 Then 'Y' Else 'N' End
				, Case When re.referenced_schema_name Is Null Then 'N' Else 'Y' End
				, re.referenced_class_desc
			From sys.dm_sql_referenced_entities(@ModSchema + '.' + @ModName, 'OBJECT') As re
				Inner Join sys.objects As so
					On so.object_id = re.referenced_id
				Inner Join #objTypes As ot
					On ot.objType = so.Type Collate SQL_Latin1_General_CP1_CI_AS
			;
		If @@RowCount = 0
		Begin		-- the module does not reference any permanent objects 
			Insert #theRefs(ModId, ModSchema, ModName, ModType
				, RefId, RefType, RefSchema, Refname, RefMinorName, isAmbiguous, isSchemaQual, RefClass)
				Select @ModId, @ModSchema, @ModName, @ModType
					, 0, '', '', '**None**', '', '', '', 'No External Ref' 
			;
		End;			-- the module does not reference any permanent objects 	
		If @debug >= 2
			Begin
				Select * From #theRefs;
				Break;
			End;
	End Try
	Begin Catch
		Declare @ErrMsg	NVarchar(max) = Error_Message()
			, @ErrNum	Integer	= Error_Number()
			, @ErrSev	Integer = Error_Severity()
			;
		Set @IsContinue	= 'N';
		If @ErrNum = 2020
		Begin	-- dependencies reported for entity %s do not include references to columns
			Set @isContinue = 'Y';
			Insert Into #badMods(ModId, ModSchema, ModName, ModType, ErrNum, ErrMsg)
				Select @ModId, @ModSchema, @ModName, @ModType, @ErrNum, @ErrMsg;
		End;
		If @IsContinue = 'Y' Continue;		-- keep processing until no more modules.
		Raiserror('Orig ErrNum = %d.  Orig Sev = %d. Orig Message = %s%s', 0, 0, @ErrNum, @ErrSev, @NewLine, @ErrMsg) With NoWait;
		Raiserror('Exiting.  Unrecoverable Error.', 16, 1) With NoWait;
		Break;
	End Catch;
End;	-- process modules

-- Return basic data
If Exists(Select Top 1 * From #theRefs)
	Select ModSchema, ModName, ModType, 'References'
		, RefType, RefSchema, Refname, [Column] = Coalesce(RefMinorName, '')
		, isAmbiguous, isSchemaQual, RefClass
	From #theRefs
	Where 1 = 1
		And 1 = Case When RefSchema = 'pViews' Then 0 Else 1 End
	Order By
		ModType, ModSchema, ModName
		, RefType, RefSchema, RefName, [Column] 
Else Select 'No Valid External References'
	;

-- Return Modules that have errors.
If Exists (Select Top 1 * From #badMods)
	Select ModType, ModSchema, ModName, ErrNum, ErrMsg
		--, N', (''' + ModSchema + N'''), (''' + ModName + N''')'
	From #badMods
	Where 1 = 1
		And ModType != 'Trig'		-- Ignore triggers
	Order By
		ModType, ModSchema, ModName
Else Select 'No Bad Modules.'
;

If Cursor_Status('Local', 'cModules') >= -1 Close cModules;
If Cursor_Status('Local', 'cModules') >= -2 Deallocate cModules;
Return;


Select
	ModType
	, ModSchema
	, ModName
	, [zDrop Snippet] = ', (N''' + ModSchema + ''', N''' + ModName + ''')'
From #badMods
Order By
	ModType, ModSchema, ModName;