/*============================================================================
  Updated sys.dm_os_waiting_tasks script to add query DOP
  http://www.sqlskills.com/blogs/paul/updated-sys-dm_os_waiting_tasks-script-2/
  File:     WaitingTasks.sql
 
  Summary:  Snapshot of waiting tasks
 
  SQL Server Versions: 2005 onwards
------------------------------------------------------------------------------
  Written by Paul S. Randal, SQLskills.com
 
  (c) 2016, SQLskills.com. All rights reserved.
 
  For more scripts and sample code, check out 
    http://www.SQLskills.com
 
  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
   
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.

	$Archive: /SQL/QueryWork/Waits_Current_Randal.sql $
	$Revision: 1 $	$Date: 16-05-12 14:11 $
============================================================================*/
Select
	owt.session_id
  , owt.exec_context_id
  , ot.scheduler_id
  , [Blocker] = owt.blocking_session_id
  , owt.wait_type
  , owt.wait_duration_ms
  , er.cpu_time
  , owt.resource_description
  ,  [Node ID] = Case owt.wait_type
	  When N'CXPACKET' Then Right(owt.resource_description, CharIndex(N'=', Reverse(owt.resource_description)) - 1)
	  Else Null
	End
  , [DOP] = eqmg.dop
  , est.text
  , er.database_id
  , eqp.query_plan
  , er.cpu_time
From
	sys.dm_os_waiting_tasks As owt
	Inner Join sys.dm_os_tasks As ot
		On owt.waiting_task_address = ot.task_address
	Inner Join sys.dm_exec_sessions As es
		On owt.session_id = es.session_id
	Inner Join sys.dm_exec_requests As er
		On es.session_id = er.session_id
	Full Join sys.dm_exec_query_memory_grants As eqmg
		On owt.session_id = eqmg.session_id
	Outer Apply sys.dm_exec_sql_text(er.sql_handle) As est
	Outer Apply sys.dm_exec_query_plan(er.plan_handle) As eqp
Where
	es.is_user_process = 1
	And owt.wait_type Not In ('BROKER_RECEIVE_WAITFOR')
Order By
	
	owt.wait_duration_ms desc
	, owt.session_id
	, owt.exec_context_id
;
Go