/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.1.1
********************************************************************************
DESCRIPTION:
Stratification and summarization of risk-time. By default, risk-time
is stratified according to age and calendar year, but this can be modified, and
stratification by other (constant) variables is also possible. 

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros


DETAILS:
Splitting up risk-time, eg when estimating standardized rates, is straight 
forward when the variables to standardize with respect to are treated as 
constant, eg gender. But usually, stratification by age and/or calendar-year is 
needed, and in this case of (monotonic) "time-dependent" variables the situation
is more complex. This macro facilitates splitting up and summarizing risk-time 
in this case, and can also be used to stratify by additional (constant)
variables.

By convention, if follow-up starts and end on the same day, that will count
as zero days of follow-up. Based on this convention, if follow-up ends on
the day after start of follow-up, that will count as one day of follow-up,
or alternatively as 1/365 or 1/366 years of follow-up depending on
whether or not the follow-up is in a leap-year or not. Expanding on this, if
a person starts follow-up on 2001-01-01, and ends follow-up on 2001-12-31, that
is 364 days or 364/365 years of follow-up, not 365 days or 1 year.

The macro was originally inspired by 
Macaluso M. "Exact stratification of person-years". Epidemiology. 1992 
doi: 10.1097/00001648-199209000-00010.
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:          (libname.)member-name of input dataset.
out_ds:         (libname.)member-name of output dataset.

*** OPTIONAL ***
birth_date:     Name of variable in <in_ds> with the birth date of the person.
                Must be a numeric variable with a format that is recognized
                by the macro as a date format, eg the DATEw. format. Unformatted 
                variables are also permitted as a fall-back solution.
                Note that a valid birth_date variable must be provided even if
                stratification by age is not done!
fu_start:       Name of variable in <in_ds> with the date of start of follow-up.
                Must be a numeric variable with a format that is recognized
                by the macro as a date format, eg the DATEw. format. Unformatted 
                variables are also permitted as a fall-back solution.
fu_end:         Name of variable in <in_ds> with the date of end of follow-up.
                Must be a numeric variable with a format that is recognized
                by the macro as a date format, eg the DATEw. format. Unformatted 
                variables are also permitted as a fall-back solution.
risk_time_unit: Specify the unit the summarized risk-time is reported in.
                - Years: risk_time_unit = years (default)
                - Days: risk_time_unit = days
                If <stratify_by> includes _year_ (see below), then leap-years
                are taken into account in an exact manner. If <stratify_by> 
                does not include _year_ then the risk_time in days is simply 
                divided by 365.25.
where:          Condition(s) used to to restrict the input dataset in a where-
                statement. Use the %str function as a wrapper, eg 
                where = %str(var = "value").
stratify_by:    Space-separated list of variables to stratify by. 
                Default is stratify_by = _year_ _age_, meaning that
                stratification is done with respect to calender year and
                age. Additional (constant) variables can be added to the list,
                and/or _year_/_age_ can be removed from the list. Finally,
                stratify_by = _null_ can be used if no stratification is needed
                and we just want to summarize all person-time.
max_ite:        Maximum number of iterations allowed when splitting risk-time
                according to time-dependent variables.
                Used to ensure infinite loops will not occur. Default value
                is max_ite = _auto_, meaning that max_ite is automatically
                set to a reasonable value depending on what variables are
                specified in <stratify_by>:
                - <stratify_by> includes both _year_ and _age_: max_ite = 40000
                - <stratify_by> includes _year_ or _age_: max_ite = 200
                - <stratify_by> is empty or only includes constant variables:
                  max_ite = 1.
                The maximum can be interpreted as the maximum number of 
                stratas allowed when splitting risk-time. for example if
                we are stratifying with respect to both calender year and age
                and a person had 200 * 200 = 40,000 age/year stratas this would
                be an indication of erroneous dates in the input dataset, since
                we would not expect a person to live 200 years. Likewise, if
                no time-dependent stratification is to be done, we do not need
                to split up the person-time at all.
                If needed, max_ite can also be specified as an integer value.
print_notes:    Print notes in log?
                - Yes: print_notes = y
                - No:  print_notes = n (default)
verbose:        Print info on what is happening during macro execution
                to the log?
                - Yes: verbose = y
                - No:  verbose = n (default)
del:            Delete intermediate datasets created by the macro:
                - Yes: del = y (default)
                - no:  del = n   
******************************************************************************/
%macro risk_time(
  in_ds           = ,
  out_ds          = ,
  birth_date      = birth_date,
  fu_start        = fu_start,
  fu_end          = fu_end,
  risk_time_unit  = years,
  where           = %str(),
  stratify_by     = _year_ _age_,
  max_ite         = _auto_,
  print_notes     = n,
  verbose         = n,
  del             = y
) / minoperator mindelimiter = ' ';


%put risk_time: start execution (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

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
  %put risk_time: *** Input parameter checks ***;
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
%let parms =  in_ds out_ds birth_date fu_start fu_end
              risk_time_unit stratify_by max_ite del;   
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

/* in_ds: check input dataset not empty. */
%local ds_id rc;
%let ds_id = %sysfunc(open(&in_ds));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Specified <in_ds> dataset "&in_ds" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* in_ds: check that the input dataset has no variables with a "__" prefix. */
proc contents data = &in_ds(obs = 0) noprint 
  out = __rt_in_ds_var_names(keep = name);
run;

%local in_ds_var_names;
proc sql noprint;
  select lower(name) into: in_ds_var_names separated by " "
  from __rt_in_ds_var_names
  where name eqt "__";
quit;

/* stratify_by: check no duplicates. */
%local i i_var j cnt;
%do i = 1 %to %sysfunc(countw(&stratify_by, %str( )));
  %let i_var = %scan(&stratify_by, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&stratify_by, %str( )));
    %if &i_var = %scan(&stratify_by, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in <stratify_by>;
    %goto end_of_macro;
  %end;
%end;

/* Split &stratify_by into time-dependent (_year_ and _age_), and any additional 
(constant) variables that have been specified. */
%local stratify_by_td stratify_by_const i i_var;
%do i = 1 %to %sysfunc(countw(&stratify_by, %str( )));
  %let i_var = %scan(&stratify_by, &i, %str( ));
  %if &i_var in _year_ _age_ %then %let stratify_by_td = &stratify_by_td &i_var;
  %else %let stratify_by_const = &stratify_by_const &i_var;
%end;

%if &stratify_by_td = %then %let stratify_by_td = _null_;
%if &stratify_by_const = %then %let stratify_by_const = _null_;

%if &verbose = y %then %do;
  %put - stratify_by_td:    &stratify_by_td;
  %put - stratify_by_const: &stratify_by_const;
%end;

%local i i_var;
%do i = 1 %to %sysfunc(countw(&in_ds_var_names, %str( )));
  %let i_var = %scan(&in_ds_var_names, &i, %str( ));
  %if &i_var ne _null_ %then %do;
    %put ERROR: Input dataset <in_ds> contains variable "&i_var".;
    %put ERROR: All variables with a "__" prefix are protected variable names.;
    %put ERROR: The input dataset is not allowed to contain any such variables;
    %put ERROR: to ensure that the macro will work as intended.;
    %goto end_of_macro; 
  %end;
%end;

/* Check specified variable names are valid and exists in the input data. */
%local var_list i i_var j j_var ds_id rc;
%let var_list = birth_date fu_start fu_end;
%if &stratify_by_const ne _null_ 
  %then %let var_list = &var_list stratify_by_const;
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(nvalid(&j_var)) = 0 %then %do;
      %if &i_var = stratify_by_const %then %do;
        %put ERROR: Variable "&j_var" specified in <stratify_by>;
      %end;
      %else %do;
        %put ERROR: Variable "&j_var" specified in <&i_var>;
      %end;
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
    %let ds_id = %sysfunc(open(&in_ds));
    %if %sysfunc(varnum(&ds_id, &j_var)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %if &i_var = stratify_by_const %then %do;
        %put ERROR: Variable "&j_var" specified in <stratify_by> does;
      %end;
      %else %do;
        %put ERROR: Variable "&j_var" specified in <&i_var> does;
      %end;
      %put ERROR: not exist in the input dataset "&in_ds"!;
      %goto end_of_macro; 
    %end;
    %let rc = %sysfunc(close(&ds_id));
  %end; /* End of j-loop */
%end; /*End of i-loop */

/* birth_date: check only one variable specified */
%if %sysevalf(%sysfunc(countw(&birth_date, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in <birth_date>!;
  %goto end_of_macro;
%end;

/* fu_start: check only one variable specified */
%if %sysevalf(%sysfunc(countw(&fu_start, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in <fu_start>!;
  %goto end_of_macro;
%end;

/* fu_end: check only one variable specified */
%if %sysevalf(%sysfunc(countw(&fu_end, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in <fu_end>!;
  %goto end_of_macro;
%end;

/* risk_time_unit: check parameter has valid value. */          
%if %eval(&risk_time_unit in years days) = 0 %then %do;
  %put ERROR: <risk_time_unit> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: risk_time_unit = years;
  %put ERROR: risk_time_unit = days;
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

/* max_ite: check that max_ite = _auto_ or positive integer. 
/* Regular expression: is _auto_, or starts with a number 1-9, followed by, 
and ends with, one or more digits (so that 0 is not allowed, but eg 10 is). */
%if %sysfunc(prxmatch('^_auto_$|^[1-9]\d*$', &max_ite)) = 0 %then %do;
  %put ERROR: <max_ite> must be a positive integer!;
  %goto end_of_macro; 
%end;
/* max_ite: if max_ite = _auto_ change to appropriate value */
%if &max_ite = _auto_ %then %do;
  %if %sysfunc(countw(&stratify_by_td, %str( ))) = 2 
    %then %let max_ite = 40000;
  %else %if &stratify_by_td = _age_ or &stratify_by_td = _year_ 
    %then %let max_ite = 200;
  %else %let max_ite = 1;
%end;

%if &verbose = y %then %do;
  %put - max_ite: &max_ite;
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
LOAD INPUT DATA
*******************************************************************************/

%if &verbose = y %then %do;
  %put risk_time: *** Load data ***;
%end;

data __rt_dat1;
  set &in_ds;
  where &where;
run;

/* If the specified where condition(s) results in any warnings or errors,
the macro is terminated. */
%if &syserr ne 0 %then %do;
  %put ERROR- The specified <where> condition:;
  %put ERROR- &where;
  %put ERROR- produced a warning or an error. Macro terminated!;
  %goto end_of_macro; 
%end;


/*******************************************************************************  
INPUT DATA CHECKS 
*******************************************************************************/

%if &verbose = y %then %do;
  %put risk_time: *** Input data checks ***;
%end;

/* Restrict input data to relevant variables */
data __rt_dat2;
  set __rt_dat1;
  rename
    &fu_start = __fu_start
    &fu_end = __fu_end
    &birth_date = __birth_date
  ;
  keep &birth_date &fu_start &fu_end;
  %if &stratify_by_const ne _null_ %then %do;
    keep &stratify_by_const;
  %end;
run;


/* 
Check that the input data conforms to what would be expected of it:
  - fu_start, fu_end and birth_date are numeric variables with a 
    recognized date format
  - No missing fu_start values
  - No missing fu_end values
  - fu_start <= fu_end
  - No missing birth_date values
  - birth_date <= fu_start 
*/

proc contents data = __rt_dat2(obs = 0) noprint out = __rt_var_info1;
run;

%local  __fail_birth_is_num __fail_birth_is_date __fail_birth_format
        __fail_start_is_num __fail_start_is_date __fail_start_format
        __fail_end_is_num   __fail_end_is_date   __fail_end_format;

/* List of recognized date formats. This is probably not the best approach.
Revise in the future if it causes problems for users. */
%local date_formats;
%let date_formats = 
  "" "DATE" "E8601DA" "YYMMDD"
  "DDMMYY" "DDMMYYB" "DDMMYYC" "DDMMYYD" "DDMMYYN" "DDMMYYP" "DDMMYYS" 
  "DDMMYY" "EURDFDE" "EURDFWDX" "EURDFWKX" "MINGUO" "MMDDYY" "MMDDYYB" 
  "MMDDYYC" "MMDDYYD" "MMDDYYN" "MMDDYYP" "MMDDYYS"
;

data __rt_var_info2;
  set __rt_var_info1(
    keep = name type format
    where = (name in ("__birth_date" "__fu_start" "__fu_end"))
  );
  if name = "__birth_date" then do;
    call symput("__fail_birth_is_num", put((type = 1), 1.));
    call symput("__fail_birth_is_date", put((upcase(format) in (%upcase(&date_formats))), 1.));
    call symput("__fail_birth_format", format);
  end;
  if name = "__fu_start" then do;
    call symput("__fail_start_is_num", put((type = 1), 1.));
    call symput("__fail_start_is_date", put((upcase(format) in (%upcase(&date_formats))), 1.));
    call symput("__fail_start_format", format);
  end;
  if name = "__fu_end" then do;
    call symput("__fail_end_is_num", put((type = 1), 1.));
    call symput("__fail_end_is_date", put((upcase(format) in (%upcase(&date_formats))), 1.));
    call symput("__fail_end_format", format);
  end;
run;

%if &__fail_birth_is_num = 0 %then %do;
  %put ERROR: Variable "&birth_date" is not numeric;
  %goto end_of_macro;
%end;
%if &__fail_birth_is_date = 0 %then %do;
  %put ERROR: Variable "&birth_date" has format &__fail_birth_format..;
  %put ERROR: This format is not recognized as a date format by the macro.;
  %put ERROR: If the variable IS a date variable, use another date format;
  %put ERROR: recognized by the macro (eg DATEw.) or remove the current format.;
  %goto end_of_macro;
%end;
%if &__fail_start_is_num = 0 %then %do;
  %put ERROR: Variable "&fu_start" is not numeric;
  %goto end_of_macro;
%end;
%if &__fail_start_is_date = 0 %then %do;
  %put ERROR: Variable "&fu_start" has format &__fail_start_format..;
  %put ERROR: This format is not recognized as a date format by the macro.;
  %put ERROR: If the variable IS a date variable, use another date format;
  %put ERROR: recognized by the macro (eg DATEw.) or remove the current format.;
  %goto end_of_macro;
%end;
%if &__fail_end_is_num = 0 %then %do;
  %put ERROR: Variable "&fu_end" is not numeric;
  %goto end_of_macro;
%end;
%if &__fail_end_is_date = 0 %then %do;
  %put ERROR: Variable "&fu_end" has format &__fail_end_format..;
  %put ERROR: This format is not recognized as a date format by the macro.;
  %put ERROR: If the variable IS a date variable, use another date format;
  %put ERROR: recognized by the macro (eg DATEw.) or remove the current format.;
  %goto end_of_macro;
%end;


data __rt_check1;
  set __rt_dat2;
  __fail_birth_miss = (__birth_date = .);
  __fail_birth_gt_start = (__birth_date > __fu_start);
  __fail_fu_start_miss = (__fu_start = .);
  __fail_fu_end_miss = (__fu_end = .);
  __fail_start_gt_end = (__fu_start > __fu_end);

run;

proc means data = __rt_check1 noprint;
  output out = __rt_check2
    sum(__fail_:) = / noinherit autoname;
run;

%local 
  __fail_birth_miss_sum __fail_birth_gt_start
  __fail_fu_start_miss_sum __fail_fu_end_miss_sum 
  __fail_start_gt_end_sum
;

proc sql noprint;
  select __fail_birth_miss_sum into :__fail_birth_miss_sum
    from __rt_check2;
  select __fail_birth_gt_start_sum into :__fail_birth_gt_start_sum
    from __rt_check2;
  select __fail_fu_start_miss_sum into :__fail_fu_start_miss_sum
    from __rt_check2;
  select __fail_fu_end_miss_sum into :__fail_fu_end_miss_sum
    from __rt_check2;
  select __fail_start_gt_end_sum into :__fail_start_gt_end_sum
    from __rt_check2;
quit;

%let __fail_birth_miss_sum
  = %left(%qsysfunc(putn(&__fail_birth_miss_sum, comma12.)));
%let __fail_birth_gt_start_sum
  = %left(%qsysfunc(putn(&__fail_birth_gt_start_sum, comma12.)));
%let __fail_fu_start_miss_sum
  = %left(%qsysfunc(putn(&__fail_fu_start_miss_sum, comma12.)));
%let __fail_fu_end_miss_sum
  = %left(%qsysfunc(putn(&__fail_fu_end_miss_sum, comma12.)));
%let __fail_start_gt_end_sum
  = %left(%qsysfunc(putn(&__fail_start_gt_end_sum, comma12.)));

 
%if &verbose = y %then %do;
  %put - Missing &birth_date values:         &__fail_birth_miss_sum;
  %put - Cases where &birth_date > &fu_start: &__fail_birth_gt_start_sum;
  %put - Missing &fu_start values:           &__fail_fu_start_miss_sum;
  %put - Missing &fu_end& values:             &__fail_fu_end_miss_sum;
  %put - Cases where &fu_start > &fu_end:     &__fail_start_gt_end_sum;
%end;

%if &__fail_birth_miss_sum > 0 %then %do;
  %put ERROR: Variable "&birth_date" has &__fail_birth_miss_sum;
  %put ERROR: missing values. Missing values are not allowed.;
  %goto end_of_macro; 
%end;
%if &__fail_birth_gt_start_sum > 0 %then %do;
  %put ERROR: "&birth_date" > "&fu_start" in &__fail_birth_gt_start_sum cases.;
  %put ERROR: Birth date is not allowed to be after start of follow-up.;
  %goto end_of_macro; 
%end;
%if &__fail_fu_start_miss_sum > 0 %then %do;
  %put ERROR: Variable "&fu_start" has &__fail_fu_start_miss_sum;
  %put ERROR: missing values. Missing values are not allowed.;
  %goto end_of_macro; 
%end;
%if &__fail_fu_end_miss_sum > 0 %then %do;
  %put ERROR: Variable "&fu_end" has &__fail_fu_end_miss_sum;
  %put ERROR: missing values. Missing values are not allowed.;
  %goto end_of_macro; 
%end;
%if &__fail_start_gt_end_sum > 0 %then %do;
  %put ERROR: "&fu_start" > "&fu_end" in &__fail_start_gt_end_sum cases.;
  %put ERROR: Start of follow-up is not allowed to be after end of follow-up.;
  %goto end_of_macro; 
%end;

 

/*******************************************************************************  
STRATIFY PERSON TIME 
*******************************************************************************/

%if &verbose = y %then %do;
  %put risk_time: *** Stratify person time ***;
%end;

%local max_ite_reached;

/* Calculate risk-time in each strata specified in <stratify_by_td> for 
each person. */
data __rt_strat1;
	set __rt_dat2;
  format __current_date __next_event yymmdd10.;
  %if _age_ in &stratify_by_td %then %do;
    length _age_ 3.;
    format __current_age __event_birthday yymmdd10.;
  %end;
  %if _year_ in &stratify_by_td %then %do;
    length _year_ 3.;
    format __current_year __event_year yymmdd10.;
  %end;

  __cnt = 0;
  __stop = 0;

  %if _age_ in &stratify_by_td %then %do;
    __age_start = floor(yrdif(__birth_date, __fu_start, "age"));
    __current_age = __age_start;
  %end;
  __current_date = __fu_start;
  
  %if _year_ in &stratify_by_td %then %do;
  __current_year = year(__fu_start);
  %end;

  do while (__stop = 0);
    __cnt = __cnt + 1;

    /* Find next event: new year, birthday or end of follow_up */
    %if _year_ in &stratify_by_td %then %do;
      __event_year = mdy(1, 1, __current_year + 1);
    %end;
    %if _age_ in &stratify_by_td %then %do;
      __event_birthday = intnx("year", __birth_date, __current_age + 1, "same");
    %end;
    __next_event = min(
      __fu_end
      %if _year_ in &stratify_by_td %then %do;
        , __event_year
      %end;
      %if _age_ in &stratify_by_td %then %do;
        , __event_birthday
      %end;
    );

    /* Calculate risk-time in strata and output */
    %if _age_ in &stratify_by_td %then %do;
      _age_ = __current_age;
    %end;
    %if _year_ in &stratify_by_td %then %do;
      _year_ = __current_year;
    %end;
    __risk_time = __next_event - __current_date;
    %if &risk_time_unit = years and _year_ in &stratify_by_td %then %do;
      /* Determine if the current year is a leap year to correctly
      find the number of days in the year. */
      if 
        mod(__current_year, 4) = 0 and 
        (
          mod(__current_year, 100) ne 0 or
          mod(__current_year, 400) = 0
        )
        then __year_length = 366;
      else __year_length = 365;
      __risk_time = __risk_time / __year_length;
    %end;
    %else %if &risk_time_unit = years %then %do;
      __risk_time = __risk_time / 365.25;
    %end;
    output;

    /* Update variables */
    __current_date = __next_event;
    %if _year_ in &stratify_by_td %then %do;
      if (__next_event = __event_year) 
        then __current_year = __current_year + 1;
    %end;
    %if _age_ in &stratify_by_td %then %do;
      if (__next_event = __event_birthday) 
        then __current_age = __current_age + 1;
    %end;

    /* if fu_end is next event then exit loop */
    if __next_event = __fu_end then __stop = 1;

    /* Use max counter iterator to protect against infinite loops. */
    if __cnt > &max_ite then do;
      __stop = 1;
      call symput("max_ite_reached", "1");
    end;
  end; 

  keep __risk_time;
  %if &stratify_by ne _null_ %then %do;
    keep &stratify_by;
  %end;
run;

%if &max_ite_reached = 1 %then %do;
  %let max_ite = %left(%qsysfunc(putn(&max_ite, comma12.)));
  %put ERROR: There is more than &max_ite &stratify_by strata for;
  %put ERROR: one or more observations in the data. If this is reasonable;
  %put ERROR: adjust the <max_ite> macro parameter. Otherwise, this indicates;
  %put ERROR: that one or more observation has erroneous data in the specified;
  %put ERROR: variables.;
  %goto end_of_macro;
%end;
	
	
/*******************************************************************************  
SUMMARIZE PERSON TIME 
*******************************************************************************/

%if &verbose = y %then %do;
  %put risk_time: *** Summarize person time ***;
%end;

proc means data = __rt_strat1 nway noprint;
  %if &stratify_by ne _null_%then %do;
    class &stratify_by;
  %end;
  var __risk_time;
  output out = __rt_sum1(drop = _freq_ _type_)
    sum(__risk_time) = __risk_time;
run;


/*******************************************************************************  
MAKE OUTPUT DATA
*******************************************************************************/

%if &verbose = y %then %do;
  %put risk_time: *** Make output data ***;
%end;

data &out_ds;
  set __rt_sum1;
  /* If age/year/risk_time names are not used as input variable, use 
  these variable names in the output. If they were, add a "__" prefix to avoid
  name collisions. Note that technically we only need to check &stratify_by 
  variables since they are the only ones that are kept in the output,
  but we choose to include the other variables as well, since it could be 
  confusing if you had chosen to call the fu_start variable "age" in the input 
  data, but in the output data the variable would have another meaning. */
  %if (age in &birth_date &fu_start &fu_end &stratify_by) = 0 and
      _age_ in &stratify_by %then %do;
    rename _age_ = age;
  %end;
  %if (year in &birth_date &fu_start &fu_end &stratify_by) = 0 and
      _year_ in &stratify_by %then %do;
    rename _year_ = year;
  %end;
  %if (risk_time in &birth_date &fu_start &fu_end &stratify_by) = 0 %then %do;
    rename __risk_time = risk_time;
  %end;
run;


%end_of_macro:

/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __rt_:;
  run;
  quit;
%end; 

/* Restore value of notes option */
options &opt_notes;

%put risk_time: end execution   (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

%mend risk_time;
