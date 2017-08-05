--$Workfile: SQLErrorLog_ReadWithFilter.sql $

/*
	This script uses the semi-documented extended procedure
	to read the SQL Server Error log.
	$Archive: /SQL/QueryWork/SQLErrorLog_ReadWithFilter.sql $
	$Revision: 1 $	$Date: 14-08-07 15:19 $

	Notes on paramters.
	StartDate/EndDate do not work in as expected.  StartDate must be at least
	One full minute prior to EndDate.  It seems that the Seconds are ignored in the comparsion
	Also the sort does not sort seconds as expected.

	See SQL Server – Reading ERRORLOG with xp_ReadErrorLog for some information.
	http://sqlandme.com/2012/01/25/sql-server-reading-errorlog-with-xp_readerrorlog/

*/


If Object_id('tempdb..#theLog', 'U') is not null
	Drop Table #theLog;
Go

Create Table #theLog(LogDate DateTime, ProcessInfo Varchar(512), Text Varchar(2048));

Declare
	@cmd			Nvarchar(4000)
	,@LogNumber		Integer		= 0		-- current log Not nUll
	,@LogType		Integer		= 1		-- SQL Error Log, 2 = Agent Log Not nUll
	,@SearchTerm1	NVarchar(50) = Null
	,@SearchTerm2	NVarchar(50) = Null
	,@StartDate		NVarchar(50) = Null
	,@EndDate		NVarchar(50) = Null
	,@SortOrder		NVarchar(5)	= 'ASC'	-- ASC or DESC
	;
Set @LogNumber = 5
Set @LogType	= 1		-- SQL Error Log
Set @SearchTerm1	= N'Error 50001';
--Set @SearchTerm2	= N'starting';
Set @StartDate		= N'2014-07-25 23:00:00';
--Set @StartDate		= N'2014-07-08 19:55:52';
--Set @EndDate		= N'2014-07-08 19:55:11';
Set @EndDate		= N'2014-07-25 23:10:00';
--Set @SortOrder		= N'ASC'

Set @cmd = N'xp_ReadErrorLog ' + cast(@LogNumber as nvarchar(4)) + N', ' + Cast(@LogType as nvarchar(4))
			 + N', ' + Case When @SearchTerm1 is null then N'NULL'
					Else  N'N''' + @SearchTerm1 + ''''
				End
			 + N', ' + Case When @SearchTerm2 is null then N'NULL'
					Else  N'N''' + @SearchTerm2 + ''''
				End
			+ N', ' + Case When @StartDate is null then N'NULL'
					Else  N'N''' + @StartDate + ''''
				End
			+ N', ' + Case When @EndDate is null then N'NULL'
					Else  N'N''' + @EndDate + ''''
				End
			+ N', ' + Case When @SortOrder is null then N'NULL'
					Else  N'N''' + @SortOrder + ''''
				End


Print @cmd;

Insert #theLog Exec sp_ExecuteSQL @cmd;
	--Exec xp_ReadErrorLog
	--		@LogNumber, @LogType
	--		, @SearchTerm1, @SearchTerm2	
	--		, @StartDate, @EndDate		
	--		, @SortOrder		

Select * from #theLog

