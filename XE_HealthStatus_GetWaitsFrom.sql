
/*
	Extended Events Query.
	Based on Extended Events with SAP (Part I)
	http://blogs.msdn.com/b/saponsqlserver/archive/2010/05/26/extended-events-with-sap-part-i.aspx
	
	$Archive: /SQL/QueryWork/XE_HealthStatus_GetWaitsFrom.sql $
	$Revision: 1 $	$Date: 14-10-31 9:03 $

	This query pulls Wait information from the default system healty Xevent session.
*/

select
	[wait_type] = XEventData.XEvent.value('(data/text)[1]', 'varchar(max)')
	, [opcode] = XEventData.XEvent.value('(data/text)[2]', 'varchar(max)')
	, [duration] = XEventData.XEvent.value('(data/value)[3]', 'varchar(max)')
	, [max_duration] = XEventData.XEvent.value('(data/value)[4]', 'varchar(max)')
	, [total_duration] = XEventData.XEvent.value('(data/value)[5]', 'varchar(max)')
	, [signal_duration] = XEventData.XEvent.value('(data/value)[6]', 'varchar(max)')
	, [completed_count] = XEventData.XEvent.value('(data/value)[7]', 'varchar(max)')
FROM
	(select	CAST(target_data as XML) as TargetData
	from sys.dm_xe_session_targets st
		inner join sys.dm_xe_sessions s
		on s.address = st.event_session_address
	where name = 'system_health'
	) AS Data
	CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData (XEvent)
where XEventData.XEvent.value('@name', 'varchar(4000)') = 'wait_info'
union all
select
	[wait_type]	= XEventData.XEvent.value('(data/text)[1]', 'varchar(max)')
	, [opcode] = XEventData.XEvent.value('(data/text)[2]', 'varchar(max)')
	, [duration] = XEventData.XEvent.value('(data/value)[3]', 'varchar(max)')
	, [max_duration] = XEventData.XEvent.value('(data/value)[4]', 'varchar(max)')
	, [total_duration] = XEventData.XEvent.value('(data/value)[5]', 'varchar(max)')
	, [signal_duration] = null
	, [completed_count] = XEventData.XEvent.value('(data/value)[6]', 'varchar(max)')
FROM
	(Select	[TargetData] = CAST(target_data as XML)
	From sys.dm_xe_session_targets as st
		inner join sys.dm_xe_sessions as s
			on s.address = st.event_session_address
	Where name = 'system_health'
	) AS Data
	CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData (XEvent)
Where XEventData.XEvent.value('@name', 'varchar(4000)') = 'wait_info_external'