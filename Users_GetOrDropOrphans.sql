-- $Workfile: Users_GetOrDropOrphans.sql $
/*
    $Archive: /SQL/QueryWork/Users_GetOrDropOrphans.sql $
    $Revision: 1 $    $Date: 14-12-12 16:26 $
    Based on
        Script to Drop All Orphaned SQL Server Database Users
        http://www.mssqltips.com/sqlservertip/3439/script-to-drop-all-orphaned-sql-server-database-users/?utm_source=dailynewsletter&utm_medium=email&utm_content=text&utm_campaign=20141211

*/
If Object_Id('tempdb..#Orphans', 'U') is not null
    Drop Table #Orphans;
If object_id('tempdb..#ActionList', 'U') is not null
    Drop Table #ActionList;
If Object_id('tempdb..#Schemas', 'U') is not null
    Drop Table #Schemas;
Go

Declare
    @DbName     Nvarchar(128)
    , @Debug    int   = 2           -- 0 execute silent, 1 execute verbose, 2 trace and report No Changes, 
    ;
Create Table #Orphans(Id int identity(1, 1)
    , DB_UserName       NVarchar(128)
    , UserTypeDesc      Nvarchar(60)
    , UserDefaultSchema NVarchar(128)
    , DB_UserId         int
    , DB_UserSID        VarBinary(85)
    , CreateDate        Datetime
    , ModifyDate        Datetime
    );
Create Table #ActionList(id int identity(1, 1)
    , ObjectType    Nvarchar(128)
    , ObjectName    Nvarchar(128)
    , PlanedAction  Nvarchar(50)
    , Cmd           Nvarchar(Max)   -- T-SQL to remedy the issue
    );
Create Table #Schemas(Id int identity(1, 1)
    , SchemaName        NVarchar(128)
    , SchemaId          Integer
    , SchemaPrincipal   Int
    );

Set @DbName = DB_Name();
-- Get all users in current database that are not associated with a Login.
Insert #Orphans(DB_UserName, UserTypeDesc, UserDefaultSchema, DB_UserId, DB_UserSID, CreateDate, ModifyDate)
    Select
          dp.name
        , dp.type_desc
        , dp.default_schema_name
        , dp.principal_id
        , dp.[SID]
        , dp.create_date
        , dp.modify_date
        --, dp.*
    From
	    sys.database_principals as dp
	    left join sys.server_principals as sp
	        on dp.[sid] = sp.[sid]
    Where 1 = 1
	    --and dp.type in ('G', 'S', 'U')
	    and dp.type_desc in ('WINDOWS_GROUP', 'SQL_USER', 'WINDOWS_USER')
	    and dp.name not in ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys',
					     'MS_DataCollectorInternalUser')
	    and sp.[sid] is null        -- Db User Not in Server Principals
    ;
If @Debug >= 1 Select * From #Orphans;

-- Check for Schema with same name as DB_UserName (holdover from SQL 2000)  (sys.schemas.principal_id
Insert #Schemas(SchemaId, SchemaName, SchemaPrincipal)
    Select s.schema_id, s.name, s.principal_id
    From
        sys.schemas as s
        inner join #orphans as o
            on o.DB_UserName = s.name
    ;
If @Debug >= 1 Select * From #Schemas;
-- Check for Objects in the schema (drop? move to dbo?)
-- Check for schemas owned by DB_UserName
-- Check for objects owned by DB_UserName - transfer to dbowner
-- Check for Role membership -- Drop DB_UserName from Role.
-- Drop User

 

