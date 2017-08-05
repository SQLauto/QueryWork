Use zDBA_Info
Go
/*
INSERT INTO zDBA_Info.dbo.SimmonsViews(
	vServer, vDatabase, vName, vObjId, isDirty)
	Select
		@@ServerName
		,'Wilco'
		,so.Name
		,so.object_id
		,0
	From
		Wilco.sys.objects as so
	Where
		so.type = 'V'

--	Delete dbo.SimmonsViews

--	DBCC CheckIdent ([dbo.SimmonsViews], Reseed)

--	Select * From dbo.SimmonsViews as sv

*/
	
Declare
	@Debug				INT
	,@CV_Id				Int
	,@DatabaseName		VARCHAR(128)
	,@ObjectId			Int
	,@ServerName		Varchar(128)
	,@ChildViewName		Varchar(128)
	,@ParentViewName	VARCHAR(128)
	,@chrEscape			Char(1)
	;
Set @chrEscape = N'\';

-- Get Each View from table and see if it is referenced in any other view.
Declare v_cursor cursor local forward_only for
	Select sv.vname, sv.vDatabase, sv.vServer, sv.vObjId, sv.Id
	from
		zDBA_Info.dbo.SimmonsViews as sv
	Where 1 = 1
		--and sv.vName = 'vw_FuelType'
		--and sv.vDatabase = 'ConSIRN'
		and sv.vDatabase = 'Wilco'
		and sv.vServer = 'Dev2008R2\S2008R2EE'
	;

Open v_cursor;
While 1 = 1
Begin	 -- process each view
	-- Find all of the  views that reference this view.
	Fetch Next From v_cursor into @ChildViewName, @DatabaseName, @ServerName, @ObjectId, @CV_Id;
	If @@FETCH_STATUS != 0 Break;
	;With theParents as (
		SELECT
			[ServerName]	= @ServerName
			,[DBName]		= @DatabaseName
			,[PV_Name]		= sv.vName
			,[PV_ObjId]		= sv.vObjId
			,[PV_Id]		= sv.Id
		FROM zDBA_Info.dbo.SimmonsViews as sv
			--INNER JOIN Consirn.sys.sql_modules as sm
			INNER JOIN Wilco.sys.sql_modules as sm
				ON sv.vObjId = sm.object_id
		Where 1 = 1
			and sm.definition like '%' + @ChildViewName + '%' Escape @chrEscape
			and sv.vName != @ChildViewName
		)
	Insert Into zDBA_Info.dbo.SimmonsViewTree (ParentView, ChildView)
	Select
		PV_Id
		,@CV_Id
	From theParents
	;
End	-- While Process Each View
If cursor_status('local', 'v_cursor') > -1 Close v_cursor;
If cursor_status('local', 'v_cursor') > -2 Deallocate v_cursor;

Select
	svt.ParentView
	,svp.vName
	,svt.ChildView
	,svc.vName
From zDBA_Info.dbo.SimmonsViewTree as svt
	inner join dbo.SimmonsViews as svp
		on svt.parentView = svp.id
	inner join dbo.SimmonsViews as svc
		on svt.ChildView = svc.id
order By
	svt.ParentView
	,svt.ChildView
	
Return;

--	Select * From dbo.SimmonsViews --where vdatabase = 'ConSIRN'
--	Delete zDBA_Info.dbo.SimmonsViewTree
-- DBCC CheckIdent ([dbo.SimmonsViewTree], Reseed, 1)
;With theCount As (
	Select [theCount] = count(*), ParentView
	From dbo.SimmonsViewTree as vt
	Group by ParentView
	)
Update sv
	set sv.isDirty = theCount
From
	SimmonsViews as sv
	inner join theCount as tc
	on sv.Id = tc.parentView


;With theCount As (
	Select [theCount] = count(*), ChildView
	From dbo.SimmonsViewTree as vt
	Group by ChildView
	)
Update sv
	set sv.isUsed = theCount
From
	SimmonsViews as sv
	inner join theCount as tc
	on sv.Id = tc.ChildView
	
Select
	sv.vDatabase
	,sv.vname
	,[# Called] = sv.isDirty
	,[# Used By] = sv.isUsed
From
	dbo.SimmonsViews as sv
Where
	sv.isDirty >= 5
	or sv.isUsed >= 5
Order By
	sv.vDatabase
	,sv.vname