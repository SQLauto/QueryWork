/*
	Snippets to help restore an object from zDrop to its original state

	$Archive: /SQL/QueryWork/Obj_zDrop_Restore.sql $
	$Date: 15-10-22 14:42 $	$Revision: 2 $
*/

Select * From dbo.CLVDBDocumentation As cd Where cd.name Like 'S200_DVNDException%'

--	Exec sp_rename '[zDrop].[S2003DVNDException]', S2003DVNDException_20151007


--	Alter Schema zDrop Transfer object::[dbo].[S2003DVNDException]
/*

Update dbo.CLVDBDocumentation Set
	 UsedInProcessing = 'Not Used'
	, TargetDB = 'N/A'
	, Comment = 'reDropped - Moved to zDrop.S2003DVNDException_20151007 by <RBH>.'
	, Schema_id = schema_Id('zDrop')
	, is_zDrop = 1
	, status = 'zDropped'
	, LastUpdate = GetDate()
Where name = 'S2003DVNDException'

*/
-- Delete dbo.CLVDBDocumentation

/*
If Object_Id('tempdb..#CLVDBDocumentation', 'U') Is Not Null Drop Table #CLVDBDocumentation;
Create Table #CLVDBDocumentation (
	  Name Varchar(255) Not Null
	, Type Varchar(50) Not Null
	, Category Int Null
	, UsedInProcessing Varchar(255) Null
	, TargetDB Varchar(255) Null
	, Comment Varchar(255) Null
	, Schema_id Int Not Null
	, is_zDrop Int Null
	, status Varchar(50) Null
	, LastUpdate DateTime Null
	, Constraint Pk_CLVDBDocumentation Primary Key Clustered
		(Name Asc, Schema_id Asc, Type Asc)
		With (Pad_Index = Off, Statistics_Norecompute = Off,
			  Ignore_Dup_Key = Off, Allow_Row_Locks = On,
			  Allow_Page_Locks = On, FillFactor = 85) On ConSIRN_Data_FG_C
	)
*/


