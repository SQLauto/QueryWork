
/*
Finding a table name from a page ID
http://www.sqlskills.com/blogs/paul/finding-table-name-page-id/
Inside the Storage Engine: Anatomy of a page
http://www.sqlskills.com/blogs/paul/inside-the-storage-engine-anatomy-of-a-page/

Paul Randal

*/
Select 
	wt.resource_description
	, wt.wait_type
	, wt.session_id
	, wt.wait_duration_ms
	, wt.*
From sys.dm_os_waiting_tasks wt
Where wt.resource_description Is Not Null
;

Return;
/*
5:8:103893118
5:1:43544550
5:15:32068345
5:11:30775353
5:18:16878037
10:1:594519
5:8:27199273
*/


--Create Table #dbcc_data(ParentObject Varchar(256),	Object Varchar(50), Field Varchar(50), VALUE Varchar(256));
Truncate Table #dbcc_data;
Insert #dbcc_data
Exec sp_executeSQL N'Dbcc Page(5, 8, 103893118, 0) With TableResults;'

Select Object_Name(Cast (d.value As Int))
From #dbcc_data As d
Where
	d.Field = 'Metadata: ObjectId';



Dbcc memoryStatus
