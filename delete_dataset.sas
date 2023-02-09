/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.0.1
********************************************************************************
DESCRIPTION:

Utility macro for flexibly deleting datasets

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** OPTIONAL ***
libname:      Space-separated list of libnames in which datasets are to be
              deleted. 
dataset:      Space-separated list of datasets in <libname> to delete.
              Case-insensitive.
pattern:      Space-separated list of Perl regular expressions used to
              identify datasets in <libname> to delete.
              List of dataset names searched for the specified patterns are
              given in all lowercase, ie either specify patterns in lowercase
              or use the /i modifier to make the pattern case-insensitive.
print_notes:  Print notes in log?
              - Yes: print_notes = y
              - No:  print_notes = n (default)
verbose:      Print info on what is happening during macro execution
              to the log:
              - Yes: verbose = y (default)
              - No:  verbose = n
del:          Delete intermediate datasets created by the macro:
              - Yes: del = y (default)
              - no:  del = n              
******************************************************************************/
%macro delete_dataset(
  libname = work,
  dataset = _null_,
  pattern = _null_,
  print_notes = n,
  verbose = y,
  del = y
) / minoperator mindelimiter = ' ';

%put delete_dataset: start execution %sysfunc(compress(%sysfunc(datetime(), datetime32.)));

/* Save value of notes option, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;


/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/

/*** verbose ***/

/* Check <verbose> has a valid value. */
%if &verbose = %then %do;
  %put ERROR: Macro parameter <verbose> not specified!;
  %goto end_of_macro;  
%end;
%else %if (&verbose in y n) = 0 %then %do;
  %put ERROR: <verbose> = &verbose is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: verbose = n;
  %put ERROR: verbose = y;
  %goto end_of_macro;  
%end;


/*** print_notes ***/

/* Check <print_notes> has a valid value. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> not specified!;
  %goto end_of_macro;  
%end;
%else %if (&print_notes in y n) = 0 %then %do;
  %put ERROR: <print_notes> = &print_notes is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: print_notes = n;
  %put ERROR: print_notes = y;
  %goto end_of_macro;  
%end;
%else %if &print_notes = y %then %do;
  options notes;
%end;


/*** libname ***/

/* Check that <libname> is specified */
%if &libname = %then %do;
  %put ERROR: Macro parameter <libname> not specified!;
  %goto end_of_macro;  
%end;


/*** del ***/

/* Check valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> = &del is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = n;
  %put ERROR: del = y;
  %goto end_of_macro;
%end;


/*******************************************************************************
FIND DATASETS
*******************************************************************************/

/* Quote libnames */
%let libname = %sysfunc(prxchange(s/(\w+)/"$1"/, -1, &libname));

/* Find all datasets in the specified directories, making sure to make exceptions
for the datasets created by the macro. */
data __dd_list;
  set sashelp.vmember;
  where lowcase(libname) in (%lowcase(&libname)) and lowcase(memtype) = "data"
    and lowcase(memname) not in ("__dd_list");
  libname = lowcase(libname);
  memname = lowcase(memname);
  keep libname memname;
run;

/* Identify datasets to delete */
%local i i_val;
data __dd_list;
  set __dd_list;
  %if &dataset = _all_ %then %do;
    delete = 1;
  %end;
  %else %do;
    %do i = 1 %to %sysfunc(countw(&dataset, %str( )));
      %let i_val = %scan(&dataset, &i, %str( ));
      if memname = %lowcase("&i_val") then delete = 1;
    %end;
    %do i = 1 %to %sysfunc(countw(&pattern, %str( )));
      %let i_val = %scan(&pattern, &i, %str( ));
      %if &i_val ne _null_ %then %do;
        if prxmatch(&i_val, memname) then delete = 1;
      %end;
    %end;
  %end;
  if delete = 1 then output;
run;


/*******************************************************************************
DELETE DATASETS
*******************************************************************************/

%local ds_delete;
proc sql noprint;
  select compress(libname || "." || memname) into :ds_delete separated " "
    from __dd_list;
quit;

%if &verbose = y %then %do;
  %put Deleting %sysfunc(countw(&ds_delete, %str( ))) datasets:;
  %put &ds_delete;
%end;

%let libname = ;
proc sql noprint;
  select distinct libname into :libname separated " "
    from __dd_list;
quit;

%local i_libname;
%do i = 1 %to %sysfunc(countw(&libname, %str( )));
  %let i_libname = %scan(&libname, &i, %str( ));
  proc sql noprint;
    select distinct memname into :dataset separated " "
      from __dd_list
      where libname = "&i_libname";
  quit;

  %if &dataset ne %then %do;
    proc datasets library = &i_libname nolist nodetails;
      delete &dataset;
    run;
    quit;
  %end;
%end;


%end_of_macro:



/* Delete temporary datasets created by the macro */
%if &del ne n %then %do;
  proc datasets nolist nodetails;
    delete __dd_:;
  run;
  quit;
%end;

/* Restore value of notes option */
options &opt_notes;

%put delete_dataset: end execution   %sysfunc(compress(%sysfunc(datetime(), datetime32.)));

%mend delete_dataset;
