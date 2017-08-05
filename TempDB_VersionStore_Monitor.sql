/*
	This file contains snippets for monitoring Version Store usage.
	Based on presentation by Vicki Harp (vicki.harp@idera.com)
	$Archive: /SQL/QueryWork/TempDB_VersionStore_Monitor.sql $
	$Date: 15-06-30 10:25 $	$Revision: 1 $
	
*/

/*
	Version Store MB should grow for a minute then drop to a very low value.  If it
	continues to grow then there is a long running txn that is causing the pages to be
	retained.
*/
Select
	[File Name] = mf.name
	--, fs.file_id
	, [VersionStore MB] = Cast((fs.version_store_reserved_page_count / 128.0) As Decimal( 14, 2))
	, [User MB] = Cast((fs.user_object_reserved_page_count / 128.0) As Decimal( 14, 2))
	, [Sys MB] = Cast((fs.internal_object_reserved_page_count / 128.0) As Decimal( 14, 2))
	, [Free MB] = Cast((fs.unallocated_extent_page_count / 128.0) As Decimal( 14, 2))
From
	sys.dm_db_file_space_usage As fs
	Inner Join sys.master_files As mf
		On mf.database_id = Db_Id('tempdb')
		And mf.file_id = fs.file_id
	
Return
/*
*/
Select *
From
	sys.dm_db_session_space_usage As su
Where 1 = 1
	And su.database_id = 2

Select *
From
	sys.dm_db_task_space_usage As tu
Where 1 = 1
	And tu.database_id = 2