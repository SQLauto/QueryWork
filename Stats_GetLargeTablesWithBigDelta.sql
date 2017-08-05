/*
	This script returns Stats on stats for large tables that are candidates for stats updates.
	$Archive: /SQL/QueryWork/Stats_GetLargeTablesWithBigDelta.sql $
	$Revision: 2 $	$Date: 16-01-15 13:15 $
*/
Declare
	@RowLimit			Int = 100000
	, @RowsModFactor	Float = 0.01		-- 
	, @StatsDate		DateTime	= DateAdd(Day, -7, GetDate())	-- Also return stats not updated recently
	, @Table			Varchar(128) = '%'
	, @Schema			Varchar(128) = ''
	, @SchemaId			Int
	;
If Schema_Id(@Schema) Is Null Set @SchemaId = -1
Select
	[Schema]		= Schema_Name(so.schema_id)
	, [Table]		= so.name
	, [Stat]		= ss.name
	, [Reason]		= Case When sp.modification_counter > sp.rows Then 'Mod Rows > Table Rows'
						When sp.last_updated < @StatsDate Then 'Stale Stats'
						Else 'Mod Rows > Change Factor'
						End
	, [No Recompute] = Case When ss.no_recompute = 0 Then 'No' Else 'Yes' End
	, [Updated]		= sp.last_updated
	, [Rows]		= sp.rows
	, [Sampled]		= sp.rows_sampled
	, [Steps]		= sp.steps
	, [ModCount]	= sp.modification_counter
	--, ss.auto_created
	--, ss.user_created
	--, ss.has_filter
	--, ss.filter_definition
	--, ss.object_id
	--, [Stat_Id]	= ss.stats_id	-- System Generated Stat Name last half is parent object Id in hex.
From
	sys.stats As ss
	Inner Join sys.objects As so
		On ss.object_id = so.object_id
	Cross Apply sys.dm_db_stats_properties(so.object_id, ss.stats_id) As sp

Where 1 = 1
	And so.schema_id != Schema_Id('zDrop')
	And so.is_ms_shipped = 0
	And ((@SchemaId < 0 And so.name Like @Table)
		Or (so.schema_id = @schemaId And so.name Like @Table)
		)
	And ((sp.rows > @RowLimit And sp.modification_counter >  Floor(sp.rows * @RowsModFactor))	-- Mods > Factor
		Or (sp.rows > @RowLimit And sp.last_updated < @StatsDate And sp.modification_counter > 0)			-- Stale Stats
		Or (sp.rows > @RowLimit And sp.modification_counter > sp.rows)		-- How ?
		)
Order By
	[Schema]
	, [Table]
	, [Stat]


--	Update Statistics pViews.TSCI_All_20151101(_WA_Sys_00000002_53F0DBB6) With Sample 10 Percent	-- 1 hour Dev2008R2		-- 1GRow, 140GB
--	Update Statistics pViews.RawFileDetail_20151206 With Fullscan;						-- 30 Min Dev2008R		-- 57MRow, 6GB
--	Update Statistics pViews.RawFileDetail_20151213 With Sample 20 Percent;				-- 25 Min Dev2008R2		-- 76MRow, 9GB
--	Update Statistics pViews.RawFileDetail_20151220 With Fullscan;						-- 37 Min Dev2008R2		-- 90MRow, 13GB
--	Update Statistics pViews.RawPumpStatusByFile_20160101 With Fullscan;				-- 30 Sec Dev2008R2		-- 400KRow, 60MB
--	Select Cast( 0x6B33686A As integer), Object_Id('dbo.tank', 'U')	-- System Generated Stat Name last half is parent object Id in hex.