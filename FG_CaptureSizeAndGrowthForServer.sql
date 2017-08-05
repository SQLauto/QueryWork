/*
	How Long Before Your Database Runs Out of Space?
	By John F. Tamburo, 2016/06/09
	http://www.sqlservercentral.com/articles/Capacity+planning/138733/

	$Archive: /SQL/QueryWork/FG_CaptureSizeAndGrowthForServer.sql $
	$Revision: 1 $	$Date: 16-06-13 16:19 $

*/
Return;
CREATE TABLE [dbo].[DBGrowthHistory](
    [TimeCollected] [datetime] NOT NULL,
    [Monitored_object] [nvarchar](100) NOT NULL,
    [DBName] [nvarchar](100) NOT NULL,
    [FGName] [nvarchar](100) NOT NULL,
    [FileLogicalName] [nvarchar](100) NOT NULL,
    [totalmb] [float] NOT NULL,
    [freemb] [float] NOT NULL,
    [growthsremaining] [int] NOT NULL,
    [DBGrowthHistory_ID] [bigint] IDENTITY(1,1) NOT NULL,
    CONSTRAINT [PK_DBGrowthHistory] PRIMARY KEY CLUSTERED
    (
        [DBGrowthHistory_ID] ASC
    )
    WITH
    (
        PAD_INDEX = OFF
        ,STATISTICS_NORECOMPUTE = OFF
        ,IGNORE_DUP_KEY = OFF
        ,ALLOW_ROW_LOCKS = ON
        ,ALLOW_PAGE_LOCKS = ON
        ,FILLFACTOR = 100
    ) ON [PRIMARY]
) ON [PRIMARY];
/*
I have devised a query to capture these statistics for every single database on a server.
It is based on a query I found online from Satya Jayanty and I am thankful for this helpful query.
Let’s have a look at what I was able to muster:
*/
SELECT
    CONVERT(datetime,CONVERT(date,GETDATE())) as [TimeCollected]
    ,@@Servername as [monitored_object]
    ,db_name() as [DBName]
    ,b.groupname AS [fgName]
    ,Name as [FileLogicalName]
    ,[Filename] as [OSFileName]
    ,CONVERT (Decimal(15,2),ROUND(a.Size/128.000,2)) as [totalMB]
    ,CONVERT (Decimal(15,2),ROUND((a.Size-FILEPROPERTY(a.Name,'SpaceUsed'))/128.000,2)) AS [freeMB]
FROM dbo.sysfiles a (NOLOCK)
JOIN sysfilegroups b (NOLOCK) 
    ON a.groupid = b.groupid
ORDER BY b.groupname;

/*
	<RBH>
	All of the following can be replaced with 
	Select *
	FROM sys.master_files AS f
		CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) as vs
*/
Exec sp_configure 'xp_cmdshell',1

reconfigure

declare @svrName varchar(255)
declare @sql varchar(400)
--by default it will take the current server name, we can the set the server name as well
set @svrName = @@SERVERNAME
set @sql = 'powershell.exe -c "Get-WmiObject -ComputerName ' + QUOTENAME(@svrName,'''') + ' -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"'
--creating a temporary table
CREATE TABLE #output
(line varchar(255))
--inserting disk name, total space and free space value in to temporary table
insert #output
EXEC xp_cmdshell @sql
--script to retrieve the values in MB from PS Script output
select @svrName as [ServerName]
 ,convert(datetime,convert(date,getdate())) as TimeCollected
 ,rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as drivename
 ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1
 ,(CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0) as 'capacity(MB)'
 ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1
 ,(CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float),0) as 'freespace(MB)'
from #output
where line like '[A-Z][:]%'
order by drivename

drop table #output

sp_configure 'xp_cmdshell',0

reconfigure


/*
Now with all of the variables, you simply need to calculate for each file group:
Days Remaining = (Free space in files) + (Growth Increment * Number of Growths remaining) / (Growth per Day [averaged])
The lowest number of days remaining from all file groups is how long you have.
It is of course vitally necessary to ensure that all numbers are in the same unit of measure. I reduce everything to megabytes.
Average growth per day can be skewed by such things as index rebuilds, archive/purge or extraordinary activity in the underlying
application. Obtain these numbers daily, and if outliers exist, decide how to account for them, or to exclude them altogether.
Your good judgment should guide you.

Reporting these numbers for a database (or for many) can be done in SQL, SSRS, Excel - whatever floats your boat. If the number
of days drops below 365, a friendly note up the chain to management should be considered. If you are under 180 days left, then 
the note should be more urgent. If you are at 2 days left and haven't notified top management of the danger at least ten 
times by now, it's time to buy an airplane ticket to a non-extradition country.
You can also calculate the above for different file groups or file locations. Your query may vary to accomplish this.

*/