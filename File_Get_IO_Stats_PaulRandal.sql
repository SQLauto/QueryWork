/*
	Based on script from Paul Randal
	How to examine IO subsystem latencies from within SQL Server
	http://www.sqlskills.com/blogs/paul/how-to-examine-io-subsystem-latencies-from-within-sql-server/
	
	This script displays aggregated data from the last time the server/service was restarted upto present


	$Workfile: File_Get_IO_Stats_PaulRandal.sql $
	$Archive: /SQL/QueryWork/File_Get_IO_Stats_PaulRandal.sql $
	$Revision: 2 $	$Date: 14-03-11 9:43 $

*/

SELECT
--virtual file latency
	[ReadLatency] = case	WHEN [num_of_reads] = 0 THEN 0
							ELSE ([io_stall_read_ms] / [num_of_reads])
					END
	, [WriteLatency] = case	WHEN [num_of_writes] = 0 THEN 0
							ELSE ([io_stall_write_ms] / [num_of_writes])
						END
	, [Latency] = case	WHEN ([num_of_reads] = 0
								AND [num_of_writes] = 0
								) THEN 0
						ELSE ([io_stall] / ([num_of_reads] + [num_of_writes]))
					END
	,
--avg bytes per IOP
	[AvgBPerRead] = case	WHEN [num_of_reads] = 0 THEN 0
							ELSE ([num_of_bytes_read] / [num_of_reads])
					END
	, [AvgBPerWrite] = case	WHEN [io_stall_write_ms] = 0 THEN 0
							ELSE ([num_of_bytes_written] / [num_of_writes])
						END
	, [AvgBPerTransfer] = case	WHEN ([num_of_reads] = 0
										AND [num_of_writes] = 0
										) THEN 0
								ELSE (([num_of_bytes_read] + [num_of_bytes_written]) / ([num_of_reads]
																						+ [num_of_writes]))
							END
	, [Drive] = left([mf].[physical_name], 2)
	, [DB] = db_name([vfs].[database_id])
	--,   [vfs].*
	, [FQPN] = [mf].[physical_name]
	, [File Name] = substring(mf.physical_name, len(mf.physical_name) - charindex('\', reverse(mf.physical_name)) + 2, 100)
FROM
	sys.dm_io_virtual_file_stats(NULL, NULL) AS [vfs]
	JOIN sys.master_files AS [mf]
		ON [vfs].[database_id] = [mf].[database_id]
			AND [vfs].[file_id] = [mf].[file_id]
WHERE 1 = 1
	--and [vfs].[file_id] = 2 -- log files
	--and db_name(vfs.database_id) = 'tempdb'
ORDER BY
	--[Latency] DESC
	[ReadLatency] DESC
	--[WriteLatency] DESC
GO

