/*


	$Workfile: DBFiles_Get_Stats.sql $
	$Archive: /SQL/QueryWork/DBFiles_Get_Stats.sql $
	$Revision: 3 $	$Date: 14-04-18 17:22 $

*/
--dbcc loginfo()
if object_id('tempdb..#FileData', 'U') is not null
	Drop Table #FileData;
Go

Create Table #FileData(
	name		VARCHAR(128)
	,fileid		INT
	,filename	VARCHAR(128)
	,filegroup	VARCHAR(128)
	,size		VARCHAR(128)
	,maxsize	VARCHAR(128)
	,growth		VARCHAR(128)
	,usage		VARCHAR(128)
	)
	
insert into #FileData Exec sp_HelpFile;
Select * From #FileData;

Return
/*
If Object_id('tempdb..#FileStats', 'U') is not null Drop Table #FileStats
Create Table #FileStats (
    Id              int identity(1,1) Primary key Clustered
    ,Fileid          int
    ,FileGroup      int
    ,TotalExtents   Int
    ,UsedExtents    Int
    ,Name           Nvarchar(128)
    ,FileName       Nvarchar(128)
    ,Captured       Datetime default GetDate()
    )
-- Truncate Table #FileStats
*/

--WaitFor Delay '01:01:00'

Insert into #FileStats(Fileid, FileGroup, TotalExtents, UsedExtents, Name, FileName)
    Exec sp_executeSQL N'DBCC ShowFileStats;'

Select *
From #FileStats
Where name like '%'
order by
    name, UsedExtents desc

/*

Return
DBCC SHRINKFILE (N'<logical Name>' , EMPTYFILE)


DBCC ShowFileStats;
*/
Exec sp_helpFile

/*
ALTER DATABASE [Consirn]  REMOVE FILE [ConSIRN_ClearViewGraphsIndex2]
GO
*/