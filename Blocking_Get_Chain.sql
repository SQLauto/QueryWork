/*
	Based on Paul Lambert - Blocking Chain (SQL Spackle)
	http://www.sqlservercentral.com/articles/Blocking/101926/
	Frustrating error in this script :(
	This finds the Sessions at the top of the blocking chain but does
	not tell you who is blocked.
	$Workfile: Blocking_Get_Chain.sql $
	$Archive: /SQL/QueryWork/Blocking_Get_Chain.sql $
	$Revision: 5 $	$Date: 14-09-26 16:17 $

*/
use Master

Select  DES.Session_ID As [Root Blocking Session ID],
    DER.Status As [Blocking Session Request Status],
    DES.Login_Time As [Blocking Session Login Time],
    DES.Login_Name As [Blocking Session Login Name],
    DES.Host_Name As [Blocking Session Host Name],
    Coalesce(DER.Start_Time,DES.Last_Request_Start_Time) As [Request Start Time],
    Case
     When DES.Last_Request_End_Time >= DES.Last_Request_Start_Time Then DES.Last_Request_End_Time
     Else Null
    End As [Request End Time],
    Substring(Text,DER.Statement_Start_Offset/2,
        Case
         When DER.Statement_End_Offset = -1 Then DataLength(Text)
         Else DER.Statement_End_Offset/2
        End) As [Executing Command],
    Case
     When DER.Session_ID Is Null Then 'Blocking session does not have an open request and may be due to an uncommitted transaction.'
     When DER.Wait_Type Is Not Null Then 'Blocking session is currently experiencing a ' + DER.Wait_Type + ' wait.'
     When DER.Status = 'Runnable' Then 'Blocking session is currently waiting for CPU time.'
     When DER.Status = 'Suspended' Then 'Blocking session has been suspended by the scheduler.'
     Else 'Blocking session is currently in a '+DER.Status+' status.'
    End As [Blocking Notes]
 From  Sys.DM_Exec_Sessions DES (READUNCOMMITTED)
 Left Join Sys.DM_Exec_Requests DER (READUNCOMMITTED)
   On DER.Session_ID = DES.Session_ID
 Outer Apply Sys.DM_Exec_Sql_Text(DER.Sql_Handle)
 Where  DES.Session_ID In (
         Select Blocking_Session_ID
         From Sys.DM_Exec_Requests (READUNCOMMITTED)
         Where Blocking_Session_ID <> 0
          And Blocking_Session_ID Not In (
                   Select session_id
                   From Sys.DM_Exec_Requests (READUNCOMMITTED)
                   Where Blocking_Session_ID <> 0
                  )
         )

Exec SP_Who2
Return;
/*

Kill 74 with statusonly
DBCC Opentran with tableResults
*/
