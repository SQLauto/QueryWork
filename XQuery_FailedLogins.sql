/*
	Use Extended Events to Get More Information About failed SQL Server Login Attempts
	http://www.mssqltips.com/sqlservertip/3214/use-extended-events-to-get-more-information-about-failed-sql-server-login-attempts/?utm_source=dailynewsletter&utm_medium=email&utm_content=text&utm_campaign=20140730

	$Archive: /SQL/QueryWork/XQuery_FailedLogins.sql $
	$Revision: 3 $	$Date: 14-11-28 16:19 $
	
	Modified for use in production environments.
	Notes:
		1 - Must have parallel task to clean up the data logging files.
		2. - There is a parallel query to extract data from the file.
	Problems.
		1. - The File names are hardcoded.
		2. - File maintenance is manual.  - looks like the target sets a maximum size and roll over count. I don't know how.

*/

-- Query to pull data from the session established by above
;WITH event_data AS(
	SELECT
		data = CONVERT(XML, event_data)
	FROM sys.fn_xe_file_target_read_file('C:\temp\FailedLogins*.xel', 'C:\temp\FailedLogins*.xem', NULL, NULL)
	)
	,tabular AS(
	SELECT 
		[host] = data.value('(event/action[@name="client_hostname"]/value)[1]','nvarchar(4000)'),
		[app] = data.value('(event/action[@name="client_app_name"]/value)[1]','nvarchar(4000)'),
		[date/time] = data.value('(event/@timestamp)[1]','datetime2'),
		[error] = data.value('(event/data[@name="error_number"]/value)[1]','int'),
		[state] = data.value('(event/data[@name="state"]/value)[1]','tinyint'),
		[message] = data.value('(event/data[@name="message"]/value)[1]','nvarchar(250)')
	FROM event_data
	)
SELECT
	[host]
	,[app]
	,[state]
	,[message]
	,[date/time]
FROM tabular
WHERE error = 18456 
ORDER BY [date/time] DESC
;
Return;

/*
Select
	*
From
	sys.dm_xe_sessions as xs



Select *
From
	sys.dm_xe_session_Object_Columns as xoc
Where
	xoc.object_Type = 'Target'

*/