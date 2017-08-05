Use Master 

/*
	How to monitor deadlock using extended events in SQL Server 2008 and later
	By HarshDeep_Singh
	http://blogs.msdn.com/b/sqlserverfaq/archive/2013/04/27/an-in-depth-look-at-sql-server-memory-part-2.aspx
*/

SELECT	[Creation_Date] = xed.value('@timestamp', 'datetime')
	  , [Extend_Event] = xed.query('.')
FROM	(SELECT	[Target_Data] = CAST([target_data] AS XML)
		 FROM	sys.dm_xe_session_targets AS xt
				INNER JOIN sys.dm_xe_sessions AS xs
					ON xs.address = xt.event_session_address
		 WHERE	xs.name = N'system_health'
				AND xt.target_name = N'ring_buffer'
		) AS XML_Data
		CROSS APPLY Target_Data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]')
		AS XEventData (xed)
ORDER BY Creation_Date DESC

Return;

/*
	Retrieving Deadlock Graphs with SQL Server 2008 Extended Events
	By Jonathan Kehayias, 2009/02/23 
	http://www.sqlservercentral.com/articles/deadlock/65658/
*/

select
	--XEventData,
	 [DeadlockGraph] = XEventData.XEvent.value('(data/value)[1]', 'varchar(max)')
			/*CAST(
			REPLACE(
				REPLACE(XEventData.XEvent.value('(data/value)[1]', 'varchar(max)')
					,'<victim-list>', '<deadlock><victim-list>')
					,'<process-list>', '</victim-list><process-list>'
				)
			as XML)*/
FROM (select [TargetData] = CAST(target_data as XML)
		from sys.dm_xe_session_targets as st
			join sys.dm_xe_sessions as s
			on s.address = st.event_session_address
		where name = 'system_health'
		) AS Data
	CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData (XEvent)
where XEventData.XEvent.value('@name', 'varchar(4000)') = 'xml_deadlock_report'



