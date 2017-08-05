/*
Are You Programming In The Database?
http://michaeljswart.com/2016/04/are-you-programming-in-the-database/

This script will return a list of procedures that call other procedures and the names of the procedures they call.
	$Archive: /SQL/QueryWork/obj_Procedure_CallsProcedure.sql $
	$Revision: 1 $	$Date: 16-05-12 14:11 $
*/
Begin Try
	Select	[Schema] = Object_Schema_Name(p.object_id)
		, [Proc] = p.name	--Object_Name(p.object_id)
		--, [External Calls] = Count(*)
		, re.referenced_server_name
		, re.referenced_database_name
		, re.referenced_schema_name
		, re.referenced_entity_name
		, re.referenced_class
		, re.referenced_class_desc
	From sys.procedures As p
		Cross Apply sys.dm_sql_referenced_entities(Schema_Name(p.schema_id) + '.' + p.name, 'OBJECT') As re
	Where 1 = 1
		And re.referenced_entity_name In (Select name From sys.procedures)
		And p.schema_id != Schema_Id('zDrop')
	--Group By p.object_id
	--Order By Count(*) Desc;
End Try
Begin Catch
	Declare
		@ErrMsg	NVarchar(4000) = Error_Message()
		, @ErrNum	Integer	= Error_Number()
	;
	Raiserror('Failed. Original Error Number = %d.  Error Message = %s', 0, 0, @ErrNum, @ErrMsg)
End Catch
Return;
Go

Begin Try
	Select Distinct
		[This procedure...] = QuoteName(Object_Schema_Name(p.object_id)) + '.' + QuoteName(Object_Name(p.object_id))
		, [... calls this procedure] = QuoteName(Object_Schema_Name(p_ref.object_id)) + '.' + QuoteName(Object_Name(p_ref.object_id))
	From sys.procedures p
		Cross Apply sys.dm_sql_referenced_entities(Schema_Name(p.schema_id) + '.' + p.name, 'OBJECT') re
		Join sys.procedures p_ref
			On re.referenced_entity_name = p_ref.name
	Where 1 = 1
			And p.schema_id != Schema_Id('zDrop')
	Order By [This procedure...], [... calls this procedure];

End Try
Begin Catch
	Declare
		@ErrMsg	NVarchar(4000) = Error_Message()
		, @ErrNum	Integer	= Error_Number()
	;
	Raiserror('Failed. Original Error Number = %d.  Error Message = %s', 0, 0, @ErrNum, @ErrMsg)
End Catch
Return;
Go

/*
	Object Referenced By Objects
*/

Declare
	@tgtSchema		NVarchar(128) = N'dbo'
	, @tgtObject	NVarchar(128) = N'FSM#WayneSalesIns'

Select tgt.*
From
	sys.dm_sql_referenced_entities(@tgtSchema + '.' + @tgtObject, 'OBJECT') As tgt
Where 1 = 1
