/*
	This is Jonathan Kehayias's article. 
	Retrieving Deadlock Graphs with SQL Server 2008 Extended Events
	http://www.sqlservercentral.com/articles/deadlock/65658/
	
	I am not sure where the original code snippet came from and I have not 
	added Kehayias's code.  I havn't made it work and I have not been able to
	interpret the output of this one :(
	RBH<2013-10-16>
	$Workfile: DeadLock_Get_EventFrom_dm_xe_Sessions.sql $
	$Archive: /SQL/QueryWork/DeadLock_Get_EventFrom_dm_xe_Sessions.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/

Use Master 

SELECT
       [Creation_Date] = xed.value('@timestamp', 'datetime')
       ,[Exented_Event] = xed.query('.')
FROM
	(SELECT CAST([target_data] AS XML) AS Target_Data
       FROM sys.dm_xe_session_targets AS xt
		   INNER JOIN sys.dm_xe_sessions AS xs
		   ON xs.address = xt.event_session_address
       WHERE xs.name = N'system_health'
		AND xt.target_name = N'ring_buffer'
	) AS XML_Data
	CROSS APPLY Target_Data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(xed)
Where 1 = 1
	and Convert(datetime, xed.value('@timestamp', 'datetime')) > dateadd(dd, -1, GetDate())
	--and xed.value like '%resource%'
ORDER BY [Creation_Date] DESC

 
