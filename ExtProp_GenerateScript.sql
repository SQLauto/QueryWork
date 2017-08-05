 /*
 Auto Generate Your Database Documentation
 http://www.sqlservercentral.com/articles/Extended+Property/137761/
Name:
(C) Andy Jones
mailto:andrew@aejsoftware.co.uk

Example usage: -

Connect SSMS to the database in which you wish to create extended properties and hit F5.

Description: -
This script will not create the extended properties, but auto generate the commands to do so.
The actual value (@value parameter) of the extended property still has to be manually input.
This script will automatically add the user and date to the extended property value.

	Change History: -
	1.0 25/11/2015 Created.
	$Archive: /SQL/QueryWork/ExtProp_GenerateScript.sql $
	$Revision: 1 $	$Date: 16-03-07 9:03 $

*/
 If Object_Id('tempdb..#Parameter', 'U') Is Not Null
	Drop Table #Parameter;
Go
Declare @extPropName	NVarchar(128) = N'Sim_Description'

Create Table #Parameter (
	type_desc sysname Not Null
	, parameter sysname Not Null
	, val NVarchar(512) Not Null
	, Primary Key Clustered (type_desc, parameter)
	);


/*set up the data for each object type specifying the correct value for each parameter.*/
 Insert	Into #Parameter (type_desc, parameter, val)
 Values	(N'CHECK_CONSTRAINT', N'value', N'_replace_value'),
		(N'CHECK_CONSTRAINT', N'level0type', N'SCHEMA'),
		(N'CHECK_CONSTRAINT', N'level0name', N'_replace_schemaname'),
		(N'CHECK_CONSTRAINT', N'level1type', N'TABLE'),
		(N'CHECK_CONSTRAINT', N'level1name', N'_replace_parentname'),
		(N'CHECK_CONSTRAINT', N'level2type', N'CONSTRAINT'),
		(N'CHECK_CONSTRAINT', N'level2name', N'_replace_name'),
		(N'FOREIGN_KEY_CONSTRAINT', N'value', N'_replace_value'),
		(N'FOREIGN_KEY_CONSTRAINT', N'level0type', N'SCHEMA'),
		(N'FOREIGN_KEY_CONSTRAINT', N'level0name', N'_replace_schemaname'),
		(N'FOREIGN_KEY_CONSTRAINT', N'level1type', N'TABLE'),
		(N'FOREIGN_KEY_CONSTRAINT', N'level1name', N'_replace_parentname'),
		(N'FOREIGN_KEY_CONSTRAINT', N'level2type', N'CONSTRAINT'),
		(N'FOREIGN_KEY_CONSTRAINT', N'level2name', N'_replace_name'),
		(N'PRIMARY_KEY_CONSTRAINT', N'value', N'_replace_value'),
		(N'PRIMARY_KEY_CONSTRAINT', N'level0type', N'SCHEMA'),
		(N'PRIMARY_KEY_CONSTRAINT', N'level0name', N'_replace_schemaname'),
		(N'PRIMARY_KEY_CONSTRAINT', N'level1type', N'TABLE'),
		(N'PRIMARY_KEY_CONSTRAINT', N'level1name', N'_replace_parentname'),
		(N'PRIMARY_KEY_CONSTRAINT', N'level2type', N'CONSTRAINT'),
		(N'PRIMARY_KEY_CONSTRAINT', N'level2name', N'_replace_name'),
		(N'UNIQUE_CONSTRAINT', N'value', N'_replace_value'),
		(N'UNIQUE_CONSTRAINT', N'level0type', N'SCHEMA'),
		(N'UNIQUE_CONSTRAINT', N'level0name', N'_replace_schemaname'),
		(N'UNIQUE_CONSTRAINT', N'level1type', N'TABLE'),
		(N'UNIQUE_CONSTRAINT', N'level1name', N'_replace_parentname'),
		(N'UNIQUE_CONSTRAINT', N'level2type', N'CONSTRAINT'),
		(N'UNIQUE_CONSTRAINT', N'level2name', N'_replace_name'),
		(N'SQL_STORED_PROCEDURE', N'value', N'_replace_value'),
		(N'SQL_STORED_PROCEDURE', N'level0type', N'SCHEMA'),
		(N'SQL_STORED_PROCEDURE', N'level0name', N'_replace_schemaname'),
		(N'SQL_STORED_PROCEDURE', N'level1type', N'PROCEDURE'),
		(N'SQL_STORED_PROCEDURE', N'level1name', N'_replace_name'),
		(N'SQL_STORED_PROCEDURE', N'level2type', N'NULL'),
		(N'SQL_STORED_PROCEDURE', N'level2name', N'NULL'),
		(N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'value', N'_replace_value'),
		(N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'level0type', N'SCHEMA'),
		(N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'level0name', N'_replace_schemaname'),
		(N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'level1type', N'FUNCTION'),
		(N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'level1name', N'_replace_name'),
		(N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'level2type', N'NULL'),
		(N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'level2name', N'NULL'),
		(N'SQL_SCALAR_FUNCTION', N'value', N'_replace_value'),
		(N'SQL_SCALAR_FUNCTION', N'level0type', N'SCHEMA'),
		(N'SQL_SCALAR_FUNCTION', N'level0name', N'_replace_schemaname'),
		(N'SQL_SCALAR_FUNCTION', N'level1type', N'FUNCTION'),
		(N'SQL_SCALAR_FUNCTION', N'level1name', N'_replace_name'),
		(N'SQL_SCALAR_FUNCTION', N'level2type', N'NULL'),
		(N'SQL_SCALAR_FUNCTION', N'level2name', N'NULL'),
		(N'USER_TABLE', N'value', N'_replace_value'),
		(N'USER_TABLE', N'level0type', N'SCHEMA'),
		(N'USER_TABLE', N'level0name', N'_replace_schemaname'),
		(N'USER_TABLE', N'level1type', N'TABLE'),
		(N'USER_TABLE', N'level1name', N'_replace_name'),
		(N'USER_TABLE', N'level2type', N'NULL'),
		(N'USER_TABLE', N'level2name', N'NULL'),
		(N'INDEX', N'value', N'_replace_value'),
		(N'INDEX', N'level0type', N'SCHEMA'),
		(N'INDEX', N'level0name', N'_replace_schemaname'),
		(N'INDEX', N'level1type', N'TABLE'),
		(N'INDEX', N'level1name', N'_replace_parentname'),
		(N'INDEX', N'level2type', N'INDEX'),
		(N'INDEX', N'level2name', N'_replace_name'),
		(N'COLUMN', N'value', N'_replace_value'),
		(N'COLUMN', N'level0type', N'SCHEMA'),
		(N'COLUMN', N'level0name', N'_replace_schemaname'),
		(N'COLUMN', N'level1type', N'TABLE'),
		(N'COLUMN', N'level1name', N'_replace_parentname'),
		(N'COLUMN', N'level2type', N'COLUMN'),
		(N'COLUMN', N'level2name', N'_replace_name');


/*union all objects on which to create extended properties. Objects, columns and indexes.*/ 
;With Obj As (
	Select	parentname = Coalesce(Object_Name(obj.parent_object_id), obj.name), name = obj.name,
			schemaname = Schema_Name(obj.schema_id), type_desc = obj.type_desc, major_id = obj.object_id, minor_id = 0,
			class_desc = N'OBJECT_OR_COLUMN'
	From	sys.objects As obj
	Where	obj.is_ms_shipped = 0
	Union All
	Select	parentname = Object_Name(c.object_id), name = c.name, schemaname = Object_Schema_Name(c.object_id),
			type_desc = N'COLUMN', major_id = c.object_id, minor_id = c.column_id, class_desc = N'OBJECT_OR_COLUMN'
	From	sys.columns As c
	Where	ObjectPropertyEx(c.object_id, 'IsMSShipped') = 0
			And ObjectPropertyEx(c.object_id, 'IsUserTable') = 1 --only document table columns, not views/functions. Remove predicate if required.
	Union All
	Select	parentname = Object_Name(i.object_id), name = i.name, schemaname = Object_Schema_Name(i.object_id),
			type_desc = N'INDEX', major_id = i.object_id, minor_id = i.index_id, class_desc = N'INDEX'
	From	sys.indexes As i
	Where	ObjectPropertyEx(i.object_id, 'IsMSShipped') = 0
			And i.is_primary_key = 0 --the constraint is already documented, don't document the index too. Remove predicate if required.
			And i.is_unique_constraint = 0 --the constraint is already documented, don't document the index too. Remove predicate if required.
			And i.type_desc <> N'HEAP' --the table is already documented, don't document the heap index row too.
	)
, Parameter_Value As (
	Select o.major_id, o.minor_id, o.class_desc, p.parameter, name = @extPropName,
			val = Case p.val
					When N'_replace_schemaname' Then o.schemaname
					When N'_replace_parentname' Then o.parentname
					When N'_replace_name' Then o.name
					When N'_replace_value'
					Then System_User + N' ' + Convert(Char(10), Current_Timestamp, 103) + N': ' + p.val
					Else p.val
				  End
	From #Parameter As p
			Inner Join Obj As o
				On o.type_desc = p.type_desc Collate Database_Default
	)

/*Join objects on which to create extended properties to the parameters, performing string replacement where necessary.*/
/*pivot the result set so we have one correctly formatted extended property create statement per object.*/
Select Add_Extended_Property = N'EXECUTE sp_addextendedproperty' + N' @name = ''' + name
		+ N''', @value = ' + value + N', @level0type = ' + level0type + N', @level0name = ' + level0name
		+ N', @level1type = ' + level1type + N', @level1name = ' + level1name + N', @level2type = ' + level2type
		+ N', @level2name = ' + level2name + N';'
From (Select pv.major_id
			, pv.minor_id
			, pv.class_desc
			, pv.name
			, pv.parameter
			, val = Case pv.val
					When N'NULL' Then pv.val
					Else '''' + pv.val + ''''
					End
		From Parameter_Value As pv
		Where Not Exists (Select *
							From sys.extended_properties As ep
							Where ep.major_id = pv.major_id
								And ep.minor_id = pv.minor_id
								And ep.class_desc = pv.class_desc
								And ep.name = pv.name )
		) As SourceTable
Pivot (Min(val) For parameter In (value, level0type, level0name, level1type, level1name, level2type, level2name) ) As PivotTable
Order By Add_Extended_Property;
