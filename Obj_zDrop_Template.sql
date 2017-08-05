-- $Workfile: Obj_zDrop_Template.sql $
/*
	This script moves designated objects to the zDrop schema
	Objects remain in that schema for a variable length of time (e.g., 180 days) and then are removed from the database.
	$Archive: /SQL/QueryWork/Obj_zDrop_Template.sql $
	$Revision: 5 $	$Date: 16-05-12 14:12 $

*/
--Use <Database>;
Go
If Object_id('tempdb..#zDrop', 'U') is not null
	Drop Table #zDrop;
Go
Set NoCount On
Declare
	@CutOffDate		DateTime = DateAdd(Day, -180, GetDate())	-- Clean up zDrop older than xxx days.
	, @debug		INT	= 1				-- 0 = Execute Silently, 1 = Execute Verbose, 2 = What If?
	, @isDropOld	Int = 1				-- 0 = don't drop older zDrop objects, > 0 = Drop zDrop objects older than xxx days

	-- No options past this point except for the delete list preset for #zDrop
	, @cmd			NVARCHAR(4000)
	, @LineStar		Nchar(80) = Replicate('*', 80)
	, @NewLine		NChar(1) = NChar(10)
	, @now			DateTime = GetDate()
	, @ObjectId		Int
	, @ObjectName	NVARCHAR(128)
	, @ObjectType	NVARCHAR(128)
	, @SchemaName	NVARCHAR(128)
	, @strNow		NCHAR(8)
	;
Create Table #zDrop (id INT IDENTITY(1, 1)
	, SchemaName	NVARCHAR(138)
	, ObjectName	NVARCHAR(128)
	, ObjectType	NVARCHAR(128)
	, ObjectId		Int
	);

-- Edit the following insert to list all of the objects that should be zDropped.
Insert Into #zDrop(SchemaName, ObjectName)
	VALUES
	 (N'<Schema>', N'<object name>')

Set @cmd = N'zDrop script Running @' + Convert(NVarchar(20), @now, 120) + N'.  @debug = %d. @isDropOld = %d. @CutOffDate = ' + Convert(Nvarchar(40), @CutOffDate, 20);
Raiserror (@cmd, 0, 0, @debug, @isDropOld) With NoWait;

Declare c_zDrop Cursor Local Forward_Only For
	Select z.SchemaName, z.ObjectName, z.ObjectId, z.ObjectType
	From #zDrop as z
	;

Set @strNow	= Convert(NCHAR(8), @Now, 112);

If Schema_Id('zDrop') Is Null
Begin
	Set @cmd = N'Create Schema zDrop;'
	If @debug > 0 Print @cmd;
	If @debug <= 1 Exec sp_executeSQL @cmd;
End;

Update z set
	z.ObjectType = Case so.type When 'U'	Then 'Table'
								When 'P'	Then 'Procedure'
								When 'FN'	Then 'Function'
								When 'IF'	Then 'Function'
								When 'TF'	Then 'Function'
								When 'V'	Then 'View'
								When 'TR'	Then 'Trigger'
								Else 'Unk'
								End
	,z.ObjectId = so.object_id
From
	#zDrop as z
	inner join sys.objects as so
		on so.name = z.ObjectName
		and so.schema_id  = schema_id(z.SchemaName)
Where
	z.ObjectId is null
;
If @Debug > 1
	Select * From #zDrop;

Open c_zDrop;
While 1 = 1
Begin	-- Process zDrop changes
	Fetch Next From c_zDrop Into @SchemaName, @ObjectName, @ObjectId, @ObjectType;
	If @@FETCH_STATUS != 0 Break;	-- Completed list
	If @ObjectId Is Null
	Begin	-- Not in database
		Raiserror('%s%s--Object %s.%s does not exist in database.', 0, 0, @LineStar, @NewLine, @SchemaName, @ObjectName);
		Continue;
	End;	-- Not in database
	If Len(@ObjectName) + Len(@SchemaName) > 118	-- Not enough room to add prefix and suffix for new name = <schema>_<name>_YYYYMMDD
	Begin
		Raiserror('%s%s--Cannot zDrop %s.%s.  The name is too long to be modified automatically.', 0, 0, @LineStar, @NewLine, @SchemaName, @ObjectName) With NoWait;
		Continue;
	End;
	Set @cmd = N'Alter Schema zDrop Transfer Object::' + Quotename(@SchemaName) + N'.' + QuoteName(@ObjectName) + N';' + @NewLine
		+ N'Exec sp_rename @objname = ''zDrop.' + @ObjectName + N''''
		+ N', @newname = ''' +  @SchemaName + N'_' + @ObjectName + N'_' + @strNow + N''''
		+ N', @objtype = ' + N'''Object'';';
		
	If @debug > 0 Raiserror('%szDropping Object:%s%s', 0, 0, @NewLine, @NewLine, @cmd);
	If @debug <= 1
	Begin	-- Transfer to zDrop Schema and Rename
		Exec sp_executeSQL @cmd;

	End;	-- Rename and Log Change
	
End;	-- Process zDrop changes

If Cursor_Status('Local', 'c_zDrop') >= -1 Close c_zDrop;
If Cursor_Status('Local', 'c_zDrop') >= -2 Deallocate c_zDrop;

If @isDropOld <= 0
Begin
	Raiserror('Skipping the Drop old objects Process.', 0, 0);
End
Else
Begin	-- Drop Older objects
	Set @cmd = N'Looking for objects zDropped prior to cutoff date = ' + Convert(Varchar(8), @CutOffDate, 112)
	Raiserror('%s%s%s%s%s%s', 0, 0, @NewLine, @LineStar, @NewLine, @cmd, @NewLine, @LineStar);
	Declare c_Drop Cursor Local Forward_Only For
		Select so.name
			, Case so.type When 'U' Then N'Table'
						When 'P' Then N'Procedure'
						When 'V' Then N'View'
						When 'FN' Then N'Function'
						When 'IF' Then N'Function'
						When 'TF' Then N'Function'
				Else N'Unk'
				End
		From
			sys.objects As so
		Where so.schema_id = Schema_Id('zDrop')
			And so.type In ('U', 'P', 'V', 'FN', 'IF', 'TF')

	Open c_Drop;
	While 1 = 1
	Begin	-- Process objects in schema zDrop
	Begin Try
		Fetch Next From c_Drop Into @ObjectName, @ObjectType;
		If @@Fetch_Status != 0 Break;
		Set @strNow = Substring(@ObjectName, Len(@ObjectName) - 7, Len(@ObjectName))	-- last eight chars should be YYYYMMDD
		If IsDate(@strNow) != 1
		Begin	-- not valid name
			Raiserror('%s%s--Invalid name for zDrop object -- %s', 0, 0, @LineStar, @NewLine, @ObjectName);
			Continue;
		End;
		If Cast(@strNow As DateTime) > @CutOffDate
		Begin	-- Object not aged out
			Raiserror('-- Skip %s - %s.', 0, 0, @ObjectType, @ObjectName) With NoWait;
			Continue;
		End;	-- Object not aged out
		-- Set up to drop object
		If @ObjectType = 'Table'
			Set @cmd = N'Truncate Table zDrop.' + QuoteName(@ObjectName) + N';' + @NewLine
		Else Set @cmd = N'';
		Set @cmd = @cmd + N'Drop ' + @ObjectType + N' zDrop.' + QuoteName(@ObjectName) + N';';
		If @debug > 0 Raiserror('%sDropping Object:%s%s', 0, 0, @NewLine, @NewLine, @cmd);
		If @debug <= 1 Exec sp_executeSQL @cmd;			
	End Try
	Begin Catch
		Declare
			@ErrMsg		NVarchar(4000) = Error_Message()
			, @ErrNum	Integer	= Error_Number()
			, @ErrSev	Integer = Error_Severity()
		Raiserror('/*%s%sDrop Failed for cmd =%s%s%sOrig Error Number = %d.  Severity = %d.  Message = %s%s%s%s%s*/', 0, 0, @LineStar, @NewLine, @NewLine, @cmd, @NewLine, @ErrNum, @ErrSev, @NewLine, @ErrMsg, @NewLine, @LineStar, @NewLine);
		Continue;			-- Process remaining items.
	End Catch;

	End;	-- Process objects in schema zDrop
	If Cursor_Status('Local', 'c_Drop') >= -1 Close c_Drop;
	If Cursor_Status('Local', 'c_Drop') >= -2 Deallocate c_Drop;
End;	-- Drop Older objects