/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.0.1
********************************************************************************
DESCRIPTION:
Export SAS dataset to a .txt file.

DETAILS:
Utility macro to export oa SAS dataset to a plain text file.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
data:             SAS dataset to export. Dataset can be specified on either
                  memname or libname.memname form, where a dataset on
                  memname form is assumed to be in the WORK directory.
file:             Quoted full filepath to where the exported dataset is saved,
                  for example
                  file = "C:\path\to\folder\exported_data.txt"
*** OPTIONAL ***
delimter:         Specify quoted delimiter symbol to use. Default is
                  delimiter = "|"
replace:          Overwrite exported file if it already exists?
                  - Yes: replace = y (default)
                  - No:  replace = n
convert_dates:    Should variables with a SAS DATE format be reformatted to
                  yyyy-mm-dd?
                  - Yes: convert_dates = y (default)
                  - No:  convert_dates = n
print_notes:      Print notes in log?
                  - Yes: print_notes = y
                  - No:  print_notes = n (default)
verbose:          Print info on what is happening during macro execution
                  to the log?
                  - Yes: verbose = y
                  - No:  verbose = n (default)
del:              Delete intermediate datasets created by the macro?
                  - Yes: del = y (default)
                  - no:  del = n   
******************************************************************************/

%macro export_to_txt(
  data           = ,
  file           = ,
  delimiter      = "|",
  replace        = y,
  convert_dates  = y,
  print_notes    = n,
  verbose        = n,
  del            = y
  ) / minoperator mindelimiter = ' ';

%put export_to_txt: start execution (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

/* Find value of notes and source options */
%local opt_notes opt_source;
%let opt_notes = %sysfunc(getoption(notes));
%let opt_source = %sysfunc(getoption(source));

/* Disable notes while doing input checks */
options nonotes;


/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/

/*** <verbose> **/ 

/* Check valid value */
%if &verbose = %then %do;
  %put ERROR: Macro parameter <verbose> is not specified!;
  %goto end_of_macro;  
%end;
%else %if (&verbose in y n) = 0 %then %do;
  %put ERROR: <verbose> = &verbose is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: verbose = y;
  %put ERORR: verbose = n;
  %goto end_of_macro;  
%end;

%if &verbose = y %then %do;
  %put export_to_txt: *** Input parameter checks ***;
%end;


/*** <print_notes> ***/

/* Check valid value */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> is not specified!;
  %goto end_of_macro;
%end;
%else %if (&print_notes in n y) = 0 %then %do;
  %put ERROR: <print_notes> = &print_notes is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: print_notes = n;
  %put ERROR: print_notes = y;
  %goto end_of_macro;
%end;


/*** <data> ***/

/* Check that <data> is specified. */
%if &data = %then %do;
  %put ERROR: Macro parameter <data> not specified!;
  %goto end_of_macro;
%end;

/* Check that <data> exists. */
%if %sysfunc(exist(&data)) = 0 %then %do;
  %put ERROR: Specified <data> dataset "&data" does not exist;
  %goto end_of_macro;
%end;

/*** <file> ***/

/* Check that <file> is specified. */
%if &file =  %then %do;
  %put ERROR: Macro parameter <file> not specified!;
  %goto end_of_macro;
%end;

/* TODO: figure out how to check that the specified filepath is quoted.
This does not seem to be straigthforward to do in a robust way. */



/*** <delimiter> ***/

/* Check that <delimiter> is specified. */
%if &delimiter = %then %do;
  %put ERROR: Macro parameter <delimiter> not specified!;
  %goto end_of_macro;
%end;

/* TODO: figure out how to check that the specified value is quoted.
This does not seem to be straightforward, when the unquoted delimiter
is a SAS operator, eg "|". */

/*** <replace> ***/

/* Check valid value */
%if &replace = %then %do;
  %put ERROR: Macro parameter <replace> is not specified!;
  %goto end_of_macro;
%end;
%else %if (&replace in n y) = 0 %then %do;
  %put ERROR: <replace> = &replace is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: replace = y;
  %put ERROR: replace = n;
  %goto end_of_macro;
%end;


/*** <convert_dates> ***/

/* Check valid value */
%if &convert_dates = %then %do;
  %put ERROR: Macro parameter <convert_dates> is not specified!;
  %goto end_of_macro;
%end;
%else %if (&convert_dates in n y) = 0 %then %do;
  %put ERROR: <convert_dates> = &convert_dates is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: convert_dates = y;
  %put ERROR: convert_dates = n;
  %goto end_of_macro;
%end;


/*** <del> ***/

/* Check valid value */
%if &del = %then %do;
  %put ERROR: Macro parameter <del> is not specified!;
  %goto end_of_macro;
%end;
%else %if (&del in n y) = 0 %then %do;
  %put ERROR: <del> = &del is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = y;
  %put ERROR: del = n;
  %goto end_of_macro;
%end;


/*******************************************************************************
IDENTIFY VARIABLES NAMES
*******************************************************************************/

%if &verbose = y %then %do;
  %put export_to_txt: *** Identify variable names ***;
%end;

%if &print_notes = y %then %do;
  options notes;
%end;

proc contents data = &data(obs = 0) noprint out = __et_info1;
run;

/* Sort variable names according to varnum variable to preserve
ordering of columns. */
proc sort data = __et_info1;
  by varnum;
run;

data __et_info2;
  set __et_info1;
  is_date_var = 0;
  if type = 1 and format =: "DATE" then is_date_var = 1;
  keep libname memname name is_date_var;
run;

%local all_var date_var;
proc sql noprint;
  select name into :date_var separated by " "
    from __et_info2
    where is_date_var = 1;
  select name into :all_var separated by " "
    from __et_info2;
quit;

%if &verbose = y %then %do;
  %put export_to_txt: all variables: &all_var;
  %put export_to_txt: date variables: &date_var;
%end;

%local i i_var;
data __et_dat;
  /* Retain all variables to make sure column order is the same when
  date variable formats are updated */
  retain &all_var;
  %if &convert_dates = y %then %do;
    %do i = 1 %to %sysfunc(countw(&date_var, %str( )));
      %let i_var = %scan(&date_var, &i, %str( ));
      format &i_var yymmdd10.;
    %end;
  %end;
  set &data;
run;


/*******************************************************************************
EXPORT DATA
*******************************************************************************/

%if &verbose = y %then %do;
  %put export_to_txt: *** Export dataset ***;
%end;

%if &replace = y %then %let replace_opt = replace;
%else %if &replace = n %then %let replace_opt = ;

options nosource;
proc export data = __et_dat outfile = &file dbms = dlm &replace_opt;
  delimiter = &delimiter;
run;
options &opt_source;


%end_of_macro:

/* Delete temporary datasets created by the macro, also when 
"del" has not be specified as either y or n. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __et_:;
  run;
  quit;
%end;

/* Restore value of notes option */
options &opt_notes;

%put export_to_txt: end execution   (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

%mend export_to_txt;
