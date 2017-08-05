Select *
From
	--sys.dm_os_wait_stats As dows
	sys.dm_os_waiting_tasks As dowt
Return;	

Select  [wait_type] ,
        [wait_time_ms] ,
        DATEADD(SS, -[wait_time_ms] / 1000, GETDATE()) AS "Date/TimeCleared" ,
        CASE WHEN [wait_time_ms] < 1000
             THEN CAST([wait_time_ms] AS VARCHAR(15)) + ' ms'
             WHEN [wait_time_ms] BETWEEN 1000 AND 60000
             THEN CAST(( [wait_time_ms] / 1000 ) AS VARCHAR(15)) + ' seconds'
             WHEN [wait_time_ms] BETWEEN 60001 AND 3600000
             THEN CAST(( [wait_time_ms] / 60000 ) AS VARCHAR(15)) + ' minutes'
             WHEN [wait_time_ms] BETWEEN 3600001 AND 86400000
             THEN CAST(( [wait_time_ms] / 3600000 ) AS VARCHAR(15)) + ' hours'
             WHEN [wait_time_ms] > 86400000
             THEN CAST(( [wait_time_ms] / 86400000 ) AS VARCHAR(15)) + ' days'
        END AS "TimeSinceCleared"
FROM    [sys].[dm_os_wait_stats]
WHERE   [wait_type] = 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP';

/*
   check SQL Server start time - 2008 and higher
*/
SELECT  [sqlserver_start_time]
FROM    [sys].[dm_os_sys_info];


/*
   check SQL Server start time - 2005 and higher   
*/
SELECT  [create_date]
FROM    [sys].[databases]
WHERE   [database_id] = 2