
/*
	Script to use XE and get deadlock info from SystemHealth.

		$Archive: /SQL/QueryWork/XE_HealthStatus_GetDeadLockFrom.sql $
		$Revision: 2 $	$Date: 14-11-28 16:19 $
*/	
Use Master 

SELECT
	[Creation_Date] = xed.value('@timestamp', 'datetime')
	, [Event Name] = xed.value('@name', 'varchar(4000)')
	, [Extend_Event] = xed.query('.')
FROM	(SELECT	CAST([target_data] AS XML) AS Target_Data
		 FROM	sys.dm_xe_session_targets AS xt
				INNER JOIN sys.dm_xe_sessions AS xs
					ON xs.address = xt.event_session_address
		 WHERE	xs.name = N'system_health'
				AND xt.target_name = N'ring_buffer'
		) AS XML_Data
		CROSS APPLY Target_Data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]')
		AS XEventData (xed)
Where 1 = 1
	and xed.value('@name', 'varchar(4000)') = 'xml_deadlock_report'
	and xed.value('@timestamp', 'datetime') > DATEADD(dd, -1, Cast(GetDate() as DATE))
ORDER BY Creation_Date DESC
