Use msdb
Declare @OpName Varchar(50);
Set @OpName = '%'

Select
    sj.name
    ,Op_Email.name
    , [Notify_EMail] = Case sj.notify_level_email When 0 Then 'Never'
                        When 1 Then 'On Success'
                        When 2 Then 'On Fail'
                        When 3 Then 'On Complete'
                        Else ''
                        End
    , sj.*
From
    dbo.sysJobs as sj
    inner join dbo.SysOperators as Op_Email
        on sj.notify_email_operator_id = Op_Email.id
Where 1 = 1
    and Op_Email.name like @OpName
Order By   
    sj.name