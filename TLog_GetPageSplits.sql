/*

	How to read the SQL Server Database Transaction Log
	http://www.mssqltips.com/sqlservertip/3076/how-to-read-the-sql-server-database-transaction-log/?utm_source=dailynewsletter&utm_medium=email&utm_content=text&utm_campaign=20150430
	$Archive: /SQL/QueryWork/TLog_GetPageSplits.sql $
	$Date: 15-04-30 15:22 $	$Revision: 1 $
*/

--Get how many times page split occurs.
SELECT 
 --sp.[Current LSN],
 --sp.[Transaction ID],
 --sp.[Operation],
 sp.[Transaction Name],
 --sp.[CONTEXT],
 --sp.[AllocUnitName],
 --sp.[Page ID],
 --sp.[Slot ID],
 --sp.[Begin Time],
 --sp.[End Time],
 --sp.[Number of Locks],
 --sp.[Lock Information],
 so.[Current LSN],
 so.[Transaction ID],
 so.[Operation],
 so.[Transaction Name],
 so.[CONTEXT],
 so.[AllocUnitName],
 so.[Page ID],
 so.[Slot ID],
 so.[Begin Time],
 so.[End Time],
 so.[Number of Locks],
 so.[Lock Information]
FROM sys.fn_dblog(NULL,NULL) as sp
	inner join sys.fn_dblog(NULL,NULL) as so
		on so.[Transaction ID] = sp.[Transaction ID]
WHERE sp.[Transaction Name] = 'SplitPage'

Return

--Get what all steps SQL Server performs during a single Page Split occurrence.
SELECT 
 [Current LSN],
 [Transaction ID],
 [Operation],
  [Transaction Name],
 [CONTEXT],
 [AllocUnitName],
 [Page ID],
 [Slot ID],
 [Begin Time],
 [End Time],
 [Number of Locks],
 [Lock Information]
FROM sys.fn_dblog(NULL,NULL)
WHERE [Transaction ID]='0004:387350d3'  
--	0004:387350d2
--	0004:387350d3