

If Object_id('TempDb..#RawBase', 'U') is not null
	Drop Table #RawBase;
If Object_id('TempDb..#RawFrac', 'U') is not null
	Drop Table #RawFrac;
Go
/*
	This script returns a set of Perfmon counters that
	are one shot Frac/Base such as Cache Hit Ratio %.
*/
Declare @Now	DATETIME;

Set @Now = GETDATE();

Create Table #RawFrac (id INT IDENTITY(1, 1)
	,ObjectName NVARCHAR(128)
	,CounterName NVARCHAR(128)
	,InstanceName NVARCHAR(128)
	,RawValue	BIGINT
	,Counter_desc VARCHAR(20)
	,SampleTime	DATETIME
	,SampleDuration Int
	);

Create Table #RawBase (id INT IDENTITY(1, 1)
	,ObjectName NVARCHAR(128)
	,CounterName NVARCHAR(128)
	,InstanceName NVARCHAR(128)
	,RawValue	BIGINT
	,Counter_desc VARCHAR(20)
	,SampleTime	DATETIME
	,SampleDuration Int
	);

Insert Into #RawFrac (ObjectName
	, CounterName, InstanceName, RawValue
	, Counter_desc, SampleTime
	)
	Select
		pc.object_name
		, pc.counter_name
		, pc.instance_name
		, pc.cntr_value
		--, pc.cntr_type
		, Case  pc.cntr_type
					When 1073939712	Then 'RawBase'		-- 'PERF_LARGE_RAW_BASE'
					When 537003264	Then 'RawFrac'		-- 'PERF_LARGE_RAW_FRACTION'
					When 1073874176	Then 'AvgBulk'		-- 'PERF_AVERAGE_BULK'
					When 272696576	Then 'BulkCount'	-- 'PERF_COUNTER_BULK_COUNT'
					When 65792		Then 'RawCount'		-- 'PERF_COUNTER_LARGE_RAWCOUNT'
					Else 'Unkown'
				End
		,@Now
	From
		sys.dm_os_performance_counters as pc
	Where 1 = 1
		and (pc.cntr_type = 537003264		-- Raw Fraction
			Or pc.cntr_type = 65792			-- Raw Count
			)
	;
Insert Into #RawBase (ObjectName
	, CounterName, InstanceName, RawValue
	, Counter_desc, SampleTime
	)
	Select
		pc.object_name
		, pc.counter_name
		, pc.instance_name
		, pc.cntr_value
		--, pc.cntr_type
		, Case  pc.cntr_type
				When 1073939712	Then 'RawBase'		-- 'PERF_LARGE_RAW_BASE'
				When 537003264	Then 'RawFrac'		-- 'PERF_LARGE_RAW_FRACTION'
				When 1073874176	Then 'AvgBulk'		-- 'PERF_AVERAGE_BULK'
				When 272696576	Then 'BulkCount'	-- 'PERF_COUNTER_BULK_COUNT'
				When 65792		Then 'RawCount'		-- 'PERF_COUNTER_LARGE_RAWCOUNT'
				Else 'Unkown'
			End
		,@Now
	From
		sys.dm_os_performance_counters as pc
	Where
		pc.cntr_type = 1073939712
	;

--Select * From #RawFrac as rf
--Select * From #RawBase as rb

Select
	rf.SampleTime
	,[Duratinon]	= COALESCE(rf.SampleDuration, 0)
	,rf.ObjectName
	,rf.InstanceName
	,rf.CounterName
	,[Cooked Value] = Case when rb.RawValue > 0 then CAST(CAST(rf.RawValue as FLOAT) / CAST(rb.RawValue as FLOAT) as DECIMAL(18,4)) else 0.0 end
	--,rf.RawValue
	--,rb.RawValue
From
	#RawBase as rb
	inner join #RawFrac as rf
		on rb.ObjectName = rf.ObjectName
		and rb.InstanceName = rf.InstanceName
Where 1 = 1
	and 0 < CHARINDEX(RTRIM(rf.CounterName), RTRIM(rb.CounterName), 1)	-- match on the Counters Names
Union
	Select 
	rf.SampleTime
	,[Duratinon]	= COALESCE(rf.SampleDuration, 0)
	,rf.ObjectName
	,rf.InstanceName
	,rf.CounterName
	,rf.RawValue
From
	#RawFrac as rf
Where 1 = 1
	and rf.Counter_desc = 'RawCount'