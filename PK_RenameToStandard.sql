/*
	Script generates code to rename all PK's in current database to PK_<TableName>.

	$Archive: /SQL/QueryWork/PK_RenameToStandard.sql $
	$Date: 15-10-01 14:04 $	$Revision: 1 $

*/

Declare
	@debug		Integer = 2			-- 0 Execute Silently, 1 = Execute verbose, 2 = What if
	, @cmd		Nvarchar(max)
	, @NewLine	NChar(1) = NChar(10)
	;

Set @cmd = N'';
Select @cmd = @cmd + N'Exec sp_Rename @objname = ''' + so.name + N''', @newname = ''PK_' + parent.name + N''', '  + N'@objtype = ''object''' + @NewLine
--	+ parent.type + @NewLine
From
	sys.objects as so
	inner join sys.objects as parent
		on parent.object_id = so.parent_object_id
Where
	so.type = 'PK'
	and parent.type != 'TT'		-- Skip Table Types used as TVP
	and so.name != 'PK_' + parent.name
If @debug > 0 Print @cmd;
If @debug <= 1 Exec sp_executeSQL @cmd;

Return;

Select *
From
	sys.objects as so
Where 1 = 1
	and so.type in ('C', 'D')




