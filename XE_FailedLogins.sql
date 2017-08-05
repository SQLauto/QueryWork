/*
	Use Extended Events to Get More Information About failed SQL Server Login Attempts
	http://www.mssqltips.com/sqlservertip/3214/use-extended-events-to-get-more-information-about-failed-sql-server-login-attempts/?utm_source=dailynewsletter&utm_medium=email&utm_content=text&utm_campaign=20140730

	$Archive: /SQL/QueryWork/XE_FailedLogins.sql $
	$Revision: 3 $	$Date: 14-11-28 16:19 $
	
	Modified for use in production environments.
	Notes:
		1 - Must have parallel task to clean up the data logging files.
		2. - There is a parallel query to extract data from the file.

	According to sys.dm_xe_session_Object_Columns as xoc this set up the data files with
	maximum size = 1MB with 5 rollover files.
	The initial file names are "FailedLogins_0_130599395521470000.xel" and "FailedLogins_0_130599395521480000.xem"
	
	
*/
-- Valid for SQL 2008
If CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') As VARCHAR(50)), 1, 2) as INT) < 10
Begin	-- Unsupported Versions
	RaisError('This Extended Event only valid for SQL 2008 and up.', 16, 1);
	Return;
End;	-- Unsupported Versions
Else If CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') As VARCHAR(50)), 1, 2) as INT) = 10
Begin	-- SQL 2008
	CREATE EVENT SESSION FailedLogins
	ON SERVER
	 ADD EVENT sqlserver.error_reported
	 (
	   ACTION 
	   (
		 sqlserver.client_app_name,
		 sqlserver.client_hostname,
		 sqlserver.nt_username
		)
		WHERE severity = 14
		  AND state > 1 -- removes redundant state 1 event
	  )
	  ADD TARGET package0.asynchronous_file_target
	  (
		SET FILENAME = N'C:\temp\FailedLogins.xel'
		, METADATAFILE = N'C:\temp\FailedLogins.xem'
	  );
End;	-- SQL 2008
Else
Begin	-- SQL 2012 and Above
	CREATE EVENT SESSION FailedLogins
	ON SERVER
	 ADD EVENT sqlserver.error_reported
	 (
	   ACTION 
	   (
		 sqlserver.client_app_name,
		 sqlserver.client_hostname,
		 sqlserver.nt_username
		)
		WHERE severity = 14

		-- added this line:
		  AND error_number = 18456

		  AND state > 1 -- removes redundant state 1 event
	  )
	  ADD TARGET package0.asynchronous_file_target
	  (
		SET FILENAME = N'C:\temp\FailedLogins.xel',
		METADATAFILE = N'C:\temp\FailedLogins.xem'
	  );
End;	-- SQL 2012 And Above


-- Turn on the Event Session.
ALTER EVENT SESSION FailedLogins ON SERVER
  STATE = START;
Return;

/*
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
*/