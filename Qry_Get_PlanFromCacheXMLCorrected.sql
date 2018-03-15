/*
	Based on Jason Brimall 20131029
	Exporting Execution Plans - SQL Spackle
	http://www.sqlservercentral.com/articles/Execution+Plans/103484/

	$Workfile: Qry_Get_PlanFromCacheXMLCorrected.sql $
	$Archive: /SQL/QueryWork/Qry_Get_PlanFromCacheXMLCorrected.sql $
	$Revision: 3 $	$Date: 18-01-06 17:33 $

	This seems pretty unwieldy for returning relatively little data.  Need to review the article <2018-01-05>
	
*/

-- ~8 minutes to run on Dev2008R2.Wilco

SELECT TOP 10 
	[total_elapsed_time] = total_elapsed_time/1000.0
	,[execution_count] = execution_count
	,[avg_elapsed_time_ms] = (total_elapsed_time/execution_count)/1000.0
	,[last_elapsed_time] = last_elapsed_time/1000.0
	,[avg_logical_reads] = total_logical_reads/execution_count
	,[Query] = st.Query
	,[query_plan] = qp.query_plan
	,[plan_handle] = qs.plan_handle
FROM sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) as qp
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st1
	CROSS APPLY (
		SELECT [processing-instruction(query)] = 
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(
			CONVERT(NVARCHAR(MAX),	N'--' + NCHAR(13) + NCHAR(10) + ist.text + NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2)
				, NCHAR(31),N'?'), NCHAR(30),N'?'), NCHAR(29),N'?'), NCHAR(28),N'?'), NCHAR(27),N'?')
				, NCHAR(26),N'?'), NCHAR(25),N'?'), NCHAR(24),N'?'), NCHAR(23),N'?'), NCHAR(22),N'?')
				, NCHAR(21),N'?'), NCHAR(20),N'?'), NCHAR(19),N'?'), NCHAR(18),N'?'), NCHAR(17),N'?')
				, NCHAR(16),N'?'), NCHAR(15),N'?'), NCHAR(14),N'?'), NCHAR(12),N'?'), NCHAR(11),N'?')
				, NCHAR(8),N'?'), NCHAR(7),N'?'), NCHAR(6),N'?'), NCHAR(5),N'?'), NCHAR(4),N'?')
				, NCHAR(3),N'?'), NCHAR(2),N'?'), NCHAR(1),N'?'), NCHAR(0),N''
			)
		FROM sys.dm_exec_sql_text(qs.sql_handle) AS ist 
		FOR XML
		PATH(''),
		TYPE
		) AS st(Query)
WHERE st1.text like '%sys.sql_modules%'
ORDER BY last_elapsed_time DESC;

/* --Original Script

SELECT TOP 10
              total_elapsed_time/1000.0 as total_elapsed_time
              ,execution_count
              ,(total_elapsed_time/execution_count)/1000.0 AS [avg_elapsed_time_ms]
              ,last_elapsed_time/1000.0 as last_elapsed_time
              ,total_logical_reads/execution_count AS [avg_logical_reads]
              ,st.Query
              ,qp.query_plan
              ,qs.plan_handle
FROM sys.dm_exec_query_stats AS qs
       CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) as qp
       CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st1
       CROSS APPLY (
                           SELECT 
                                  REPLACE
                                  (
                                         REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                         REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                         REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                                CONVERT
                                                (
                                                      NVARCHAR(MAX),
                                                       N'--' + NCHAR(13) + NCHAR(10) + ist.text + NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2
                                                )
                                                ,NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?')
                                                ,NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?')
                                                ,NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?')
                                                ,NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?')
                                                ,NCHAR(12),N'?'),NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?')
                                                ,NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?')
                                         ,NCHAR(0),N''
                                  ) AS [processing-instruction(query)]
                                  FROM sys.dm_exec_sql_text(qs.sql_handle) AS ist 
                           FOR XML
                                  PATH(''),
                                  TYPE
                     ) AS st(Query)
WHERE st1.text like '%sys.sql_modules%'
ORDER BY last_elapsed_time DESC;

*/