

/*
	The Scary DBA - Grant Fritchey - http://www.sqlservercentral.com/blogs/scarydba/
	Targeted Plan Cache Removal
	http://www.sqlservercentral.com/blogs/scarydba/2015/08/24/targeted-plan-cache-removal/

	$Archive: /SQL/QueryWork/QP_GetForText.sql $
	$Date: 15-09-11 12:24 $	$Revision: 3 $

	Eamil to Grant asksing for some quidance/input.  He was very helpful.

	Objective is given a SQL Text string, say a query in a UDF or a Table Name, return the Query Stats and Plan
	for queries that contain that string.
*/
-- Based on Query from Grant Fritchey via Email.
Declare
	 @PlanHandle	Varbinary(64)
	 , @ProcName	NVarchar(128)
	 , @strSearch	NVarchar(128)
	 , @dummy		NVarchar(128) = N'[SPID] = er.session_id'
	 , @LF			NChar(1) = NChar(10)
	 , @Cr			NChar(1) = NChar(13)
	 , @Tab			NChar(1) = NChar(9)
	 , @Blank		NChar(1) = NChar(32)
	 ;

Set @strSearch = N'ConSIRNPanelExceptions';

Select
	[SPID] = er.session_id
	, [ObjectName] = Coalesce(Object_Name(st.objectid, st.dbid), 'N/A')
	, [Time in Cache (hours)] = DateDiff(hh, qs.creation_time, GetDate())
	, [Execution Count] = qs.execution_count
	, [Avg Execution/Hour] = qs.execution_count / Case When DateDiff(hh, qs.creation_time, GetDate()) = 0 Then 1 Else  DateDiff(hh, qs.creation_time, GetDate()) End
	, [Tot Worker Time (ms)] = qs.total_worker_time / 1000
	, [Max Worker Time (ms)] = qs.max_worker_time / 1000
	, [Avg Worker Time (ms)] = ((qs.total_worker_time / 1000) / qs.execution_count)
	, [Tot Elapsed Time (ms)] = qs.total_elapsed_time / 1000
	, [Max Elapsed Time (ms)] = qs.max_elapsed_time / 1000
	, [Avg Elapsed Time (ms)] = ((qs.total_elapsed_time / 1000) / qs.execution_count)
	, [Tot Logical Reads] = qs.total_logical_reads
	, [Max Logical Reads] = qs.max_logical_reads
	, [Avg Logical Reads] = (qs.total_logical_reads / qs.execution_count)
	, [Tot Rows] = qs.total_rows
	, [Max Rows] = qs.max_rows
	, [Avg Rows] = (qs.total_rows / qs.execution_count)
	, [Qry Text] = Case when ((case qs.statement_end_offset
								WHEN -1 THEN datalength(st.text)
								ELSE qs.statement_end_offset
								END - qs.statement_start_offset)
								/ 2) + 1 <= 0 then st.text
						else substring(st.text, (qs.statement_start_offset / 2) + 1, 
							((case qs.statement_end_offset
							WHEN -1 THEN datalength(st.text)
							ELSE qs.statement_end_offset
							END
							- qs.statement_start_offset)
							 / 2) + 1)
						end
	, [Query Plan] = qp.query_plan
	, [Last Execution] = qs.last_execution_time
	, [Cache Time] = qs.creation_time
	--, [Tot CLR Time(ms)] = qs.total_clr_time / 1000
	--, [Max CLR Time(ms)] = qs.max_clr_time / 1000
	--, [Avg CLR Time(ms)] = ((qs.total_clr_time / 1000) / qs.execution_count)
	--, qs.*
FROM sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
	CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
	Left Join sys.dm_exec_requests As er
		On (er.sql_handle = qs.sql_handle
			Or er.plan_handle = qs.plan_handle)
Where 1 = 1
	And st.text Like N'%' + @strSearch + N'%' Escape '\'
	And st.Text Not Like N'%' + @Dummy + N'%'

;
