Use MSDB
Go
Declare @SearchString NVARCHAR(100)

Set @SearchString = N'%xp_CmdShell%';

Select
	[Server Name] = @@servername
	,[Db Name] = js.database_name
	,[Job Name] = sj.name
	,[Step Name] = js.step_name
	,[Step Id] = js.step_id
	,[Schedule Id] = sjs.schedule_id
	,[Command] = js.command
	,[Last Date] = js.last_run_date
	,[Enabled] = sj.enabled
	,[Next Date] = sjs.next_run_date
	,[Next Time] = sjs.next_run_time
From
	sysjobsteps	as js
	inner join sysjobs as sj
		on sj.job_id = js.job_id
	inner join sysjobschedules as sjs
		on sjs.job_id = sj.job_id
Where 1 = 1
	and (js.command like @SearchString
		or sj.name like @SearchString
		or js.step_name like @SearchString
		or js.command like @SearchString
		)
Order By
	[Server Name]
	,[Db Name]
	,[Job Name]
	,[Schedule Id]
	,[Step Id]
