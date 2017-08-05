/*
	This Script returns size information for the database
	files.
	$Workfile: DB_GetFileNameAndSizeInfo.sql $
	$Archive: /SQL/QueryWork/DB_GetFileNameAndSizeInfo.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/
If Object_Id('tempdb..#FileData', 'U') Is Not Null
	Drop Table #FileData;
Go
Create Table #FileData(
	name		Varchar(128)
	, fileid	Int
	, filename	Varchar(128)
	, filegroup	Varchar(128)
	, size		Varchar(128)
	, maxsize	Varchar(128)
	, growth	Varchar(128)
	, usage		Varchar(128)
	);

Insert #FileData
Exec sys.sp_helpfile
;

Select
	[Logical Name] = fd.name
	, [Size (GB)] = Cast(Cast(Replace(fd.size, ' KB', '') As Decimal(12, 3))/ (1024.0 * 1024.0) As Decimal(10, 3))
	, [Physical Name] = Reverse(Substring(Reverse(fd.filename), 1, CharIndex('\', Reverse(fd.filename), 1) - 1))
	, [Drive] = Substring(fd.filename, 1, 1)
	--, fd.filename
	--, fd.size
-- Select * 
From #FileData As fd
Order By
	[Size (GB)] Desc;


Return;

Select
	mf.name
	, [Drive] = Substring(mf.physical_name, 1, 1)
	, [Size (GB)] = Cast((mf.size * 8.192)/ (1024.0 * 1024.0) As Decimal(12,3))
	, mf.physical_name
From
	sys.master_files As mf
Where
	mf.database_id > 4
	--and mf.database_id = db_id('ConSIRN')
	And mf.file_id != 2
Order By
	[Size (GB)] Desc;