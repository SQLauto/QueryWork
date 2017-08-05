/*
	This script returns aggregated run duration stats for SQL Agent Jobs/Steps
	for several days (default = 5)
	
	
	$Archive: /SQL/QueryWork/Job_RunDuration_AvgStats.sql $
	$Revision: 4 $	$Date: 16-12-16 12:20 $
*/
Use MSDB;
Set NoCount On;

Declare
	@DateEnd		Datetime = DateAdd(day, DateDiff(Day, '2015-01-01', GETDATE()), '2015-01-01')  -- Enddate is today
	, @DateRange	Int = 5					-- Number of days back to retrieve; default is yesterday
	, @DateStart	Datetime
	, @JobName		NVarchar(128) = N''	-- Wild carded search
	;

Set @DateStart = DATEADD(DAY, -@DateRange, @DateEnd);

Select
	j.name
	, js.step_name
	, jh.step_id
	, [Num Runs]= COUNT(*)
	, [Num Succeed] = Sum(Case When jh.run_status = 1 Then 1 Else 0 End)
	, [Num Retry] = Sum(Case When jh.run_status = 2 Then 1 Else 0 End)
	, [Num Failed] = Sum(Case When jh.run_status = 0 Then 1 Else 0 End)
	, [Num Canceled] = Sum(Case When jh.run_status = 3 Then 1 Else 0 End)
	--,jh.run_date
	--,jh.run_time
	--,[runTime] = Convert(DateTime, CONVERT(varchar(50), jh.run_date) + ' '
	--			+ right('00' + Convert(Varchar(50), (jh.run_time/10000) % 100), 2)	-- Hours
	--			+ ':' + right('00' + Convert(Varchar(50), (jh.run_time/100) % 100), 2)	-- Minutes
	--			+ ':' + right('00' + Convert(Varchar(50), (jh.run_time % 100)), 2)	-- Seconda
	--			)
	--,jh.run_duration
	--,[Duration sec] = (jh.run_duration % 100)						-- Seconds
	--				 + 60 * ((jh.run_duration /100) % 100)			-- + minutes to seconds
	--				 + 3600 * ((jh.run_duration / 10000) % 100) 	-- + Hours to seconds
	,[Avg Dur (sec)] = Avg((jh.run_duration % 100)						-- Seconds
					 + 60 * ((jh.run_duration /100) % 100)			-- + minutes to seconds
					 + 3600 * ((jh.run_duration / 10000) % 100) 	-- + Hours to seconds
					 )
	,[Min Dur (sce)] = Min((jh.run_duration % 100)						-- Seconds
					 + 60 * ((jh.run_duration /100) % 100)			-- + minutes to seconds
					 + 3600 * ((jh.run_duration / 10000) % 100) 	-- + Hours to seconds
					 )
	,[Max Dur (sec)] = Max((jh.run_duration % 100)						-- Seconds
					 + 60 * ((jh.run_duration /100) % 100)			-- + minutes to seconds
					 + 3600 * ((jh.run_duration / 10000) % 100) 	-- + Hours to seconds
					 )
	,[StDev Dur (sec)] = isNull(cast(StDev((jh.run_duration % 100)						-- Seconds
					 + 60 * ((jh.run_duration /100) % 100)			-- + minutes to seconds
					 + 3600 * ((jh.run_duration / 10000) % 100) 	-- + Hours to seconds
					 ) as Decimal(18,2)), -99.99)
From msdb.dbo.sysjobhistory as jh
	inner join msdb.dbo.sysjobs as j
		on j.job_id = jh.job_id
	inner join msdb.dbo.sysjobsteps as js
		on js.job_id = jh.job_id
		and js.step_id = jh.step_id
Where 1 = 1
	and jh.run_status <= 3	-- Only process terminal rows in the job step history.  don't process "Progress Report" or "Unknown"
	and j.name like '%' + @JobName + '%'
	and 
		Convert(DateTime, CONVERT(varchar(50), jh.run_date) + ' '
					+ right('00' + Convert(Varchar(50), (jh.run_time/10000) % 100), 2)	-- Hours
					+ ':' + right('00' + Convert(Varchar(50), (jh.run_time/100) % 100), 2)	-- Minutes
					+ ':' + right('00' + Convert(Varchar(50), (jh.run_time % 100)), 2)	-- Seconda
					)
		Between @DateStart and @DateEnd
Group By
	j.name
	, jh.step_id
	, js.step_name
Order By
	j.name
	, jh.step_id