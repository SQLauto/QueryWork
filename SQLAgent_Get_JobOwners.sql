
/*
$Archive: /SQL/QueryWork/SQLAgent_Get_JobOwners.sql $
$Revision: 2 $	$Date: 17-11-18 10:00 $
*/
Use MSDB;
Go

Select
	sj.name
	,SUSER_SNAME( sj.owner_sid)
	--,sj.owner_sid
	,sj.enabled
	,sj.date_created
	,[LastRun] = MAX(jh.run_date)
	--,jh.*
From
	sysjobs as sj
	inner join sysjobhistory as jh
		on jh.job_id = sj.job_id
Where 1 = 1
	and jh.step_id = 0
	and SUSER_SNAME( sj.owner_sid) != 'sa'
Group By	
	sj.name
	,SUSER_SNAME( sj.owner_sid)
	--,sj.owner_sid
	,sj.enabled
	,sj.date_created
Order By
	sj.name
	