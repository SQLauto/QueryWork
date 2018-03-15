/*
	This script will find the Object Name, Object Type and Object Definition
	for objects in the current database whose definition contains @strSearch1

	$Workfile: Obj_Get_WithStrInDefinition.sql $
	$Archive: /SQL/QueryWork/Obj_Get_WithStrInDefinition.sql $
	$Revision: 17 $	$Date: 9/12/17 11:35a $

*/
If Object_Id('tempdb..#theRefs', 'U') Is Not Null
	Drop Table #theRefs;
If Object_Id('tempdb..#theStrings', 'U') Is Not Null
	Drop Table #theStrings;
Go
Set NoCount On;
Set Transaction Isolation Level Read Uncommitted;
Create Table #theStrings(strSearch	Varchar(50));
Create Table #theRefs(
	DBName				NVarchar(128)
	, oSchema			NVarchar(128)
	, oName				NVarchar(128)
	, oType				NVarchar(128)
	, FirstOccurrence	NVarchar(Max)
	, ObjDef_500		NVarchar(Max)
	);

Insert #theStrings(strSearch)
	Values ('BoxScoreDM')
		, ('BP.'), ('ClvRawData'), ('ConSIRN')
		, ('Custs.'), ('DotNetNuk2'), ('MultiDispatch')
		, ('PI_ProfileStore.'), ('SIR'), ('SIR25')
		, ('Utility.'), ('Wilco')--, ('')
		;
Declare
	@strSearch1		Varchar(50) = ''
	, @chrEscape		Char(1) = N'\'
	, @strSearch2	Varchar(50) = ''
	, @strExclude	Varchar(50) = ''
	, @CR			NChar(1) = NChar(13)
	, @LF			NChar(1) = NChar(10)
	, @Tab			NChar(1) = NChar(9)
	;
Insert Into #theRefs(DBName, oSchema, oName, oType, FirstOccurrence, ObjDef_500)
SELECT
	db_name()
	, Schema_name(so.schema_id)
	, so.name
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
	, Replace(Replace(Replace(
		substring(sm.definition, charindex(@strSearch1, sm.definition, 1) - 75, 300)
		, @LF, ' '), @CR, ' '), @Tab, ' ')
	, Replace(Replace(Replace(Substring(sm.definition, 1, 512), @LF, ' '), @CR, ' '), @Tab, ' ')
From sys.objects as so
	INNER JOIN sys.sql_modules as sm
		ON so.object_id = sm.object_id
Where 1 = 1
	and (sm.definition like '%' + @strSearch1 + '%' Escape @chrEscape
		And (Len(@strSearch2) = 0		-- if @strSearch2 specified then both must be present.
			Or sm.definition like '%' + @strSearch2 + '%' Escape @chrEscape)
		)
	And so.name not like 'zDrop_%'
	And so.name != @strSearch1		-- Exclude the actual definition of the object
	And so.schema_id != Coalesce(Schema_Id('zDrop'), -1)
	--and sm.definition not like '%' + @strExclude + '%' Escape @chrEscape
	and so.type in ( 'FN', 'IF', 'P', 'TF', 'TR', 'V')	-- Executables Scalar Function, Inline Function, procedure, Table Function, Trigger
	--and so.type = 'P'
	--and so.type = 'TR'		-- Trigger

-- Add Table Columns
Union All
Select
	db_name()
	, Schema_name(so.schema_id)
	, so.name + '.' + sc.name
	, 'Column'
	, st.name
	, ''
From Sys.columns As sc
	Inner Join sys.objects As so On so.object_id = sc.object_id
	Inner Join sys.types As st On st.user_type_id = sc.user_type_id
Where 1 = 1
	and (sc.name like '%' + @strSearch1 + '%' Escape @chrEscape
		--and sc.name like '%' + @strSearch2 + '%' Escape @chrEscape
		)
	And so.schema_id != Coalesce(Schema_Id('zDrop'), -1)


Select DBName, oSchema, oName, oType, FirstOccurrence, ObjDef_500
From #theRefs
Order By
	oType 
	, oName
;
Return;

--	Create a working table to receive the results for later processing.
/*
/*
	CREATE TABLE zDBAInfo.dbo.StringRefs(
		Id int IDENTITY(1, 1) NOT NULL
		, DBName nvarchar(128)
		, oSchema nvarchar(128)
		, oName nvarchar(128)
		, oType nvarchar(128)
		, FirstOccurrence nvarchar(512)
		, ObjDef_500 nvarchar(512)
		, CONSTRAINT PK_StringRefs PRIMARY KEY CLUSTERED (Id ASC)
			With (FILLFACTOR = 100) ON [Default]
	) ON [Default]
*/

--	Truncate Table zDBAInfo.dbo.ComputeByRefs
Insert zDBAInfo.dbo.StringRefs(DBName, oSchema, oName, oType, FirstOccurrence, ObjDef_500)
	Select DBName, oSchema, oName, oType, FirstOccurrence, ObjDef_500
	From #theRefs;

*/

