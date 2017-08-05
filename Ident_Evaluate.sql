/*
	Monitor SQL Server IDENTITY Column Values to Prevent Arithmetic Overflow Errors
	https://www.mssqltips.com/sqlservertip/4375/monitor-sql-server-identity-column-values-to-prevent-arithmetic-overflow-errors/
	$Archive: /SQL/QueryWork/Ident_Evaluate.sql $
	$Revision: 1 $	$Date: 17-01-12 14:22 $

*/


-- define the max value for each data type
If Object_Id('tempdb..#DataTypeMaxValue', 'U') Is Not Null
	Drop Table #DataTypeMaxValue;
Go

Create Table #DataTypeMaxValue (
	  DataType Varchar(50)
	, MaxValue BigInt
	);

Insert Into #DataTypeMaxValue
Values ('tinyint', 255)
	, ('smallint', 32767)
	, ('int', 2147483647)
	, ('bigint', 9223372036854775807);

-- retrieve identity column information
Select Distinct
	[Database] = Db_Name()
	, [Table Name] = Object_Name(IC.object_id)
	, [Column Name] = IC.name
	, [Data Type] = Type_Name(IC.system_type_id)
	, [Max Value] = DTM.MaxValue
	, [Identity Seed] = IC.seed_value
	, [Identity Increment] = IC.increment_value
	, [Current] = IC.last_value
	, [NumberOfRows] = DBPS.row_count
	, [Curr Percent] = (Convert(Decimal(9, 7), Convert(BigInt, IC.last_value) * 100 / DTM.MaxValue))
From sys.identity_columns IC
	Join sys.tables TN
		On IC.object_id = TN.object_id
	Join #DataTypeMaxValue DTM
		On Type_Name(IC.system_type_id) = DTM.DataType
	Join sys.dm_db_partition_stats DBPS
		On DBPS.object_id = IC.object_id
	Join sys.indexes As IDX
		On DBPS.index_id = IDX.index_id
Where DBPS.row_count > 0
Order By [Curr Percent] Desc;
