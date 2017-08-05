
/*
Adapted From
Automate Alerting for SQL Server Suspect Database Pages
https://www.mssqltips.com/sqlservertip/4166/automate-alerting-for-sql-server-suspect-database-pages/

*/
Declare
	@Count				Integer
	, @TableBody		NVarchar(Max)
	, @eMailSubj		NVarchar(100) = N'Suspect Pages Found in ' + @@ServerName
	, @eMailRecipients	NVarchar(256) = N'ray.herring@simmons-corp.com'
	, @eMailProfile		NVarchar(128) = N'Simmons DBA'
	, @Res				Integer = 0
	;
Select @Count = Count(1)
From msdb.dbo.suspect_pages;

Set @TableBody =
	N'<H1>Suspect Pages Found in ' + @@ServerName + ', details are below.</H1>'
	+ N'<table border="1">'
	+ N'<tr><th>Database ID</th><th>Database</th>'
	+ N'<th>File ID</th><th>File</th><th>Page ID</th>'
	+ N'<th>Event Desc</th><th>Error Count</th><th>Last Updated</th></tr>'
	+	Cast((Select td = sp.database_id, ''
				, td = d.name, ''
				, td = sp.file_id, ''
				, td = mf.physical_name, ''
				, td = sp.page_id, ''
				, td = Case When sp.event_type = 1 Then '823 or 824 error other than a bad checksum or a torn page'
					When sp.event_type = 2 Then 'Bad checksum'
					When sp.event_type = 3 Then 'Torn Page'
					When sp.event_type = 4 Then 'Restored (The page was restored after it was marked bad)'
					When sp.event_type = 5 Then 'Repaired (DBCC repaired the page)'
					When sp.event_type = 7 Then 'Deallocated by DBCC'
					End, ''
				, td = sp.error_count, ''
				, td = sp.last_update_date
			From msdb.dbo.suspect_pages sp
				Inner Join sys.databases d On d.database_id = sp.database_id
				Inner Join sys.master_files mf On mf.database_id = sp.database_id And mf.file_id = sp.file_id
			For Xml Path('tr'), Type 
			) As NVarchar(Max)
			)
	+ N'</table>';

If @Count > 0
Begin
	Exec @Res = msdb.dbo.sp_send_dbmail
		@recipients = @eMailRecipients
		, @body= @TableBody
		, @subject = @eMailSubj
		, @body_format = 'HTML'
		, @profile_name = @eMailProfile
End;

--	Delete From msdb.dbo.suspect_pages Where last_update_date < DateAdd(Day, -90, GetDate())

Return;

