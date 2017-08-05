/*
	Get Server properties
	$Archive: /SQL/QueryWork/Server_GetProperties.sql $
	$Revision: 2 $	$Date: 15-11-25 16:22 $
*/
Select
	[Edition] = ServerProperty('Edition')
	, [ProductVersion] = ServerProperty('ProductVersion')
	, [ProductLevel] = ServerProperty('ProductLevel')
	, [ResourceVersion] = ServerProperty('ResourceVersion')


Select * From Sys.servers