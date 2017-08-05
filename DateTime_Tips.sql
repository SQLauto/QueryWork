/*
	Snippets for manipulating DateTime
	$Revision: 1 $	$Date: 14-09-09 11:02 $

	References:
	SQL SERVER – Script to Find First Day of Current Month
		http://blog.sqlauthority.com/2014/08/14/sql-server-script-to-find-first-day-of-current-month/
*/
Declare @theDate Datetime;
Set @theDate = Convert(datetime, '2014-05-15 15:32');
/*
To Get last day of the previous month
1.	use the Day function to get the day-of-month for the supplied date.
2.	Use the DateAdd function to subtract the Day-of-Month from the supplied date
3.	If you want a date with 00 time then cast the supplied date as a Date datatype
*/
Select DateAdd (dd, -Day(@theDate), Cast(@theDate as Date));
/*
Using this core piece it is easy to obtain other markers.  For example to obtain the first day of the month just add 1 to –Day(@theDate)
So in the example  -Day(@theDate) is -15 and adding 1 we have -14 so the DateAdd function will return the 1st. 
*/

Select DateAdd (dd, -Day(@theDate) + 1, Cast(@theDate as Date));

/*
Once you have the First of the current month or the last of the previous then you can Add/Subtract a month(s) to get the appropriate date.
So the first day of the next month
*/

Select DateAdd (dd, -Day(@theDate) + 1, DateAdd(mm, 1, Cast(@theDate as Date)));

