
/*
	This script drops all of the database objects that were "zDropped" a specified
	time in the past.
	This script only processes objects in the current database and only processes objects that can
	be dropped uning the DDL statement Drop <Object Type> <Object Name>.
	The zDrop process renames objects to the form "zDrop_<oldname>_YYYYMMDD" where YYYYMMDD is the
	date the object is renamed.
	If, after a suitable time frame, the object is not restored to its original name then it can be
	Safely dropped from the database.
	$Archive: /SQL/QueryWork/Objects_Drop_zDropped.sql $
	$Revision: 2 $	$Date: 14-05-20 12:09 $

	Status - ready for Production.
*/
Set NoCount On;
Declare
	@cmd			NVARCHAR(4000)
	,@cnt			INTEGER = 0
	,@DaysToRetain	INT = 90		-- number of days to let the object lay fallow
	,@DbName		NVARCHAR(128) = db_name()
	,@Debug			INT = 2			-- 0 - excute sliently, 1 - execute verbose, 2 - no execute verbose, 3 - ?
	,@ErrorMsg		NVARCHAR(256)
	,@ErrorNum		INTEGER
	,@Now			DATETIME = GETDATE()
	,@ObjectId		Integer
	,@ObjectName	Nvarchar(128)
	,@ObjectSchema	NVARCHAR(128)
	,@ObjectSuffix	NVARCHAR(8)
	,@ObjectType	NVARCHAR(24)
	,@RC			INTEGER						-- return code
	,@UserName		NVARCHAR(128) = SUSER_SNAME()	
	;
Set @Debug = 2;
Set @DaysToRetain = 45;
Declare cDrops cursor forward_only local For
	Select
		QUOTENAME(schema_name(so.schema_id)) + '.' + QUOTENAME(so.name)
		,so.Object_id
		,case so.type
			When 'U' Then N'Table '
			When 'P' Then N'Procedure '
			When 'FN' Then N'Function '
			When 'IF' Then N'Function '
			When 'TF' Then N'Function '
			When 'V' Then N'View '
			Else N'I don''t Know!'
			End
		,REVERSE(SUBSTRING(REVERSE(so.name), 1, 8))
	From
		sys.objects as so
	Where
		so.name like 'zDrop%'
		and CAST(REVERSE(SUBSTRING(REVERSE(so.name), 1, 8))as Datetime) < DATEADD(dd, -@DaysToRetain, @Now)
	;

Open cDrops;

While 1 = 1
Begin	-- Process objects
	Fetch Next From cDrops Into @ObjectName, @ObjectId, @ObjectType, @ObjectSuffix
	If @@Fetch_Status != 0 Break	-- Processed all Rows.
	Set @cnt = @cnt + 1;
	--If @debug > 0 Print @ObjectName + N'; ' + @ObjectSchema + N'; ' + @ObjectType + N'; ' + @ObjectSuffix;
	Set @cmd = N'Drop ' + @ObjectType + N' ' + @ObjectName;
	If @debug > 0 RaisError('%s', 1, 1, @cmd) With NoWait;
	If @Debug <= 1
	Begin
	Begin Try
		-- Drop the object
		Exec @RC = sp_executeSQL @cmd;
		-- Log the change
		EXECUTE @RC = [Sim_ObjHist].[Utility].[dbo].[Sim_ObjectHistoryInsert] 
		   @DBName		= @DbName
		  ,@ObjName		= @ObjectName
		  ,@ObjType		= @ObjectType
		  ,@DDL_Op		= 'Drop'
		  ,@OpDate		= @Now
		  ,@OpUser		= @UserName
		  ,@OpComment	= 'Test Removing zDrop objects'
		  ,@ObjId		= @ObjectId
		  ,@DaysToKeep	= 180
		  ;
	End Try
	Begin Catch
		Set @ErrorMsg	= Error_Message();
		Set @ErrorNum	= Error_Number();
		
		RaisError('Error Dropping %s %s. Error Number = %d, @RC = %d.  Error Message = %s', 1, 1, 1
				, @ObjectType, @ObjectName, @ErrorNum, @RC, @ErrorMsg) with nowait;
		Continue;
	End Catch;
	End;
	
End	-- Process objects
RaisError('Dropped a total of %d objects.', 1, 1, @cnt);

If Cursor_Status('local', 'cDrops') > -1 Close cDrops;
If Cursor_Status('local', 'cDrops') > -2 Deallocate cDrops;