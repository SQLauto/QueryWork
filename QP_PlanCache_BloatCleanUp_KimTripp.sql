/*
	Kimberly Tripp (
	Plan cache and optimizing for adhoc workloads
	http://www.sqlskills.com/blogs/kimberly/plan-cache-and-optimizing-for-adhoc-workloads/

	This script reports the usage of plan cache to see if a lot of space is being used
	by Single Use (e.g., Ad Hoc) plans.
	
	There is also a script to evalute the usage and free cache if appropriate (perhaps a SQL Job)

	See Also - Fabiano Amorim Article	
	Fixing Cache Bloat Problems With Guide Plans and Forced Parameterization
	https://www.simple-talk.com/sql/performance/fixing-cache-bloat-problems-with-guide-plans-and-forced-parameterization/?utm_source=simpletalk&utm_medium=email-main&utm_content=fixingcachebloat-20140303&utm_campaign=sql

	$Workfile: QP_PlanCache_BloatCleanUp_KimTripp.sql $
	$Archive: /SQL/QueryWork/QP_PlanCache_BloatCleanUp_KimTripp.sql $
	$Revision: 5 $	$Date: 16-02-12 16:43 $
*/



SELECT
	[CacheType] = cp.objtype
    , [Total Plans] = count_big(*)
    , [Total MBs] = sum(cast(cp.size_in_bytes as decimal(18,2))) / (1024.0 * 1024.0)
    , [Avg Use Count] = avg(cp.usecounts)
    , [USE Count 1 (MBs)] = sum(cast((CASE WHEN cp.usecounts = 1
								THEN cp.size_in_bytes
								ELSE 0
								END) as decimal(18,2)))
							/ (1024.0 * 1024.0)
    , [USE Count 1 Num Plans] = sum(CASE WHEN cp.usecounts = 1 THEN 1 ELSE 0 END)
FROM sys.dm_exec_cached_plans as cp
GROUP BY cp.objtype
ORDER BY  [USE Count 1 (MBs)] DESC
Return;


/*
	Plan cache, adhoc workloads and clearing the single-use plan cache bloat
	http://www.sqlskills.com/blogs/kimberly/plan-cache-adhoc-workloads-and-clearing-the-single-use-plan-cache-bloat/
Cleared SQL2008R2 on 20140501 <RBH>
CacheType	Total Plans	Total MBs	Avg Use Count	USE Count 1 (MBs)	USE Count 1 Num Plans
Adhoc		49785		872.036262	124				291.845886			43425
Prepared	2856		265.132812	8242			114.820312			1549

*/

-- Clearing *JUST* the 'SQL Plans' based on *just* the amount of Adhoc/Prepared single-use plans (2005/2008): 
DECLARE
	@MB DECIMAL(19, 3)
	, @Count BIGINT
	, @StrMB NVARCHAR(20) 
SELECT
	@MB = sum(cast((case WHEN usecounts = 1 AND objtype IN ('Adhoc', 'Prepared')
						THEN size_in_bytes
						ELSE 0
						END) as DECIMAL(12, 2))) / (1024.0 * 1024.0)
	, @Count = sum(case	WHEN usecounts = 1 AND objtype IN ('Adhoc', 'Prepared')
						THEN 1
						ELSE 0
						END)
	, @StrMB = convert(NVARCHAR(20), @MB)
FROM
	sys.dm_exec_cached_plans

IF @MB > 10
	BEGIN
		DBCC FREESYSTEMCACHE('SQL Plans') 
		RAISERROR ('%s MB was allocated to single-use plan cache. Single-use plans have been cleared.', 0, 0, @StrMB)
	END
ELSE
	BEGIN
		RAISERROR ('Only %s MB is allocated to single-use plan cache – no need to clear cache now.', 0, 0, @StrMB)
	END
Return;

/*============================================================================
  File:     sp_SQLskills_CheckPlanCache

  Summary:  This procedure looks at cache and totals the single-use plans
			to report the percentage of memory consumed (and therefore wasted)
			from single-use plans.
			
  Date:     April 2010

  Version:	2008.
------------------------------------------------------------------------------
  Written by Kimberly L. Tripp, SQLskills.com

  For more scripts and sample code, check out 
    http://www.SQLskills.com

  This script is intended only as a supplement to demos and lectures
  given by SQLskills instructors.  
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.

  Plan cache, adhoc workloads and clearing the single-use plan cache bloat
  http://www.sqlskills.com/blogs/kimberly/plan-cache-adhoc-workloads-and-clearing-the-single-use-plan-cache-bloat/
============================================================================*/

USE zDBAInfo
go

if OBJECTPROPERTY(OBJECT_ID('sp_SQLskills_CheckPlanCache'), 'IsProcedure') = 1
	DROP PROCEDURE sp_SQLskills_CheckPlanCache
go

CREATE PROCEDURE sp_SQLskills_CheckPlanCache
	(@Percent	decimal(6,3) OUTPUT,
	 @WastedMB	decimal(19,3) OUTPUT)
As
Begin	-- Procedure
	SET NOCOUNT ON

	DECLARE @ConfiguredMemory	decimal(19,3)
		, @PhysicalMemory		decimal(19,3)
		, @MemoryInUse			decimal(19,3)
		, @SingleUsePlanCount	bigint

	CREATE TABLE #ConfigurationOptions
	(
		[name]				nvarchar(35)
		, [minimum]			int
		, [maximum]			int
		, [config_value]	int				-- in bytes
		, [run_value]		int				-- in bytes
	);
	INSERT #ConfigurationOptions EXEC ('sp_configure ''max server memory''');

	SELECT @ConfiguredMemory = run_value/(1024 * 1024) 
	FROM #ConfigurationOptions 
	WHERE name = 'max server memory (MB)'

	SELECT @PhysicalMemory = total_physical_memory_kb/1024 
	FROM sys.dm_os_sys_memory

	SELECT @MemoryInUse = physical_memory_in_use_kb/1024 
	FROM sys.dm_os_process_memory

	SELECT @WastedMB = sum(cast((CASE WHEN usecounts = 1 AND objtype IN ('Adhoc', 'Prepared') 
									THEN size_in_bytes ELSE 0 END) AS DECIMAL(12,2)))/(1024 * 1024) 
		, @SingleUsePlanCount = sum(CASE WHEN usecounts = 1 AND objtype IN ('Adhoc', 'Prepared') 
									THEN 1 ELSE 0 END)
		, @Percent = @WastedMB/@MemoryInUse * 100
	FROM sys.dm_exec_cached_plans

	SELECT
		[TotalPhysicalMemory (MB)] = @PhysicalMemory
		, [TotalConfiguredMemory (MB)] = @ConfiguredMemory
		, [MaxMemoryAvailableToSQLServer (%)] = @ConfiguredMemory/@PhysicalMemory * 100
		, [MemoryInUseBySQLServer (MB)] = @MemoryInUse
		, [TotalSingleUsePlanCache (MB)] = @WastedMB
		, TotalNumberOfSingleUsePlans = @SingleUsePlanCount
		, [PercentOfConfiguredCacheWastedForSingleUsePlans (%)] = @Percent
End;	-- Procedure
GO
Return;
EXEC sys.sp_MS_marksystemobject 'sp_SQLskills_CheckPlanCache'
go
Return;
-----------------------------------------------------------------
-- Logic (in a job?) to decide whether or not to clear - using sproc...
-----------------------------------------------------------------

DECLARE @Percent		decimal(6, 3)
		, @WastedMB		decimal(19,3)
		, @StrMB		nvarchar(20)
		, @StrPercent	nvarchar(20)
EXEC sp_SQLskills_CheckPlanCache @Percent output, @WastedMB output

SELECT @StrMB = CONVERT(nvarchar(20), @WastedMB)
		, @StrPercent = CONVERT(nvarchar(20), @Percent)

IF @Percent > 10 OR @WastedMB > 10
	BEGIN
		DBCC FREESYSTEMCACHE('SQL Plans') 
		RAISERROR ('%s MB (%s percent) was allocated to single-use plan cache. Single-use plans have been cleared.', 10, 1, @StrMB, @StrPercent)
	END
ELSE
	BEGIN
		RAISERROR ('Only %s MB (%s percent) is allocated to single-use plan cache - no need to clear cache now.', 10, 1, @StrMB, @StrPercent)
			-- Note: this is only a warning message and not an actual error.
	END
go