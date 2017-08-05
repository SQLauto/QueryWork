/*
	This script based on:
	Andrew Pruski - Identifying large queries using Extended Events
		http://www.sqlservercentral.com/blogs/the-dba-who-came-in-from-the-cold/2014/10/01/identifying-large-queries-using-extended-events/

	$Archive: /SQL/QueryWork/XE_FirstTrys.sql $
	$Revision: 1 $	$Date: 14-10-31 9:03 $

	Sigh ;(
	The Event in the article (SQL_Batch_Completed) does not seem to be available in SQL 2008R2
	The File name attribute in the Target clause apparently requires a literal !!!
*/

USE [master];
GO

Declare
	@DateStr	NVARCHAR(128)
	, @FileName	NVARCHAR(50)
	, @FilePath	NVARCHAR(128)
	;
Set @DateStr = LEFT(REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(24), GETDATE(), 120), ':', ''), '-', ''), ' ', '_'), 13);
Print @DateStr;

Set @FileName = N'QueryGT2KReads_' + @DateStr + N'.xel';
Set @FilePath = Case @@SERVERNAME
				When N'rHerring\SQL2008R2' Then N'C:\_Simmons\PerformanceData\XEvents\'
				When N'Dev2008R2' Then N'C:\rHerring\XEvents\'
				Else N'C:\rHerring'
				End;

CREATE EVENT SESSION [QueriesWith2kReads] ON SERVER 
	ADD EVENT sqlserver.sql_batch_completed(
		ACTION(sqlserver.client_hostname
			,sqlserver.database_name
			,sqlserver.session_id
			,sqlserver.sql_text
			,sqlserver.tsql_stack
			,sqlserver.username)
		WHERE ([logical_reads]>2000))
	ADD TARGET package0.event_file(SET filename = N'C:\_Simmons\PerformanceData\XEvents\QueryGT2KReads.xel')
													 -- N'C:\SQLServer\XEvents\QueriesWith200kReads.xel')
GO
