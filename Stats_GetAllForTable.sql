
/*
	Based on BOL
*/

Declare @Table	Varchar(128)	= 'FuelSale_20160228'
Select
	so.name
	, st.name
	, st.stats_id
	, sp.last_updated
	, sp.rows
	, sp.rows_sampled
	, [Sample%] = Cast(Cast(sp.rows_sampled As Float) / Cast(sp.rows As Float) * 100.0 As Decimal(15, 6))
	, [Modified%] = Cast(Cast(sp.modification_counter As Float) / Cast(sp.rows As Float) * 100.0 As Decimal(15, 6))
	, sp.steps
	, sp.unfiltered_rows
	, sp.modification_counter

From
	sys.objects As so
	Inner Join sys.stats As st
		On st.object_id = so.object_id
	Cross Apply sys.dm_db_stats_properties (st.object_id, st.stats_id) As sp
Where
	so.name Like @Table

Dbcc Show_Statistics('[pviews].[FuelSale_20160228]', PK_FuelSale_20160228)


