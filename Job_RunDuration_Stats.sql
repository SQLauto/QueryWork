/*
	This script returns detail run duration data for all SQL Agent Jobs/Steps
	by default to show any job steps with run status != Succeeded that ran yesterday filtering out the
	InProgress status.
	
	Four options are available.
	1. @DateRange	- default = 1, change to go back further in history
	2. @JobName		- wild card to filter on job name.  Default is %%
	3. @StepStatus	- default = 0 show all, = 1 show !succeeded (e.g. Failed, Cancled, ...)
	4. @Progress	- default = 0 filter out InProgress status, 1 = include InProgress status
	
	$Archive: /SQL/QueryWork/Job_RunDuration_Stats.sql $
	$Revision: 5 $	$Date: 16-12-16 12:12 $
*/
Use msdb;
Set NoCount On;

Declare
	@DateEnd			DateTime = DateAdd(Day, DateDiff(Day, '2015-01-01', GetDate()) + 1, '2015-01-01')  -- Default Enddate is today at 23:59
	, @DateRange		Int = 2		-- default 2 gives all jobs from yesterday upto now
	, @DateStart		DateTime
	, @MSDBDateEnd		Int
	, @MSDBDateStart	Int
	, @JobName			NVarchar(128) = N''
	, @StepStatus		Int = 0				-- 0 show all, 1 = show Not Succeeded Only
	, @Progress			Int = 0				-- 0 Filter out "InProgress", 1 = Include "InProgress"
	;

Set @DateStart = DateAdd(dd, -@DateRange, @DateEnd);
Set @MSDBDateEnd = Cast(((DatePart(Year, @DateEnd) * 10000) + DatePart(Month, @DateEnd) * 100) + DATEPART(Day, @DateEnd) as int);
Set @MSDBDateStart = @MSDBDateEnd - @DateRange;
Select [DateStart] = @DateStart, [@DateEnd] = @DateEnd, [@DateRange] = @DateRange, [@MSDBDateStart] = @MSDBDateStart, [@MSDBDateEnd] = @MSDBDateEnd
Select
	[Job Name]		= j.name
	, [Step Name]	= js.step_name
	, [Step Id]		= jh.step_id
	--, jh.instance_id		-- History table row id
	, [Run Time]	= dbo.agent_datetime(jh.run_date, jh.run_time)
	, [Retries]		= jh.retries_attempted
	, [Duration sec] = (jh.run_duration % 100)						-- Seconds
					 + 60 * ((jh.run_duration /100) % 100)			-- + minutes to seconds
					 + 3600 * ((jh.run_duration / 10000) % 100) 	-- + Hours to seconds
	, [Step Status] = Case jh.run_status When 0 Then 'Failed'
					When 1 Then 'Succeeded'
					When 2 Then 'Retry'
					When 3 Then 'Canceled'
					When 4 Then 'In Progress'
					When 5 Then 'Unknown'
					Else 'Illegal Status'
					End
	--, [Run Date Int] = jh.run_date
	--, [Run Time Int] = jh.run_time
	--, jh.run_duration		-- HHMMSS
From dbo.sysjobhistory As jh
	Inner Join dbo.sysjobs As j
		On j.job_id = jh.job_id
	Inner Join dbo.sysjobsteps As js
		On js.job_id = jh.job_id
		And js.step_id = jh.step_id
Where 1 = 1
	And 1 = Case When @Progress = 1 Then 1	-- Show All
				When jh.run_status = 4 Then 0	-- don't process "Progress Report" or "Unknown"
				Else 1							-- Default is show
				End
	And j.name Like '%' + @JobName + '%'
	And jh.run_date < @MSDBDateEnd		-- Jobs ran Before today
	And jh.run_date >= @MSDBDateStart
	And jh.run_duration > 0
	And 1 = Case When @StepStatus = 0 Then 1		-- show all
				When jh.run_status != 1 Then 1	-- show any non success
				Else 0							-- don't show step
				End
Order By
--	[Duration sec]	Desc,
--	[Run Time] Desc,
	[Job Name]		--j.name
	, [Run Time]
	, [Step Id]		--jh.step_id
--	, [Run Time Int]
--	, jh.instance_id

Return;


