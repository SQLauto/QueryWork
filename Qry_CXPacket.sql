/*
	I may finally have a good start on tracking parallel queries with 
	CxPacket Waits :)
	
	$Archive: /SQL/QueryWork/Qry_CXPacket.sql $
	$Date: 15-04-30 15:23 $	$Revision: 2 $
*/
Declare @SPID	int = 102
	;
Select
	[Req SPID] = er.Session_id
	, [Req Id] = er.request_id
	, [Req UserId] = er.user_id
	, [Req Wait] = er.wait_type
	, [Task ContextId] = ot.exec_context_id
	, [Task SchedId] = ot.scheduler_id
	, [Task State] = ot.task_state
	, [Task ContextSwitches] = ot.context_switches_count
	, [Task PndIOCount] = ot.pending_io_count
	, [Task PndIOByteCount] = ot.pending_io_byte_count
	, [Task PndIOByteAvg] =ot.pending_io_byte_average
	, [QM RequestMem] = qm.requested_memory_kb
	, [QM GrantMem] = qm.granted_memory_kb
	, [QM RequiredMem] = qm.required_memory_kb
	, [QM WaitTime] = qm.wait_time_ms
	, [QM CalcWait] = datediff(ms, qm.request_time, qm.grant_time)
	, [QM DOP] = qm.dop
From
	sys.dm_exec_requests as er
	Inner Join sys.dm_os_tasks as ot
		on ot.session_id = er.session_id
		and ot.request_id = er.request_id
	Inner Join sys.dm_exec_sessions as es
		on es.session_id = er.session_id
	inner join sys.dm_exec_query_memory_grants as qm
		on qm.session_id = er.session_id
		and qm.request_id = er.request_id
Where 1 = 1
	And er.wait_type = 'CXPACKET'
	And es.session_id = @SPID
Order By
	er.Session_id
	, er.request_id
	, ot.exec_context_id asc

/*
-- From BOL ms-help://MS.SQLCC.v10/MS.SQLSVR.v10.en/s10de_6tsql/html/180a3c41-e71b-4670-819d-85ea7ef98bac.htm

SELECT
	session_id,
	request_id,
	exec_context_id,
	scheduler_id,
	task_state,
	task_address,
	context_switches_count,
	pending_io_count,
	pending_io_byte_count,
	pending_io_byte_average,
	worker_address,
	host_address
FROM sys.dm_os_tasks
ORDER BY session_id, request_id;
*/

--	Select * From sys.dm_os_schedulers as dos

--sys.dm_exec_sessions as es
--	Left Outer Join
	--, [Sess Dur(sec)] = DateDiff(ss, es.Login_Time, GetDate())
	--, [Sess Req Dur(sec)] = Case When es.last_request_end_time is null Then DateDiff(ss, es.last_request_start_time, GetDate())
	--				Else DateDiff(ss, es.last_request_start_time, es.last_request_end_time)
	--				End
	--, [Sess Mem(KB)] = es.memory_usage * 8
	--, [Sess Reads] = es.reads
	--, [Sess Writes] = es.writes
	--, [Sess LogicalReads] = es.logical_reads
	--, [Sess CPU] = es.cpu_time
	--, [Sess Elapsed] = es.total_elapsed_time
	--, [Sess Login] = es.Login_Time
	--, [Sess ReqStart] = es.last_request_start_time
	--, [Sess ProgName] = es.program_name
	--, [Sess Login] = es.Login_Name
	--, [Sess Host] = es.Host_Name
	--, [Sess Status] = es.status
	--, es.*