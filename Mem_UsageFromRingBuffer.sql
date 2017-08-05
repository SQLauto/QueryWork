/*
	From : How to reduce paging of buffer pool memory in the 64-bit version of SQL Server - http://support.microsoft.com/kb/918483

	Ideally, you collect this baseline information during peak loads. Therefore, you can determine the memory requirements for various
	applications and components to support the peak load. The memory requirements vary from one system to another system, depending on
	the activities and the applications that are running on the system. 
	
	How to use the information from SQL Server ring buffers to determine the memory conditions when paging occurs
	You can use information from SQL Server ring buffers to determine the memory conditions on the server when paging occurs. You can
	use a script such as the following script to obtain this information.
	
	You can query the information that is provided in the dynamic management view sys.dm_os_process_memory to understand whether
	the system is encountering low memory conditions. For more information, see the SQL Server 2008 Books Online reference at the
	following MSDN Web site: 
		http://msdn.microsoft.com/en-us/library/bb510747.aspx

	$Workfile: Memory_UsageFromRingBuffer.sql $
	$Archive: /SQL/QueryWork/Memory_UsageFromRingBuffer.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/


SELECT CONVERT (varchar(30), GETDATE(), 121) as runtime,
DATEADD (ms, -1 * (sys.ms_ticks - a.[Record Time]), GETDATE()) AS Notification_time,  
 a.* , sys.ms_ticks AS [Current Time]
 FROM 
 (SELECT x.value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') AS [Notification_type], 
 x.value('(//Record/MemoryRecord/MemoryUtilization)[1]', 'bigint') AS [MemoryUtilization %], 
 x.value('(//Record/MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS [TotalPhysicalMemory_KB], 
 x.value('(//Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS [AvailablePhysicalMemory_KB], 
 x.value('(//Record/MemoryRecord/TotalPageFile)[1]', 'bigint') AS [TotalPageFile_KB], 
 x.value('(//Record/MemoryRecord/AvailablePageFile)[1]', 'bigint') AS [AvailablePageFile_KB], 
 x.value('(//Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS [TotalVirtualAddressSpace_KB], 
 x.value('(//Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'bigint') AS [AvailableVirtualAddressSpace_KB], 
 x.value('(//Record/MemoryNode/@id)[1]', 'bigint') AS [Node Id], 
 x.value('(//Record/MemoryNode/ReservedMemory)[1]', 'bigint') AS [SQL_ReservedMemory_KB], 
 x.value('(//Record/MemoryNode/CommittedMemory)[1]', 'bigint') AS [SQL_CommittedMemory_KB], 
 x.value('(//Record/@id)[1]', 'bigint') AS [Record Id], 
 x.value('(//Record/@type)[1]', 'varchar(30)') AS [Type], 
 x.value('(//Record/ResourceMonitor/Indicators)[1]', 'bigint') AS [Indicators], 
 x.value('(//Record/@time)[1]', 'bigint') AS [Record Time]
 FROM (SELECT CAST (record as xml) FROM sys.dm_os_ring_buffers 
 WHERE ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR') AS R(x)) a 
CROSS JOIN sys.dm_os_sys_info sys
ORDER BY a.[Record Time] ASC
