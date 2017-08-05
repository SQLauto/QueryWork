/*
Steve Hood
Query the Buffer Pool
http://www.sqlservercentral.com/blogs/simple-sql-server/2016/01/04/query-the-buffer-pool/

Excerpts from article. (selective editing)

	Now you can see what’s in your memory. Hopefully you’ll see one or two things that stand out
on here that don’t make sense; those are your easy tuning opportunities.

	This will return every index that is using at least 1 MB of memory for every database on your
server.  It also returns space in memory that is associated with unallocated space in the tables
which shows up as NULL for everything except the size of the space and the table name.

	I’ll warn you now that the unallocated space can be surprisingly high for TempDB, and I talk
about that in TempDB Memory Leak?.  Hopefully we can get a good comment thread going on that post
to talk through what we’re seeing and how common the issue really is.

	If an index is 100% in cache then you’re scanning on it, and that may be an issue.  Yes, you 
can find when you did scans on indexes using the scripts in my Indexes – Unused and Duplicates post
, but it helps to have another view of what that means in your memory.

	One thing the index monitoring scripts in the post I just mentioned can’t do is tell you
when you’re doing large seeks as opposed to small seeks.  With the typical phone book example
, you could ask for all the names in the phone book where the last names begins with anything from A to Y
, giving you 98% of the phone book as results.  Index usage stats will show you did a seek
, which sounds efficient.  The script on this post will show that you have 98% of your 
index in cache immediately after running the query, and that gives you the opportunity to find the issue.

	When you see an index that looks out of place here, dive back into the scripts on 
Cleaning Up the Buffer Pool to Increase PLE to see what’s in cache using that index.
If the query isn’t in cache for any reason, you may be able to look at the last time the index had a scan
or seek against it in sys.dm_db_index_usage_stats and compare that to results from an Extended Events session
you had running to see what it could have been.

	The main point is that you have something to get you started.  You have specific
indexes that are in memory, and you can hunt down when and why those indexes are being used that way.  It’s not
always going to be easy, but you have a start.

	$Archive: /SQL/QueryWork/Mem_GetIndexesInBufferPool.sql $
	$Revision: 3 $	$Date: 16-01-07 11:30 $

*/


If OBJECT_ID('TempDB..#BufferSummary') IS NOT NULL BEGIN
	DROP TABLE #BufferSummary;
END;

IF OBJECT_ID('TempDB..#BufferPool') IS NOT NULL BEGIN
	DROP TABLE #BufferPool;
END;

Create Table #BufferPool (
	  Cached_MB Int
	, Database_Name sysname
	, Schema_Name sysname Null
	, Object_Name sysname Null
	, Index_ID Int Null
	, Index_Name sysname Null
	, Used_MB Int Null
	, Used_InRow_MB Int Null
	, Row_Count BigInt Null
	);
Create Table #BufferSummary(
	Pages			Integer
	, allocation_unit_id	BigInt
	, database_id	Integer
	);

DECLARE @DateAdded SmallDateTime = GETDATE()
	, @SQL NVarChar(4000)
	;

Insert INTO #BufferSummary(Pages, allocation_unit_id, database_id)
	SELECT Pages = COUNT(1)
		, allocation_unit_id
		, database_id
	FROM sys.dm_os_buffer_descriptors
	GROUP BY allocation_unit_id, database_id
	;

SELECT @SQL = ' USE [?]
INSERT INTO #BufferPool (
	Cached_MB
	, Database_Name
	, Schema_Name
	, Object_Name
	, Index_ID
	, Index_Name
	, Used_MB
	, Used_InRow_MB
	, Row_Count
	)
SELECT sum(bd.Pages)/128
	, DB_Name(bd.database_id)
	, Schema_Name(o.schema_id)
	, o.name
	, p.index_id
	, ix.Name
	, i.Used_MB
	, i.Used_InRow_MB
	, i.Row_Count
FROM #BufferSummary AS bd
	LEFT JOIN sys.allocation_units au ON bd.allocation_unit_id = au.allocation_unit_id
	LEFT JOIN sys.partitions p ON (au.container_id = p.hobt_id AND au.type in (1,3)) OR (au.container_id = p.partition_id and au.type = 2)
	LEFT JOIN (
		SELECT PS.object_id
			, PS.index_id
			, Used_MB = SUM(PS.used_page_count) / 128
			, Used_InRow_MB = SUM(PS.in_row_used_page_count) / 128
			, Used_LOB_MB = SUM(PS.lob_used_page_count) / 128
			, Reserved_MB = SUM(PS.reserved_page_count) / 128
			, Row_Count = SUM(row_count)
		FROM sys.dm_db_partition_stats PS
		GROUP BY PS.object_id
			, PS.index_id
	) i ON p.object_id = i.object_id AND p.index_id = i.index_id
	LEFT JOIN sys.indexes ix ON i.object_id = ix.object_id AND i.index_id = ix.index_id
	LEFT JOIN sys.objects o ON p.object_id = o.object_id
WHERE database_id = db_id()
GROUP BY bd.database_id
	, o.schema_id
	, o.name
	, p.index_id
	, ix.Name
	, i.Used_MB
	, i.Used_InRow_MB
	, i.Row_Count
HAVING SUM(bd.pages) > 128
ORDER BY 1 DESC;';

EXEC sp_MSforeachdb @SQL;

SELECT Cached_MB
	, Used_MB
	, Used_InRow_MB
	, Row_Count
	, Pct_of_Cache = CAST(Cached_MB * 100.0 / SUM(Cached_MB) OVER () as Dec(20,3))
	, Pct_Index_in_Cache = CAST(Cached_MB * 100.0 / CASE Used_MB WHEN 0 THEN 0.001 ELSE Used_MB END as DEC(20,3))
	, Ray_Pct_Index_in_Cache = CASE Used_MB WHEN 0 THEN 0 Else Cast(Cached_MB * 100.0 / Used_MB as DEC(20,3))END
	, Database_Name
	, Schema_Name
	, Object_Name
	, Index_Name
	, Index_ID
FROM #BufferPool
ORDER By
	--Database_Name,
	Cached_MB DESC;


/*
SELECT bd.page_type
	, MB = count(1) / 128
FROM sys.dm_os_buffer_descriptors bd
	LEFT JOIN sys.allocation_units au ON bd.allocation_unit_id = au.allocation_unit_id
WHERE bd.database_id = 2 --TempDB
	AND bd.is_modified = 0 --Let's not play dirty, only clean pages
	AND au.allocation_unit_id IS NULL --It's not even allocated
GROUP BY bd.page_type 
ORDER BY 2 Desc



--	Select Object_Name(437576597, 5)	-- VRAlarmLog
--	CheckPoint
--	DBCC DropCleanBuffers

SELECT TOP 100 bd.*
FROM sys.dm_os_buffer_descriptors bd
	LEFT JOIN sys.allocation_units au ON bd.allocation_unit_id = au.allocation_unit_id
WHERE bd.database_id = Db_Id('TempDB')
	AND bd.is_modified = 0 --Let's not play dirty, only clean pages
	AND au.allocation_unit_id IS NULL --It's not even allocated
*/