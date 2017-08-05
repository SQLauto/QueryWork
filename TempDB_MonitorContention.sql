/*
	This file contains snippets for monitoring TempDB contention
	Based on presentation by Vicki Harp (vicki.harp@idera.com)
	$Archive: /SQL/QueryWork/TempDB_MonitorContention.sql $
	$Date: 15-06-30 10:25 $	$Revision: 1 $
*/

Select *
From
	sys.dm_os_waiting_tasks As wt
Where 1 = 1
	--And wt.wait_type Like 'Page%Latch_%'
	--And wt.resource_description Like '2:%'	-- TempDB Resources only