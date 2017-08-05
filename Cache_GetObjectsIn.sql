/*
	From Brent Ozar email about finding Cache page owners.
	The first query is Brent's with minor formatting changes.

	DBA Training Week 8 - What Pages Are In Memory?
	$Workfile: Cache_GetObjectsIn.sql $
	$Archive: /SQL/QueryWork/Cache_GetObjectsIn.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/

-- <Brent Ozar>
SELECT
	[CachedDataMB] = cast(count(*) * 8 / 1024.0 AS NUMERIC(10, 2))
	,[DatabaseName] =  case database_id
		WHEN 32767 THEN 'ResourceDb'
		ELSE db_name(database_id)
		END
-- Select top 100 *
FROM
	sys.dm_os_buffer_descriptors
GROUP BY
	db_name(database_id)
	, database_id
ORDER BY
	1 DESC

-- </Brent Ozar>

Select --top 100
	au.allocation_unit_id
	,au.container_id
	,au.data_space_id
	,au.type
	,bd.database_id
	,bd.page_id
	,bd.row_count
	,[Object Name] = object_name(sp.object_id)
	,sp.index_id
From
	sys.allocation_units as au
	inner join sys.dm_os_buffer_descriptors as bd
		on bd.allocation_unit_Id = au.allocation_unit_id
			and bd.database_id = db_id('Consirn')
	inner join sys.partitions as sp
		on (((au.type = 1 or au.type = 3) and au.container_id = sp.partition_id)
			or (au.type = 2 and au.container_id = sp.hobt_id)
			or (au.type = 0 and 0 = 1)
			)
		and sp.object_id > 50000
	