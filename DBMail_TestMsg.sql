

Exec msdb.dbo.sp_send_dbmail
	@profile_name = 'ClearView_DBA'
	, @subject = 'Test of dal.dg_SQLProdSupportD@DoverFS.com -- From Query Window'
	, @recipients = 'dal.dg_SQLProdSupportD@DoverFS.com'
	, @copy_recipients = 'Ray.Herring@DoverFS.com;Brian.Pugnali@DoverFS.com'
	, @body = 'Testing the Distribution List with Anonymous SMTP.
		Please Reply to Ray.Herring@DoverFS.com if you receive this email.'
	, @reply_to = 'Ray.Herring@DoverFS.com'
	;
