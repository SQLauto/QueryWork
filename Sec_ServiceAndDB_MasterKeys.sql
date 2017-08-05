
--	SELECT * FROM master.sys.symmetric_keys WHERE name = '##MS_ServiceMasterKey##';

Select Name, db.is_master_key_encrypted_by_server, *
From Sys.databases As db
Where db.database_id > 4


Create Master Key Encryption By Password = N'1df7fd2ff85244bca59980f30067e63d'
SELECT * FROM sys.symmetric_keys

Declare @cmd	NVarchar(max) = N'Backup Service Master Key To File = N''\\Seagate\SQLBackups\KeyBackups\'
		+ Replace(@@ServerName, '\', '+') + N'_ServiceMasterKey_' + Convert(NVarchar(24), GetDate(), 112) + N''''
		+ N' Encryption By Password = ''1df7fd2ff85244bca59980f30067e63d'''

Print @cmd;
Exec sp_ExecuteSQL @cmd;


