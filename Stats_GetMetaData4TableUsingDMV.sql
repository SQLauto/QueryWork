/*

	Note: If the table has never been queried then there won't be any stats even if thousands of rows
	have been inserted.  !!
	$Archive: /SQL/QueryWork/Stats_GetMetaData4TableUsingDMV.sql $
	$Revision: 1 $	$Date: 17-05-06 11:36 $

*/

Declare @TableName	Sysname = N''


Select
	st.TableName
	, st.CreatedOn
	, st.NumRows
	, st.LastMaintenanceDate
	, part.Rows
	, ss.name
	, ss.object_id
	, ss.stats_id
	, ss.auto_created
	--, stats.last_updated
	--, stats.modification_counter

From pViews.pv_subTableStatus As st
	Inner Join sys.Partitions As part
		On part.object_id = Object_Id('pViews.' + st.TableName, 'U')
	Inner Join sys.stats As ss
		On ss.object_id = part.object_id
	CROSS APPLY sys.dm_db_stats_properties (part.object_id, ss.stats_id) As stats 
Where 1 = 1
	And st.NumRows < part.Rows
	And ss.Stats_id = 1

--	Create NonClustered Index IX_Junk On pViews.File_IO_RawDataSnapShot_20170312(NumReads)


Select
	Object_Name(ss.object_id)
	,*
From
	sys.stats As ss
	CROSS APPLY sys.dm_db_stats_properties (ss.object_id, ss.stats_id) As stats 
Where 1 = 1
	And objectproperty(ss.object_Id, 'isMSShipped') = 0
	And objectproperty(ss.object_id, 'SchemaId ') = Schema_Id('pViews')

Select Top 5 rds.*
From pViews.File_IO_RawDataSnapShot_20170326 As rds
	--	dbo.File_IO_RawDataSnapShot
Where 1 = 1
And rds.DbId = db_id('ConSIRN')
	