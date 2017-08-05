/*
	This query returns tables that may be unused or unneeded
	based on a name pattern string
	
	$Workfile: Cleanup_Get_CandidatesByNamePattern.sql $
	$Archive: /SQL/QueryWork/Cleanup_Get_CandidatesByNamePattern.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/
Declare
	@NamePattern varChar(50)

Set @NamePattern = '%TankSystem%';
Set @NamePattern = '%TSZI%';

Select
	[Table Name] = st.name
	,[Create Date] = st.create_date
	,[ Modified Date]= st.modify_date
	,[Size KB] = cast(cast(sps.reserved_page_count as float) * 8192.0/1000.0 as decimal(10, 2))
	,[Num Rows] = sps.row_count
	,[Index Id] = sps.index_id
	,[Partition Num] = sps.partition_number
From sys.tables as st
	inner join sys.dm_db_partition_stats as sps
		on sps.object_id = st.object_id
Where 1 = 1
	and st.name like @NamePattern
	and st.type like 'U'
Order By
	st.name
	--sps.reserved_page_count --desc
	,st.create_date
	,st.modify_date
	
/*
ComplianceTSZI
ComplianceTSZI_History
NAUV_TSZI
NBXI_TSZI_20080131
NBXI_TSZI_20080131_2
NCBO_TSZI
newtemptsziinsert
newtemptsziupdate
SaveTSZI_4254
TempDeleteRowsFromTSZI
TempTSZI
TempTSZI1491
temptsziinsert
temptsziupdate
TSZI_2005_02_07
TSZI_AAFV_20080301
TSZI_nadj_acj
TSZI_NANH
TSZI_NAUV
TSZI_NCKX
tszi20100729
tszi2010072917
TSZIProcessed
*/