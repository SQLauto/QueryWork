

/*

	$Archive: /SQL/QueryWork/DBMail_TroubleShoot.sql $
	$Revision: 3 $	$Date: 17-11-18 10:00 $

*/

Use MSDB

/*
	Enable DB Mail and Set up DBA Profile.

Exec sp_configure 'show Advanced Options', 1;
Reconfigure with Override;
Go

Exec sp_configure 'Database Mail XPs',  1;
Reconfigure with Override;
Exec sp_configure;

Return;
*/

Declare @StartDate DateTime --	= '2016-05-10 00:00'
	, @EndDate DateTime = GetDate()
	, @Subject NVARCHAR(128) = N''
	;
Print Len(@Subject)

Set @EndDate = DateAdd(Hour, 24, N'2018-01-17 12:00');
Set @StartDate = DateAdd(Hour, -24, @EndDate);

Select 
	[Status] = CASE sm.sent_status
		When 0 Then 'Unsent'
		When 1 Then 'Sent'
		When 2 Then 'Failed'
		When 3 Then 'Retrying'
		End
	, [Subj] = sm.subject
	, [Sent] = sm.sent_date
	, [To] = sm.recipients
	, [From] = sm.from_address
	, [Reply To] = sm.reply_to
	, [Req Date] = sm.send_request_date
	, [Req User] = sm.send_request_user
	, [Profile] = sp.name
	, [CC] = sm.copy_recipients
	, [BC] = sm.blind_copy_recipients
	, [Body] = sm.body
	, [Attachment] = Coalesce(ma.filename, N'No Attachement')
	, [Attachment Size] = Coalesce(ma.filesize, 0) 
	/*
	, [x] = sm.sent_status
	, sm.body_format
	, sm.importance
	, sm.sensitivity
	, sm.file_attachments
	, sm.attachment_encoding
	, sm.query
	, sm.execute_query_database
	, sm.attach_query_result_as_file
	, sm.query_result_header
	, sm.query_result_width
	, sm.query_result_separator
	, sm.exclude_query_output
	, sm.append_query_error
	, sm.sent_account_id
	, sm.last_mod_date
	, sm.last_mod_user
	, sm.profile_id
	, sm.mailitem_id
	*/
From
	dbo.sysmail_mailitems As sm
	Inner Join dbo.sysmail_profile As sp
		On sp.profile_id = sm.profile_id
	Left Join dbo.sysmail_attachments as ma
		on ma.mailitem_id  = sm.mailitem_id
Where 1 = 1
	And 1 = (Case When Len(@Subject) > 0 And sm.Subject Not Like '%' + @Subject + '%' Then 0 Else 1 End)
	And(sm.send_request_date >= @StartDate
		And sm.send_request_date < @EndDate)
Order By sm.send_request_date

--
 Return;

--
/*
Select ml.event_type
	 , ml.log_date
	 , ml.description
	 , ml.account_id
	 , ml.log_id
	 , ml.last_mod_date
	 , ml.last_mod_user
	 --, ml.mailitem_id
-- Select *
From
	dbo.sysMail_Event_log As ml	
	--dbo.sysMail_log As ml
Where 1 = 1
	And ml.log_date >= @StartDate
	And ml.log_date <= @EndDate
Order By
	ml.log_date desc
Return;
--*/

Select Top 1000 *
From
	dbo.sysmail_unsentitems As su
Order By
	su.send_request_date desc

Select Top 1000 *
From
	dbo.sysmail_sentitems As si
Order By
	si.send_request_date desc

Select Top 1000 *
From
	dbo.sysmail_faileditems As sf
Order By
	sf.send_request_date Desc

Select Top 1000 *
From
	dbo.sysmail_allitems As ai
Order By
	ai.send_request_date Desc

/*
myra.canterbury@doverfs.com;teresa.crouch@doverfs.com;khoa.le@doverfs.com
*/
Go
Return

/*
	Shell to send a DBMail.
*/


--	Execute As User = '\';
--	Execute As Login  = '\';
--	Revert;
--/*
Declare
	@Profile			NVarchar(50) = N'SIR25 Mail Profile'
	, @Recipients		NVarchar(2000) = N''
	, @SQL				NVarchar(4000) = N''

	, @Body				NVarchar(2000) = N''
	, @CopyRecipients	NVarchar(2000) = N'Ray.Herring@Hotmail.com;'
	, @NewLine			NChar(1) = NChar(10)
	, @RV				Integer
	, @strDate			NVarchar(50) = Convert(NVarchar(50), GetDate(), 120)
	, @Subj				NVarchar(128)
	;
Set @Subj = N'Test message using profile [' + @Profile + N'] at ' + @strDate;
Set @Body = N'This is a test message sent using TSQL and sp_send_dbmail.' + @NewLine
	 + N'-- Server Name = ' + @@ServerName + @NewLine
	 + N'-- Current DB = ' + Db_Name() + @NewLine
	 + N'-- Current User = ' + SUser_SName() + @NewLine
	 + N'-- Current Time = ' + @strDate
	 ;
Print @Subj;
Print @Recipients;
Print @Body;
   
Exec @RV = msdb.dbo.sp_send_dbmail
	@profile_name = @Profile
	--, @query = @SQL
	--, @query_result_separator = ';'
	--, @attach_query_result_as_file = 1
	--, @query_attachment_filename = 'Ready.csv'
	--, @query_result_width = 32767
	--, @exclude_query_output = 1
	--, @query_result_no_padding = 1
	--, @append_query_error = 0
	--, @query_result_header = 0
	, @recipients = @Recipients
	, @copy_recipients = @CopyRecipients
	, @subject = @Subj
	, @body = @Body
	; 
Raiserror('sp_send_mail results = %d', 0, 0, @RV);

--	Revert;

Return;
--*/