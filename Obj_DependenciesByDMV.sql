/*
	Snippets to determine object relationships in a database
	SQL database refactoring – Finding and updating internal references
	- See more at: http://solutioncenter.apexsql.com/sql-database-refactoring-finding-and-updating-internal-references/#sthash.75DbwBbI.dpuf
	TSQL: Schema-Bound dependency
	https://baakal.wordpress.com/2014/07/20/tsql-schema-bound-dependency/
	$Archive: /SQL/QueryWork/Obj_DependenciesByDMV.sql $
	$Revision: 3 $	$Date: 17-02-10 10:04 $

	Both Views and functions are available.  There is some overlap and some omission which means neither is wholly sufficient :( for the task.

*/
If Object_Id('tempdb..#theData', 'U') Is Not Null Drop Table tempdb..#theData;
Go
	
Declare
	@RefObjName		NVarchar(128) = N'fn_TSCIALLwithTempLoss'
	, @RefObjSchema	NVarchar(128) = N'dbo'
	;

Create Table #theData(
	referencing_id				Int Not Null
	, referencing_object_schema	Sysname
	, referencing_object_name	Sysname
	, referencing_object_type	Sysname
	, referencing_minor_id		Int Not Null
	, referencing_class			TinyInt	Not Null
	, referencing_class_desc	NVarchar(60) Not Null
	, is_schema_bound_reference	Bit	Not Null
	, referenced_class			TinyInt	Not Null
	, referenced_class_desc		NVarchar(60) Not Null
	, referenced_server_name	Sysname Null
	, referenced_database_name	Sysname Null
	, referenced_schema_name	Sysname Null
	, referenced_entity_name	Sysname Null
	, referenced_id				Int Null
	, referenced_minor_id		Int Not Null
	, is_caller_dependent		Bit Not Null
	, is_ambiguous				Bit Not Null

	)
Select
	[Obj Schema] = Schema_Name(so.schema_id)
	, [Obj Name] = so.name
	, [Obj Type] = Case so.type
			When 'C' Then 'Check'
			When 'D' Then 'Default'
			When 'FN' Then 'Scalar Fn'
			When 'IF' Then 'Inline Fn'
			When 'P' Then 'SProc'
			When 'TF' Then 'TV Fn'
			When 'TR' Then 'Trigger'
			When 'U' Then 'Table'
			When 'V' Then 'View'
			Else Substring(so.type_desc, 1, 10) End
	--, [Ref Class] = sed.referenced_class_desc
	, [isSchemaBound] = Case sed.is_schema_bound_reference When 0 Then 'No' Else 'Yes' End
	--, sed.* 
From sys.sql_expression_dependencies As sed
	Left Outer Join sys.objects As so
		On so.object_id = sed.referencing_id
Where 1 = 1
	And sed.referenced_id = Object_Id(@RefObjSchema + N'.' + @RefObjName)
Order By
	[Obj Type]
	, [Obj Schema]
	, [Obj Name]

Insert #theData(referencing_id, referencing_object_schema, referencing_object_name, referencing_object_type
	, referencing_minor_id, referencing_class, referencing_class_desc, is_schema_bound_reference, referenced_class
	, referenced_class_desc, referenced_server_name, referenced_database_name, referenced_schema_name
	, referenced_entity_name, referenced_id, referenced_minor_id, is_caller_dependent, is_ambiguous
	)
Select sed.referencing_id, SCHEMA_NAME(so.schema_id), so.name
	, Case so.type
			When 'C' Then 'Check'
			When 'D' Then 'Default'
			When 'FN' Then 'Scalar Fn'
			When 'IF' Then 'Inline Fn'
			When 'P' Then 'SProc'
			When 'TF' Then 'TV Fn'
			When 'TR' Then 'Trigger'
			When 'U' Then 'Table'
			When 'V' Then 'View'
			Else Substring(so.type_desc, 1, 10) End
	, sed.referencing_minor_id, sed.referencing_class, sed.referencing_class_desc, sed.is_schema_bound_reference
	, sed.referenced_class, sed.referenced_class_desc, sed.referenced_server_name, sed.referenced_database_name, sed.referenced_schema_name
	, sed.referenced_entity_name, sed.referenced_id, sed.referenced_minor_id, sed.is_caller_dependent, sed.is_ambiguous
From sys.sql_expression_dependencies As sed
	Left Outer Join sys.objects As so
		On so.object_id = sed.referencing_id
Where 1 = 1
	And sed.referenced_id = Object_Id(@RefObjSchema + N'.' + @RefObjName)

Select
	[Obj Schema] = referencing_object_schema
	, [Obj Name] = referencing_object_name
	--, [Obj Id] = referencing_id
	, [Obj Type] = referencing_object_type
	--, referencing_minor_id
	, [IsScheamBound] = Case When is_schema_bound_reference = 1 Then 'Y' Else 'N' End
	--, referencing_class, referencing_class_desc, referenced_class, referenced_class_desc
	, [Refed Server] = referenced_server_name
	, [Refed DB] = referenced_database_name
	, [Refed Schema] = referenced_schema_name
	, [Refed Obj] = referenced_entity_name
	, [Ref ObjId] = referenced_id
	--, referenced_minor_id
	, [isCallerDep] = Case is_caller_dependent When 1 Then 'Y' When 0 Then 'N' Else 'Unk' End
	, [isAmbig] = Case is_ambiguous When 1 Then 'Y' When 0 Then 'N' Else 'Unk' End
From #theData;

--	sys.dm_sql_referenced_entities
--	sys.dm_sql_referencing_entities

--	To get a list of Schema-Bound Dependency of an object use the following script:

Select referencing_id, referencing_schema_name, referencing_entity_name, referencing_class_desc
From sys.dm_sql_referencing_entities (@RefObjSchema + N'.' + @RefObjName, 'OBJECT')
Where ObjectProperty(referencing_id, 'IsSchemaBound') = 1;