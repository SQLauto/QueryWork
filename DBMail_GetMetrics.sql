 
/*
	This query returns metrics related to recent DB Mail events.
	What Mail Items Have Been Sent With Database Mail
	http://www.databasejournal.com/features/mssql/what-mail-items-have-been-sent-with-database-mail.html
	$Archive: /SQL/QueryWork/DBMail_GetMetrics.sql $
	$Revision: 3 $	$Date: 9/20/17 11:17a $

	Seems like this could turn into a useful report in a couple of ways.
		1. Errors sending mail
		2. Stats - who sent how much, how often
		3. ??
*/

Use MSDB

SELECT msi.send_request_date
     , msi.send_request_user
     , msi.subject
	 , msi.sent_status	-- 'sent', 'failed', 'retrying'
	 , [Profile] = sp.name
	 , [Acct] = sa.name
	 , [From] = sa.email_address
	 , [To] = msi.recipients
	 , msi.*
FROM msdb.dbo.sysmail_sentitems As msi
	Inner Join msdb.dbo.sysmail_profile As sp
		On msi.profile_id = sp.profile_id
	Inner Join msdb.dbo.sysmail_account As sa
		On sa.account_id = msi.sent_account_id
	
Where 1 = 1
	And msi.sent_date >= DATEADD(dd,-1,getdate())
	--And msi.sent_status != 'sent'	-- 'sent', 'failed', 'retrying'
/*
Select *
From
	dbo.sysmail_event_log As sel
*/