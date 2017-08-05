
/*

    Based on - Advanced SQL Server 2008 Extended Events with Examples
        - See more at: http://www.sqlteam.com/article/advanced-sql-server-2008-extended-events-with-examples#sthash.E9uoP9B3.dpuf
        By Mladen Prajdic 
*/

CREATE EVENT SESSION SQLErrorReportedSession ON SERVER
    ADD EVENT sqlserver.error_reported
        -- collect failed SQL statement, the SQL stack that led to the error,
        -- the database id in which the error happened and the username that ran the statement  
	(
	    ACTION (sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.database_id, sqlserver.username)
	    WHERE sqlserver.database_id = 8
	)
	ADD TARGET package0.ring_buffer
	    (SET max_memory = 4096) WITH (max_dispatch_latency = 1 seconds)
;
-- we have to manually manage the session
/*
Return;
ALTER EVENT SESSION SQLErrorReportedSession ON SERVER
    STATE = START

*/
/*
Return;
ALTER EVENT SESSION SQLErrorReportedSession ON SERVER
    STATE = STOP
*/

/*
Return;
Drop EVENT SESSION SQLErrorReportedSession ON SERVER
*/

/*
Return;
SELECT [xmlData] = CAST(t.target_data AS XML)
FROM sys.dm_xe_session_targets as t
    JOIN sys.dm_xe_sessions as s
        ON s.Address = t.event_session_address
    JOIN sys.server_event_sessions as ss
        ON s.Name = ss.Name
WHERE t.target_name = 'ring_buffer'
    AND s.Name = 'SQLErrorReportedSession'

*/

--  SELECT * FROM sys.dm_xe_sessions
/*
    SELECT * FROM sys.dm_xe_objects
    WHERE object_type in ('map', 'type')
    ORDER BY name;
*/
--  SELECT * FROM sys.dm_xe_map_values;

select *
From
    sys.dm_exec_query_plan(0x0100070075E78C031058ABAD000000000000000000000000) as p
    --sys.dm_exec_requests as der
Where
    d.plan_handle = 0x0100070075E78C031058ABAD000000000000000000000000
    