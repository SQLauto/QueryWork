--###############################################################################################
-- Quick script to enumerate Active directory users who get permissions from An Active Directory Group
--###############################################################################################


/*
	Enumerate Windows Group Members
	http://www.sqlservercentral.com/articles/Active+Directory/138308/

	$Archvie: $
	$Revision: 1 $	$Date: 16-05-12 14:11 $

*/
If Object_Id('tempdb.dbo.#tmp') Is Not Null
  Drop Table #tmp;
Go
Set NoCount On;

Declare @GroupName NVarchar(256);
--a table variable capturing any errors in the try...catch below
Declare @ErrorRecap Table
  (
     ID           Int Identity(1, 1) Not Null Primary Key,
     AccountName  NVarchar(256),
     ErrorMessage NVarchar(512)
  ); 

--table for capturing valid resutls form xp_logininfo
Create Table dbo.#TMP (
	  AccountName NVarchar(256) Null
	, TYPE Varchar(8) Null
	, Privilege Varchar(8) Null
	, MappedLoginName NVarchar(256) Null
	, PermissionPath NVarchar(256) Null
	);

  --###############################################################################################
  --cursor definition
  --###############################################################################################
 Declare c1 Cursor Local Forward_Only Static Read_Only For
	Select name 
	From master.sys.server_principals 
	Where type_desc =  'WINDOWS_GROUP'; 
   --###############################################################################################
Open c1;
While 1 = 1
	Begin	-- Cursor Loop
	Fetch Next From c1 Into @GroupName;
	If @@Fetch_Status != 0 Break;
	Begin Try
		Insert Into #TMP(AccountName, TYPE, Privilege, MappedLoginName, PermissionPath)
			Exec master..xp_logininfo @acctname = @GroupName, @option = 'members';     -- show group members
	End Try
	Begin Catch
		--capture the error details
		Declare	@ErrorSeverity Int = Error_Severity()
			, @ErrorNumber Int = Error_Number()
			, @ErrorMessage NVarchar(4000) = Error_Message()
			, @ErrorState Int = Error_State()
			;

		--put all the errors in a table together
		Insert Into @ErrorRecap(AccountName, ErrorMessage)
			Select @GroupName, @ErrorMessage;

		--echo out the supressed error, the try catch allows us to continue processing, isntead of stopping on the first error
		Print 'Msg ' + Convert(Varchar(12), @ErrorNumber) + ' Level ' + Convert(Varchar(12), @ErrorSeverity) + ' State '
			 + Convert(Varchar(12), @ErrorState);
		Print @ErrorMessage;
	End Catch;
	End;	-- Cursor Loop
Close c1;
Deallocate c1;

--display both results and errors
Select AccountName, TYPE, Privilege, MappedLoginName, PermissionPath From #TMP;
Select ID, AccountName, ErrorMessage From @ErrorRecap;