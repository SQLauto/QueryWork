
/*
	Extended Events Query.
	Based on Extended Events with SAP (Part I)
	http://blogs.msdn.com/b/saponsqlserver/archive/2010/05/26/extended-events-with-sap-part-i.aspx
	
	$Archive: /SQL/QueryWork/XE_HealthStatus_GetErrorsFrom.sql $
	$Revision: 1 $	$Date: 14-10-31 9:03 $

	This query pulls error messages from the default system healty Xevent session.
	
	The second query is for Deadlocks and seems to have an issue
*/


Select 
    [Error] = XEventData.XEvent.value('(data/value)[1]', 'varchar(max)')
    , [Severity] = XEventData.XEvent.value('(data/value)[2]', 'varchar(max)')
    , [State] = XEventData.XEvent.value('(data/value)[3]', 'varchar(max)')
    , [Userdefined] = XEventData.XEvent.value('(data/value)[4]', 'varchar(max)')
    , [Message] = XEventData.XEvent.value('(data/value)[5]', 'varchar(max)')
FROM
	(Select [TargetData] = CAST(target_data as xml) 
		From sys.dm_xe_session_targets as st 
			Inner join sys.dm_xe_sessions as s
			on s.address = st.event_session_address
		Where name = 'system_health'
	) AS Data     
	CROSS APPLY TargetData.nodes ('//RingBufferTarget/event')
	AS XEventData (XEvent)
Where XEventData.XEvent.value('@name', 'varchar(4000)') = 'error_reported'  

/*
Select
    cast(XEventData.XEvent.value('(data/value)[1]', 
    'nvarchar(max)') as XML) as DeadlockGraph
FROM
    (Select CAST(target_data as xml) as TargetData 
     from sys.dm_xe_session_targets st join 
          sys.dm_xe_sessions s on 
          s.address = st.event_session_address
     where name = 'system_health') AS Data
     CROSS APPLY TargetData.nodes ('//RingBufferTarget/event') 
     AS XEventData (XEvent)
where XEventData.XEvent.value('@name', 'nvarchar(4000)') 
= 'xml_deadlock_report' 

*/