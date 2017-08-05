-- $Workfile: TempDB_DetermineUsage.sql $

/*
	This is a collection of diagnostic queries to investigate TEMPDB usage.
	Original reference was
		Monitoring tempdb Transactions and Space usage
		http://blogs.msdn.com/b/deepakbi/archive/2010/04/14/monitoring-tempdb-transactions-and-space-usage.aspx
	Queries have been "Rayified" and extended.
	$Archive: /SQL/QueryWork/TempDB_DetermineUsage.sql $
	$Revision: 3 $	$Date: 14-06-30 11:01 $
	
*/
-- check the current tempdb size
Use tempdb;
Select
	[Free Pages] = Sum(unallocated_extent_page_count)
	, [Free Space in GB] = Cast((Sum(unallocated_extent_page_count)*1.0/128)/1000.0 As DECIMAL(12,2))
From sys.dm_db_file_space_usage
;
Return;

-- Determine the Amount Space Used by the Version Store
Use tempdb;
Select
	[version store pages used] = Sum(version_store_reserved_page_count)
	,[version store space in MB]  = (Sum(version_store_reserved_page_count)*1.0/128)
From sys.dm_db_file_space_usage
;
Return;

-- Determine the Running Transactions by duration
Use tempdb;
Select
	[SPID] = tas.session_id
	--, [Trans Id] = tas.transaction_id
	, [Duration (s)] = tas.elapsed_time_seconds
	, [Memory USAGE (MB)] = Cast((es.memory_usage * 1.0 / 128.0) As DECIMAL(15,3))
	, [User Obj in use(MB)] = Cast((ssu.user_objects_alloc_page_count * 1.0 / 128.0) - (ssu.user_objects_dealloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	, [Host Name] = es.host_name
	, [USER Name] = es.login_name
	, [Host PID] = es.host_process_id
	, [Interface] = es.client_interface_name
	, [Program] = es.program_name
	, [Alloc USER Obj (MB)] = Cast((ssu.user_objects_alloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	, [Dealloc USER Obj (MB)] = Cast((ssu.user_objects_dealloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	, [Alloc Internal Obj (MB)] = Cast((ssu.internal_objects_alloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	, [Dealloc Internal Obj (MB)] = Cast((ssu.internal_objects_dealloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	--, es.*
	--, tas.*
From sys.dm_tran_active_snapshot_database_transactions As tas
	Inner Join sys.dm_exec_sessions As es
		On tas.session_id = es.session_id
	Left Join sys.dm_db_session_space_usage As ssu
		On tas.session_id = ssu.session_id
Where 1 = 1
	And es.is_user_process = 1
Order By
	tas.elapsed_time_seconds Desc;

Return;

-- TempDB Session File usage
Use tempdb;
Select
	[SPID] = es.session_id
	, [Host Name] = es.host_name
	, [Login Name] = es.login_name
	, [Program Abbr] = Substring(es.program_name, 1, 20)
	, [CPU TIME (ms)] = es.cpu_time
	, [Elapsed Time (ms)] = es.total_elapsed_time
	, [Alloc Total (MB)] = Cast((ssu.user_objects_alloc_page_count * 1.0 / 128.0) + (ssu.internal_objects_alloc_page_count * 1.0 / 128.0)  As DECIMAL(15,3))
	, [Scheduled Time (ms)] = es.total_scheduled_time
	, [Memory Usage (MB)] = Cast((es.memory_usage * 1.0 / 128.0) As DECIMAL(15,3))
	, [Alloc User Obj (MB)] = Cast((ssu.user_objects_alloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	, [Dealloc User Obj (MB)] = Cast((ssu.user_objects_dealloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	--, [User Obj in use(MB)] = cast((ssu.user_objects_alloc_page_count * 1.0 / 128.0) - (ssu.user_objects_dealloc_page_count * 1.0 / 128.0) as DECIMAL(15,3))
	, [Alloc Internal Obj (MB)] = Cast((ssu.internal_objects_alloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	, [Dealloc Internal Obj (MB)] = Cast((ssu.internal_objects_dealloc_page_count * 1.0 / 128.0) As DECIMAL(15,3))
	, [SESSION Type] = Case es.is_user_process
		When 1 Then 'user session'
		When 0 Then 'system session'
		End
	, [Row Count] = es.row_count
	, [Database Name] = Db_Name(ssu.database_id)
	, [Program Name] = es.program_name
	, [Session Status] = es.status
From
	sys.dm_db_session_space_usage As ssu
	Inner Join sys.dm_exec_sessions As es
		On ssu.session_id = es.session_id
Where 1 = 1
	--and es.is_user_process = 1
	And es.session_id > 50	-- skip system sessions
;
Return;

-- Long running transction / Log space
Select
	--[Transacton ID] = at.transaction_id
	[Host] = es.host_name
	, [user] = es.login_name
	, [Program] = es.program_name
	, [Session Id] = Coalesce(st.session_id, -1)
	, [TRANSACTION Name] = at.[name]
	, [TRANSACTION BEGIN TIME] = at.transaction_begin_time
	, [Elapsed TIME (in MIN)] = DateDiff(mi, at.transaction_begin_time, GetDate())
	, [TRANSACTION Type] = Case at.transaction_type
			When 1 Then 'Read/write'
			When 2 Then 'Read-only'
			When 3 Then 'System'
			When 4 Then 'Distributed'
		End
	, [TRANSACTION Description] = Case at.transaction_state
			When 0 Then 'The transaction has not been completely initialized yet.'
			When 1 Then 'The transaction has been initialized but has not started.'
			When 2 Then 'The transaction is active.'
			When 3 Then 'The transaction has ended. This is used for read-only transactions.'
			When 4
			Then 'The commit process has been initiated on the distributed transaction. This is for distributed transactions only. The distributed transaction is still active but further processing cannot take place.'
			When 5 Then 'The transaction is in a prepared state and waiting resolution.'
			When 6 Then 'The transaction has been committed.'
			When 7 Then 'The transaction is being rolled back.'
			When 8 Then 'The transaction has been rolled back.'
		End
From
	sys.dm_tran_active_transactions As at
	Left Outer Join sys.dm_tran_session_transactions As st
		On st.transaction_id = at.transaction_id
	Inner Join sys.dm_exec_sessions As es
		On es.session_id = st.session_id
Where 1 = 1
	And st.session_id Is Not Null
Order By
	[Elapsed TIME (in MIN)]  Desc
;
Return;

-- DBCC OpenTran
--  Running Queries (Exec Requests) using tempDB
-- I think this means the session has a "use TempDb"
Use tempdb;
Select
	[SPID] = der.session_id
	--, [DATABASE Name] = db_name(der.database_id)
	, [User Name] = User_Name(der.user_id)
	--, [CONNECTION ID] = der.connection_id
	, [Command] = der.command
	, [Blocking SPID] = der.blocking_session_id
	, [Elapsed TIME (ms)] = der.total_elapsed_time
	, [Percent Completed] = der.percent_complete
	, [Host Name] = des.host_name
	, [Program Name] = des.program_name
	, [Est Completion Time (ms)] = der.estimated_completion_time
	, [CPU Time used (ms)] = der.cpu_time
	, [Request Start Time] = der.start_time
	, [Status] = der.status
	, [Command Type] = der.command
	, [Waiting Type] = der.wait_type
	, [Waiting Duration] = der.wait_time
	, [Waiting FOR Resource] = der.wait_resource
	--, [Transaction ID] = der.transaction_id
	, [Memory Usage (KB)] = (des.memory_usage * 8)
	, [Query Text] = (Select text From sys.dm_exec_sql_text(der.sql_handle))
From
	sys.dm_exec_requests As der
	Inner Join sys.dm_exec_sessions As des
		On der.session_id = des.session_id
Where 1 = 1
	And der.database_id = Db_Id('tempdb')
	And des.is_user_process = 1	-- User Processes only
	And der.session_id != @@SPID

Order By
	[Elapsed TIME (ms)] Desc
;
Return;
