/*
	This script returns job history error messages for jobs by name and rundate.
	
	$Archive: /SQL/QueryWork/Job_Get_HistoryForDateRange.sql $
	$Revision: 8 $	$Date: 16-05-12 14:12 $
*/
Use msdb;
Go
Declare
	@RunDate	Datetime = DateAdd(dd, -1, Cast(GetDate() As Date))	-- Latest date in history
	,@DaysBack	Integer = 1								-- number of days to return
	,@DateEnd	Integer									-- YYYYMMDD - SQL Agent Date Format
	,@DateStart	integer

Set @DateEnd = cast(Convert(Varchar(12), @RunDate, 112) as Int)
Set @DateStart = @DateEnd - @DaysBack;
;With jobData as (
	Select
		[JobName] = sj.name
		, [JobId] = sj.Job_Id
		, [StepName] = js.Step_name
		, [StepId] = js.Step_id
		, [StepStatus] = jh.run_status
		, [RunDateTime] = dbo.agent_datetime(jh.run_date, jh.run_time)
		, [LastStatus] = Case jh.run_status when 0 then 'Failed'
							When 1 then 'Succeeded'
							When 2 then 'Retry'
							When 3 then 'Canceled'
							Else 'Unknown'
							End 
		, [StepDay]		= SUBSTRING(DateName(dw, dbo.agent_datetime(jh.run_date, jh.run_time)), 1, 3)
		, [StepHour]	= DATEPART(hh, dbo.agent_datetime(jh.run_date, jh.run_time))
		, [StepMinute]	= DATEPART(mi, dbo.agent_datetime(jh.run_date, jh.run_time))
		--,jh.run_date
		--,jh.run_time
		--, [StepDurHHMMSS] = jh.run_duration
		, [StepDurSec] = (jh.run_duration % 100) + (((jh.run_duration/100) % 100) * 60) + ((jh.run_duration/10000) * 3600)
		, [JobMsgId] = jh.sql_message_id
		, [JobMessage] = jh.message
		, [SysMessage] = sm.text
	From
		sysjobs as sj
		inner join sysjobsteps as js
			on js.job_id = sj.job_id
		inner join sysjobhistory as jh
			on jh.job_id = sj.job_id
			and jh.step_id = js.step_id
		inner join master.sys.messages as sm
			on sm.message_id = jh.sql_message_id
			and sm.language_id = 1033
	Where 1 = 1
		and jh.run_date >= @DateStart
		and jh.run_date <= @DateEnd
	)
Select
	[Job] = jd.JobName
	, [Step] = jd.StepName
	, [Step Id] = jd.stepId
	, [Duration (sec)] = jd.StepDurSec
	, [Step Status] = jd.StepStatus
	, [Last Status] = jd.LastStatus
	--, StepDurHHMMSS
	, [Day] = jd.StepDay
	, [Hour] = jd.StepHour
	, [Minute] = jd.StepMinute
	, [Run DT] = jd.RunDateTime
	, [Message] = jd.SysMessage
From JobData as jd
Where 1 = 1
	-- And jd.StepHour < 3
	 --And jd.StepId = 4
	-- And (jd.StepMinute = 20 Or jd.StepMinute = 40)
	 --And jd.JobName in (
		--'UpdatePOSJournalToFuelSale'
		--)
	--	'CLV_LevelA Generate Fuelsale'
	--	, 'CLV_PanelLevelBGenerateSales'
	--	, 'CLV_BirIAB00_And_ConsirnEodGenerate'
	--	)
Order By
	jd.JobName,
	jd.RunDateTime Desc,
	jd.stepId,
	jd.LastStatus,
	jd.StepDay, 
	jd.StepHour,
	jd.StepName,
	jd.stepDurSec Desc
;

/*
Select
	[Job Name]
	,[Step Name]
	,[COUNT] = COUNT (*)
	,[MAX] = MAX([Step Dur Sec])
	,[Min] = Min([Step Dur Sec])
	,[Avg] = Avg([Step Dur Sec])
	,[Stdev] = CAST(Stdev([Step Dur Sec]) as Decimal(12,2))
From 
	JobData
Where
	[Step Dur Sec] > 0
group by
	[Job Name]
	,[Step Name]
*/

