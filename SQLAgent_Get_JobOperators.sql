--$Workfile: SQLAgent_Get_JobOperators.sql $

/*
	This script returns all of the SQL Agent operators defined for this server
	and then all of the jobs/steps where the operator is referenced.
	
	$Archive: /SQL/QueryWork/SQLAgent_Get_JobOperators.sql $
	$Revision: 4 $	$Date: 16-01-15 13:15 $
*/
Use msdb;
Set NoCount On;

Select
	[Server] = @@ServerName
	, [Operator Name] = so.name
	, [Operator Id] = so.id
	, [Notify Email Add] = so.email_address
	, [Operator Enabled] = Case When so.enabled > 0 Then 'Yes' Else 'No' End
--	,so.category_id
	, [Email Notifcations] = Sum(Case When sj_email.notify_email_operator_id Is Not Null Then 1 Else 0 End)
	, [Pager Notifcations] = Sum(Case When sj_pager.notify_page_operator_id Is Not Null Then 1 Else 0 End)
From
	dbo.sysoperators As so
	Left Outer Join dbo.sysjobs As sj_email
		On so.id = sj_email.notify_email_operator_id
	Left Outer Join dbo.sysjobs As sj_pager
		On so.id = sj_pager.notify_page_operator_id
Group By
	so.name
	, so.id
	, so.email_address
	, so.enabled
	, so.category_id
;

Select 
	sj.name
	,[Op Name] = Coalesce(so_notify_email_operator_id.name, 'No Operator')
	,[notify_email_operator_id] = Case When so_notify_email_operator_id.email_address Is Null Then -99 Else so_notify_email_operator_id.id End
	,[notify_level_email] = Case When so_notify_level_email.email_address Is Null Then '<No Entry>' Else so_notify_level_email.email_address End--,[] = case when so_.email_address IS null then '<No Entry>' else so_.email_address end
	,so_notify_level_email.name
	,[notify_level_page] = Case When so_notify_level_page.email_address Is Null Then '<No Entry>' Else so_notify_level_page.email_address End
	,so_notify_level_page.name
	--,[notify_netsend_operator_id] = case when so_notify_netsend_operator_id.email_address IS null then -99 else so_notify_netsend_operator_id.id end
	--,so_notify_netsend_operator_id.name
	,[notify_page_operator_id] = Case When so_notify_page_operator_id.email_address Is Null Then -99 Else so_notify_page_operator_id.id End
	,[notify_page_operator_name] = so_notify_page_operator_id.name
	
From
	sysjobs As sj
	Left Outer Join sysoperators As so_notify_email_operator_id
		On sj.notify_email_operator_id  = so_notify_email_operator_id.id
	Left Outer Join sysoperators As so_notify_level_email
		On sj.notify_email_operator_id  = so_notify_level_email.id
	Left Outer Join sysoperators As so_notify_level_page
		On sj.notify_level_page  = so_notify_level_page.id
	--left outer join sysoperators as so_notify_netsend_operator_id
	--	on sj.notify_netsend_operator_id  = so_notify_netsend_operator_id.id
	Left Outer Join sysoperators As so_notify_page_operator_id
		On sj.notify_page_operator_id  = so_notify_page_operator_id.id
Where 1 = 1
	--and (
	--	sj.notify_email_operator_id > 0
	--	or sj.notify_level_email > 0
	--	or sj.notify_level_page > 0
	--	or sj.notify_netsend_operator_id > 0
	--	or sj.notify_page_operator_id > 0
	--)
Order By
	[notify_email_operator_id],
	sj.name