
/*
https://www.mssqltips.com/sqlservertip/2710/steps-to-clean-up-orphaned-replication-settings-in-sql-server/
https://blogs.msdn.microsoft.com/repltalk/2010/11/17/how-to-cleanup-replication-bits/


*/

Use [master]
exec sp_helpreplicationdboption --@dbname = N'Wilco'
Go


exec sp_replicationdboption @dbname = N'Wilco', @optname = N'publish', @value = N'false'


--	exec Distribution.dbo.sp_MSremove_published_jobs @server = 'DFW111VsClvDB1', @database = 'Wilco'

Exec sp_helpreplicationoption 'transactional'

Exec sp_helppublication

Exec sp_removedbreplication @dbname = 'ConSirn'
    , @type = 'Tran'