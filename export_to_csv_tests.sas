/*******************************************************************************
BASIC TESTS
*******************************************************************************/

%let from_path = S:\Thomas Rasmussen\github_repos\test_from;
%let to_path = S:\Thomas Rasmussen\github_repos\test_to;

data "&from_path\test1.sas7bdat";
  var = 1;
  output;
run;

data "&from_path\test2.sas7bdat";
  var = 1;
  output;
run;

/* Check that the macro throws an error if any of the macro parameters
are empty */
%export_to_csv();
%export_to_csv(datasets = test1);
%export_to_csv(datasets = test1, from = &from_path);
%export_to_csv(datasets = test1, to = &to_path);
%export_to_csv(from = &from_path, to = &to_path);

%macro test1;
%let opt_vars = replace convert_date_formats print_notes verbose del;
%do i = 1 %to %sysfunc(countw(&opt_vars, %str( )));
  %let i_var = %scan(&opt_vars, &i, %str( ));
  %put ERROR: "&i_var = ";
  %export_to_csv(datasets = test1, from = &from_path, to = &to_path, &i_var =);
%end;
%mend test1;
%test1;


/*** Test <from> parameter ***/

/* Test that macro throws error if directory does not exist */
%export_to_csv(datasets = test1, from = invalid, to = &to_path);


/*** Test <to> parameter ***/

/* Test that macro throws error if directory does not exist */
%export_to_csv(datasets = test1, from = &from_path, to = invalid);


/*** Test <datasets> parameter ***/

/* Test that macro throws error if a dataset in <datasets> does not exist */
%export_to_csv(datasets = invalid, from = &from_path, to = &to_path);
%export_to_csv(datasets = test1 invalid, from = &from_path, to = &to_path);

/* Test that macro can handle multiple datasets at once */
%export_to_csv(datasets = test1 test2, from = &from_path, to = &to_path);


/*** Test <replace> parameter ***/

/* Test invalid value triggers error */
%export_to_csv(datasets = test1, from = &from_path, to = &to_path, replace = abc);


/*** Test <convert_dates> parameter ***/

/* Test invalid value triggers error */
%export_to_csv(
  datasets = test1,
  from = &from_path,
  to = &to_path,
  convert_dates = abc
);


/*** Test <print_notes> parameter ***/

/* Test invalid value triggers error */
%export_to_csv(datasets = test1, from = &from_path, to = &to_path, print_notes = abc);


/*** Test <verbose> parameter ***/

/* Test invalid value triggers error */
%export_to_csv(datasets = test1, from = &from_path, to = &to_path, verbose = abc);


/*** Test <del> parameter ***/

/* Test invalid value triggers error */
%export_to_csv(datasets = test1, from = &from_path, to = &to_path, del = abc);


/*******************************************************************************
TEST CONVERT_DATES
*******************************************************************************/

data "&from_path\test3.sas7bdat";
  format date_var2 date9. date_var3 yymmdd10.;
  date_var1 = 1;
  date_var2 = 1;
  date_var3 = 1;
  output;
run;

%export_to_csv(
  datasets = test3,
  from = &from_path,
  to = &to_path,
  convert_dates = y
);
/* Note that the unformatted date variable is left unformatted */

%export_to_csv(
  datasets = test3,
  from = &from_path,
  to = &to_path,
  convert_dates = n
);
/* Keeps the formats */

/*******************************************************************************
TEST COMMA AND QUOTE SYMBOLS IN STRINGS
*******************************************************************************/

/* Test if proc export automatically quotes character variables if they 
contain commas (delimiter symbol) and quote values */

data "&from_path\test4.sas7bdat";
  var1 = "contains ,. should be quoted";
  var2 = "not quoted?";
  var3 = "how are ' handled?";
  var4 = 'How about "?';
  output;
run;

%export_to_csv(datasets = test4, from = &from_path, to = &to_path);

/* Both var1 and var4 are quoted, but not var2 and var3. Ok. */
