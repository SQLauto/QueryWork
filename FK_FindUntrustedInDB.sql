
/*
	Based on Kendra Little Webinar
	http://www.brentozar.com/archive/2015/03/foreign-keys-in-sql-server-video/
	
	$Archive: /SQL/QueryWork/FK_FindUntrustedInDB.sql $
	$Date: 15-04-01 15:39 $	$Date: 15-04-01 15:39 $
*/


Select
	[FroeignKeyName] = quotename(s.name)
	+ '.' + quotename(so.name)
	+ '.' + quotename(fk.name)

From sys.foreign_keys as fk
	inner join sys.objects as so
		on so.object_id = fk.parent_object_id
		inner join sys.schemas as s
		on s.schema_id = so.schema_id
Where 1 = 1
	and fk.is_not_trusted = 1
	and fk.is_not_for_replication = 0
;