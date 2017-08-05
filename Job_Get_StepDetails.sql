/*
	Return Job Detail
	$Archive: /SQL/QueryWork/Job_Get_StepDetails.sql $
	$Revision: 1 $	$Date: 15-09-23 15:14 $
*/
Declare @JobId UniqueIdentifier
	, @JobName		NVarchar(128) = N''


Set @JobId = (Select job_id From dbo.sysjobs Where name = @JobName)

Select
	[Job] = sj.name
	, [Step] = st.step_name
	, [Step Num] = st.step_id
	, [SubSystem] = st.subsystem
	, [DB Name] = st.database_name
	, [DB User] = Coalesce(st.database_user_name, N'Unk')
	, [Last Outcome] = Case st.last_run_outcome When 1 Then 'Success' Else 'Failed' End
	--, [(HHMMSS)] = st.last_run_duration
	, [Last Duration Sec] = (st.last_run_duration % 100) + (((st.last_run_duration/100) % 100) * 60) + ((st.last_run_duration/10000) * 3600)
	, [Success Action] = Case st.on_success_action
						When 1 Then N'Quit with Success'
						When 2 Then N'Quit with Failure'
						When 3 Then N'Next Step'
						When 4 Then N'Goto Step'
						Else N'Unk'
						End
	, [Fail Action] = Case st.on_fail_action
						When 1 Then N'Quit with Success'
						When 2 Then N'Quit with Failure'
						When 3 Then N'Next Step'
						When 4 Then N'Goto Step'
						Else N'Unk'
						End
	, [Command] = st.command 
From
	dbo.SysJobs As sj
	Inner Join dbo.sysjobsteps As st
		On st.job_id = sj.job_id
Where sj.job_id = @JobId