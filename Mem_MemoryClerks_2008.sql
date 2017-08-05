
/*
	Start of a query to investigate SQL Memory Usage
	SQL 2008 version.  SQL 2012 column names change :(
	
	$Workfile: Mem_MemoryClerks_2008.sql $
	$Archive: /SQL/QueryWork/Mem_MemoryClerks_2008.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/
SELECT
	[type]
	, name
	, memory_node_id
	, single_pages_kb
	, multi_pages_kb
	, virtual_memory_reserved_kb
	, virtual_memory_committed_kb
	, awe_allocated_kb
FROM
	sys.dm_os_memory_clerks
Where 1 = 1
	--and 
ORDER BY
	virtual_memory_reserved_kb DESC;