
/*
	This is a start on a script to check/validate
	The Database Owners and SIDS after dbs are re-attached/restored.
*/

Select
	d.name
	,d.owner_sid
	,sp.sid
	,case When sp.sid = d.owner_sid then 'Same' Else 'Differ' end
	,d.database_id
from sys.databases as d
	Inner Join Sys.server_principals as sp
		on sp.sid = d.owner_sid
 where d.database_id > 4
