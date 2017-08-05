
Use <DBName>
Go

Declare
	@cmdStr		NVarchar(4000)
	,@SchemaName NVarchar(50)
	,@TableName NVarchar(100)
	,@Today		NVarchar(8)
	;
	
Set @Today = convert(NVarchar(8), getDate(), 112);
Select @Today;

Set @TableName = N'';
Set @SchemaName = N'dbo';
Set @cmdStr = N'sp_rename  ''' + @SchemaName + N'.' + @TableName + N''', ''zDrop_' + @TableName + N'_' + @Today + N'''';
Print @cmdStr;
If Object_id(@SchemaName + '.' + @TableName , 'U') is not Null
Begin
	Print 'Renaming Table ' + @SchemaName + '.' + @TableName;
	Exec sp_ExecuteSQL @cmdStr;
End
Else Print @SchemaName + '.' + @TableName + ' does not exist'
;

