/*******************************************************************************
BASIC TESTS
*******************************************************************************/

%let file = "C:\export_to_txt_example\dat01.txt";

data dat01;
  format date_var1 date9. date_var2 mmddyy10.;
  do i = 1 to 10;
  num_var = i;
  char_var = put(i, 2.);
  date_var1 = i;
  date_var2 = i;
  output;
  end;
  drop i;
run;

/* Check that the macro throws an error if any of the macro parameters
are empty */
%export_to_txt();
%export_to_txt(data = dat01);
%export_to_txt(file = &file);
%export_to_txt(data = dat01, file = &file, replace = );
%export_to_txt(data = dat01, file = &file, convert_dates = );
%export_to_txt(data = dat01, file = &file, print_notes = );
%export_to_txt(data = dat01, file = &file, verbose = );
%export_to_txt(data = dat01, file = &file, del = );


/*** Test <data> parameter ***/

/* Test that macro throws error if <data> does not exists */
%export_to_txt(data = abc, file = &file);
%export_to_txt(data = sashelp.abc, file = &file);

/* Test that explicit use of work libname works */
%export_to_txt(data = work.dat01, file = &file);

/*** Test <file> parameter ***/

/* Test that a meaningful error is thrown if a specified
file path does not exist. */
%let file_not_valid = "C:\not\valid\dat01.txt";
%export_to_txt(data = dat01, file = &file_not_valid);

/* Note: If an unquoted filepath is given, the macro will throw a
cryptic error. */

/*** Test <delimiter> parameter ***/

/* Note: If an unquoted delimiter is given, the macro will throw a
cryptic error. */


/*** Test <replace> parameter ***/

/* Test invalid value triggers error */
%export_to_txt(data = dat01, file = &file, replace = abc);


/*** Test <convert_dates> parameter ***/

/* Test invalid value triggers error */
%export_to_txt(data = dat01, file = &file, convert_dates = abc);


/*** Test <print_notes> parameter ***/

/* Test invalid value triggers error */
%export_to_txt(data = dat01, file = &file, print_notes = abc);


/*** Test <verbose> parameter ***/

/* Test invalid value triggers error */
%export_to_txt(data = dat01, file = &file, verbose = abc);


/*** Test <del> parameter ***/

/* Test invalid value triggers error */
%export_to_txt(data = dat01, file = &file, del = abc);


/*******************************************************************************
TEST USE OF DELIMITER SYMBOL IN CHARACTER VARIABLES
*******************************************************************************/

/* Test if proc export automatically quotes character variable values if they 
contain the delimiter symbol */

data dat02;
  var1 = "contains | symbol";
  var2 = "no delimiter symbol";
  output;
run;

%export_to_txt(data = dat02, file = &file, delimiter = "|");

/* Seems like proc export quotes variable where values can contain the
delimiter symbol. */
