/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.0.1
********************************************************************************
DESCRIPTION:
Export datasets to CSV

DETAILS:
Export a set of specified datasets to CSV using PROC EXPORT.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
datasets:         Space-separated list of dataset names in <from> to export.
from:             Path to folder where <datasets> are located.
to:               Path to folder where exported dataets are to be saved.
*** OPTIONAL ***
replace:          Overwrite exported files if they already exist in <to>?
                  - Yes: replace = y (default)
                  - No:  replace = n
convert_dates:    Should variables with date formats be reformatted to
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
%macro export_to_csv(
  datasets       = ,
  from           = ,
  to             = ,
  replace        = y,
  convert_dates  = y,
  print_notes    = n,
  verbose        = n,
  del            = y
  ) / minoperator mindelimiter = ' ';

%put export_to_csv: start execution (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

/* Find value of notes and source options */
%local opt_notes opt_source;
%let opt_notes = %sysfunc(getoption(notes));
%let opt_source = %sysfunc(getoption(source));

/* Disable notes while doing input checks */
options nonotes;


/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/

/* verbose: check parameter not empty. */
%if &verbose = %then %do;
  %put ERROR: Macro parameter <verbose> not specified!;
  %goto end_of_macro;  
%end;

/* verbose: check parameter has valid value. */
%if (&verbose in y n) = 0 %then %do;
  %put ERROR: <verbose> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: verbose = y (Yes);
  %put ERROR: verbose = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;  
%end;

%if &verbose = y %then %do;
  %put export_to_csv: *** Input parameter checks ***;
%end;

/* print_notes: check parameter not empty. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> not specified!;
  %goto end_of_macro;  
%end;

/*print_notes: check parameter has valid value. */
%if (&print_notes in y n) = 0 %then %do;
  %put ERROR: <print_notes> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: print_notes = y (Yes);
  %put ERROR: print_notes = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;  
%end;

%if &print_notes = y %then %do;
  options notes;
%end;   

/* Check remaining macro parameters not empty. */
%local parms i i_parm;
%let parms = datasets from to replace convert_dates del;                 
%do i = 1 %to %sysfunc(countw(&parms, %str( )));
  %let i_parm = %scan(&parms, &i, %str( ));
  %if %bquote(&&&i_parm) = %then %do;
    %put ERROR: Macro parameter <&i_parm> not specified!;
    %goto end_of_macro;    
  %end;
%end;

/* from: check directory exists */
%local rc fileref;
%let rc = %sysfunc(filename(fileref, &from));
%if %sysfunc(fexist(&fileref)) = 0 %then %do;
  %put ERROR: <from> directory "&from" does not exist!;
  %goto end_of_macro;
%end;

/* to: check directory exists */
%local rc fileref;
%let rc = %sysfunc(filename(fileref, &to));
%if %sysfunc(fexist(&fileref)) = 0 %then %do;
  %put ERROR: <to> directory "&to" does not exist!;
  %goto end_of_macro;
%end;

/* datasets: check datasets exists in <from> */
%local i i_ds;
%do i = 1 %to %sysfunc(countw(&datasets, %str( )));
  %let i_ds = %scan(&datasets, &i, %str( ));
  %if %sysfunc(fileexist(&from\&i_ds..sas7bdat)) = 0 %then %do;
    %put ERROR: Specified <datasets> dataset "&i_ds" does not exist in <from> directory!;
    %goto end_of_macro;
  %end;
%end;

/* replace: check parameter has valid value. */          
%if %eval(&replace in n y) = 0 %then %do;
  %put ERROR: <replace> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: replace = y (Yes);
  %put ERROR: replace = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

/* convert_dates: check parameter has valid value. */          
%if %eval(&convert_dates in n y) = 0 %then %do;
  %put ERROR: <convert_dates> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: convert_dates = y (Yes);
  %put ERROR: convert_dates = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

/* del: check parameter has valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = y (Yes);
  %put ERROR: del = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;


/*******************************************************************************
EXPORT DATA
*******************************************************************************/

%if &replace = y %then %let replace = replace;
%else %if &replace = n %then %let replace = ;

%local i i_ds i_from i_to j j_var;

%let n_ds = %sysfunc(countw(&datasets, %str( )));
%do i = 1 %to &n_ds;
  %let i_ds = %scan(&datasets, &i, %str( ));
  %let i_from = &from\&i_ds..sas7bdat;
  %let i_to = &to\&i_ds..csv;

  %put export_to_csv: &i/&n_ds Exporting &i_ds;

  /* Identify date variables */
  proc contents data = "&i_from"(obs = 0) noprint out = __ed_info1;
  run;

  data __ed_info2;
    set __ed_info1;
    date_var = 0;
    if type = 1 and format in: ("DATE" "YYMMDD" "DDMMYY"  "MMDDYYD")
      then __date_var = 1;
    keep libname memname name __date_var;
  run;

  %local all_var date_var;
  proc sql noprint;
    select name into :date_var separated by " "
      from __ed_info2
      where __date_var = 1;
    select name into :all_var separated by " "
      from __ed_info2;
  quit;
  %if &verbose = y %then %do;
    %put export_to_csv: all variables: &all_var;
    %put export_to_csv: Identified date variables: &date_var;
  %end;

  data __ed_dat;
    /* Retain all variables to make sure column order is the same when
    date variable formats are updated */
    retain &all_var;
    %if &convert_dates = y %then %do;
      %do j = 1 %to %sysfunc(countw(&date_var, %str( )));
        %let j_var = %scan(&date_var, &j, %str( ));
        format &j_var yymmdd10.;
      %end;
    %end;
    set "&i_from";
  run;

  options nosource;
  proc export data = __ed_dat outfile = "&i_to" dbms = csv &replace;
  run;
  options &opt_source;
%end;

%end_of_macro:

/* Delete temporary datasets created by the macro, also when 
"del" has not be specified as either y or n. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __ed_:;
  run;
  quit;
%end;

/* Restore value of notes option */
options &opt_notes;

%put export_to_csv: end execution   (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

%mend export_to_csv;
