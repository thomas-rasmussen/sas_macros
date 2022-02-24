/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.0.1
********************************************************************************
DESCRIPTION:
Compress a dataset.

DETAILS:
Compressing is done using the COMPRESS dataset option. By default the type of
compression is automatically chosen based on the total record length of numeric
and character variables. By default, the dataet is only compressed if it results
in a smaller filesize. If not, the output dataset is set to the output dataset.
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:          (libname.)member-name of input dataset.
out_ds:         (libname.)member-name of output dataset.
*** OPTIONAL ***
compress:         How should the dataset be compressed using the COMPRESS 
                  dataset option?
                  - Automatically: compress = auto (default)
                  - No: compress = no
                  - Yes, use RLE: compress = char
                  - Yes, use RDC: compress = binary
                  See documentation for the dataset COMPRESS option for more
                  information on RLE and RDC compression. By default the
                  approach described under details is used to determine whether
                  what compression type is most likely the best to use. 
min_length:       Specify the minimal total record length of numeric/character
                  variables used to decide whether or not it is worth it to
                  compress the dataset, when compress = auto. By default, this
                  length is set to 0, ie always compress the dataset.
always_compress:  Should the dataset be compressed if it is larger than the 
                  uncompressed dataset?
                  - No: always_compress = n (default)
                  - Yes: always_compress = y
print_notes:      Print notes in log?
                  - Yes: print_notes = y
                  - No:  print_notes = n (default)
verbose:          Print info on what is happening during macro execution
                  to the log?
                  - Yes: verbose = y
                  - No:  verbose = n (default)
del:              Delete intermediate datasets created by the macro:
                  - Yes: del = y (default)
                  - no:  del = n   
******************************************************************************/
%macro compress(
  in_ds           = ,
  out_ds          = ,
  compress        = auto,
  min_length      = 0,
  always_compress = n,
  print_notes     = n,
  verbose         = n,
  del             = y
) / minoperator mindelimiter = ' ';


%put compress: start execution (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

/* Find value of notes option, save it, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
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
  %put compress: *** Input parameter checks ***;
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

/* Check remaining macro parameters (except where) not empty. */
%local parms i i_parm;
%let parms =  in_ds out_ds compress min_length always_compress del;   
%do i = 1 %to %sysfunc(countw(&parms, %str( )));
  %let i_parm = %scan(&parms, &i, %str( ));
  %if %bquote(&&&i_parm) = %then %do;
    %put ERROR: Macro parameter <&i_parm> not specified!;
    %goto end_of_macro;    
  %end;
%end;

/* in_ds: check input dataset exists. */
%if %sysfunc(exist(&in_ds)) = 0 %then %do;
  %put ERROR: Specified <in_ds> dataset "&in_ds" does not exist!;
  %goto end_of_macro;
%end;

/* compress: check parameter has valid value */
%if %eval(&compress in auto no char binary) = 0 %then %do;
  %put ERROR: <compress> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: compress = auto (default);
  %put ERROR: compress = no;
  %put ERROR: compress = char;
  %put ERROR: compress = binary;
  %put ERROR: See documentation for more information.;
  %goto end_of_macro;
%end;

/* min_length: check non-negative integer. */
%if %sysfunc(prxmatch('^\d+$', &min_length)) = 0 %then %do;
  %put ERROR: <min_length> must be a non-negative integer!;
  %goto end_of_macro; 
%end;

/* always_compress: check parameter has valid value. */          
%if %eval(&always_compress in n y) = 0 %then %do;
  %put ERROR: <always_compress> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: always_compress = n (No);
  %put ERROR: always_compress = y (Yes);
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
FIND TOTAL RECORD LENGTH
*******************************************************************************/

%if &verbose = y %then %do;
  %put compress: *** Find total record length ***;
%end;

proc contents data = &in_ds out = __c_contents noprint;
run;

proc means data = __c_contents nway noprint;
  class type;
  output out = __c_lengths sum(length) = sum_length;
run;


%local num_length char_length;
%let num_length = 0;
%let char_length = 0;

data _null_;
  set __c_lengths;
  if type = 1 then call symputx("num_length", sum_length);
  if type = 2 then call symputx("char_length", sum_length);
run;

%if &compress = auto %then %do;
  %if &num_length >= &min_length and &num_length > &char_length
    %then %let compress = binary;
  %else %if &char_length >= &min_length and &char_length >= &num_length
    %then %let compress = char;
  %else %let compress = no;
%end;

%if &verbose = y %then %do;
  %put compress: Numeric variables: &num_length;
  %put compress: Character variables: &char_length;
  %put compress: COMPRESS option set to: &compress;
%end;


/*******************************************************************************  
COMPRESS
*******************************************************************************/

%if &verbose = y %then %do;
  %put compress: *** Compress data ***;
%end;

data &out_ds(compress = &compress);
  set &in_ds;
run;


/*******************************************************************************  
SIZE OF INPUT AND OUTPUT DATASET
*******************************************************************************/

%if &verbose = y %then %do;
  %put compress: *** Find size ***;
%end;

/* Parse in- and -output dataset name into library and memname */
%local in_lib in_name out_lib out_name;
data _null_;
  length tmp lib name $100;
  /* parse input dataset */
  tmp = "&in_ds";
  lib_given = (index(tmp, ".") ne 0);
  if lib_given = 1 then do;
    lib = scan(tmp, 1, ".");
    name = scan(tmp, 2, ".");
  end;
  else do;
    lib = "work";
    name = "&in_ds";
  end;
  call symputx("in_lib", lowcase(lib));
  call symputx("in_name", lowcase(name));
  /* parse output dataset */
  tmp = "&out_ds";
  lib_given = (index(tmp, ".") ne 0);
  if lib_given = 1 then do;
    lib = scan(tmp, 1, ".");
    name = scan(tmp, 2, ".");
  end;
  else do;
    lib = "work";
    name = "&out_ds";
  end;
  call symputx("out_lib", lowcase(lib));
  call symputx("out_name", lowcase(name));
run;

%if &verbose = y %then %do;
  %put compress: parsed input lib: &in_lib;
  %put compress: parsed input name: &in_name;
  %put compress: parsed output lib: &out_lib;
  %put compress: parsed output name: &out_name;
%end;

/* Find size of dataets */
%local in_size out_size;
proc sql noprint;
  select filesize into: in_size
    from sashelp.vtable
    where lowcase(libname) = "&in_lib" and lowcase(memname) = "&in_name";
  select filesize into: out_size
    from sashelp.vtable
    where lowcase(libname) = "&out_lib" and lowcase(memname) = "&out_name";
quit;
%local in_size_format out_size_format;
%let in_size_format = %left(%qsysfunc(putn(&in_size, sizekmg.)));
%let out_size_format = %left(%qsysfunc(putn(&out_size, sizekmg.)));

/* Print info to log */
%put compress: input &in_lib..&in_name size - &in_size_format;
%put compress: output &out_lib..&out_name size - &out_size_format;

/* If the compressed dataset is larger than the uncompressed dataset, overwrite
the output dataset with the input dataset, and write note in log. */
%if &always_compress = n %then %do;
  %if %eval(&in_size < &out_size) %then %do;
    data &out_ds;
      set &in_ds;
    run;
    option &opt_notes;
    %put NOTE: Compressing &in_ds results in larger size. Dataset not compressed.;
    option nonotes;
  %end;
%end;

%end_of_macro:

/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __c_:;
  run;
  quit;
%end; 

/* Restore value of notes option */
options &opt_notes;

%put compress: end execution   (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

%mend compress;
