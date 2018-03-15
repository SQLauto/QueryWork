/*

	Start of a query to disable all enabled jobs and remember them so they
	can be reenabled later.
	$Archive: /SQL/QueryWork/SQLAgent_Disable_AllJobs.sql $
	$Revision: 1 $	$Date: 9/16/17 10:37a $

*/

Use msdb;

Declare @cmd NVARCHAR(Max) = N''
	, @NewLine	NCHAR(1) = NChar(10)

Select @cmd = @cmd + N'Exec sp_update_job @job_name = ''' + sj.name + N''', @enabled = 0;' + @NewLine
From dbo.sysjobs As sj
Where sj.enabled = 1

Print @cmd


