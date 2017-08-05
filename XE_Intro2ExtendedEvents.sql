/*
    Introduction to Extended Events
    http://blogs.msdn.com/b/extended_events/archive/2010/04/14/introduction-to-extended-events.aspx

*/
-- TRIES TO ELIMINATE PREVIOUS SESSIONS

BEGIN TRY
    DROP EVENT SESSION test_session ON SERVER
END TRY
BEGIN CATCH
END CATCH

GO

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
GO


-- STARTS THE SESSION

ALTER EVENT SESSION test_session ON SERVER STATE = START 
--ALTER EVENT SESSION test_session ON SERVER STATE = Stop 

GO

--Select * From sys.dm_xe_sessions as dxs
--select * From sys.dm_xe_session_events as dxse
 

-- THIS ERROR WILL BE FILTERED BECAUSE SEVERITY <2 

RAISERROR (N'PUBLISH', 1, 1, 7, 3, N'abcde');

GO

-- THIS ERROR WILL BE FILTERED BECAUSE MESSAGE = 'FILTER'

RAISERROR (N'FILTER', 2, 1, 7, 3, N'abcde');

GO

-- THIS ERROR WILL BE PUBLISHED

RAISERROR (N'PUBLISH', 2, 1, 7, 3, N'abcde');

GO

 

-- STOPS LISTENING FOR THE EVENT

ALTER EVENT SESSION test_session ON SERVER STATE = STOP

GO

 

-- REMOVES THE EVENT SESSION FROM THE SERVER

DROP EVENT SESSION test_session ON SERVER

GO

-- REMOVES THE EVENT SESSION FROM THE SERVER

select [event_data] = CAST(event_data as XML)
from sys.fn_xe_file_target_read_file ('c:\_Junk\data2*.xel','c:\_Junk\data2*.xem', null, null) 

 


--  select * From sys.dm_xe_packages as dxp
--  Select * From sys.dm_xe_Sessions as xs

Select
    dxo.name
    ,dxo.object_type
    ,dxo.description
    ,dxo.type_name
    ,dxo.type_size
--    ,dxo.capabilities_desc
--    ,dxo.*
From sys.dm_xe_objects as dxo
Where 1 = 1
    --and dxo.object_type = 'Event'
    --and dxo.object_type like 'pred_%'
    --and dxo.object_type = 'action'
    --and dxo.object_type = 'target'
    and dxo.object_type in ('map', 'type')
    --and dxo.name like '%transaction%'
Order By
    dxo.object_type
    ,dxo.name

select [keyword] = map_value from sys.dm_xe_map_values
where name = 'keyword_map'

