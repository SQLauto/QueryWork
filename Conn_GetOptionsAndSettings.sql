
/*
	$Archive: /SQL/QueryWork/Conn_GetOptionsAndSettings.sql $
	$Revision: 1 $	$Date: 16-03-07 9:03 $

	Based on BOL
*/


Set Xact_Abort On
Set NoCount On;
Declare @Options Integer = @@Options;
Select 
	Cast(@options As Varbinary(8))
	, [Deferred Constraint Ck] = Case When @Options & 0x01 = 0x01 Then 'Disabled' Else 'No' End
	, [Implicit Trans] = Case When @Options & 0X02 = 0X02 Then 'Yes' Else 'No' End
	, [Cursor Close on Commit] = Case When @Options & 0X04 = 0X04 Then 'Yes' Else 'No' End
	, [Ansi Warnings] = Case When @Options & 0X08 = 0X08 Then 'Yes' Else 'No' End
	, [Ansi Padding] = Case When @Options & 0X10 = 0X10 Then 'Yes' Else 'No' End
	, [Ansi Nulls] = Case When @Options & 0X20 = 0X20 Then 'Yes' Else 'No' End
	, [ARITHABORT] = Case When @Options & 0X040 = 0X040 Then 'Yes'  Else 'No' End
	, [ARITHIGNORE] = Case When @Options & 0X80 = 0X80 Then 'Yes'  Else 'No' End
	, [QUOTED_IDENTIFIER] = Case When @Options & 0X100 = 0X100 Then 'Yes'  Else 'No' End
	, [NOCOUNT] = Case When @Options & 0X200 = 0X200 Then 'Yes'  Else 'No' End
	, [ANSI_NULL_DFLT_ON] = Case When @Options & 0X400 = 0X400 Then 'Yes'  Else 'No' End
	, [ANSI_NULL_DFLT_OFF] = Case When @Options & 0X800 = 0X800 Then 'Yes'  Else 'No' End
	, [CONCAT_NULL_YIELDS_NULL] = Case When @Options & 0X1000 = 0X1000 Then 'Yes'  Else 'No' End
	, [NUMERIC_ROUNDABORT] = Case When @Options & 0X2000 = 0X2000 Then 'Yes'  Else 'No' End
	, [XACT_ABORT] = Case When @Options & 0X4000 = 0X4000 Then 'Yes'  Else 'No' End


