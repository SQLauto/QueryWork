
/*
--SQL server: Deciphering Wait resource
--http://www.practicalsqldba.com/2012/04/sql-server-deciphering-wait-resource.html

	$Workfile: Objects_Get_ByResourceKeyOrPage.sql $
	$Archive: /SQL/QueryWork/Objects_Get_ByResourceKeyOrPage.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $
*/

-- Find object for a WaitResource Key = xxxxxxxxxxx
SELECT o.name, i.name 
FROM sys.partitions p 
	JOIN sys.objects o
		ON p.object_id = o.object_id 
	JOIN sys.indexes i
		ON p.object_id = i.object_id 
		AND p.index_id = i.index_id 
WHERE p.hobt_id = 72057594075021312
Return

-- Find object for WaitResource Page = <db_id>.<file_id>.<pageNumber> e.g. 5:1:73612726

Select DB_NAME(5)
DBCC TraceOn(3604)	-- Direct DBCC output to this client
--	DBCC page( <db_id>, <file_id>, <pageNumber>)
DBCC page( 5, 1, 57672835)
-- look for "Metadata: ObjectId = 247137563" about 9 lines from bottom in the query results tab

Select OBJECT_NAME(, 5)