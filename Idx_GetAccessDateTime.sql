/*
	http://www.sqlsoldier.com/wp/sqlserver/returnmaxorminvalueofagroupofcolumnsasasinglecolumn#respond
	 I saw some examples from Adam Machanic (blog|@adammachanic) where he used the VALUES clause to treat values as records in a subquery. I decided to try this approach.

	 First step was to put the 3 columns into the VALUES clause as a subquery:

	 <RBH> I modified this quite a bit from the original purpose. <2016-06-25>
	 This query returns all of the indexes in the database with the date of the most recent User and System
	 Access.
	 $Archive: /SQL/QueryWork/Idx_GetAccessDateTime.sql $
	 $Revision: 1 $	$Date: 17-01-12 14:22 $

	 This also demonstrates a neat use of the Values clause.

	(Values (ius.last_user_scan), (ius.last_user_lookup), (ius.last_user_seek))

	This will cause the 3 columns to be treated as 3 rows. I want to get the MAX value of these 3 columns so I need to alias the subquery to treat it as a table and provide a name for the column of 3 rows:

*/
--	Set Statistics IO On
Select
	[Schema] = Schema_Name(so.schema_id)
	, [Table Name] = so.name
	, [Index] = si.name
	, [Row Count] = sp.rows
	, [Create Date] = so.create_date
	, [Modified Date] = so.modify_date
	, [Last User Access] =
		(Select Max(dt.LastUserAccess)	--Top 1 dso.LastUserRead
		From (
			Values (ius.last_user_scan), (ius.last_user_lookup), (ius.last_user_seek), (ius.last_user_update)
			 ) As dt (LastUserAccess)-- Order By dso.LastUserRead Desc
		)
	, [Last System Access] =
		(Select Max(dt.LastSystemAccess)	--Top 1 dso.LastUserRead
		From (
			Values (ius.last_system_scan), (ius.last_system_lookup), (ius.last_system_seek), (ius.last_system_update)
			 ) As dt (LastSystemAccess)-- Order By dso.LastUserRead Desc
		)
From sys.objects As so
	Inner Join sys.indexes As si
		On si.object_id = so.object_id
	Inner Join sys.partitions As sp
		On so.object_id = sp.object_id
		And si.index_id = sp.index_id
	inner Join sys.dm_db_index_usage_stats ius
		On ius.object_id = si.object_id
		And ius.index_id = si.index_id
Where 1 = 1
	And so.type = 'U'
Order By so.name;
Return;

	--, [last_user_scan] = ius.last_user_scan
	--, [last_user_lookup] = ius.last_user_lookup
	--, [last_user_seek] = ius.last_user_seek
	--, [last_user_update] = ius.last_user_update
	--, [last_system_seek] = ius.last_system_seek
	--, [last_system_scan] = ius.last_system_scan
	--, [last_system_lookup] = ius.last_system_lookup
	--, [last_system_update] = ius.last_system_update