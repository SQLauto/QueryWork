
/*
	This script finds both referenced and referencing objects for a specified <schema.object>
	Schema is required.
	Caution, this will only find "persisted" references.  It will not find dynamic sql references regardless
	of the server name and it will not find references from a linked server.
	It will find references to a linked server.

	$Archive: /SQL/QueryWork/Obj_RefsfBydm_sql_ref.sql $
	$Revision: 2 $	$Date: 16-06-15 9:14 $

*/

Declare @theObject	Varchar(256)	= ''		-- schema.name e.g 'dbo.vw_PanelActive'
	, @theType		Varchar(50)		= 'object'
	, @isExcludezDrop	Bit	= 0		-- 0 = Include zDropm 1 = Exclude zDrop
	
Select
	' Is Referenced By - '
	, [Server] = 'N/A'
	, [Database] = 'N/A'
	, [Schema] = Coalesce(re.referencing_schema_name, 'Not Specified')
	, [Obj Name] = re.referencing_entity_name
	, [Obj Type] = so.type_desc
	, [Column] = 'N/A'
	, [CallerDep] = 'N/A'
	, [Ambiguous] = 'N/A'
From
	sys.dm_sql_referencing_entities(@theObject, @theType) As re
	Inner Join sys.objects As so
		On so.object_id = re.referencing_id
Where 1 = 1
	And 1 = Case
				When re.referencing_schema_name != 'zDrop' Then 1
				When @isExcludezDrop = 1 And re.referencing_schema_name = 'zDrop' Then 0
				Else 1
				End
Union All
Select
	' References - '
	, [Server] = Coalesce(re.referenced_server_name, 'Not Specified')
	, [Database] = Coalesce(re.referenced_database_name, 'Not Specified')
	, [Schema] = Coalesce(re.referenced_schema_name, 'Not Specified')
	, [Obj Name] = re.referenced_entity_name
	, [Obj Type] = so.type_desc
	, [Column] = Coalesce(re.referenced_minor_name, 'N/A')
	, [CallerDependent] = Case When re.is_caller_dependent = 1 Then 'Yes' Else 'No' End
	, [AmbiguousRef] = Case When re.is_ambiguous = 1 Then 'Yes' Else 'No' End
From
	sys.dm_sql_referenced_entities(@theObject, @theType) As re
	Inner Join sys.objects As so
		On so.object_id = re.referenced_id
Where 1 = 1
	And 1 = Case
				When re.referenced_schema_name != 'zDrop' Then 1
				When @isExcludezDrop = 1 And re.referenced_schema_name = 'zDrop' Then 0
				Else 1
				End
Return;
/*
	Phil Factor on Simple Talk
	Automatically Creating UML Database Diagrams for SQL Server
	https://www.simple-talk.com/sql/sql-tools/automatically-creating-uml-database-diagrams-for-sql-server/?utm_source=simpletalk&utm_medium=pubemail&utm_content=uml-diagrams-20160523&utm_campaign=sql&utm_term=simpletalkmain


*/
DECLARE @object_ID INT
SELECT @Object_ID=object_id('HumanResources.vEmployeeDepartmentHistory')
SELECT coalesce(object_schema_name(referencing_ID)+'.','')
     + object_name(referencing_ID) +' --|> '
       + referenced_schema_name+'.'+Referenced_Entity_name
       + ':References'
           --AS reference
FROM sys.sql_expression_dependencies
    WHERE (referencing_id =@object_ID
       OR referenced_ID = @object_ID)
      AND is_schema_bound_reference =0
       and referenced_ID is not null
UNION ALL
SELECT coalesce(object_schema_name(parent_object_ID)+'.','')
    + object_name(parent_object_ID) + ' --|> '
       + coalesce(object_schema_name(referenced_object_ID)+'.','')
       + object_name(referenced_object_ID)+':FK'
FROM sys.foreign_keys
    WHERE parent_object_ID = @object_ID
      OR referenced_object_ID = @object_ID
 