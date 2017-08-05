

Select
    so.name
    ,ps.index_id
    ,ps.partition_number
    ,[TableHasPrimaryKey] = OBJECTPROPERTY(so.object_id, 'TableHasPrimaryKey')
    ,[TableHasClustIndex] = OBJECTPROPERTY(so.object_id, 'TableHasClustIndex')
    ,[TableHasForeignRef] = OBJECTPROPERTY(so.object_id, 'TableHasForeignRef')
    ,ps.used_page_count
    ,ps.row_count
    ,ps.in_row_data_page_count
    ,ps.in_row_reserved_page_count
    ,ps.reserved_page_count
From
    sys.objects as so
    inner join sys.dm_db_partition_stats as ps
        on ps.object_id = so.object_id and ps.index_id between 0 and 1
Where 1 = 1
    and (OBJECTPROPERTY(so.object_id, 'TableHasPrimaryKey') = 0
        or OBJECTPROPERTY(so.object_id, 'TableHasClustIndex') = 0
        )
    and so.type = 'U'
    --and ps.used_page_count > 8      -- 64KB     128        -- 1MB
Order By
    so.name

/*

Select (sum(ps.used_page_count) * 8192) / 1000000
From
    sys.objects as so
    inner join sys.dm_db_partition_stats as ps
        on ps.object_id = so.object_id and ps.index_id between 0 and 1
Where
    so.name like 'ComplianceLog_%'
    
*/