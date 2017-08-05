/*
	
	See notes at end of script for how to determine the wait resource, Job Names, etc.

	$Workfile: Query_GetByConnections.sql $
	$Archive: /SQL/QueryWork/Query_GetByConnections.sql $
	$Revision: 1 $	$Date: 14-09-25 13:58 $
*/


select
	ec.session_id
	, [Req Status] = coalesce(er.status, 'Not Active')
	, [Conn Time] = ec.connect_time
	, [Conn Transport] = ec.net_transport
	--, 
	, ec.*
	, es.*
	, er.*
from 
	sys.dm_exec_connections as ec
	left outer join sys.dm_exec_sessions as es
		on es.session_id = ec.session_id
	left outer join sys.dm_exec_requests as er
		on er.session_id = ec.session_id
order by
	ec.session_id





Return;
/*
	The query often shows SQL Agent Jobs in the "program_name" column.  For Example consider:
		SQLAgent - TSQL JobStep (Job 0x2F415BEDA4B24A41960C7F9FC250F4E1 : Step 7)
	The long Hex string is the Job Id which is a Unique Identifier in msdb..sysjobs.  However, it is displayed here
	as a VarBinary() and it is not easy to convert to a Unique Identifier.
		Cut&Paste from Results - 0x2F415BEDA4B24A41960C7F9FC250F4E1
		Divide with Hyphens as - 2F415BED-A4B2-4A41-960C-7F9FC250F4E1
	
	Note the string is in the proper format now but it is still not the correct value.  The first half
	of the string is byte-reversed but the last half is correct.  So 2F415BED has to be morphed to ED5B412F.
	I.E, the order of the bytes (character pairs) has to be reversed.  The same is true for the 2nd and 3rd
	portions of the string.  The final, correct result is:
		ED5B412F-B2A4-414A-960C-7F9FC250F4E1
	
	This bit of SQL can be used to find the correct Job name.  Just Cut&Paste the hex string directly from
	the query results omitting parens, ticks, quotes, brackets, etc.

*/

Select
	sj.Job_id
	,CAST(sj.job_id as varbinary(36))
	,sj.name
From
	msdb..sysjobs as sj
Where 1 = 1
	and cast(sj.job_id as varbinary(35)) = 0x4429DD294FE4714A9D7B88077A0F402A
;
;
-- SQL2008R2 Jobs.
--SQLAgent - TSQL JobStep (Job 0x2F415BEDA4B24A41960C7F9FC250F4E1 : Step 6)	-- DOMSalesProcess
--SQLAgent - TSQL JobStep (Job 0x97F6528F1ECDEC49AD3F064ACC4FF711 : Step 2)	-- CheckMissingCallinInterval
--SQLAgent - TSQL JobStep (Job 0x0EAE8844529EA045AB911AC1CDB5FBBC : Step 5)	-- BirIAB00 & ConsirnEod generate
--SQLAgent - TSQL JobStep (Job 0xE102123ABC644045B2ED555A3B94200F : Step 6)	-- CLVLevelA Generate Fuelsale
--SQLAgent - TSQL JobStep (Job 0xFBCF354E7166424992564B03019167FB : Step 5)	-- PanellevelB Generate Sales
--Dev-SQL-01 Jobs
--SQLAgent - TSQL JobStep (Job 0x4429DD294FE4714A9D7B88077A0F402A : Step 4) -- CLV_LevelAGenerateFuelSale
Return;


/*

If Wait_Resource is of the form "OBJECT: 5:1465185857:0" then the first digit, i.e., "5" is the Database Id
	and the second digit string, i.e., is the object id in the database.

	Select Db_Name(5)
	Select object_name (1465185857, 5)

If the Wait_Resource is of the form "5:1:27696624" then it is "Db_Id:File_id:PageNum" and can be used
	with DBCC Page as follows:

		DBCC TraceOn (3604)
		DBCC page (10,12,6266330, 3)
About midway down the results page (20 or so lines) you will find:
		Metadata: ObjectId = 1465185857
Which is the object id in the database
	Select object_name (606806861, 12)
	
	10:12:6266330

*/
--If OBJECT_ID('TempDb..#DBCCData', 'U') is not null
--	Drop Table #DBCCData


--Declare
--	@cmd		NVarchar(4000)
--	,@ResStr	NVarchar(50)
--;
--Set @ResStr = N'5:1:36199899';
--Create Table #DBCCData(id int identity(1,1), txtLine varchar(128));

--Set @ResStr = N'(' + Replace(@ResStr, ':', ', ') + N', 1)'
--print @ResStr;
--Set @cmd = N'
--	DBCC TraceOn(3604);
--	DBCC Page (5, 1, 3490764, 1);
--	DBCC TraceOff(3604)'
--	;

--Insert #DBCCData(txtLine)	
--Exec sp_ExecuteSQL @cmd;
--	5:1:49998542	-- S2005BOLMatched D:
--	5:8:14355730	-- TSCI_All
--	5:1:17910150	-- QueitBusyPoint
--	Select OBJECT_NAME(34, 5)
