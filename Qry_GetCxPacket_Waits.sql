/*
	This query is planned to gather information about CxPacket
	related issues.
	
	$Archive: /SQL/QueryWork/Qry_GetCxPacket_Waits.sql $
	$Revision: 5 $	$Date: 15-11-25 16:22 $
*/
/*
	Based on Carly Wang script to find long running queries.
	
	See notes at end of script for how to determine the wait resource, Job Names, etc.
	
	Modify to investigate CXPACKET wait Types.

	$Workfile: Qry_GetCxPacket_Waits.sql $
	$Archive: /SQL/QueryWork/Qry_GetCxPacket_Waits.sql $
	$Revision: 5 $	$Date: 15-11-25 16:22 $
*/
Declare
	@SPId	Int = 88	-- 0		-- SPID to return data.  0 = all
	;
SELECT
	[SPID] = R.session_id
	--ot.session_id
	--, [Database] = DB_NAME(R.database_id)
	, [DB Id] = r.database_id
	, [Context Id] = ot.exec_context_id
	, [Sched Id] = ot.scheduler_id
	, [State] = ot.task_state
	, [Pending I/O] = ot.pending_io_count
	, [Avg Pending Bytes] = ot.pending_io_byte_average
	, [Pending Bytes] = ot.pending_io_byte_count
	, [Context Switches] = ot.context_switches_count
	, [Request Id] = ot.request_id
	, [Wait Res Desc] = wt.resource_description
	--,ot.*
	, [Req Blocker] = R.blocking_session_id
	, [Req Duration(sec)] = Cast((datediff(ms, R.start_time, current_timestamp) /1000.0) as Decimal(12,2))
	, [Req % Cmp]	= cast(R.percent_complete as Decimal(12,3))									-- Seems to track progress but only for some queries
	, [Req Remaining(sec)] = Cast((R.estimated_completion_time / 1000.0) as Decimal(12, 3))		-- Very Approximate
	, [Req Curr Wait(ms)] =  R.wait_time
	, [Req Wait Type] = R.wait_type
	, [Req Wait Resource ] = R.wait_resource
	, [Req Last Wait Type] = R.last_wait_type
	, [Req start_time] = R.start_time
	, [Req status] = R.status
	, [Req command] = R.command
	, [Session Host] = S.HOST_NAME
	, [Req cpu_time] = R.cpu_time
	, [Req Tot Time (Sec)] = cast(R.total_elapsed_time * 1.0 / 1000.0 as decimal(12, 3))
	, [Req reads] = R.reads
	, [Req writes] = R.writes
	, [Req logical_reads] = R.logical_reads
	, [Req row_count] = R.row_count
	, C.connect_time
	, [Connection Packet Reads] = C.num_reads
	, [Connection Packet Writes] = C.num_writes
	, [Connection Last Read] = C.last_read
	, [Connection Last Write] = C.last_write
	, S.program_name
	, [Session client_interface_name] = S.client_interface_name
	, [Session Login] = S.login_name
	, [Session Domain] = S.nt_domain
	, wt.*
--	, [nt_user_name] = S.nt_user_name
--	, [client_net_address] = C.client_net_address
--	, [net_packet_size] = C.net_packet_size
--	, C.net_transport
--	, C.auth_scheme
/*	--
	, [Procname] = object_name(ST.objectid)
	, [Query] = case WHEN st.encrypted = 1 THEN N'encrypted'
				WHEN r.session_id IS NULL THEN st.text
				WHEN ((case	WHEN r.statement_end_offset = -1 THEN datalength(st.text)
							ELSE r.statement_end_offset
							END
						) - r.statement_start_offset) / 2 <= 0
					then st.text
				ELSE ltrim(
					substring(st.text, r.statement_start_offset / 2 + 1,(
							(case WHEN r.statement_end_offset = -1 THEN datalength(st.text)
								ELSE r.statement_end_offset
							END
							) - r.statement_start_offset) / 2)
					)
				END
	, [query_text] = case when ((case R.statement_end_offset
								WHEN -1 THEN datalength(ST.text)
								ELSE R.statement_end_offset
								END - R.statement_start_offset)
								/ 2) + 1 <= 0 then ST.text
						else substring(ST.text, (R.statement_start_offset / 2) + 1, 
							((case R.statement_end_offset
							WHEN -1 THEN datalength(ST.text)
							ELSE R.statement_end_offset
							END
							- R.statement_start_offset)
							 / 2) + 1)
						end
	--, [xml_batch_query_plan] = QP.query_plan
	--, [xml_statement_query_plan] = TQP.query_plan		  --Comment out if you do not have SQL 2005 SP2 or higher.
*/	--
-- select * 
FROM
	sys.dm_os_tasks as ot
	inner join sys.dm_exec_requests as R
		on R.request_id = ot.request_id
		and R.session_id = ot.session_id
	Inner JOIN sys.dm_exec_connections As C
		ON R.connection_id = C.connection_id
		AND R.session_id = C.most_recent_session_id
	Inner JOIN sys.dm_exec_sessions As S
		ON C.session_id = S.session_id
	Inner Join sys.dm_os_waiting_tasks as wt
		on wt.session_id = r.session_id
		and wt.waiting_task_address = ot.task_address
/*
	CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) As ST 
	CROSS APPLY sys.dm_exec_query_plan(R.plan_handle) As QP 
	CROSS APPLY sys.dm_exec_text_query_plan(R.plan_handle, R.statement_start_offset, R.statement_end_offset) As TQP  --Comment out if you do not have SQL 2005 SP2 or higher.
*/
Where 1 = 1
	and R.wait_type = 'CXPACKET'
	and R.session_id = Case @SPId When 0 Then R.session_id Else @SPId End
order by
	Case when R.blocking_session_id > 0 then R.blocking_session_id else 0 end desc
	, [SPID]
	, [Context Id]
	, [Sched Id] 
	, [Req Duration(sec)]	desc		-- = datediff(second, R.start_time, current_timestamp)
	, [Req Curr Wait(ms)]	desc		--  =  R.wait_time
	, R.wait_resource
	, S.HOST_NAME
;

Return;


--	Select * From sys.dm_os_wait_stats Where waiting_tasks_count > 0

--exchangeEvent id=Pipeeda5a2300 WaitType=e_waitPipeGetRow nodeId=0
