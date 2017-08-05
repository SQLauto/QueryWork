-- $Workfile: Query_GetPercentComplete.sql $

/*
	Based on Tim Ford Blog post
	Identify Completion Time for Long Running SQL Server Processes using Dynamic Management Objects
	http://www.mssqltips.com/sqlservertip/3176/identify-completion-time-for-long-running-sql-server-processes-using-dynamic-management-objects/?utm_source=dailynewsletter&utm_medium=email&utm_content=text&utm_campaign=20140303
--
	This query returns % complete information for running queries.
	Generally the data is available for queries like:
		1. Database Backup and Restore 
		2. Index Reorganizations -- but not create :(
		3. Various DBCC operations (SHRINKFILE, SHRINKDATABASE, CHECKDB, CHECKTABLE...) 
		4. Rollback Operations 

	$Archive: /SQL/QueryWork/Query_GetPercentComplete.sql $
	$Revision: 5 $	$Date: 14-08-07 15:19 $
*/

SELECT
		[SPID] = R.session_id
		,[Percent] = R.percent_complete
		,[Elapsed Secs] = R.total_elapsed_time / 1000
		,[Current Wait Type] = R.wait_type
		,[Wait Time(ms)] = R.wait_time
		,[Resource] = R.wait_resource
					 --Case when 1 = isnumeric(substring(R.wait_resource, 1, 1))
						--	Then substring(R.wait_resource, 1, 1)
						--	Else R.wait_resource
						--	End
		,[Last Wait Type] =  R.last_wait_type
		,[Start]= R.start_time
		,R.command
		--, es.login_name
		,[Est Completion Time] = dateadd(s, 100 / ((R.percent_complete) / (R.total_elapsed_time / 1000)), R.start_time)
		,[Stmt Executing] = substring(ST.text, R.statement_start_offset / 2,
					(case	WHEN R.statement_end_offset = -1 THEN datalength(ST.text)
							ELSE R.statement_end_offset
							END
					 - R.statement_start_offset) / 2)
		--,[Whole Query] = ST.text
	FROM
		sys.dm_exec_requests As R
		--inner join sys.dm_exec_sessions as es
		--	on es.session_id = es.session_id
		CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) As ST
	WHERE 1 = 1
		And R.percent_complete > 0
		AND R.session_id <> @@spid
		--And R.session_id = 76
    Order By [Elapsed Secs] desc
    OPTION
	(RECOMPILE);

--Return;

exec master..sqbStatus 1

--Consirn#CreateBusyQuietPointNew
--Generate#DispenserOutofUse
/*
Generate#DispenserOutofUse
ConsirnPanelExceptions#AutoIns
ConsirnPanelExceptions#AutoIns
Consirn#GenDailyOverShort
Generate#DispenserOutofUse
Consirn#CreateBusyQuietPointNew
Generate#DispenserOutofUse
Consirn#GenDailyOverShort
Generate#ConsirnEod
*/