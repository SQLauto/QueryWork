
/*
	Insight into the SQL Server Agent Job Schedules
	https://www.sqlprofessionals.com/blog/sql-scripts/2014/10/06/insight-into-sql-agent-job-schedules/

	$Archive: /SQL/QueryWork/Job_ScheduleSummary.sql $
	$Revision: 4 $	$Date: 18-02-02 10:32 $

	Modified to add additional data and restructure some of the query.
*/
Use msdb;

Select
	[JobName]		= sj.name
	, [Category]	= sc.name
	, [Owner]		= SUSER_SNAME(sj.owner_sid)
	, [Job Status]	= Case When sj.enabled = 1 Then 'Enabled' Else 'Disabled' End
	, [Sked Status]	= Case When sked.enabled = 1 Then 'Enabled' Else 'Disabled' End
	, [Next_Run_Date] = --dbo.agent_datetime(js.next_run_date, js.next_run_time)
			CASE js.next_run_date
				WHEN 0 THEN CONVERT(DATETIME, '1900/1/1')
				ELSE CONVERT(DATETIME, CONVERT(CHAR(8), js.next_run_date, 112) + ' ' + 
						STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), js.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
			END
	, [Last Run Time] = jh.LastRunTime
	, [Description] = sj.description
	, [Created]		= sj.date_created
	, [Modified]	= sj.date_modified
	, [Occurs] = 
			CASE sked.freq_type
				WHEN   1 THEN 'Once'
				WHEN   4 THEN 'Daily'
				WHEN   8 THEN 'Weekly'
				WHEN  16 THEN 'Monthly'
				WHEN  32 THEN 'Monthly relative'
				WHEN  64 THEN 'When SQL Server Agent starts'
				WHEN 128 THEN 'Start whenever the CPU(s) become idle' 
				ELSE 'Unknown'
			END
	, [Occurs_detail] = 
			CASE sked.freq_type
				WHEN   1 THEN 'O'
				WHEN   4 THEN 'Every ' + CONVERT(VARCHAR, sked.freq_interval) + ' day(s)'
				WHEN   8 THEN 'Every ' + CONVERT(VARCHAR, sked.freq_recurrence_factor) + ' weeks(s) on ' + 
					LEFT(CASE WHEN sked.freq_interval &  1 =  1 THEN 'Sunday, '    ELSE '' END
						+ CASE WHEN sked.freq_interval &  2 =  2 THEN 'Monday, '    ELSE '' END
						+ CASE WHEN sked.freq_interval &  4 =  4 THEN 'Tuesday, '   ELSE '' END
						+ CASE WHEN sked.freq_interval &  8 =  8 THEN 'Wednesday, ' ELSE '' END
						+ CASE WHEN sked.freq_interval & 16 = 16 THEN 'Thursday, '  ELSE '' END
						+ CASE WHEN sked.freq_interval & 32 = 32 THEN 'Friday, '    ELSE '' END
						+ CASE WHEN sked.freq_interval & 64 = 64 THEN 'Saturday, '  ELSE '' END
						, 
						LEN (CASE WHEN sked.freq_interval &  2 =  2 THEN 'Monday, '    ELSE '' END
							+ CASE WHEN sked.freq_interval &  4 =  4 THEN 'Tuesday, '   ELSE '' END
							+ CASE WHEN sked.freq_interval &  8 =  8 THEN 'Wednesday, ' ELSE '' END
							+ CASE WHEN sked.freq_interval & 16 = 16 THEN 'Thursday, '  ELSE '' END
							+ CASE WHEN sked.freq_interval & 32 = 32 THEN 'Friday, '    ELSE '' END
							+ CASE WHEN sked.freq_interval & 64 = 64 THEN 'Saturday, '  ELSE '' END 
							) - 1
						)
				WHEN  16 THEN 'Day ' + CONVERT(VARCHAR, sked.freq_interval) + ' of every ' + CONVERT(VARCHAR, sked.freq_recurrence_factor) + ' month(s)'
				WHEN  32 THEN 'The ' + 
						CASE sked.freq_relative_interval
							WHEN  1 THEN 'First'
							WHEN  2 THEN 'Second'
							WHEN  4 THEN 'Third'
							WHEN  8 THEN 'Fourth'
							WHEN 16 THEN 'Last' 
							END
						+ CASE sked.freq_interval
							WHEN  1 THEN ' Sunday'
							WHEN  2 THEN ' Monday'
							WHEN  3 THEN ' Tuesday'
							WHEN  4 THEN ' Wednesday'
							WHEN  5 THEN ' Thursday'
							WHEN  6 THEN ' Friday'
							WHEN  7 THEN ' Saturday'
							WHEN  8 THEN ' Day'
							WHEN  9 THEN ' Weekday'
							WHEN 10 THEN ' Weekend Day' 
							END
						+ ' of every ' + CONVERT(VARCHAR, sked.freq_recurrence_factor) + ' month(s)' 
				ELSE ''
			END
	, [Frequency] = 
			CASE sked.freq_subday_type
				WHEN 1 THEN 'Occurs once at '
							+ STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sked.active_start_time), 6), 5, 0, ':'), 3, 0, ':')
				WHEN 2 THEN 'Occurs every '
							+ CONVERT(VARCHAR, sked.freq_subday_interval) + ' Seconds(s) between '
							+ STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sked.active_start_time), 6), 5, 0, ':'), 3, 0, ':')
							+ ' and ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sked.active_end_time), 6), 5, 0, ':'), 3, 0, ':')
				WHEN 4 THEN 'Occurs every '
							+ CONVERT(VARCHAR, sked.freq_subday_interval) + ' Minute(s) between '
							+  STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sked.active_start_time), 6), 5, 0, ':'), 3, 0, ':') + ' and '
							+ STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sked.active_end_time), 6), 5, 0, ':'), 3, 0, ':')
				WHEN 8 THEN 'Occurs every '
							+ CONVERT(VARCHAR, sked.freq_subday_interval) + ' Hour(s) between '
							+ STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sked.active_start_time), 6), 5, 0, ':'), 3, 0, ':') + ' and '
							+ STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sked.active_end_time), 6), 5, 0, ':'), 3, 0, ':')
				ELSE ''
			End
	, [Avg Duration (hrs)]	= jh.AvgDurationHr
FROM msdb.dbo.sysjobs AS sj With(NOLOCK) 
		 LEFT OUTER JOIN msdb.dbo.sysjobschedules AS js With(NOLOCK) 
				 ON sj.job_id = js.job_id 
		 LEFT OUTER JOIN msdb.dbo.sysschedules AS sked With(NOLOCK) 
				 ON js.schedule_id = sked.schedule_id
		 INNER JOIN msdb.dbo.syscategories AS sc With(NOLOCK) 
				 ON sj.category_id = sc.category_id 
		 LEFT OUTER JOIN 
					(SELECT hist.job_id
						, [AvgDurationHr] = (SUM(((hist.run_duration / 10000 * 3600) + 
										((hist.run_duration % 10000) / 100 * 60) + 
										(hist.run_duration % 10000) % 100)) * 1.0) / COUNT(hist.job_id)
						, [LastRunTime] = Max(dbo.agent_datetime(hist.run_date, hist.run_time))
						FROM msdb.dbo.sysjobhistory as hist With(NOLOCK)
						WHERE step_id = 0 
						GROUP BY job_id
					 ) AS jh 
				 ON jh.job_id = sj.job_id
Order By
	sj.Enabled
	, sked.Enabled
	, sj.name
;