/*
	SQL Server Wait Information from sys.dm_os_wait_stats
	Copyright (C) 2013, Brent Ozar Unlimited.
	See http://BrentOzar.com/go/eula for the End User Licensing Agreement.
	Based on Paul Randal Blog
	Wait statistics, or please tell me where it hurts
	http://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/

	Modifed by adding addtional ignorable waits from Paul Randal.
	RayiFied.
	
	$Archive: /SQL/QueryWork/WaitStats_Get_TotAndSample.sql $
	$Revision: 3 $	$Date: 18-02-02 16:14 $

	
--	DBCC SQLPERF (N'sys.dm_os_wait_stats', CLEAR);

*/

/*********************************
Let's build a list of waits we can safely ignore.
*********************************/
If Object_Id ('tempdb..#ignorable_waits') Is Not Null Drop Table #ignorable_waits;
Go

Create Table #ignorable_waits (wait_type NVARCHAR(256) Primary Key);
Insert
	#ignorable_waits (wait_type)
	Values ('')
		, (N'BROKER_EVENTHANDLER'), (N'BROKER_RECEIVE_WAITFOR'), (N'BROKER_TASK_STOP'), (N'BROKER_TRANSMITTER'), (N'BROKER_TO_FLUSH')

		, (N'CHECKPOINT_QUEUE'), (N'CHKPT')

		, (N'CLR_AUTO_EVENT'), (N'CLR_MANUAL_EVENT'), (N'CLR_SEMAPHORE')

		, (N'DBMIRROR_DBM_EVENT'), (N'DBMIRROR_DBM_MUTEX'), (N'DBMIRROR_EVENTS_QUEUE'), (N'DBMIRROR_WORKER_QUEUE'), (N'DBMIRRORING_CMD')

		, (N'DIRTY_PAGE_POLL')
		, (N'DISPATCHER_QUEUE_SEMAPHORE')
		, (N'EXECSYNC')
		, (N'FSAGENT')
		, (N'FT_IFTSHC_MUTEX'), (N'FT_IFTS_SCHEDULER_IDLE_WAIT')

		, (N'HADR_CLUSAPI_CALL'), (N'HADR_FILESTREAM_IOMGR_IOCOMPLETION'), (N'HADR_LOGCAPTURE_WAIT'), (N'HADR_NOTIFICATION_DEQUEUE')
		, (N'HADR_TIMER_TASK'), (N'HADR_WORK_QUEUE')

		, (N'KSOURCE_WAKEUP')
		, (N'LAZYWRITER_SLEEP')
		, (N'LOGMGR_QUEUE')
		, (N'ONDEMAND_TASK_QUEUE')
		, (N'PWAIT_ALL_COMPONENTS_INITIALIZED')

		, (N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'), (N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP')

		, (N'REQUEST_FOR_DEADLOCK_SEARCH')
		, (N'RESOURCE_QUEUE')
		, (N'SERVER_IDLE_CHECK')

		, (N'SLEEP_BPOOL_FLUSH'), (N'SLEEP_DBSTARTUP'), (N'SLEEP_DCOMSTARTUP'), (N'SLEEP_MASTERDBREADY')
		, (N'SLEEP_MASTERMDREADY'), (N'SLEEP_MASTERUPGRADED'), (N'SLEEP_MSDBSTARTUP'), (N'SLEEP_SYSTEMTASK')
		, (N'SLEEP_TASK'), (N'SLEEP_TEMPDBSTARTUP')

		, (N'SNI_HTTP_ACCEPT')
		, (N'SP_SERVER_DIAGNOSTICS_SLEEP')

		, (N'SQLTRACE_BUFFER_FLUSH'), (N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP'), (N'SQLTRACE_WAIT_ENTRIES')

		, (N'WAIT_FOR_RESULTS'), (N'WAITFOR'), (N'WAITFOR_TASKSHUTDOWN')
		, (N'WAIT_XTP_HOST_WAIT'), (N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG'), (N'WAIT_XTP_CKPT_CLOSE')

		, (N'XE_DISPATCHER_WAIT'), (N'XE_DISPATCHER_JOIN'), (N'XE_TIMER_EVENT')
		;

/*********************************
What are the highest overall waits since startup?
*********************************/
Select Top 50
	[Wait Type] = os.wait_type
  , [Total Wait (ms)]	= Sum (os.wait_time_ms) Over (Partition By os.wait_type)
  , [Percent Wait Time]		= Cast(100.0 * Sum (os.wait_time_ms) Over (Partition By os.wait_type)
							 / (1.0 * Sum (os.wait_time_ms) Over ()) As NUMERIC(12, 1))
  , [Cnt Waiting Tasks]	= Sum (os.waiting_tasks_count) Over (Partition By os.wait_type)
  , [Avg Wait Time (ms)]  = Case
							When Sum (os.waiting_tasks_count) Over (Partition By os.wait_type) > 0 Then
							Cast(Sum (os.wait_time_ms) Over (Partition By os.wait_type)
								 / (1.0 * Sum (os.waiting_tasks_count) Over (Partition By os.wait_type)) As NUMERIC(12, 1))
							Else 0
						End
  , [Sample Time]	= Current_Timestamp
From
	sys.dm_os_wait_stats As os
	Left Join #ignorable_waits As iw
		On os.wait_type = iw.wait_type
Where iw.wait_type Is Null
Order By [Total Wait (ms)] Desc;
Go

/*********************************
What are the higest waits *right now*?
*********************************/

/* Note: this is dependent on the #ignorable_waits table created earlier. */
If Object_Id ('tempdb..#wait_batches') Is Not Null Drop Table #wait_batches;
If Object_Id ('tempdb..#wait_data') Is Not Null Drop Table #wait_data;
Go

Create Table #wait_batches (batch_id INT Identity Primary Key, sample_time DATETIME Not Null);
Create Table #wait_data (
	batch_id	  INT			Not Null
  , wait_type	  NVARCHAR(256) Not Null
  , wait_time_ms  BIGINT		Not Null
  , waiting_tasks BIGINT		Not Null
);
Create Clustered Index cx_wait_data On #wait_data (batch_id);
Go

/*
This temporary procedure records wait data to a temp table.
*/
If Object_Id ('tempdb..#get_wait_data') Is Not Null Drop Procedure #get_wait_data;
Go
Create Procedure #get_wait_data
	@intervals TINYINT	= 2
  , @delay	   CHAR(12) = '00:00:30.000'	/* 30 seconds*/
As
	Declare
		@batch_id INT
	  , @current_interval TINYINT
	  , @msg NVARCHAR(Max);

	Set NoCount On;
	Set @current_interval = 1;

	While @current_interval <= @intervals
	Begin
		Insert #wait_batches (sample_time) Select Current_Timestamp;

		Select @batch_id = Scope_Identity ();

		Insert
			#wait_data (batch_id, wait_type, wait_time_ms, waiting_tasks)
			Select
				@batch_id
			  , os.wait_type
			  , sum_wait_time_ms  = Sum (os.wait_time_ms) Over (Partition By os.wait_type)
			  , sum_waiting_tasks = Sum (os.waiting_tasks_count) Over (Partition By os.wait_type)
			From
				sys.dm_os_wait_stats As os
				Left Join #ignorable_waits As iw
					On os.wait_type = iw.wait_type
			Where iw.wait_type Is Null
			Order By sum_wait_time_ms Desc;

		Set @msg = Convert (CHAR(23), Current_Timestamp, 121) + N': Completed sample '
			  + Cast(@current_interval As NVARCHAR(4)) + N' of ' + Cast(@intervals As NVARCHAR(4)) + '.';
		Raiserror (@msg, 0, 0) With NoWait;

		Set @current_interval = @current_interval + 1;

		If @current_interval <= @intervals WaitFor Delay @delay;
	End;
Go

/*
Let's take two samples 30 seconds apart
*/
Exec #get_wait_data @intervals = 2, @delay = '00:00:30.000';
Go

/*
What were we waiting on?
This query compares the most recent two samples.
*/
With max_batch As (Select Top 1 batch_id, sample_time From #wait_batches Order By batch_id Desc)
Select
	[Second Sample Time]		 = b.sample_time
  , [Sample Duration in Seconds] = DateDiff (ss, wb1.sample_time, b.sample_time)
  , wd1.wait_type
  , [Wait Time (Seconds)]		 = Cast((wd2.wait_time_ms - wd1.wait_time_ms) / 1000. As NUMERIC(12, 1))
  , [Number of Waits]			 = (wd2.waiting_tasks - wd1.waiting_tasks)
  , [Avg ms Per Wait]			 = Case
									   When (wd2.waiting_tasks - wd1.waiting_tasks) > 0 Then
									   Cast((wd2.wait_time_ms - wd1.wait_time_ms)
											/ (1.0 * (wd2.waiting_tasks - wd1.waiting_tasks)) As NUMERIC(12, 1))
									   Else 0
								   End
From
	max_batch As b
	Inner Join #wait_data As wd2
		On wd2.batch_id = b.batch_id
	Inner Join #wait_data As wd1
		On wd1.wait_type = wd2.wait_type And wd2.batch_id - 1 = wd1.batch_id
	Inner Join #wait_batches As wb1
		On wd1.batch_id = wb1.batch_id
Where (wd2.waiting_tasks - wd1.waiting_tasks) > 0
Order By [Wait Time (Seconds)] Desc;
Go
Return;

/*
Appendix A: Monitoring SQL Server health
https://technet.microsoft.com/en-us/library/bb838723(office.12).aspx
*/
/*
select wait_type
	, waiting_tasks_count
	, wait_time_ms
	, signal_wait_time_ms
	, [Avg MS per I/O Wait] = wait_time_ms / waiting_tasks_count
	, [Avg MS per Signal Wait] = signal_wait_time_ms / waiting_tasks_count
	
from sys.dm_os_wait_stats  
where wait_type like 'PAGEIOLATCH%'  and waiting_tasks_count > 0
order by wait_type

select 
    database_id, 
    file_id, 
    io_stall,
    io_pending_ms_ticks,
    scheduler_address 
from  sys.dm_io_virtual_file_stats(NULL, NULL)t1,
        sys.dm_io_pending_io_requests as t2
where t1.file_handle = t2.io_handle

select top 5 (total_logical_reads/execution_count) as avg_logical_reads,
                   (total_logical_writes/execution_count) as avg_logical_writes,
           (total_physical_reads/execution_count) as avg_physical_reads,
           Execution_count, statement_start_offset, p.query_plan, q.text
from sys.dm_exec_query_stats
      cross apply sys.dm_exec_query_plan(plan_handle) p
      cross apply sys.dm_exec_sql_text(plan_handle) as q
order by (total_logical_reads + total_logical_writes)/execution_count Desc

select top 5 
    (total_logical_reads/execution_count) as avg_logical_reads,
    (total_logical_writes/execution_count) as avg_logical_writes,
    (total_physical_reads/execution_count) as avg_phys_reads,
     Execution_count, 
    statement_start_offset as stmt_start_offset, 
    sql_handle, 
    plan_handle
from sys.dm_exec_query_stats  
order by  (total_logical_reads + total_logical_writes) Desc

*/