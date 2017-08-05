/*
	
	Database Suspect Data Page Event Class
	https://docs.microsoft.com/en-us/sql/relational-databases/event-classes/database-suspect-data-page-event-class
*/

SELECT
	[DB] = DB_NAME(sp.database_id)
	, [FILE] = mf.name
	, sp.*
FROM msdb.dbo.suspect_pages as sp
	inner join sys.master_files as mf
		on mf.database_id = sp.database_id
		and mf.file_id = sp.file_id
;
/*
DELETE FROM msdb..suspect_pages  
   WHERE 1 = 1
	And (event_type = -1	-- Dummy
		Or event_type = 1	-- 823 or 824 e.g., bad checksum or CRC
		Or event_type = 4	-- Restored after marked bad
		OR event_type = 5	-- Repaired by DBCC
		OR event_type = 7	-- Deallocated by DBCC
	);  
*/  
/*


DBCC Page ('ClearView_History', 3, 22657294, 3)

DBCC Page ('ClearView_History', 3, 22657294, 3)

select object_name(357576312)	-- TSCI_All_20160601

Select  count(*) From pViews.TSCI_All_20160601

DBCC TraceOn(3604, 1)
DBCC Page(5, 19, 48881735, 3)

Select OBJECT_NAME(1012484423, 5)		-- ConSIRN.pViews.TSCI_All_20161201

DBCC CheckTable ([pViews.TSCI_All_20161201]) With All_ErrorMsgs, Physical_Only;


Alter Index IX_TSCI_All_20161201_PanelID_ReadingDate on pViews.TSCI_All_20161201 REORGANIZE
*/ 