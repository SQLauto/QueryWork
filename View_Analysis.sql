

Declare
	@ViewChain	VARCHAR(4000)
	,@DbName	VARCHAR(128)
	,@TopView	VARCHAR(128)
	,@TopViewId	int
	;

Declare c_Tops cursor local FAST_FORWARD For
	Select
		sv.Id, sv.vName, sv.vDatabase
	From
		dbo.SimmonsViews as sv
	Where 1 = 1
		and sv.vName like '%PanelActive%'
		--and sv.isDirty = 0
		--and sv.isUsed = 0
	;
Open c_Tops;
While 1 = 1
Begin	 -- Process Each View Chain
	Fetch Next from c_Tops Into @topViewId, @TopView, @DbName
	If @@FETCH_STATUS != 0 Break;
	Set @ViewChain = @DbName + '..' + @TopView + ' - ' + char(10);

	Select
		@ViewChain = @ViewChain + char(9) + '-' + sv.vname + char(10)
	From
		dbo.SimmonsViewTree as vt
		inner join dbo.SimmonsViews as sv
			on sv.id = vt.ChildView
	Where
		vt.parentView = @topViewId
	;
	Print @ViewChain;
End	 -- Process Each View Chain
If cursor_status('local', 'c_Tops') > -1 Close c_Tops;
If cursor_status('local', 'c_Tops') > -2 Deallocate c_Tops;
Return
-- I want a list of all the views called by the second level views in a specified top level view
;With Firstlevel as(
	Select
		svt.childview
		,sv.vName
	From dbo.SimmonsViewTree as svt
		inner join dbo.SimmonsViews as sv
			on sv.id = svt.childview
	Where svt.ParentView = (select sv1.id from dbo.SimmonsViews as sv1 where sv1.vName = 'vw_PanelActiveDynamicsales')
	)
Select
	*
from dbo.SimmonsViewTree as svt
	inner join Firstlevel as fl
		on fl.childView = svt.parentview
	inner join dbo.SimmonsViews as sv2
		on sv2.id = svt.childView
where 1 = 1
	--and isused = 0
	--and isdirty = 0
--order by vname, vDatabase