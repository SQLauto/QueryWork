/*
	What SQL Statements Are Currently Using The Transaction Logs?
	By Ian Stirk, 2016/06/17 (first published: 2015/03/10)
	http://www.sqlservercentral.com/articles/Transaction+Log/122600/
-- Purpose: Report active transactions by space or duration.
-- Author: I. Stirk.
	$Archive: /SQL/QueryWork/TLog_QueryUsageByDB.sql $
	$Revision: 1 $	$Date: 16-06-21 15:03 $
*/
-- Do not lock anything, and do not get held up by any locks.
Set NoCount On;
Set Transaction Isolation Level Read Uncommitted;
Go
-- What SQL statements are currently using the transaction logs?
Select [SPID] = tst.session_id
	, [OrigLogin] = es.original_login_name
	, [TransDuration(s)] = DateDiff(Millisecond, tat.transaction_begin_time, GetDate())
	, [DatabaseName] = Db_Name(tdt.database_id)
	, [SpaceUsed] = tdt.database_transaction_log_bytes_used
	, [SpaceRes] = tdt.database_transaction_log_bytes_reserved
	, [Log Records] = tdt.database_transaction_log_record_count
	, [DB Duration] = DateDiff(Millisecond, tdt.database_transaction_begin_time, GetDate())
	, [TransactionState] = Case tat.transaction_state
		When 0 Then 'The transaction has not been completely initialized yet'
		When 1 Then 'The transaction has been initialized but has not started'
		When 2 Then 'The transaction is active'
		When 3 Then 'The transaction has ended'
		When 4 Then 'The commit process has been initiated on the distributed tran'
		When 5 Then 'The transaction is in a prepared state and waiting resolution'
		When 6 Then 'The transaction has been committed'
		When 7 Then 'The transaction is being rolled back'
		When 8 Then 'The transaction has been rolled back'
		Else 'Unknown'
	End
	, [CurrentQuery] = Substring(TXT.text, (er.statement_start_offset / 2) + 1,
				((Case When er.statement_end_offset = -1 Then Len(Convert(NVarchar(Max), TXT.text)) * 2
						Else er.statement_end_offset
				End - er.statement_start_offset) / 2) + 1)
	, [ParentQuery] = txt.text 
	, [Host] = es.host_name
	, [TransactionType] = Case tat.transaction_type
		When 1 Then 'Read/Write Transaction'
		When 2 Then 'Read-Only Transaction'
		When 3 Then 'System Transaction'
		When 4 Then 'Distributed Transaction'
		Else 'Unknown'
	End
	, [StartTime] = tat.transaction_begin_time
From sys.dm_tran_session_transactions As tst
	Inner Join sys.dm_tran_active_transactions As tat
		On tst.transaction_id = tat.transaction_id
	Inner Join sys.dm_tran_database_transactions As tdt
		On tst.transaction_id = tdt.transaction_id
	Inner Join sys.dm_exec_sessions As es
		On tst.session_id = es.session_id
	Inner Join sys.dm_exec_requests As er
		On tst.session_id = er.session_id
	Cross Apply sys.dm_exec_sql_text(er.sql_handle) As txt
Order By
	[SPID]
	-- , [TransDuration(s)] Desc -- transaction duration.
	, tdt.database_transaction_log_record_count DESC -- log space size.
	;