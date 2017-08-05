/*


	$Workfile: Objects_Count_ByType.sql $
	$Archive: /SQL/QueryWork/Objects_Count_ByType.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $
*/
Select
	so.type_desc
	,[Count] = count(so.object_id)
From
	sys.objects as so
Where 1 = 1
	and so.is_ms_shipped != 1
	and so.is_published != 1
	and so.is_schema_published != 1
Group By
	so.type_desc

/*
Object Type						WilcoR2.Wilco		SQL2008R2.Consirn
CHECK_CONSTRAINT					199				76	
CLR_SCALAR_FUNCTION					1				1
CLR_STORED_PROCEDURE				0				3	
DEFAULT_CONSTRAINT					742				556
FOREIGN_KEY_CONSTRAINT				4				9	
PRIMARY_KEY_CONSTRAINT				302				415
SQL_INLINE_TABLE_VALUED_FUNCTION	0				2	
SQL_SCALAR_FUNCTION					16				47	
SQL_STORED_PROCEDURE				2315			2467
SQL_TABLE_VALUED_FUNCTION			11				89	
SQL_TRIGGER							185				134	
UNIQUE_CONSTRAINT					5				16
USER_TABLE							499				620
VIEW								48				106
												
*/	

Select * From sys.numbered_procedures