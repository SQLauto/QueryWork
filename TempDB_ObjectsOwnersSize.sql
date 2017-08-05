-- Query details about objects allocated in TEMPDB. This must be run in context of SET 
--	Query details about objects allocated in TEMPDB.
--	http://www.sqlservercentral.com/scripts/tempdb/151252/
/*
	$Archive: /SQL/QueryWork/TempDB_ObjectsOwnersSize.sql $
	$Revision: 2 $	$Date: 17-02-10 10:04 $
*/
Set Lock_Timeout 10000;
Set Deadlock_Priority Low;
Set Transaction Isolation Level Read Uncommitted;

Use tempdb;

Select  *
From (Select Distinct
        [DatabaseName] = Db_Name()
        , [ObjectID] = ps.object_id
        , [ObjectType] = o.type_desc
        , [ObjectName] = o.name
        , [ObjectCreated] = o.create_date
        , [IndexName] = si.name
        , [IndexType] = Case si.index_id
            When 0 Then 'HEAP'
            When 1 Then 'CLUSTERED'
            Else 'NONCLUSTERED'
			End
        , [RowsCount] = ps.row_count
        , [ReservedMB] = ps.reserved_page_count / 128
        , [SPID] = trace.SPID
        , [RequestStartTime] = er.start_time
        , [ApplicationName] = trace.ApplicationName
        , [ProcedureName] = Object_Name(qt.objectid, qt.dbid)
        , [StatementText] = Substring(Char(13)
							+ Substring(qt.text
								, (er.statement_start_offset / 2) + 1
								, ((Case When er.statement_end_offset = -1
										Then Len(Convert(NVarchar(Max), qt.text)) * 2
                                        Else er.statement_end_offset
										End - er.statement_start_offset) / 2) + 1)
							, 1, 8000)
        , [HostName] = trace.HostName
        , [LoginName] = trace.LoginName
	-- Select *
    From   sys.dm_db_partition_stats As ps
        Join sys.tables As o
            On o.object_id = ps.object_id
            And o.is_ms_shipped = 0
        Left Join sys.indexes As si
            On si.object_id = o.object_id
            And si.index_id = ps.index_id
        Left Join (Select HostName
						, LoginName, SPID, ApplicationName, DatabaseName, ObjectID
                        , MostRecentObjectReference = Row_Number() Over (Partition By ObjectID Order By StartTime Desc)
                    From sys.fn_trace_gettable((Select Left(path, Len(path) - CharIndex('\', Reverse(path))) + '\Log.trc'
                                                From sys.traces
                                                Where is_default = 1
												), Default)
                    Where ObjectID Is Not Null
                    ) As trace
            On trace.ObjectID = ps.object_id
            And trace.DatabaseName = 'tempdb'
            And trace.MostRecentObjectReference = 1
        Left Join sys.dm_exec_requests As er
            On er.session_id = trace.SPID
        Outer Apply sys.dm_exec_sql_text(er.sql_handle) As qt
	--Where ps.reserved_page_count > 0
	--Order By [ReservedMB] Desc
	) As T
Where   T.ReservedMB > 0
Order By T.ReservedMB Desc;