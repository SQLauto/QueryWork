/*
	Hash warnings (last hour)
	http://sqlmonitormetrics.red-gate.com/hash-warnings-in-last-hour/
	
	$Archive: /SQL/QueryWork/SQLMon_HashWarningsLastHour.sql $
	$Date: 15-04-01 15:39 $	$Revision: 1 $
*/


DECLARE	@Str NVARCHAR(MAX); 

SELECT
	@Str = CONVERT(NVARCHAR(MAX), Value)
FROM
	::FN_TRACE_GETINFO(DEFAULT) AS Tab
WHERE
	Tab.Property = 2
	AND Traceid = 1; 

SELECT
	--COUNT(*) AS Cnt
	te.Name
	,t.DatabaseName
	,t.HostName
	,t.ClientProcessID
	,t.ObjectID
	,t.ObjectName
	,t.ObjectType
	,t.ApplicationName
	,t.TransactionID
	,t.*
FROM
	FN_TRACE_GETTABLE(@Str, DEFAULT) AS t
	INNER JOIN sys.trace_events te
		ON te.trace_event_id = t.EventClass
WHERE 1 = 1
	--and te.name LIKE '% Warning%'
	AND t.StartTime >= DATEADD(hh, -1, GETDATE())
--Order By
	--t.ObjectId desc
	
--	Select Object_Name(4)