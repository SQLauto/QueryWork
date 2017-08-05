/*
	This script generates T-SQL to rename a set of tables
	in preparation for dropping the tables.

*/
Set NoCount On
Declare @theTables table(tName nVarchar(128))
Declare
	@cmd Nvarchar(4000)
	,@NewLine NChar(1)
	,@Now	NChar(8)
	,@Tab	NChar(1)
	;

Set @NewLine = nchar(10);
Set @Tab = nchar(9);
Set @Now = Cast(substring((replace(convert(nvarchar(24), getdate(), 120),'-', '')), 1, 8) as nchar(8));

Insert into @theTables(tName)
Values
	 (N'CurrentReportQueue'), (N'CustomerReportOptions'), (N'CustomerReportQueue'), (N'CustomerReports')
	, (N'CustReportTmp'), (N'ErrReportParameters'), (N'MurphyFilesStautsReport'), (N'ReportLog')
	, (N'ReportLogDeleted'), (N'ReportQueue'), (N'ReportQueueLog'), (N'ReportSortTypes')
	, (N'RptsReportTmp'), (N'SCSReportTmp'), (N'SCReportTmp'), (N'SPTReportLog')
	, (N'tempReport'), (N'tempReportTemp'), (N'tempROIXReport'), (N'tempROIXReportTemp')
;

Set @cmd = N'';
Select
	@cmd = @cmd + N'If Object_Id(''' + tName + N''', ''U'') is not null' + @NewLine
	+ N'Begin' + @NewLine
	+ @Tab + N'Exec sp_rename ''' + tName + N''', ''' + N'zDrop_' + tName + N'_' + @Now + N''';'  + @NewLine
	+ N'End;' + @NewLine
From @theTables
;
Print @cmd;