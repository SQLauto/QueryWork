/*

	This Script returns job summary information
	$Archive: /SQL/QueryWork/Jobs_getSummaryInfo.sql $
	$Revision: 2 $	$Date: 14-06-24 11:12 $
*/
Use msdb
Go

Select
	[Name]			= sj.name
	,[Job Status]	= Case When sj.enabled = 1 Then 'Enabled' Else 'Disabled' End
	,[Sked Status]	= Case When sked.enabled = 1 Then 'Enabled' Else 'Disabled' End
	,[Desc]			= sj.description
	,[Category]		= sc.name
	,[Created]		= sj.date_created
	,[Modified]		= sj.date_modified
From Sysjobs as sj
	inner join dbo.syscategories as sc
		on sc.category_id = sj.category_id
	inner join dbo.sysjobschedules as js
		on js.job_id = sj.job_id
	inner join dbo.sysschedules as sked
		on sked.schedule_id = js.schedule_id
Order by
	sj.enabled asc