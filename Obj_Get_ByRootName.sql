/*
	This query finds database objects by type (procedure, Table, function, ...)
	That have names that have a root match and differ in the suffix.
	The root is everthing before the last "_" in the object name.
	If the object name does not have an "_" it is ignored.
	The CTE and the Select where clauses need to be "customized" to narrow down the results.
	Some object types are excluded, e.g., Foreign and Primary keys, Constraints, Triggers, CLR Assemblies, ...

	Note: this script will return both false positives and may miss duplicates.  This approach only finds
	Duplicate objects where the suffix is used to make the duplicate.
		E.g. Proc_name, Proc_name_Old, Proc_name_Old1.
	The logic keys on an "_" in the object name.
	
	$Workfile: Objects_Get_ByRootName.sql $
	$Archive: /SQL/QueryWork/Objects_Get_ByRootName.sql $
	$Revision: 3 $	$Date: 14-04-18 17:22 $

	ConSIRN - 3277 total objects, 2465 Procedures
		597 candidate duplicate objects, ~565 procedures
	Wilco	- 3012 total objects, 2389 Procedures
		382 candidate duplicate objects, ~370 Procedures
*/
/*
Select	so.type, [Count] = COUNT(*)
From sys.objects as so
Where
	so.is_ms_shipped = 0
	and so.type in ('FN', 'IF', 'P', 'TF', 'U', 'V')
group by so.type
order by so.type;
*/

;With theDupes As (
	Select
		[RootName] = Reverse(substring(reverse(so.name), charIndex('_', reverse(so.name)) + 1, len(so.name) + 1))
		, [Type] = so.type
		,[NumDupes] = count(*)
	From
		sys.objects as so
	Where 1 = 1
		and so.name not like 'zDrop_%'						-- don't look at objects already in the drop process
		and so.type in ('FN', 'IF', 'P', 'TF', 'U', 'V')
		and charindex('_', so.name, 1) > 0					-- must have "_" in name
		and so.name not like 'dt\_%' Escape '\'
	Group By
		Reverse(substring(reverse(so.name), charIndex('_', reverse(so.name)) + 1, len(so.name) + 1))
		,so.type
	Having
		count(*) > 1
	--Order By [RootName]--so.name
	)
Select Distinct
	[Root Name] = d.RootName
	--,[Duplicate Name] = so.name
	,[Type] = so.type
	--,[Root Id] = object_Id(d.RootName, d.type)
	--,[Dupe Id] = so.object_Id
From
	sys.Objects as so
	inner join theDupes as d
		on so.name like d.rootname + '\_%' Escape '\'
		and so.type = d.type
Where 1 = 1
	And so.type in ('FN', 'IF', 'P', 'TF', 'U', 'V')
	And object_Id(d.RootName, d.type) is not null		-- make sure the root name is actually an object
	And so.name != d.RootName							-- But don't list the root as a duplicate
Order By
	so.Type
	,d.RootName
	--,so.name
