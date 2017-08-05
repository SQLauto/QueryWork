
/*
	Query for transaction information
	
	$Archive: /SQL/QueryWork/Tran_GetStatusInfo.sql $
	$Date: 15-09-23 15:14 $	$Revision: 2 $

	DBCC OpenTran

	Notes:
	1.  If you run DBCC OpenTran and then this query you may not see the Open Tran result.  This is because, in a well
	tuned system, the transaction will not be open very long :).
	2.  The sys.dm_exec_requests data elements are the same way.  if the request is not blocked or long running
	then it will probably be complete when this query runs.

*/

select
	-- Instance wide and Session data elements
	[InstTxnId] = at.transaction_id
	, [SPID] = st.session_id
	, [Host] = es.host_name
	, [NTUserName] = es.nt_user_name
	, [Program] = es.program_name
	, [TxnStart] = at.transaction_begin_time
	, [Duration(ms)] = DateDiff(ms, at.transaction_begin_time, getDate())
	, [IsUser] = case when st.is_user_transaction = 1 then 'User' else 'System' end
	, [IsLocal] = case when st.is_local = 1 then 'Local' else 'Dsitributed' end
	, [IsEnliseted] = case when st.is_enlisted = 1 then 'Enliseted' else 'Not Enlisted' end
	, [TxnName] = at.name
	, [TxnState] = Case at.transaction_state When 0 Then 'Not full Intialized'
					When 1 Then 'Initialized not Started'
					When 2 Then 'Active'
					When 3 Then 'Ended (R/O Only)'
					When 4 Then 'Commit Initiated (Distributed Only)'
					When 5 Then 'Preped - Waiting Resolution'
					When 6 Then 'Committed'
					When 7 Then 'Rolling Back'
					When 8 Then 'Rolled Back'
					Else 'Unknown'
					End
	, [TxnType] = Case at.transaction_type When 1 Then 'Read/Write'
				When 2 then 'Read Only'
				When 3 then 'System'
				When 4 Then 'Distributed'
				Else 'Unknown'
				End
	, [Database] = db_Name(dt.database_id)
	, [Txntate] = Case dt.database_transaction_state When 1 then 'Not Initialized'
				When 3 then 't-log initialize'
				When 4 then 't-log used'
				When 5 then 'tran preped'
				When 10 then 'tran committed'
				When 11 then 'rolling back'
				When 12 then 'being committed'
				else 'Unknown'
				End
	, [DBTxnType] = Case dt.database_transaction_type When 1 Then 'Read/Write'
				When 2 then 'Read Only'
				When 3 then 'System'
				Else 'Unknown'
				End
	, [DBTxnStart] = dt.database_transaction_begin_time
	, [DBTxnLogRecords] = dt.database_transaction_log_record_count
	, [DBTxnLogBytes] = dt.database_transaction_log_bytes_used
	--,dt.*
from sys.dm_tran_active_transactions as at
	inner join sys.dm_tran_session_transactions as st
		on st.transaction_id = at.transaction_id
	inner join sys.dm_tran_database_transactions as dt
		on dt.transaction_id = at.transaction_id
	left outer join sys.dm_exec_sessions as es
		on es.session_id = st.session_id
Order By
	at.transaction_id