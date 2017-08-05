/*
    Introduction to Extended Events
    http://blogs.msdn.com/b/extended_events/archive/2010/04/14/introduction-to-extended-events.aspx

    Paul Randal - TechNet Magazine article (Good Intro tutorial 2008 - 
    http://technet.microsoft.com/en-us/magazine/2009.01.sql2008.aspx
*/

-- TRIES TO ELIMINATE PREVIOUS SESSIONS
Return;
BEGIN TRY
    DROP EVENT SESSION test_session ON SERVER
END TRY
BEGIN CATCH
END CATCH

Return;
-- CREATES THE SESSION
CREATE EVENT SESSION test_session ON SERVER
    ADD EVENT sqlserver.error_reported (
          ACTION (sqlserver.sql_text) 
          WHERE severity > 1 and (not (message = 'filter'))
       -- WHERE severity > 1 and message <> 'filter' -- equivalent statements
    )
    ADD TARGET package0.asynchronous_file_target(
         set filename = 'C:\_Junk\data2.xel'
          , metadatafile = 'C:\_Junk\data2.xem') 

-- STARTS THE SESSION
Return;
ALTER EVENT SESSION test_session ON SERVER STATE = START 
--ALTER EVENT SESSION test_session ON SERVER STATE = Stop 

--Select * From sys.dm_xe_sessions as dxs
--select * From sys.dm_xe_session_events as dxse
 

-- THIS ERROR WILL BE FILTERED BECAUSE SEVERITY <2 
Return;
RAISERROR (N'PUBLISH', 1, 1, 7, 3, N'abcde');

-- THIS ERROR WILL BE FILTERED BECAUSE MESSAGE = 'FILTER'
Return;
RAISERROR (N'FILTER', 2, 1, 7, 3, N'abcde');

Return;
-- THIS ERROR WILL BE PUBLISHED
RAISERROR (N'PUBLISH', 2, 1, 7, 3, N'abcde');


 

Return;
-- STOPS LISTENING FOR THE EVENT
ALTER EVENT SESSION test_session ON SERVER STATE = STOP
 

Return;
-- REMOVES THE EVENT SESSION FROM THE SERVER
DROP EVENT SESSION test_session ON SERVER



-- REMOVES THE EVENT SESSION FROM THE SERVER

select [event_data] = CAST(event_data as XML)
from sys.fn_xe_file_target_read_file ('c:\_Junk\data2*.xel','c:\_Junk\data2*.xem', null, null) 

Return; 
-- You can see the list of all defined events for SQL 2008 using the following code:
SELECT xp.[name], xo.*
FROM sys.dm_xe_objects xo, sys.dm_xe_packages xp
WHERE xp.[guid] = xo.[package_guid]
  AND xo.[object_type] = 'event'
ORDER BY xp.[name];

Return;
--And you can find the payload for a specific event using this code:
SELECT * FROM sys.dm_xe_object_columns
  WHERE [object_name] = 'sql_statement_completed';
GO


