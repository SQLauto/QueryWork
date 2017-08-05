
use msdb

/*
    When creating maintenance plans in SQL 2008+ the plan owner defaults to the logged on user.
    All SQL Agent jobs created for the plan are also owned by the logged on user.  Unfortunately
    any time the maintenance plan is edited the Job owner is reset to the package owner which can
    cause future problems.
    The following snippets of SQL can be used to find the appropriate package entries and change
    the owner to ‘SA’.  Once the package owner is corrected the SQLAgent Job owner should also be
    changed to ‘SA’.  For servers set the maintenance plan and job owner to DOMAIN\SQLMaintain.

    See “Job Owner Reverts to Previous Owner when Scheduled Maintenance Plan is Edited”
    https://connect.microsoft.com/SQLServer/feedback/details/295846/job-owner-reverts-to-previous-owner-when-scheduled-maintenance-plan-is-edited
    4Archive: $
    $Revision: 1 $    $Date: 14-11-28 16:20 $
*/

Select
	sp.name
	,[Owner] = SUSER_SNAME(sp.ownersid)
	,sp.ownersid
	,sp.description
	,[SA_UserSID]= SUSER_SID('sa')
	-- ,sp.id
-- Update sp set ownersid = SUSER_SID('sa')
From
	sysssispackages as sp
Where sp.name like 'zDBA_MP_%'

Return

use msdb
Select
	sj.name
	,sj.owner_sid
	,[Owner] = SUSER_SNAME(sj.owner_sid)
-- Update sj set owner_sid = SUSER_SID('sa')
From sysjobs as sj
Where sj.name like 'zDBA_MP_%'
