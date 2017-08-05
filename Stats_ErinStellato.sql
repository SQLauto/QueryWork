/*
	SQLskills SQL101: Updating SQL Server Statistics Part II – Scheduled Updates
	https://www.sqlskills.com/blogs/erin/sqlskills-sql101-updating-sql-server-statistics-part-ii-scheduled-updates/
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-stats-properties-transact-sql

	Thanks Erin,
	This is exactly what I needed to replace the SQL2000 vintage update stats job on my servers. 
	Of course the real problem is picking a trigger point. For example, I have a Partitioned View that contains rolling, date-based sub-tables. Each week a new table is created and added to the view. The table receives about 30GB of data in 225M Rows at a pretty constant rate 24X7. The query references are almost all Insert or Select (minimal updates -no deletes). After a few weeks the table is rolled out of the view, truncated, and dropped.

	The data is keyed by a combination of a sort of device number (Int, TinyInt) (about 10,000 discrete devices) and a generally increasing datetime.

	I am thinking of just tracking the #Rows in the sub-tables in the meta-data that controls this process and then update stats after ?? rows are added.

	Any thoughts?
*/
Select so.name
	, ss.name
	, sp.* 
From sys.objects As so
	Inner Join sys.stats As ss
		On ss.object_id = so.object_id
	Cross Apply  sys.dm_db_stats_properties(so.object_id, ss.stats_id) As sp
Where
	so.name Like '%TSCI_ALL_%'
	And so.schema_id = Schema_Id('pViews')
