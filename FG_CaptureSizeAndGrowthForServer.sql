/*
	How Long Before Your Database Runs Out of Space?
	By John F. Tamburo, 2016/06/09
	http://www.sqlservercentral.com/articles/Capacity+planning/138733/

	$Archive: /SQL/QueryWork/FG_CaptureSizeAndGrowthForServer.sql $
	$Revision: 1 $	$Date: 16-06-13 16:19 $

	I started a substantial rework of the original version(Revision 1) and there is a lot
	remaining.
	Removed the set/clear xp_cmdShell code, Powershell, WMI, etc.
	need to complete the "data capture" etc.

	This is not the query I use for the server configuration worksheets.
*/
--Return;
Use zDBAInfo;
Go
If Object_Id('dbo.DBGrowthHistory', 'U') Is Null
	Create Table dbo.DBGrowthHistory (
		TimeCollected      DATETIME      Not Null
	  , Monitored_object   NVARCHAR(100) Not Null
	  , DBName             NVARCHAR(100) Not Null
	  , FGName             NVARCHAR(100) Not Null
	  , FileLogicalName    NVARCHAR(100) Not Null
	  , totalmb            FLOAT         Not Null
	  , freemb             FLOAT         Not Null
	  , growthsremaining   INT           Not Null
	  , DBGrowthHistory_ID BIGINT        Identity(1, 1) Not Null
	  , Constraint PK_DBGrowthHistory
			Primary Key Clustered (DBGrowthHistory_ID Asc)
			With (Pad_Index = Off, Statistics_Norecompute = Off, Ignore_Dup_Key = Off, Allow_Row_Locks = On
			  , Allow_Page_Locks = On, FillFactor = 100
				) On [Default]
		) On [Default];
/*
I have devised a query to capture these statistics for every single database on a server.
It is based on a query I found online from Satya Jayanty and I am thankful for this helpful query.
Let’s have a look at what I was able to muster:
*/
Select
	'TimeCollected' = Convert(DATETIME, Convert(DATE, GetDate()))
	, 'monitored_object'  = @@Servername
	, 'DBName'            = Db_Name()
	, 'fgName'            = b.groupname
	, 'FileLogicalName'   = name
	, 'OSFileName'        = filename
	, 'totalMB'           = Convert(DECIMAL(15, 2), Round(a.size / 128.000, 2))
	, 'freeMB'            = Convert(DECIMAL(15, 2), Round((a.size - FileProperty(a.name, 'SpaceUsed')) / 128.000, 2))
From
    dbo.sysfiles As a (NoLock)
    Join sysfilegroups As b (NoLock)
        On a.groupid = b.groupid
Order By b.groupname;

/*
	<RBH>
	All of the following can be replaced with 
	Select *
	FROM sys.master_files AS f
		CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) as vs
*/
Declare @svrName VARCHAR(255);
Declare @sql VARCHAR(400);
--by default it will take the current server name, we can the set the server name as well
Set @svrName = @@SERVERNAME;
Set @sql
    = 'powershell.exe -c "Get-WmiObject -ComputerName ' + QuoteName(@svrName, '''')
      + ' -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1MB +''%''+$_.freespace/1MB +''*''}"';
--creating a temporary table	--1048576
Create Table #output (line VARCHAR(255));
--inserting disk name, total space and free space value in to temporary table
Insert #output	-- Exec xp_cmdshell @sql;
	Select 
		[Server] = @@SERVERNAME
		, [Database] = Db_Name(f.database_id)
		, [Logical File] = f.name
		, [File Name] = f.physical_name
		, [File State] = f.state_desc
		, [Size (MB)] = f.size/128		-- #8KB pages / 128 = MB
		, [Max Size] = Case When f.max_size < 0 Then f.max_size Else f.max_size/128 End	-- #8KB pages / 128 = MB
		, [Growth] = Case When f.is_percent_growth = 0 Then Cast(f.growth /128 As VARCHAR(50)) + 'MB' Else Cast(f.growth As VARCHAR(50)) + N'%' End
		, [IsPercentGrowth] = Case When f.is_percent_growth = 0 Then 'No' Else 'Yes' End
		, [Drive] = vs.volume_mount_point
		--, vs.file_system_type
		, [Drive Size(MB)] = vs.total_bytes / 1024000
		, [Drive Free(MB)] = vs.available_bytes / 1024000
	FROM sys.master_files AS f
		Cross APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) as vs
/*
--Query to retrieve the values in MB from PS Script output
Select
	'ServerName' = @svrName
	, 'TimeCollected'  = Convert(DATETIME, Convert(DATE, GetDate()))
	, 'drivename'      = RTrim(LTrim(Substring(line, 1, CharIndex('|', line) - 1)))
	, 'capacity(MB)'   = Round(Cast(RTrim(LTrim(
		Substring(line, CharIndex('|', line) + 1, (CharIndex('%', line) - 1) - CharIndex('|', line)
		))) As FLOAT), 0)
	, 'freespace(MB)'  = Round(Cast(RTrim(LTrim(
		Substring(line, CharIndex('%', line) + 1, (CharIndex('*', line) - 1) - CharIndex('%', line)
		))) As FLOAT), 0)
From #output
Where line Like '[A-Z][:]%'
Order By drivename;
*/
--	

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