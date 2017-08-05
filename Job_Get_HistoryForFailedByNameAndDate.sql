/*
	This script returns error messages for jobs since rundate.
	Job name may be specified with wild cards.
	The time interval defaults to yesterday 00:00:00
	
	$Archive: /SQL/QueryWork/Job_Get_HistoryForFailedByNameAndDate.sql $
	$Revision: 5 $	$Date: 17-02-10 10:04 $
*/
Use msdb;
If Object_Id('tempdb..#theData', 'U') Is Not Null Drop Table #theData;
Go
Set NoCount On;
Create Table #theData(Id Int Identity(1, 1) Primary Key Clustered
	, JobName		NVarchar(128)
	, JobId			UniqueIdentifier
	, StepName		NVarchar(128)
	, StepId		Int
	, RunDateInt	Int
	, RunTimeInt	Int
	, RunDateTime	DateTime
	, ErrorText		NVarchar(Max)
	, StepMsg		NVarchar(Max)
	, StepStatus	NVarchar(20)
	);
Declare
	@Body			NVarchar(Max)
	, @StartDate	DateTime		= DATEADD(day, DATEDIFF(day, 0, GetDate()), -1)
	, @StartDateInt	Int					-- Job run date as integer in YYYYMMDD format
	, @JobName		NVarchar(128)	= N'';
	
Set @StartDateInt = (((DatePart(Year, @StartDate) * 100) + DatePart(Month, @StartDate)) * 100 + DatePart(Day, @StartDate));
--	Print @StartDateInt;
If Substring(@JobName, 1, 1) != N'%' Set @JobName = N'%' + @JobName;
If Substring(@JobName, Len(@JobName), 1) != N'%' Set @JobName = @JobName +  N'%';
Insert Into #theData(JobName, JobId, StepName, StepId, RunDateInt, RunTimeInt	
	, RunDateTime, ErrorText, StepMsg, StepStatus
	)
	Select [JobName] = sj.name
		, [JobId] = sj.Job_Id
		, [StepName] = js.step_name
		, [StepId] = js.step_id
		, [RunDateInt] = jh.run_date
		, [RunTimeInt] = jh.run_time
		, [RunDateTime] = dbo.agent_datetime(jh.run_date, jh.run_time)
		, [ErrorText] = 'Error Num = ' + Cast(jh.sql_message_id As Varchar(12)) + Char(10)
				+ 'Error Msg = ' + Coalesce(sm.text, 'N/A')
		, [StepMsg] = jh.message
		, [StepStatus] = Case jh.run_status
						When 0 Then 'Failed'
						When 1 Then 'Success'
						When 2 Then 'Retry'
						When 3 Then 'Canceled'
						When 4 Then 'InProgress'
						Else 'Unk - ' + Cast(jh.run_status As NVarchar(12))
					End
	From dbo.sysjobs As sj
		Inner Join dbo.sysjobsteps As js
			On js.job_id = sj.job_id
		Inner Join dbo.sysjobhistory As jh
			On jh.job_id = sj.job_id
			And jh.step_id = js.step_id
		Left Join master.sys.messages As sm
			On sm.message_id = jh.sql_message_id
				And sm.language_id = 1033
	Where 1 = 1
		And sj.name Like @JobName
		And jh.run_date > @StartDateInt			-- 20140318
		--And jh.run_status != 1				-- Any steps with Status other than succeeded
		And jh.run_status = 0				-- Only failed
	Order By
		-- jh.run_date	Desc
		--, jh.run_time	Desc
		RunDateTime Desc
		, sj.name
		, jh.step_id Desc;
Select * From #theData As td

--Set @Body = '<html><body>SQL Agent Job Steps that failed since ' + '
--		</br>
--		</br>
--		<table border = 1 style="font-family:Tahoma,Microsoft Sans Serif,Courier New,Arial,Verdana,Helvetica, sans-serif;font-size:11px"> 
--		<tr><th> session_id </th><th> [Duration(sec)] </th><th> [HOST_NAME] </th><th> Procname </th><th> start_time </th> 
--		<th> [Query] </th> <th> status</th> <th> command</th> <th> database_name </th> 
--		<th> blocking_session_id</th> <th> wait_type</th> <th> wait_time</th> <th> client_net_address</th><th> login_name</th>
--		<th> nt_domain</th><th> nt_user_name</th></tr>'   


set @body = cast( (
select td =  
	JobName + '</td><td>'
--	+ cast(d.JobId as varchar(30)) + '</td><td>'
	+ cast(d.StepStatus as varchar(30)) + '</td><td>'
	+ cast(d.StepName as varchar(30)) + '</td><td>'
	+ cast(d.StepId as varchar(30)) + '</td><td>'
--	+ cast(d.RunDateInt as varchar(30)) + '</td><td>'
--	+ cast(d.RunTimeInt as varchar(30)) + '</td><td>'
	+ cast(d.RunDateTime as varchar(30)) + '</td><td>'
	+ cast(d.ErrorText as varchar(30)) + '</td><td>'
	+ cast(d.StepMsg as varchar(30)) + '</td><td>'	
From #theData As d
for xml path( 'tr' ), type ) as varchar(max) )
Print @Body

--Return
Set @body = '<table border = 1 style="font-family:Tahoma,Microsoft Sans Serif,Courier New,Arial,Verdana,Helvetica, sans-serif;font-size:11px"> '
        + '<tr><th>JobName</th>'
--		+ '<th> JobId </th>'
		+ '<th> StepStatus</th>'
		+ '<th> StepName </th>'
		+ '<th> StepId </th><th> start_time </th>'
--		+ '<th> RunDateInt </th>'
--		+ '<th> RunTimeIn </th>'
		+ '<th> RunDateTime </th>'
		+ '<th> ErrorText </th> '
		+ '<th> StepMsg</th>'
        + replace( replace( @body, '&lt;', '<' ), '&gt;', '>' )
        + '</table>'
 print @body