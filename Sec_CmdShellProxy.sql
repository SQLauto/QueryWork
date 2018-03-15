
/*

	This script sets up a high privilege SQL Proxy Login so normal, low privilege
	user logins can execute xp_cmdShell.
	$Archive: /SQL/QueryWork/Sec_CmdShellProxy.sql $
	$Revision: 1 $	$Date: 9/14/17 3:32p $
	Steps:
	1. Create a domain (or maybe local machine) Login for the high privilege account.
	2. Add high privilege account as SQL login and membership in SysAdmin fixed role.
	3. Create Credential '##xp_cmdshell_proxy_account##' for high privilege login
	4. Add low privilege login as user in master database in public role.
	5. Grant low privilege login execute permission on master.sys.xp_cmdShell
	6 test With following snippet.
		Execute As Login = '<domain>\<low privilege login'
		Exec sys.xp_cmdshell 'Dir C:\'
		Revert
*/

--	Exec sys.sp_configure 'show advanced options'
--	Exec sys.sp_configure 'xp_cmdshell', 1
--	Reconfigure with OverRide

Use Master

Create User [<Domain>\<low privilege login] For Login [<Domain>\<low privilege login];
Grant Execute On master.sys.xp_cmdshell To [<Domain>\<low privilege login];

CREATE CREDENTIAL ##xp_cmdshell_proxy_account## WITH IDENTITY = '<Domain>\<high privilege login',secret = 'password'

-- Use following to modify the credential if necessary, e.g., change password.
--	ALTER CREDENTIAL credential_name WITH IDENTITY = '##xp_cmdshell_proxy_account##', SECRET = 'secret'


/*
	-- Enble this query to add a credential for Execute As
	Create CREDENTIAL ClearViewSysAdminProxy WITH IDENTITY = '<Domain>\<high privilege login',secret = 'password'
*/

Return;


Select * From master.sys.credentials As c
