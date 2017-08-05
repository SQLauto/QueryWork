/*
	
	See notes at end of script for how to determine the wait resource, Job Names, etc.

	$Workfile: Qry_ActiveQrySummary.sql $
	$Archive: /SQL/QueryWork/Qry_ActiveQrySummary.sql $
	$Revision: 10 $	$Date: 17-03-20 14:27 $
*/
Use master;
Set NoCount On;
Set Transaction Isolation Level Read Uncommitted;		-- sometimes the problem query actually blocks this one !!

Select
	[SPID] = ec.session_id
	, [Blocker] = er.blocking_session_id
	, [Database] = Db_Name(er.database_id)
	, [Curr Wait(ms)] =  er.wait_time
	, [Host] = es.host_name
	, [Req Cmd] = er.command
	, [Prog] = es.program_name
	, [Proc Name] = Case When st.objectid Is Null Then 'n/a' Else Object_Name(st.objectid, st.dbid) End
	, [Req Waiting For] = Case
					When Substring(er.wait_resource, 1, CharIndex(':', er.wait_resource, 1) ) Between '000' And '999'
						Then 'DB Page'
					When er.wait_resource Like 'OBJECT:%' 
						Then Object_Name(Cast(Substring(Substring(er.wait_resource, CharIndex(':', er.wait_resource, 8) + 1, Len(er.wait_resource)), 1 
								, CharIndex(':', Substring(er.wait_resource, CharIndex(':', er.wait_resource, 8) + 1, Len(er.wait_resource)), 1) -1 )
							As Int),
							Cast(Substring(er.wait_resource, CharIndex(':', er.wait_resource, 1) + 1
								, CharIndex(':', er.wait_resource, 8) -  CharIndex(':', er.wait_resource, 1) - 1) As Int)
								)
					When er.wait_resource Like 'Key:%'
						Then 'Key:'
						
					When Len(er.wait_resource) = 0 Then
						Case When er.status = 'running' Then 'running'
							When er.status = 'runnable' Then 'CPU'
							When er.wait_type = 'CXPACKET' Then 'Parallel'
							When er.wait_type = 'ASYNC_NETWORK_IO' Then 'Client results'
							When er.wait_type In ('PREEMPTIVE_OS_WRITEFILE', 'WRITE_COMPLETION') Then 'I/O Op'
							When er.wait_type = 'WRITELOG' Then 'TLog I/O'
							When er.wait_type = 'BACKUPIO' Then 'BACKUPIO'
							When er.wait_type = 'SLEEP_BPOOL_FLUSH' Then 'BPoolFlsh'
							When er.wait_type = 'ASYNC_IO_COMPLETION' Then 'I/O'
							When er.wait_type = 'PREEMPTIVE_OS_GETPROCADDRESS' Then 'External Process'
							Else 'Unk - ' + er.wait_type End
					Else er.wait_resource
					End
	, [Elapsed (sec)] = Case When DateDiff(dd, er.start_time, GetDate()) > 7	-- Started more than 7 days ago
								Then Cast(99999999999999.99 As Decimal(18, 2))		-- force over flow  :)
								Else Cast((DateDiff(ss, er.start_time, GetDate())) As Decimal(18,2))
								End	
	, [% Cmp]	= Cast(er.percent_complete As Decimal(12,3))
	, [Req Status] = Coalesce(er.status, 'No Req Active')
	, [Wait Resource] = er.wait_resource
	, [Last Wait] = er.last_wait_type
	, [Wait Type]= Case
					When er.wait_type Is Null And er.status = 'running' Then 'None'
					When er.wait_type Is Null And er.status = 'runnable' Then 'Processor'
					When er.wait_type Is Null Then 'null'
					Else er.wait_type
					End
	, [CPU] = es.cpu_time
	, [Sess Login] = es.login_name
	, [Client PID] = es.host_process_id
	, [Phys Reads] = er.reads
	, [Phys Writes] = er.writes
	, [Logical Reads] = er.logical_reads
	, [Worker Time] = er.cpu_time
	, [Tot Time (Sec)] = Cast(er.total_elapsed_time * 1.0 / 1000.0 As Decimal(24, 3))
	, [Last Req Time] = es.last_request_start_time
	, [Last Req End] = es.last_request_end_time
	, [% Cmp]	= Cast(er.percent_complete As Decimal(12,3))									-- Seems to track progress but only for some queries
	, [Remaining(sec)] = Cast((er.estimated_completion_time / 1000.0) As Decimal(12, 3))		-- Very Approximate
	, [Rows] = er.row_count
	, [Sess Start] = er.start_time
	, [Sess Connect] = ec.connect_time
	, [Provider] = es.client_interface_name
	, [Client IP] = ec.client_net_address
	, [Protocol] = ec.net_transport
	, [Conn Auth] = ec.auth_scheme
	, [Query] = Case When st.encrypted = 1 Then N'encrypted'
				When er.session_id Is Null Then N'er.session_id is null'		-- st.text
				When st.text Is Null Then N'st.text is null'
				When ((Case	When er.statement_end_offset = -1 Then DataLength(st.text)
							Else er.statement_end_offset
							End
						) - er.statement_start_offset) / 2 <= 0
					Then 'Invalid Query Text Length'	--st.text
				Else LTrim(
					Substring(st.text, er.statement_start_offset / 2 + 1, (
							(Case When er.statement_end_offset = -1 Then DataLength(st.text)
								Else er.statement_end_offset
							End
							) - er.statement_start_offset) / 2)
					)
				End
	--, [Login Name] = es.nt_user_name
	--, [Domain] = es.nt_domain
	--, [Packet Size] = ec.net_packet_size
	--, ec.local_net_address
	--, [packet reads] = ec.num_reads
	--, [packet writes] = ec.num_writes
	--, [last packet read] = ec.last_read
	--, [last packet write] = ec.last_write
	, [Most Recent SQL Handle] = ec.most_recent_sql_handle
	--, [xml_batch_query_plan] = QP.query_plan
	--, [xml_statement_query_plan] = TQP.query_plan		  --Comment out if you do not have SQL 2005 SP2 or higher.
-- select  * 
From
	sys.dm_exec_connections As ec
	Inner Join sys.dm_exec_sessions As es
		On ec.session_id = es.session_id
	--Left Join sys.dm_exec_requests As er				-- Change to Left Join to get ALL connections regardless of whether there is an active request
	Inner Join sys.dm_exec_requests As er
		On er.connection_id = ec.connection_id
		--AND er.session_id = ec.most_recent_session_id
	Outer Apply sys.dm_exec_sql_text(er.sql_handle) As st 
--	Outer APPLY sys.dm_exec_query_plan(er.plan_handle) As QP 
--	Outer APPLY sys.dm_exec_text_query_plan(er.plan_handle, er.statement_start_offset, er.statement_end_offset) As TQP  --Comment out if you do not have SQL 2005 SP2 or higher.
Where 1 = 1
	And ec.session_id != @@Spid				-- skip self
	And 1 = Case When(er.wait_type Is Null) Then 1
				When er.wait_type In (							-- Ignore sessions in meaningless wait states
							'BROKER_RECEIVE_WAITFOR', 'WaitFor'
				) Then 0
				Else 1
				End
Order By
	[Blocker]				Desc
	--, [Last Req End] 
	, [Curr Wait(ms)]		Desc		-- er.wait_time
	, [Req Status]			Desc		-- er.status				Desc
	, [SPID]				Asc			-- er.session_id			Asc
	--, [Req Wait Resource]				-- er.wait_resource
	--, [Host]							-- es.host_name
	--, [ElapsedTime(sec)]	Desc		-- = datediff(second, er.start_time, current_timestamp)
;

Return;


--**********************************************************************************************************
/*
	useful code snippets and explanatory text follow.
	These will help interpret and analyze the results.
*/
--- to see the proc parameters for a session use DBCC INPUTBUFFER(SPID)
--  DBCC INPUTBUFFER(116)

-- To find most recent query for a process paste the [Most Recent SQL Handle] in the query below

Select *
From sys.dm_exec_sql_text(0x01000400EB08F51FE0DC3082000000000000000000000000) As st

-- Find the most recent job
;With LastRunJob As
	(Select sj.name, sj.job_id, LastRun = Max(jh.instance_id)
	From msdb.dbo.sysjobs As sj
		Inner Join msdb.dbo.sysjobhistory As jh
			On sj.job_id = jh.job_id
			And jh.step_id = 0
	Group By
		sj.name, sj.job_id
	)
	Select
		jobs = 'job that has a failed step'
	  , l.name
	  , jh.step_name
	  , jh.message
	From
		msdb.dbo.sysjobhistory As jh
		Inner Join LastRunJob As l
			On jh.job_id = l.job_id
			   And jh.instance_id > l.LastRun
			   And jh.run_status <> 1;
 -- 1 = success

Return;

-- To find the Job Name based on Job Id as Varbinary
/*
	The query often shows SQL Agent Jobs in the "program_name" column.  For Example consider:
		SQLAgent - TSQL JobStep (Job 0x2F415BEDA4B24A41960C7F9FC250F4E1 : Step 7)
	The long Hex string is the Job Id which is a Unique Identifier in msdb..sysjobs.  However, it is displayed here
	as a VarBinary() and it is not easy to convert to a Unique Identifier.
		Cut&Paste from Results - 0x2F415BEDA4B24A41960C7F9FC250F4E1
		Divide with Hyphens as - 2F415BED-A4B2-4A41-960C-7F9FC250F4E1
	
	Note the string is in the proper format now but it is still not the correct value.  The first half
	of the string is byte-reversed but the last half is correct.  So 2F415BED has to be morphed to ED5B412F.
	I.E, the order of the bytes (character pairs) has to be reversed.  The same is true for the 2nd and 3rd
	portions of the string.  The final, correct result is:
		ED5B412F-B2A4-414A-960C-7F9FC250F4E1
	An easier solution is to cast the MSDB job_id to VarBinary and compare to the string :)

	This bit of SQL can be used to find the correct Job name.  Just Cut&Paste the hex string directly from
	the query results omitting parens, ticks, quotes, brackets, etc.
*/

Select
	sj.job_id
	,Cast(sj.job_id As Varbinary(36))
	,sj.name
From
	msdb..sysjobs As sj
Where 1 = 1
	And Cast(sj.job_id As Varbinary(36)) = 0xFB6BFE147DE6CD4892F02FF344EC5126-- 0xFB6BFE147DE6CD4892F02FF344EC5126 
;

Return;

-- WaitResource Interpretation
-- from: Understanding and resolving SQL Server blocking problems
-- https://support.microsoft.com/en-us/kb/224453
/*
	WaitResource	Format
	Table:			DB_Id:Object_id:IndexId
	Page:			DB_Id:FileId:PageId
	Key:			DB_Id:Hobt_id (Hash value of index key) Note: The sys.partitions will give Object/Index.  There is no way to unhash the index key hash to a specific index key value.
	Row:			DB_Id:FileId:PageId:Slot(row)		-- Slot is row in the page
	Compile:		DB_Id:ObjectId:[Compile]			-- Lock on stored procedure
*/

-- When WaitResource = KEY -- the first digit, i.e., "9" is the Database Id
-- WaitResource = KEY: 9:72057594696368128 (45537ca690bf)
-- DBId = 9, HOBT = 72057594696368128, Hash = (45537ca690bf)		-- disregard the hash.
-- Use <db Name>
Select [Table] = Object_Name(sp.object_id)
	, [Index] = si.name
From
	sys.partitions As sp
	Inner Join sys.indexes As si
		On si.object_id = sp.object_id
		And si.index_id = sp.index_id
Where
	sp.hobt_id = 72057594696368128	-- <HOBT>
/*
Wait_Resource = Object: "OBJECT: 5:1465185857:0" the first digit, i.e., "5" is the Database Id
	and the second digit string is the object id in the database.

	Select Db_Name(5)
	Select object_name (1465185857, 5)
*/
/*
Wait_Resource is "10:12:6266330" then it is "Db_Id:File_id:PageNum" and can be used
Use DBCC Page as follows:

		DBCC TraceOn (3604)		-- enable output to user console session
		DBCC page (10, 12, 6266330, 3)
About midway down the results page (20 or so lines) you will find:
		Metadata: ObjectId = 1465185857
Which is the object id in the database
	Select object_name (1465185857, 10)

*/

--	Kill 74 with StatusOnly

--	DBCC InputBuffer (114)

Exec zDBAInfo.dbo.sp_WhoIsActive

Exec sp_who2;

Dbcc OpenTran;

Return;

