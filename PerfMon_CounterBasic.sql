/*
	This script queries basic SQL performance counters from Sys.dm_os_PerformanceCounters.
	$Archive: /SQL/QueryWork/PerfCounter_Basic.sql $
	$Revision: 2 $	$Date: 15-03-25 15:50 $
	References:
	Interpreting the counter values from sys.dm_os_performance_counters
	http://blogs.msdn.com/b/psssql/archive/2013/09/23/interpreting-the-counter-values-from-sys-dm-os-performance-counters.aspx

	Objective: - Collect two raw samples of every counter with a sample duration of @SampleDur (default 10 sec) then
		Calculate the counter values based on Counter Type.
	See Description of counter types at the end of the script.
*/
If object_id('tempdb.dbo.#First', 'U') is not null
	Drop Table #First;
If object_id('tempdb.dbo.#Second', 'U') is not null
	Drop Table #Second;
If object_id('tempdb.dbo.#CounterValue', 'U') is not null
	Drop Table #CounterValue;
Go

Declare
	@StartTime	DATETIME = GETDATE()
	,@StopTime	DateTime
	,@SampleDur	NCHAR(10) = N'00:00:10'
	;
Create Table #First(Id INT IDENTITY(1,1)
	,ObjectName NVARCHAR(128)
	,CounterName NVARCHAR(128)
	,InstanceName NVARCHAR(128)
	,Value	BIGINT
	,CntrType	INT
	,CounterDesc VARCHAR(20)
	,SampleTime	DATETIME
	);
Create Table #Second(Id INT IDENTITY(1,1)
	,ObjectName NVARCHAR(128)
	,CounterName NVARCHAR(128)
	,InstanceName NVARCHAR(128)
	,Value	BIGINT
	,CntrType	INT
	,CounterDesc VARCHAR(20)
	,SampleTime	DATETIME
	);
Create Table #CounterValue(Id INT IDENTITY(1,1)
	,ObjectName NVARCHAR(128)
	,CounterName NVARCHAR(128)
	,CounterBase NVARCHAR(128)
	,InstanceName NVARCHAR(128)
	,Value	BIGINT
	,CntrType	INT
	,CounterDesc VARCHAR(20)
	,SampleTime	DATETIME
	,SampleDuration Int
	);

Insert Into #First (SampleTime, ObjectName, CounterName, InstanceName, Value, CntrType, CounterDesc)
	Select
		@StartTime, pc.object_name, pc.counter_name, pc.instance_name, pc.cntr_value, pc.cntr_type
		,[Cntr_Type_Desc] = Case  pc.cntr_type
								When 1073939712	Then 'RawBase'		-- 'PERF_LARGE_RAW_BASE'
								When 537003264	Then 'RawFrac'		-- 'PERF_LARGE_RAW_FRACTION' D/B * 100 = %
								When 1073874176	Then 'AvgBulk'		-- 'PERF_AVERAGE_BULK' (D2 - D1)/(B2 - B1)
								When 272696576	Then 'BulkCount'	-- 'PERF_COUNTER_BULK_COUNT' (V2 - V1)/SampleDur
								When 65792		Then 'RawCount'		-- 'PERF_COUNTER_LARGE_RAWCOUNT' Snapshot
								Else 'Unknown'
							End
		
	From
		sys.dm_os_performance_counters as pc;
WaitFor Delay @SampleDur;
Set @StopTime = GetDate();

Insert Into #Second (SampleTime, ObjectName, CounterName, InstanceName, Value, CntrType, CounterDesc)
	Select
		@StopTime, pc.object_name, pc.counter_name, pc.instance_name, pc.cntr_value, pc.cntr_type
		,[Cntr_Type_Desc] = Case  pc.cntr_type
								When 1073939712	Then 'RawBase'		-- 'PERF_LARGE_RAW_BASE'
								When 537003264	Then 'RawFrac'		-- 'PERF_LARGE_RAW_FRACTION' D/B * 100 = %
								When 1073874176	Then 'AvgBulk'		-- 'PERF_AVERAGE_BULK' (D2 - D1)/(B2 - B1)
								When 272696576	Then 'BulkCount'	-- 'PERF_COUNTER_BULK_COUNT' (V2 - V1)/SampleDur
								When 65792		Then 'RawCount'		-- 'PERF_COUNTER_LARGE_RAWCOUNT' Snapshot
								Else 'Unknown'
							End
	From
		sys.dm_os_performance_counters as pc;

Insert #CounterValue(ObjectName, CounterName, CounterBase, InstanceName, Value, CntrType, CounterDesc, SampleTime, SampleDuration)
	Select
		sN.ObjectName
		, sN.CounterName
		, SD.CounterName
		, sN.InstanceName
		, Case sN.CounterDesc
				When 'RawCount' Then sN.Value
				When 'BulkCount' Then (sN.Value - fN.value) / DateDiff(ss, fN.SampleTime, sN.SampleTime)
				When 'RawFrac' Then Case When sD.value = 0 Then 0 Else Cast((sN.Value / sD.Value) as Decimal(32, 8)) * 100 End
			Else -sN.Value End
		, sN.CntrType
		, sN.CounterDesc
		, sN.SampleTime
		, DateDiff(ss, fN.SampleTime, sN.SampleTime)
	From
		#Second As sN	-- Second Numerator
		Inner Join #First as fN	-- Sirst Numerator
			on fN.ObjectName = sN.ObjectName
			And fN.InstanceName = sN.InstanceName
			And fN.CounterName = sN.CounterName
		Left Outer Join #Second as sD	-- Second Denomintor
			on sD.ObjectName = sN.ObjectName
			and sD.InstanceName = sN.InstanceName
			and Replace(Rtrim(sD.CounterName), ' Base', '') Like Rtrim(sN.CounterName)
			and sD.CounterDesc = 'RawBase'
		
		
	Where
		sN.CounterDesc != 'RawBase'


Select * From #CounterValue as cv
Select * From #First;
Return;

 /*
 Interpretation of pc.Cntr_Value
 
PERF_LARGE_RAW_BASE	- This counter type is used to form the Denominator (base) of a calculated value such as Cache Hit Ratio
	To calculate the actual value find the corresponing counter Fractional value.  The Numerator has the same Object, Counter, and 
	Instance name except that the counter name will not have "_base" appended.
	This counter is also used as an accumulating counter for PERF_AVERAGE_BULK counters. 

PERF_LARGE_RAW_FRACTION - This counter type is used to form the Numerator of a calculated value such as Cache Hit Ratio.
	(i.e., It is the numerator of an instanteous or snapshot value).
	The counter is associated with a PERF_LARGE_RAW_BASE counter with the same Object, Counter, and Instance name except the
	counter name will have "_base" appended.  Divide the Fraction by the Base to obtain the actual value as a decimal fraction.
	Multiply by 100 to convert to a percent.

PERF_AVERAGE_BULK - This counter type is similar to PERF_LARGE_RAW_FRACTION except it is accumulating.  So to calculate the
	actual value requires taking the difference between two samples and dividing by the difference between two corresponding
	PERF_LARGE_RAW_BASE values for the same Object, Counter, and Instance.  e.g. (N2 - N1)/(B2 - B1)
	An example is Average Latch Wait Time (ms)

PERF_COUNTER_BULK_COUNT - an accumulating rate metric.  The difference between two successive samples divided by the sample interval
	yields the rate.  For example, Transactions per second.

PERF_COUNTER_LARGE_RAWCOUNT - last observed value (current value) e.g. Total Pages.
 
 
 */
 
 Select
		sN.ObjectName
		, sN.CounterName
		, SD.CounterName
		, sN.InstanceName
		, sN.Value
		, sN.CntrType
		, sN.CounterDesc
	From
		#Second As sN	-- Numerator
		left outer join #Second as sD	-- Denomintor
			on sD.ObjectName = sN.ObjectName
			and sD.InstanceName = sN.InstanceName
			and Replace(Rtrim(sD.CounterName), ' Base', '') Like Rtrim(sN.CounterName)
			and sD.CounterDesc = 'RawBase'
	Where
		sN.CounterDesc != 'RawBase'
		--and sD.CounterDesc = 'RawBase'