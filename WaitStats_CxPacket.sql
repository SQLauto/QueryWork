/*

	This goal of this script is to provide information about parallel executions
	and try to highlight issues related to performance.
	$Archive: /SQL/QueryWork/WaitStats_CxPacket.sql $
	$Revision: 1 $	$Date: 18-02-03 15:13 $
*/

Select [SPID] = es.session_id
	, [Sess GroupId] = es.group_id
	, [RequestId] = er.request_id
	, [oTask  eCID] = ot.exec_context_id
	, [wTask eCID] = wt.exec_context_id
	, [wTask Blk eCID] = wt.blocking_exec_context_id
	, [Req SchdId] = er.scheduler_id
	, [wTask Blocker] = wt.blocking_session_id
	, [wTask Wait Ms] = wt.wait_duration_ms
	, [Req Wait Ms] = er.wait_time
	, [Req Wait Type] = er.wait_type
	, [wTask Wait Type] = wt.wait_type
	, [wTask Res] = wt.resource_description
	, [wTask Wait Dur] = wt.wait_duration_ms
	--, [Req Cmd] = er.command
	--, [HOST] = es.host_name
	--, [Login] = es.login_name
	--, [Sess lReads] = es.logical_reads
	--, [Sess pReads] = es.reads
	--, [Sess Writes] = es.writes
	--, [Rows] = es.row_count
	--, [Sess Elapsed Time] = es.total_elapsed_time
	--, [Sess Execution Time] = es.total_scheduled_time
	--, [Sess CPU] = es.cpu_time
	--, [Sess Mem (MB)] = es.memory_usage / 128
	--, [Host PID] = es.host_process_id
	--, [Res Add] = wt.resource_address
From
	sys.dm_exec_sessions as es
	inner join sys.dm_exec_requests as er
		on er.session_id = es.session_id
	inner join sys.dm_os_tasks as ot
		on ot.session_id = es.session_id
		and ot.request_id = er.request_id
	inner join sys.dm_os_waiting_tasks as wt
		on wt.session_id = es.session_id
		and wt.exec_context_id = ot.exec_context_id
		--and wt.
Where 1 = 1
	And wt.wait_type = 'CXPACKET'
	--and es.session_id = 74
Order By
	es.session_id
	, wt.exec_context_id
	, wt.blocking_exec_context_id
	, ot.exec_context_id
