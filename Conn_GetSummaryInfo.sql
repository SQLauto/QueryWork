/*

	Query to return open connections with last query submitted and
	some other info.

	$Archive: /SQL/QueryWork/Connections_GetSummaryInfo.sql $
	$Gevision: $	$Date: 14-10-03 16:55 $

*/

select
	C.Session_Id
	,C.connect_time
	, [packet_reads] = C.num_reads
	, [packet_writes] = C.num_writes
	, [last_packet_read] = C.last_read
	, [last_packet_write] = C.last_write
	, [query_text] = case when ((case R.statement_end_offset
								WHEN -1 THEN datalength(ST.text)
								ELSE R.statement_end_offset
								END - R.statement_start_offset)
								/ 2) + 1 <= 0 then ST.text
						else substring(ST.text, (R.statement_start_offset / 2) + 1, 
							((case R.statement_end_offset
							WHEN -1 THEN datalength(ST.text)
							ELSE R.statement_end_offset
							END
							- R.statement_start_offset)
							 / 2) + 1)
						end
From
	sys.dm_exec_requests As R
	Inner JOIN sys.dm_exec_connections As C
		ON R.connection_id = C.connection_id
			AND R.session_id = C.most_recent_session_id
	CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) As ST 
Where 1 = 1
	--and dec.connection_id = 65
	--and C.session_id = 65
Order By
	c.session_id
	
/*
insert	@totalizertime(
	panelid, pricechangetime, PanelDispenserNum, DispenserNum
	, readingdate, lastuser, lastupdate, grade
	)
	select	p.panelid
			, p.pricechangetime
			, d.PanelDispenserNum
			, d.DispenserNum
			, MAX(s.ReadingDate) as readingdate
			, 'Pamsale'
			, GETDATE()
			, d.SIMYCoord 
--into #totalizertime
	from	@pricelist p
			inner join vw_DispenserActive d
				on p.panelid = d.PanelID
				and p.grade = d.SIMYCoord
			inner join FuelSale s with (nolock)
				on p.panelid = s.PanelID
				and d.PanelDispenserNum = s.DispenserNum
				and s.ReadingDate >= '1/1/2013'
				and s.ReadingDate < pricechangetime
	group by p.panelid
			, p.pricechangetime
			, d.PanelDispenserNum
			, d.DispenserNum
			, d.SIMYCoord 
  
  */