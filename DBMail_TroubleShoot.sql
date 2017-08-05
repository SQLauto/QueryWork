

Use MSDB

Declare @StartDate DateTime --	= '2016-05-10 00:00'
	, @EndDate DateTime = GetDate()

Set @StartDate = DateAdd(Hour, -24, @EndDate);
--Set @EndDate = DateAdd(Hour, 24, @StartDate);

Select *
From
	dbo.sysMail_log As ml
Where 1 = 1
	And ml.log_date >= @StartDate
	And ml.log_date <= @EndDate
Order By
	ml.log_date asc
Return;


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
The mail could not be sent to the recipients because of the mail server failure.
 (Sending Mail using Account 1 (2016-05-14T23:00:06). 
 Exception Message: Cannot send mails to mail server. 
 (The SMTP server requires a secure connection or the client was not authenticated.
  The server response was: 5.7.1 Client was not authenticated).
)

The mail could not be sent to the recipients because of the mail server failure.
 (Sending Mail using Account 4 (2016-05-16T12:03:59). 
 Exception Message: Cannot send mails to mail server. 
 (The SMTP server requires a secure connection or the client was not authenticated.
 The server response was: 5.7.1 Client was not authenticated).
)
*/