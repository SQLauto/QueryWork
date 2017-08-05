/*
	This script requires both on line and offline actions.
	It provides a template for moving one or more of the physical files associateed with a Database
	to a different file system location on the same server

	ms-help://MS.SQLCC.v10/MS.SQLSVR.v10.en/s10de_1devconc/html/ad9a4e92-13fb-457d-996a-66ffc2d55b79.htm
	$Workfile: DB_Move_Files_Template.sql $
	$Archive: /SQL/QueryWork/DB_Move_Files_Template.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/

/*
	Steps
	1. determine the logical names of the file(s) to move.
	2. Take the databasse offline
	3. Copy the phyiscal file(s) to the new location(s)
	5. Run the snippet to alter the database
	6. Place the database Online
	7. check file location(s)
*/
Return
-- Run this procedure and copy the returned data for reference.  Particularly the logical name of the file(s) to be moved
Exec sp_helpfile;
Return
-- Use the following to take the database offline.
Alter Database AdventureWorks Set OffLine With RollBack Immediate;
Return

-- Now copy the file(s) to the new location(s) using Windows Explorer.

-- After the file copy run the following snippet for each file moved.
Alter Database AdventureWorks Modify File (
	Name = LogicalName
	,FileName = 'new_path\os_file_name'	-- Include the suffix MDF, NDF, LDF
	);
Return

-- Use the following to set the database online.
Alter Database AdventureWorks Set OnLine;
Return

-- Check the results.
Exec sp_helpfile