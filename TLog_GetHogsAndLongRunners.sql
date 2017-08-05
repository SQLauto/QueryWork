--$Workfile: TLog_GetHogsAndLongRunners.sql $
/*
-- Purpose: Report active transactions by space or duration.
-- Author: I. Stirk.
What SQL Statements Are Currently Using The Transaction Logs?
http://www.sqlservercentral.com/articles/Transaction+Log/122600/

	$Archive: /SQL/QueryWork/TLog_GetHogsAndLongRunners.sql $
	$Date: 15-03-25 15:50 $	$Revision: 2 $
*/

-- Do not lock anything, and do not get held up by any locks.
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- What SQL statements are currently using the transaction logs?
SELECT
	tst.session_id
  , es.original_login_name
  , es.host_name
  , [Database] = DB_NAME(tdt.database_id)
  , [TxnDur-sec] =  DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE())
  , [NumLogRecords] =  tdt.database_transaction_log_record_count
  , [LogBytesUsed] =  tdt.database_transaction_log_bytes_used
  , [TxnType] = CASE tat.transaction_type
      WHEN 1 THEN 'R/W Txn'
      WHEN 2 THEN 'RO Txn'
      WHEN 3 THEN 'System Txn'
              WHEN 4 THEN 'Distributed Txn'
              ELSE 'Unknown'
	END
  , [TxnState] = CASE tat.transaction_state
      WHEN 0 THEN 'Txn not completely initialized'
      WHEN 1 THEN 'Txn initialized - not started'
      WHEN 2 THEN 'Txn is active'
      WHEN 3 THEN 'Txn has ended'
      WHEN 4 THEN 'Commit Initiated - Distributed Tran'
      WHEN 5 THEN 'Txn in prepared state - waiting resolution'
      WHEN 6 THEN 'Txn committed'
      WHEN 7 THEN 'Txn being rolled back'
      WHEN 8 THEN 'Txn rolled back'
      ELSE 'Unknown'
  END
  , [CurrentQuery] = SUBSTRING(TXT.text, ( er.statement_start_offset / 2 ) + 1,
       ( ( CASE WHEN er.statement_end_offset = -1
                     THEN LEN(CONVERT(NVARCHAR(MAX), TXT.text)) * 2
                     ELSE er.statement_end_offset
              END - er.statement_start_offset ) / 2 ) + 1)
  , TXT.text
  , [TxnStart] = tat.transaction_begin_time
FROM sys.dm_tran_session_transactions AS tst
       INNER JOIN sys.dm_tran_active_transactions AS tat
              ON tst.transaction_id = tat.transaction_id
       INNER JOIN sys.dm_tran_database_transactions AS tdt
              ON tst.transaction_id = tdt.transaction_id
       INNER JOIN sys.dm_exec_sessions es
              ON tst.session_id = es.session_id
       INNER JOIN sys.dm_exec_requests er
              ON tst.session_id = er.session_id
       CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) TXT
--ORDER BY tdt.database_transaction_log_record_count DESC -- log space size.
ORDER BY
	--[TxnDur-sec] DESC -- transaction duration.
	[LogBytesUsed] Desc