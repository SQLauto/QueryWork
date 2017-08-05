/*
	This script returns a list of database user objects and all of the objects that reference the object.

	$Archive: /SQL/QueryWork/Obj_Module_GetWhoTouchesMe.sql $
	$Revision: 5 $	$Date: 17-04-04 17:52 $
*/

Set NoCount On;

If Cursor_Status('Local', 'cModules') >= -1 Close cModules;
If Cursor_Status('Local', 'cModules') >= -2 Deallocate cModules;
If Object_Id('tempdb..#badTgts', 'U') Is Not Null Drop Table #badTgts;
If Object_Id('tempdb..#NoRefTgts', 'U') Is Not Null Drop Table #NoRefTgts;
If Object_Id('tempdb..#objTypes', 'U') Is Not Null Drop Table #objTypes;
If Object_Id('tempdb..#theRefs', 'U') Is Not Null Drop Table #theRefs;

Go

Declare
	@debug				Integer = 1				-- 0 = Silent, 1 = verbose, 2 = What if
	, @TgtSchema		SysName	= N''
	, @TgtName			SysName = N''			-- If object_Id(@tgtSchema.@TgtName) is not null then only search for items that touch that object, otherwise do all objects
	, @isExcludePViews	Char(1) = 'Y'			-- Y = exclude references to PView subtables.

--		No changeable parameters after this point.
	, @cnt				Integer = 0
	, @isCallerDependent Integer
	, @IsContinue		Char(1)
	, @RefId			Integer
	, @RefClass			NVarchar(60)
	, @RefMinorName		SysName
	, @RefName			SysName					-- Referencing Object
	, @RefSchema		SysName
	, @NewLine			NChar(1) = NChar(10)
	, @Tab				NChar(1) = NChar(9)
	, @TgtId			Integer					-- Object being touched
	, @TgtType			Char(8)
	;

Create Table #theRefs(Id	Integer Identity(1, 1) Primary Key Clustered
	, TgtId			Integer
	, TgtSchema		SysName
	, TgtName		SysName
	, TgtType		Char(8)
	, RefId			Integer
    , RefType		Char(8)
	, RefSchema		SysName
	, RefName		SysName
	, isCallerDependent	Char(1)
	, RefClass		NVarchar(60)
	);
Create Table #NoRefTgts(Id	Integer Identity(1, 1) Primary Key Clustered
	, TgtId			Integer
	, TgtSchema		SysName
	, TgtName		SysName
	, TgtType		Char(8)
	);
Create Table #badTgts(Id	Integer Identity(1, 1) Primary Key Clustered
	, TgtId			Integer
	, TgtSchema		SysName
	, TgtName		SysName
	, TgtType		Char(8)
	, ErrNum		Integer
	, ErrMsg		Varchar(4000)
	);
Create Table #objTypes (id	Integer Identity(1, 1) Primary Key Clustered, objType NChar(2), objCode NChar(8));
	
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
		And ObjectProperty(so.object_id, 'IsMSShipped') = 0
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
	Fetch Next From cModules Into @TgtId, @TgtSchema, @TgtName, @TgtType
	If @@Fetch_Status != 0
	Begin	-- End of Modules
		Break;
	End;	-- End of Modules
	Set @cnt += 1;
	If @Debug > 1 Raiserror('count = %6d, TgtType = %s, TgtSchema = %s, TgtName = %-50s, TgtId = %d.', 0, 0, @cnt, @TgtType, @TgtSchema, @TgtName, @TgtId)
	Begin Try
		If @debug >= 1 Raiserror('Count = %4d. Processing %s Module %s.%s', 0, 0, @cnt, @TgtType, @TgtSchema, @TgtName) With NoWait;
		Insert #theRefs(TgtId, TgtSchema, TgtName, TgtType
				, RefId, RefType, RefSchema, Refname, isCallerDependent, RefClass)
			Select @TgtId, @TgtSchema, @TgtName, @TgtType, re.referencing_id, ot.objCode
				, Coalesce(re.referencing_schema_name, Schema_Name(so.schema_id))
				, re.referencing_entity_name
				, Case When re.is_caller_dependent = 1 Then 'Y' Else 'N' End
				, re.referencing_class_desc
			From sys.dm_sql_referencing_entities(@TgtSchema + '.' + @TgtName, 'OBJECT') As re
				Inner Join sys.objects As so
					On so.object_id = re.referencing_id
				Inner Join #objTypes As ot
					On ot.objType = so.Type Collate SQL_Latin1_General_CP1_CI_AS
			;
		If @@RowCount = 0
		Begin		-- the module is not referenced by any permanent objects 
			Insert #NoRefTgts(TgtId, TgtSchema, TgtName, TgtType)
				Select @TgtId, @TgtSchema, @TgtName, @TgtType
			;
		End;		-- the module is not referenced by any permanent objects  	
		If @debug >= 2
			Begin
				Select * From #theRefs;
				Break;
			End;
	End Try
	Begin Catch
		Declare @ErrMsg		NVarchar(max) = Error_Message()
			, @ErrNum		Integer	= Error_Number()
			, @ErrSev		Integer = Error_Severity()
			;
		Set @IsContinue	= 'N'
		If @ErrNum = 2020
		Begin	-- dependencies reported for entity %s do not include references to columns
			Set @isContinue = 'Y';
			Insert Into #badTgts(TgtId, TgtSchema, TgtName, TgtType, ErrNum, ErrMsg)
				Select @TgtId, @TgtSchema, @TgtName, @TgtType, @ErrNum, @ErrMsg;
		End;
		If @IsContinue = 'Y' Continue;		-- keep processing until no more modules.
		Raiserror('Orig ErrNum = %d.  Orig Sev = %d. Orig Message = %s%s', 0, 0, @ErrNum, @ErrSev, @NewLine, @ErrMsg) With NoWait;
		Raiserror('Exiting.  Unrecoverable Error.', 16, 1) With NoWait;
		Break;
	End Catch;
End;	-- process modules

-- Return basic data
Select TgtId
	, TgtSchema, TgtName, TgtType
	, RefId, RefSchema, RefName, RefType
	, isCallerDependent, RefClass
From #theRefs
Where 1 = 1
	And RefSchema != 'zDrop'
Order By
	TgtType, TgtSchema, TgtName
	, RefType, RefSchema, RefName


Select
	'Not Referenced by any Permanent Object in DB'
	, TgtId		
	, TgtSchema	
	, TgtName	
	, TgtType
From #NoRefTgts
Where 1 = 1
	And 1 = Case When @isExcludePViews = 'Y' And TgtSchema ='pViews' Then 0 Else 1 End
Order By
	TgtType, TgtSchema, TgtName
	;

-- Return Modules that have errors.
If Exists (Select Top 1 * From #badTgts)
	Select N'Error for Tgt (bad references?)', TgtType, TgtSchema, TgtName, ErrNum, ErrMsg
		, N', (''' + TgtSchema + N'''), (''' + TgtName + N''')'
	From #badTgts
	Where 1 = 1
		--And TgtType != 'Trig'
	Order By
		TgtType, TgtSchema, TgtName
Else Select N'No Tgts with reference errors.';

If Cursor_Status('Local', 'cModules') >= -1 Close cModules;
If Cursor_Status('Local', 'cModules') >= -2 Deallocate cModules;
Return;


