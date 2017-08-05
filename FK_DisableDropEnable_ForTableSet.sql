/*
	For a set of tables
		1. Find all Foreign keys that reference the tables
		2. Optionally Drop, Disable, or ReEnable the keys.
	$Archive: /SQL/QueryWork/FK_DisableDropEnable_ForTableSet.sql $
	$Revision: 1 $	$Date: 16-01-05 14:41 $
*/

If Object_id ('tempdb..#theFKs', 'U') Is Not Null Drop Table #theFKs;
If Object_id ('tempdb..#pTables', 'U') Is Not Null Drop Table #pTables;
Go

Declare
	@Action			Varchar(10)	= 'Disable'		-- Drop, Disable, Enable With Check.
	, @cmd			NVarchar(max)
	, @debug		Integer	= 1					-- 0 = Execute Silently, 1 = Execute Verbose, 2 = What If
	, @hRes			Integer = 0
	, @KeyCols		NVarchar(2048)
	, @NewLine		NChar(1) = NChar(10)
	, @Tab			NChar(1) = NChar(9)
	, @FKName		NVarchar(128)
	, @FKId			Integer
	, @ParentSchema	NVarchar(128)
	, @ParentName	NVarchar(128)
	, @ParentId		Integer
	, @RefedName	NVarchar(128)
	, @RefedId		Integer
	, @isNotTrusted	Bit
	, @isDisabled	Bit
	;
Create Table #theFKs(
	Id	Int	Identity(1, 1)
	, FKName		NVarchar(128)
	, FKId			Integer
	, ParentSchema	NVarchar(128)
	, ParentName	Nvarchar(128)
	, ParentId		Integer
	, RefedName		Nvarchar(128)
	, RefedId		Integer
	, FKCols		NVarchar(2000)
	, isNotTrusted	Bit
	, isDisabled	Bit
	)

--	Select * From sys.objects Where type = 'F'
Create Table #pTables(ParentSchema NVarchar(128), TName NVarchar(128), TId Integer);

Insert #pTables(ParentSchema, TName, TId)
	Select pt.sch, pt.tab, Object_Id(pt.sch + N'.' + pt.tab)
	From (Values
		('dbo', 'Authority'), ('dbo', 'Contact'), ('dbo', 'CSR'), ('dbo', 'Customer')
		, ('dbo', 'CustomerContact'), ('dbo', 'Dispenser'), ('dbo', 'FuelType')
		, ('dbo', 'Panel'), ('dbo', 'PanelAlarm'), ('dbo', 'Probe'), ('dbo', 'Product')
		, ('dbo', 'Rank'), ('dbo', 'ReportType'), ('dbo', 'ServiceCenter'), ('dbo', 'SIM')
		, ('dbo', 'Site'), ('dbo', 'Subscription'), ('dbo', 'Tank'), ('dbo', 'TankSystem')
	) As pt (sch, tab)
;
--	Select * From #pTables

Insert #theFKs (FKName, FKId, ParentSchema, ParentName, ParentId, RefedName, RefedId, isNotTrusted, isDisabled)
	Select fk.name
		, fk.object_id
		, Schema_name(fk.schema_id)
		, Object_Name(fk.parent_object_id)
		, fk.parent_object_id
		, Object_Name(fk.referenced_object_id)
		, fk.referenced_object_id
		, fk.is_not_trusted
		, fk.is_disabled
	From
		sys.foreign_keys As fk
		Inner Join #pTables As pt
			On fk.referenced_object_id = pt.TId
	Where 1 = 1
		And fk.type = 'F'
Declare c_FKs Cursor Local Forward_Only For
	Select FKName, FKId, ParentSchema, ParentName, ParentId, RefedName, RefedId, isNotTrusted, isDisabled
	From #theFKs;
-- Select * From #theFKs
Open c_FKs
While 1 = 1
Begin	-- Process Each Key
	Fetch Next From c_FKs Into @FKName, @FKId, @ParentSchema, @ParentName, @ParentId
			, @RefedName, @RefedId, @isNotTrusted, @isDisabled	
	If @@Fetch_Status != 0 Break;
	-- Process Keys based on Action
	If @Action = 'Disable'
	Begin		-- Disable
		If @isDisabled = 0	-- Key is not disabled
		Begin -- Disable
			Raiserror('Disabling FK %s in %s.%s that references %s.', 0, 0, @FKName, @ParentSchema, @ParentName, @RefedName) With NoWait;
			Set @cmd = N'Alter Table ' + QuoteName(@ParentSchema) + N'.' + QuoteName(@ParentName)
				+ N' NoCheck Constraint ' + QuoteName(@FKName) + N';' ;
		End -- Disable
		Else Begin	-- Key is Disabled
			RaiSerror('Key %s From Table %s.%s already Disabled', 0, 0, @FKName, @ParentSchema, @ParentName) With NoWait;
			Continue;
		End;	-- Key is Disabled

	End;		-- Disable
	Else if @Action = 'Enable'
	Begin		-- Enable
		If @isNotTrusted = 1 or @isDisabled = 1	-- Key is not trusted or key is disabled
		Begin -- Enable with Check
			Raiserror('Enabling FK %s From Table %s.%s', 0, 0, @FKName, @ParentSchema, @ParentName) With NoWait;
			Set @cmd = N'Alter Table ' + QuoteName(@ParentSchema) + N'.' + QuoteName(@ParentName)
				+ N' With Check Check Constraint ' + QuoteName(@FKName) + N';' ;
		End -- Enable with Check
		Else Begin	-- Key is Enabled and Trusted
			RaiSerror('Key %s From Table %s.%s already Enabled and Trusted', 0, 0, @FKName, @ParentSchema, @ParentName) With NoWait;
			Continue;
		End;	-- Key is Enabled and Trusted

	End;
	Else if @Action = 'Drop'
	Begin		-- Drop
		RaisError('Dropping FK %s From Table %s.%s', 0, 0, @FKName, @ParentSchema, @ParentName) With NoWait;
		Set @cmd = N'Alter Table ' + QuoteName(@ParentSchema) + N'.' + QuoteName(@ParentName) + N' Drop Constraint ' + QuoteName(@FKName) + N';';
	End;
	Else
	Begin	-- Unknown Action
		RaisError('Unknown Action', 16, 0) With NoWait;
		Break;
	End;	-- Unknown Action
	If @debug > 0
		Raiserror('Executing:%s%s', 0, 0, @NewLine, @cmd) With NoWait;
	Begin Try
	If @debug <= 1
		Exec @hres = sp_ExecuteSQL @cmd;
	End Try
	Begin Catch
		Declare @ErrorMessage NVarchar(2048) = Error_Message()
			, @ErrorNum			Integer	= Error_Number()
			, @ErrorSeverity	Integer = Error_Severity()
			, @ErrorState		Integer	= Error_State()

		RaisError('Error Executing @cmd = %s%s', 16, 0, @NewLine, @cmd) With NoWait;
		Raiserror('Original Error Data: Error Number = %d, Severity = %d, State = %s.%s Error Message = %s%s', 0, 0
					, @ErrorNum, @ErrorSeverity, @ErrorState, @NewLine, @NewLine, @ErrorMessage)
	End Catch;
End;	-- Process Each Foreign Key
Return

/*
USE [ConSIRN]

ALTER TABLE [dbo].[SiteGeoCodes] DROP CONSTRAINT [FK_SiteGeoCodes_Site]


ALTER TABLE [dbo].[SiteGeoCodes]  WITH CHECK ADD  CONSTRAINT [FK_SiteGeoCodes_Site] FOREIGN KEY([CustID], [SiteID])
REFERENCES [dbo].[Site] ([CustID], [SiteID])

ALTER TABLE [dbo].[SiteGeoCodes] CHECK CONSTRAINT [FK_SiteGeoCodes_Site]
*/

