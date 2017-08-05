/*
	http://www.katieandemil.com/sql-server-add-linked-server

	sp_addlinkedserver (Transact-SQL)	-- http://msdn.microsoft.com/en-us/library/ms190479(v=sql.105).aspx
	sp_addlinkedsrvlogin (Transact-SQL)	-- http://msdn.microsoft.com/en-us/library/ms189811(v=sql.105).aspx
	
	This script is a template for creating linked servers.
	The script is run on, and the linked server <Linked Server Name> is created on the server
	on which you will be running queries.  The Remote Server is the target you will be accessing.
	The script provides commmented options showing how you can setup a common linked server name
	in different environments (e.g. Dev, Test, Production) to point to the appropriate remote server
	in each environment.
	
	Includes SQL snippets to test the Linked server and ...
	$Archive: /SQL/QueryWork/LinkedServer_Create_Template.sql $
	$Revision: 1 $	$Date: 14-05-17 11:42 $
	
*/

Use master
GO

If exists (select * from sys.servers where name = N'<Linked Server Name>')
Begin
	Exec sp_DropServer N'<Linked Server Name>';
End;
Go

EXEC sp_addlinkedserver @server = N'<Linked Server Name>'
	, @srvproduct = N''							-- Product can't be null but does not matter when provider is SQLNCLI
	, @provider = N'SQLNCLI'
	--, @datasrc = N'<Remote Server A>'				-- use this Option to access Production
	, @datasrc = N'<Remote Server B\Instance Name'	-- use this Option to access Dev
	--, @datasrc = N'<Remote Server C>'				-- use this Option to access a third server
	, @catalog = N'<Target Database>'				-- Does not seem to have an effect when @useSelf = 'True'
	;

-- These options permit Stored Procedure execution on the remote server
EXEC master.dbo.sp_serveroption @server = N'<Linked Server Name>', @optname = N'rpc', @optvalue = N'true';
EXEC master.dbo.sp_serveroption @server = N'<Linked Server Name>', @optname = N'rpc out', @optvalue = N'true';

-- This option enables remote server access using the current user's credential to determine database permissions.
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'<Linked Server Name>', @useself = N'True', @locallogin = NULL, @rmtuser = NULL, @rmtpassword = NULL;

-- This option forces remote server access to use the specified SQL Login.  The login has restricted access to the server/database.
--EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'<Linked Server Name>', @useself = N'False', @locallogin = NULL,	@rmtuser = N'<SQLLoginOnRemoteServer>', @rmtpassword = N'<PasswordOnRemoteServer>';

Return;

/* ***************************************************************************************
	Use these snippets to Test correct access to the remote Server
   ****************************************************************************************
*/
/*
-- This one succeeds because Public has Select access to Sys.Objects system view?
Select *
From <Linked Server Name>.<Target Database>.sys.objects
Where type = 'P';

-- This one should succeed
Select top 10 *
From <Linked Server Name>.<Target Database>.dbo.<SomeTable>

*/


