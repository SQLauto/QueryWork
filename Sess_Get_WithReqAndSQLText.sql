/*
	Script based on Listing 2.14 and Listing 2.20 
		Performance Tuning with SQL Server Dynamic Views by Louis Davidson and Tim Ford
		SimpleTalk Publishing 2010
	This script returns list of currently executing code on the SQL instance.
	
	Additional References:
		SQL server: Deciphering Wait resource - http://www.practicalsqldba.com/2012/04/sql-server-deciphering-wait-resource.html
	$Workfile: ExecSessionsAndReq_Get_WithSQLText.sql $
	$Archive: /SQL/QueryWork/ExecSessionsAndReq_Get_WithSQLText.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/

Use Master

Select
	[SPID] = der.session_id
	,[Blker] = der.blocking_session_id
	,[Status] = des.status
	,[Elapsed Time(ms)] = der.total_elapsed_time
	--,[Est Complete] = der.estimated_completion_time -- Meaningless number
	,[% Complete] = der.percent_complete
	,[Wait Time (ms)] = der.wait_time
	,[Resource] = case when der.wait_resource = '' then 'None' else der.wait_resource end
	,[Wait Type] = der.wait_type
	,[Reads] = des.reads
	,[Writes] = des.writes
	,[CPU (ms)] = des.cpu_time
	,[Command] = der.command
	,[Login] = des.login_name
	,[Host] = des.host_name
	,[Application] = des.program_name
	,[Last Read] = dec.last_read
	,[Last Write] = dec.last_write
	,[Database_Name] = DB_NAME(der.database_id)
	,[ObjectName] = OBJECT_NAME(dest.objectid, der.database_id)
	,[last request start] = des.last_request_start_time
	--,[Last request End] = des.last_request_end_time
	--,[Stmt Strt] = der.statement_start_offset
	--,[Stmt End] = der.statement_end_offset
	,[StatementExecuting] =
		SUBSTRING(dest.text, der.statement_start_offset / 2
				, (Case When der.statement_end_offset < 0 Then DATALENGTH(dest.text)
						Else der.statement_end_offset
					End) / 2
				)
	,[Qry Pln] = deqp.query_plan
From
	sys.dm_exec_sessions as des
	left join sys.dm_exec_requests as der
		on des.session_id = der.session_id
	left join sys.dm_exec_connections as dec
		on dec.session_id = des.session_id
	Cross Apply sys.dm_exec_sql_text(der.sql_handle) as dest
	Cross Apply sys.dm_exec_query_plan(der.plan_handle) as deqp
Where 1 = 1
	and des.is_user_process = 1
	--and des.session_id != @@SPID
	--and der.wait_type not like '%WaitFor%'
	--and des.session_id in (55, 94, 154)
order by
	der.wait_time desc

Return
-- sp_Who2
-- Kill 79

/*
	Determine object for Wait Resource
*/
DBCC traceOn (3604, 1)	-- Send DBCC Page output to this session

DBCC Page (5, 9, 12915894)	-- Resource Id = dbid, fileid, pageid

-- look for tag "Metadata: ObjectId = 1323333416" about mid way down the output
Select OBJECT_NAME(1323333416, 5)	-- Object_id, DBId

-- If the resource is a HOBT eg 72057594040811520
SELECT 
	 [TableName] = o.name
	,[IndexName] = i.name
	,[SchemaName] = SCHEMA_NAME(o.schema_id)
FROM
	sys.partitions As p
	Inner JOIN sys.objects as o
		ON p.OBJECT_ID = o.OBJECT_ID 
	Inner JOIN sys.indexes as i
		ON p.OBJECT_ID = i.OBJECT_ID
			AND p.index_id = i.index_id 
WHERE p.hobt_id = 72057594040811520


Return