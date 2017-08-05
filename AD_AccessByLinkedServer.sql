
/*
	Thanks to bparker@czarnowski.com

*/
Declare @ldap nvarchar(256)

-- Either value seems to work:
SET @ldap = 'DC=MYDOMAIN,DC=com'
SET @ldap = 'MYDOMAIN.com/DC=MYDOMAIN,DC=com'

SET NOCOUNT ON
DECLARE @sql nvarchar(max)

----------------------------------------------------------------------------
-- Other AD attributes: http://msdn.microsoft.com/en-us/library/ms675090
SET @sql = '
    SELECT *
    FROM OPENQUERY(ADSI,
        ''SELECT objectSID
            , distinguishedName, ADsPath
            , mail, telephoneNumber, Name, sn, givenName, SAMAccountName
        FROM ''''LDAP://' + @ldap + '''''
        WHERE SAMAccountName = ''''BParker''''
        ORDER BY Name'')'
--PRINT @sql
EXEC sp_executesql @sql

----------------------------------------------------------------------------
-- Iterate through the list of Active Directory groups and get membership.
SET @sql = '
    DECLARE @group nvarchar(256), @sql2 nvarchar(max)

    DECLARE curADGroups CURSOR LOCAL FAST_FORWARD FOR
        SELECT name
        FROM OPENQUERY(ADSI,
            ''SELECT name
            FROM ''''LDAP://' + @ldap + '''''
            WHERE objectCategory = ''''Group'''' AND objectClass = ''''group''''
            AND name = ''''SSRS_Admin'''' OR name = ''''SSRS_Users''''
            '')
        ORDER BY name

    OPEN curADGroups; FETCH NEXT FROM curADGroups INTO @group
    WHILE @@fetch_status = 0 BEGIN
        PRINT @group
        
        SET @sql2 = ''
        SELECT SAMAccountName, '''''' + @group + '''''' as "group_name"
        FROM OPENQUERY(ADSI,
            ''''SELECT SAMAccountName  
            FROM ''''''''LDAP://' + @ldap + '''''''''
            WHERE memberOf = ''''''''CN='' + @group + '',' + 'OU=Administration,DC=czarnowski,DC=com' + '''''''''
            ORDER BY Name
            '''')''
        EXEC(@sql2)

        FETCH NEXT FROM curADGroups INTO @group
    END
    CLOSE curADGroups; DEALLOCATE curADGroups'
EXEC(@sql)


----------------------------------------------------------------------------
-- Find groups a user belongs to. BASED ON MY LIMITED RESEARCH THIS IS NOT
-- 100% RELIABLE.
SET @sql = '
   SELECT name AS LdapGroup
   FROM OPENQUERY(ADSI,''
       SELECT name
       FROM ''''LDAP://DC=czarnowski,DC=com''''
       WHERE
           objectClass=''''group'''' AND
           member=''''CN=Brian Parker,OU=IT Accounts,OU=Users,OU=Pittsburgh,DC=czarnowski,DC=com''''
   '')
   ORDER BY name
'
EXEC SP_EXECUTESQL @sql

-- Don't forget you can drop the results into a table to work with it in a way you are more comfortable, i.e.:
INSERT INTO @x (SAMAccountName, Name, group_name)
EXEC(@sql)
