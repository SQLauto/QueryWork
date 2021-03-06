/*
	$Archive: $
	$Revision: $	$Date: $

	Find
		Heaps
		Missing Primary Key
		Primary Keys with system generated name
*/

Select
	[Schema] = schema_name(so.schema_id)
	, [Table] = so.name
	, [Key] = pk.name
	, [Index] = si.name
	, [IndexType] = case when si.index_id = 0 then 'Heap' else 'Clustered' End
From sys.objects as so
	left join sys.objects as pk
		on pk.parent_object_id = so.object_id
		and pk.type = 'PK'
	inner join sys.indexes as si
		on si.object_id = so.object_id
Where 1 = 1
	and so.type = 'U'
	and si.index_id <= 1
	and (pk.name is null or si.index_id = 0 or pk.name like '%\_\_%')
;

Return;

Select
	[Schema] = schema_name(so.schema_id)
	, [Table] = so.name
	, [Key] = fk.name
From sys.objects as so
	left join sys.foreign_keys as fk
		on so.object_id = fk.parent_object_id
Where 1 = 1
	and so.is_ms_shipped = 0
	
