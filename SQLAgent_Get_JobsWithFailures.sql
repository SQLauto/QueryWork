/*
	This script pulls information about SQL Agent jobs that have run in the past xxx days
	and reported errors	
	
	references
		Producing dates from SYSJOBS and SYSJOBHISTORY -- http://www.sqlservercentral.com/Forums/Topic542581-145-1.aspx
*/

Use MSDB

Select
	sj.name
	--,jh.instance_id
	,jh.step_id
	,jh.step_name
	--,jh.run_date
	--,[Run_Date] = Convert(varchar(10), Cast(Cast(jh.run_date as varChar(24)) as Datetime), 120)
	,[Run_DateTime] = dbo.agent_datetime(jh.run_date, jh.run_time)
	--,jh.run_time
	,jh.run_duration
	,[Error Id] = jh.sql_message_id
	,jh.message
	,jh.sql_severity
	,jh.run_status
	
From
	dbo.sysjobs as sj
	inner join dbo.sysjobhistory as jh
		on jh.Job_id = sj.job_id
Where 1 = 1
	and jh.run_status = 0			-- step failed
	and jh.sql_message_id > 0		-- "has a useful SQL error message"
	and jh.sql_message_id != 3621	-- "The statement has been terminated"
Order By
	sj.name
	--,jh.step_id
	,jh.run_date desc
	
Return

Select top 10 *
From dbo.sysjobactivity

Select *
From Sys.messages as sm
where 
	sm.message_id = 3621

