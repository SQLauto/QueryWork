/*
	This query finds database objects of a given type (procedure, Table, function, ...)
	That have names that have a root match and differ in the suffix.
	The root is everthing before the last "_" in the object name.
	If the object name does not have an "_" it is ignored.
	The CTE and the Select have "where" clauses that can be "customized" to narrow down the results.
	The out put includes TSQL Statements that will rename the objects to a conventional name
	so they can be dropped later after a trial period.
	
	Use the Object Name and Root Name columns to determine the filters required to "narrow" the set of
	objects that will be renamed down to a manageable size.
	
	New name is of form "zDrop_<original name>_YYYYMMDD"
	
	Save a copy of the scirpt with filters for specific database for a specific run.

	$Workfile: Objects_GetDupesByRootName_Template.sql $
	$Archive: /SQL/QueryWork/Objects_GetDupesByRootName_Template.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/
--Use <DBName>
Go
Declare @Now Char(8);
Set @Now = convert(char(8), GetDate(), 112);

;With theDupes As (
	Select
		[RootName] = Reverse(substring(reverse(so.name), charIndex('_', reverse(so.name)) + 1, len(so.name) + 1))
		,[NumDupes] = count(*)
	From
		sys.objects as so
	Where 1 = 1
		and so.type = 'P'								-- usually just process one object type at a time 
		--and so.type = 'U'
		--and so.type = 'V'
		and charindex('_', so.name, 1) > 0				-- Must have "_" character in the name
		and so.name not like 'zDrop\_%' Escape '\'		-- Don't reprocess procs already renamed ;)
		--and so.name not like 'usp\_%' Escape '\'
		--and so.name not like 'Bill#%'					-- Wilco
		--and so.name not like 'CircleK\_%' Escape '\'	-- Wilco
		--and so.name not like 'IP\_%' Escape '\'			-- Wilco
		-- Table root names to skip completely
		and Reverse(substring(reverse(so.name), charIndex('_', reverse(so.name)) + 1, len(so.name) + 1))
			Not In (
				'', ''					-- Filter out specfic root names completely
				)
		and so.name not like 'dt\_%' Escape '\'			-- any DB that was once SQL 2000 DB
		and so.name not like 'sp\_%' Escape '\'			-- 
	Group By
		Reverse(substring(reverse(so.name), charIndex('_', reverse(so.name)) + 1, len(so.name) + 1))
	Having
		count(*) > 1
	)
Select
	[Object Name] = so.name
	,[Root Name] = d.RootName
	,[Num Dupes] = d.NumDupes
	,[Script] = N'Exec sp_executeSQL N''sp_rename ' + so.name + ', zDrop_' + so.name+ N'_'  + @Now + N''''
From
	sys.Objects as so
	inner join theDupes as d
		on so.name like d.rootname + '\_%' Escape '\'
Where 1 = 1
	And so.type = 'P'							-- usually just process one object type at a time 
	--and so.type = 'U'
	--and so.type = 'V'
	--And so.name != d.RootName
	--And so.name != ''			-- Wilco
	--And so.name != ''			-- Wilco
	--And so.name != ''			-- Wilco
Order By
	d.RootName
	,so.name

-- Select count(*) from Sys.objects where type = 'P'
