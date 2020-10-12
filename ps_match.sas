/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.1.3
********************************************************************************
DESCRIPTION:
Propensity score (ps) pair matching using nearest neighbor matching 
with a caliper.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros

DETAILS:
By default the matching is done on the logit of the ps using a caliper 
corresponding to 0.2 times the standard deviation of the logit of the ps, as
this has been shown to perform well in various scenarios. For more info, see

Austin, P. C. (2011). Optimal caliper widths for propensity-score matching when 
estimating differences in means and differences in proportions in observational 
studies.
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:        (libname.)member-name of input dataset with treated/exposed and 
              untreated/unexposed patients.
out_pf:       (libname.)member-name prefix of output datasets. The following
              datasets are created by the macro:
              - <out_pf>_matches: matched population. 
              - <out_pf>_no_matches: information on patients for which 
              no match could be found.
              - <out_pf>_info: miscellaneous information and diagnostics of 
              the matching procedure.
group_var:    Grouping variable. Must be anumeric variable taking 0/1 values.
              Matching is done for each observation with <group_var> = 1, usually
              the treated/exposed patients.
ps_var:       Name of ps variable. Must be a numeric variable where
              0 < ps_var < 1 for all patients.
*** OPTIONAL ***
match_on:     Should matching be done on the ps or logit(ps)?
              - ps: match_on = ps
              - logit(ps): match_on = logit_ps (default)
caliper:      Caliper width used in matching. By default (caliper = auto), the 
              caliper is chosen as described in the details above. Otherwise,
              a postive number can be specified to be used as a caliper (fixed
              across by-variables).
replace:      Match with or without replacement?
              - With replacement: replace = y (default)
              - Without replacement: replace = n.
match_order:  In what order is matching to be done?
              Random order: order = rand (default)
              Data order: order = asis       
where:        Condition(s) used to to restrict the input dataset in a where-
              statement. Use the %str function as a wrapper, eg 
              where = %str(var = "value").
by:           Space-separated list of by-variables. Default is by = _null_,
              ie no by-variables.    
print_notes:  Print notes in log?
              - Yes: print_notes = y
              - No:  print_notes = n (default)
verbose:      Print info on what is happening during macro execution
              to the log?
              - Yes: verbose = y
              - No:  verbose = n (default)
seed:         Seed used for random number generation. Default is seed = 0,
              ie a random seed is used.        
del:          Delete intermediate datasets created by the macro:
              - Yes: del = y (default)
              - no:  del = n            
******************************************************************************/
%macro ps_match(
  in_ds       = ,
  out_pf      = ,
  group_var   = ,
  ps_var      = ,
  match_on    = logit_ps,
  caliper     = auto,
  replace     = y,
  match_order = rand,
  where       = %str(),
  by          = _null_,
  print_notes = n,
  verbose     = n,
  seed        = 0,
  del         = y
) / minoperator mindelimiter = ' ';

%put ps_match: start execution;

/* Find value of notes option, save it, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;

/* Make sure there are no intermediate dataset from from a previous 
run of the macro in the work directory before execution. */
proc datasets nolist nodetails;
  delete __ps_:;
run;
quit;


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
  %goto end_of_macro;  
%end;

%if &verbose = y %then %do;
  %put ps_match: *** Input checks ***;
%end;

/* print_notes: check parameter not empty. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> not specified!;
  %goto end_of_macro;  
%end;

/*print_notes: check parameter has valid value. */
%if (&print_notes in y n) = 0 %then %do;
  %put ERROR: <print_notes> does not have a valid value!;
  %goto end_of_macro;  
%end;

%if &print_notes = y %then %do;
  options notes;
%end;   
    
/* Check remaining macro parameters (except where) not empty. */
%local parms i i_parm;
%let parms =  in_ds out_pf group_var ps_var match_on caliper replace 
              match_order by seed del;   
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
data __ps_in_ds_var_names;
  set &in_ds.(obs = 0);
run;

%local in_ds_var_names;
proc sql noprint;
  select lower(name) into: in_ds_var_names separated by " "
  from sashelp.vcolumn
  where libname = "WORK" and memname = "__PS_IN_DS_VAR_NAMES"
    and name eqt "__";
quit;

%local i i_var;
%do i = 1 %to %sysfunc(countw(&in_ds_var_names, %str( )));
  %let i_var = %scan(&in_ds_var_names, &i, %str( ));
  %put ERROR: Input dataset <in_ds> contains variable "&i_var".;
  %put ERROR: All variables with a "__" prefix are protected variable names.;
  %put ERROR: The input dataset is not allowed contain any such variables;
  %put ERROR: to ensure that the macro will work as intended.;
  %goto end_of_macro; 
%end;

/* Check specified variable names are valid and exists in the input data. */
%local var_list i i_var j j_var ds_id rc;
%let var_list = group_var ps_var;
%if &by ne _null_ %then %let var_list = &var_list by;
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(nvalid(&j_var)) = 0 %then %do;
      %put ERROR: Variable "&j_var" specified in <&i_var>;
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
    %let ds_id = %sysfunc(open(&in_ds));
    %if %sysfunc(varnum(&ds_id, &j_var)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable "&j_var" specified in <&i_var> does;
      %put ERROR: not exist in the input dataset "&in_ds"!;
      %goto end_of_macro; 
    %end;
    %let rc = %sysfunc(close(&ds_id));
  %end; /* End of j-loop */
%end; /*End of i-loop */

/* Outcome dataset prefix needs to be a valid (libname.)member-name, where
the member-name part can be 21 characters at the most, to make sure that
the suffixes added to the prefix does not make the output dataset names exeed
32 characters.
Regular expression: (lib-name.)member-name, where the libname is
optional. The libname must start with a letter, followed by 0-7 letters, 
numbers or underscores and must end with a ".". Member-name part must start
with a letter or underscore, and is followed by 0-20 letters, numbers or 
underscores. The whole regular expression is case-insensitive. */
%if %sysfunc(prxmatch('^([a-z][\w\d]{0,7}\.)*[\w][\w\d]{0,20}$', &out_pf)) = 0 
  %then %do;
  %put ERROR: Output dataset prefix specified in <out_pf> is invalid.;
  %put ERROR: Must be speficied as (libname.)member-name and can only be 21 characters long at most!;
  %goto end_of_macro; 
%end;

/* group_var: check only one variable specified. */
%if %eval(%sysfunc(countw(&group_var, %str( ))) > 1) %then %do;
  %put ERROR: Only one <group_var> variable can be specified!;
  %goto end_of_macro;
%end;

/* group_var: check numerical variable. */
%local group_var_vt;
data _null_;
  set &in_ds(obs = 1 keep = &group_var);
  call symput("group_var_vt", vtype(&group_var));
run;

%if &group_var_vt ne N %then %do;
  %put ERROR: <group_var> must be a numerical variable!;
  %goto end_of_macro;
%end;

/* group_var: check no missing values. */
%local group_var_nmiss;
proc sql noprint;
  select nmiss(&group_var) into :group_var_nmiss
  from &in_ds;
quit;
%if &group_var_nmiss > 0 %then %do;
  %put ERROR: <group_var> has missing values!;
  %goto end_of_macro;
%end;

/* group_var: check variable has at most two values. */
%local group_var_nval;
proc sql noprint;
  select count(distinct &group_var) into :group_var_nval 
    from &in_ds;
quit;

%if %eval(&group_var_nval > 2) %then %do;
  %put ERROR: The variable "&group_var" specified in <group_var> takes more;
  %put ERROR: than two different values!;
  %goto end_of_macro; 
%end;

/* group_var: check only 0/1 values. */
%local group_var_min group_var_max;
proc sql noprint;
  select min(&group_var), max(&group_var) 
  into 
  :group_var_min, :group_var_max
  from &in_ds;
quit;

%if (&group_var_min in 0 1) = 0 or (&group_var_max in 0 1) = 0 %then %do;
  %put ERROR: <group_var> can only take 0/1 values!;
  %goto end_of_macro;
%end;

/* ps_var: check only one variable specified. */
%if %eval(%sysfunc(countw(&ps_var, %str( ))) > 1) %then %do;
  %put ERROR: Only one <ps_var> variable can be specified!;
  %goto end_of_macro;
%end;

/* ps_var: check numerical variable. */
%local ps_var_vt;
data _null_;
  set &in_ds(obs = 1 keep = &ps_var);
  call symput("ps_var_vt", vtype(&ps_var));
run;

%if &ps_var_vt ne N %then %do;
  %put ERROR: <ps_var> must be a numerical variable!;
  %goto end_of_macro;
%end;

/* ps_var: check no missing values. */
%local ps_var_nmiss;
proc sql noprint;
  select nmiss(&ps_var) into :ps_var_nmiss
  from &in_ds;
quit;

%if &ps_var_nmiss > 0 %then %do;
  %put ERROR: <ps_var> has missing values!;
  %goto end_of_macro;
%end;

/* ps_var: check only values in (0;1). */
%local ps_var_min ps_var_max;
proc sql noprint;
  select min(&ps_var), max(&ps_var) 
  into 
  :ps_var_min, :ps_var_max
  from &in_ds;
quit;

%if %eval(&ps_var_min <= 0 or &ps_var_max >= 1) %then %do;
  %put ERROR: <ps_var> takes values outside the interval (0%str(;)1)!;
  %goto end_of_macro;
%end;

/* match_on: check valid value */
%if (&match_on in ps logit_ps) = 0 %then %do;
  %put ERROR: <match_on> does not have a valid value!;
  %goto end_of_macro;
%end;

/* caliper: check value is auto or a positive number. 
/* Check that the parameter is either auto or a (decimal) number. */
%if %sysfunc(prxmatch('^auto$|^(\d+.)\d+$', &caliper)) = 0 %then %do;
  %put ERROR: <caliper> must take the value "auto" or a be a positive number!;
  %goto end_of_macro; 
%end;
/* Make sure that specified numbers are positive */
%else %if %sysfunc(prxmatch('^(\d+.)\d+$', &caliper)) %then %do;
  %if %sysevalf(&caliper <= 0) %then %do;
    %put ERROR: <caliper> must take the value "auto" or a be a positive number!;
    %goto end_of_macro; 
  %end;
%end;

/* replace: check valid value */
%if (&replace in y n) = 0 %then %do;
  %put ERROR: <replace> does not have a valid value!;
  %goto end_of_macro;
%end;

/* match_order: check valid value. */
%if (&match_order in rand asis) = 0 %then %do;
  %put ERROR: <match_order> does not have a valid value!;
  %goto end_of_macro;
%end;

/* by: check no duplicates. */
%local i i_var j cnt;
%do i = 1 %to %sysfunc(countw(&by, %str( )));
  %let i_var = %scan(&by, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&by, %str( )));
    %if &i_var = %scan(&by, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in <by>;
    %goto end_of_macro;
  %end;
%end;

/* seed: check integer. */
%if %sysfunc(prxmatch('^-*\d*$', &seed)) = 0 %then %do;
  %put ERROR: <seed> must be an integer!;
  %goto end_of_macro; 
%end;

/* del: check parameter has valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> does not have a valid value!;
  %goto end_of_macro;
%end;


/*******************************************************************************  
LOAD INPUT DATA
*******************************************************************************/

%if &verbose = y %then %do;
  %put ps_match: *** Load data ***;
%end;

data __ps_dat1;
  call streaminit(&seed);
  set &in_ds;
  where &where;
  __id = _n_;
  /* Add a very small number to the ps. This will ensure that if multiple
  observations have the same ps value, a random match will be made among
  all observations with the same ps. */
  __ps = &ps_var + rand("uniform") * 10**(-10);
  /* Make sure that the modified ps does not violate the 0 < ps < 1
  requirement. */
  __ps = min(1 - 10**(-10), __ps);
  __ps = max(0 + 10**(-10), __ps);
  /* If matching is done on logit(ps), transform the __ps variable. */
  %if &match_on = logit_ps %then %do;
    __ps = log(__ps / (1 - __ps));
  %end;
  __rand_order = rand("uniform");
  %if &by = _null_ %then %do;
    __by_dummy = "dummy";
  %end;
run;

%if &by = _null_ %then %let by = __by_dummy;

/* If the specified where condition(s) results in any warnings or errors,
the macro is terminated. */
%if &syserr ne 0 %then %do;
  %put ERROR- The specified <where> condition:;
  %put ERROR- &where;
  %put ERROR- produced a warning or an error. Macro terminated!;
  %goto end_of_macro; 
%end;

/* Make a combined by-variable */
proc sort data = __ps_dat1(keep = &by) out = __ps_by_key1 nodupkeys;
  by &by;
run;

data __ps_by_key2;
  set __ps_by_key1;
  __by = _n_;
run;

/* Save number of by-variable stratas in macro variable. */
%local n_strata;
proc sql noprint;
  select count(*) into :n_strata
    from __ps_by_key2;
quit;

/* Replace by-variables in data and restrict to the variables needed
to do the matching. */
%local i i_var;
proc sql;
  create table __ps_dat2 as
    select b.__by, a.&group_var, a.__id, a.__ps, a.__rand_order
    from __ps_dat1 as a
    left join
    __ps_by_key2 as b
    on
    %do i = 1 %to %sysfunc(countw(&by, %str( )));
      %let i_var = %scan(&by, &i, %str( ));
      %if &i ne 1 %then %do; and %end;
      a.&i_var = b.&i_var
    %end;
    ;
quit;

%if &verbose = y %then %do;
  %put ps_match: - Create an index for fast subsetting of data;
  %put ps_match:   during matching.;
%end;

/* Create index. */
proc sort data = __ps_dat2 out = __ps_dat3(index = (__by &group_var) drop = __rand_order);
	by __by &group_var  
    %if &match_order = rand %then %do; __rand_order %end;
    %else %do; __id %end;
  ;
run;


/*******************************************************************************  
CALCULATE CALIPER WIDTHS
*******************************************************************************/

%if &verbose = y %then %do;
  %put ps_match: *** Calculate calipers ***;
%end;
 
/* Calculate the caliper as described in the details if <caliper> = auto. */
proc means data = __ps_dat3 noprint nway;
  class __by &group_var;
  var __ps;
  output out = __ps_caliper1 var = __var / noinherit;
run;

data __ps_caliper2;
  set __ps_caliper1;
  by __by &group_var;
  retain __n_total __n_0 __n_1 __var_0 __var_1;
  if first.__by then do;
    __var_0 = __var;
    __n_0 = _freq_;
  end;
  else do;
    __var_1 = __var;
    __n_1 = _freq_;
  end;
  if last.__by then do;
    __n_total = max(__n_0, 0) + max(__n_1, 0);
    %if &caliper = auto %then %do;
      __caliper = 0.2 * sqrt((__var_0 + __var_1) / 2);
    %end;
    %else %do;
      __caliper = &caliper;
    %end;
    output;
  end;
  drop &group_var _type_ _freq_;
run;

/* Make macro variable with caliper values for each by strata */
%local calipers;
proc sql noprint;
  select __caliper into :calipers separated by "$"
    from __ps_caliper2;
quit;

%if &verbose = y %then %do;
  %put ps_match: - calipers:;
  %put ps_match:   &calipers;
%end;


/******************************************************************************
MATCHING
******************************************************************************/

%if &verbose = y %then %do;
  %put ps_match: *** Matching ***;
%end;

/* Find 10 approximately evenly spaced out strata values, and calculate the 
percentage of progress that have been made at that point in the matching 
process. */
data __ps_progress;
  do i = 1 to 10;
    progress_strata = ceil(i * &n_strata / 10);
    progress_pct = compress(put(progress_strata / &n_strata, percent10.));
    output;
  end;
  drop i;
run;

%local progress_strata progress_pct;
proc sql noprint;
  select distinct progress_strata, progress_pct
    into :progress_strata separated by "$" 
         ,:progress_pct separated by "$"
    from __ps_progress;
quit;

/* Disable notes in log irrespective of the value of the
print_notes parameter. */
options nonotes;

/* Find matches in each strata. */
%local i i_caliper;
%do i = 1 %to &n_strata;
  %let i_caliper = %scan(&calipers, &i, $);
  
  %if &i = 1 %then %do;
    %put Matching progress:;
    %put %sysfunc(datetime(), datetime32.): %str(  0%%);
  %end;

  %local time_start;
  %let time_start = %sysfunc(datetime());

  /* Restrict and split data. */
  data __ps_strata_group_1;
    set __ps_dat3(where = (__by = &i and &group_var = 1));
  run;

  data __ps_strata_group_0;
    set __ps_dat3(where = (__by = &i and &group_var = 0));
    rename 
      __ps = __ps_0
      __id = __id_0
    ;
  run;

  /* Find available memory in session. Taken from
  https://sasnrd.com/sas-available-memory/
  The xmrlmem option is undocumented, and I don't understand why
  10e6 and not 1024**3 is the proper denominator... But it is clear from
  testing that 1024**3 gives the wrong answer. */
  %local avail_mem;
  data _null_;
    call symput("avail_mem", input(getoption('xmrlmem'), 20.2) / 10e6);
  run;

  /* Find size of dataset that is to be loaded into a hash object. */
  %local size;
  proc sql noprint;
    select filesize / 1024**3 into :size
      from sashelp.vtable
      where libname = "WORK" and memname = "__PS_STRATA_GROUP_0";
  quit;

  %if &verbose = y %then %do;
    %put ps_match: - Strata: &i;
    %put ps_match:   Caliper: &i_caliper;
    %put ps_match:   Available memory: %left(%qsysfunc(putn(&avail_mem, 20.2))) GB;
    %put ps_match:   Size of hash object: %left(%qsysfunc(putn(&size, 20.2))) GB;
  %end;

  /* If the dataset can't fit in memory, terminate the macro. */
  %if %eval(&size > &avail_mem) %then %do;
    %put ERROR: Hash-table can%str(%')t fit in memory!;
    %put ERROR: Hash-table size: %left(%qsysfunc(putn(&size, 20.2))) GB;
    %put ERROR: Available memory: %left(%qsysfunc(putn(&avail_mem, 20.2))) GB;
    %goto end_of_macro;  
  %end;

  /* Find number of patients in strata. */
  %local n_strata_group_1 n_strata_group_0;
  proc sql noprint;
    select count(*) 
      into :n_strata_group_1
      from __ps_strata_group_1;
    select count(*) 
      into :n_strata_group_0
      from __ps_strata_group_0;
  quit;

  /* If there are patients in both groups in the strata, and the caliper
  is not missing, find matches for each patient with <group_var> = 1. */
  %if &i_caliper ne . and &n_strata_group_1 > 0 and &n_strata_group_0 > 0 
    %then %do;

    data __ps_strata_matches;
      length __ps_0 __closest_dist __closest_id __id_0 8;
      /* Load potential matches into hash object */
      if _n_= 1 then do;
        declare hash h( dataset: "__ps_strata_group_0");
        declare hiter iter("h");
        h.defineKey("__id_0");
        h.defineData("__id_0", "__ps_0");
        h.defineDone();
        call missing(__id_0, __ps_0);
      end;
      /* Open dataset with patients for which we want to find matches. */
      set __ps_strata_group_1;
      /* Iterate over the hash object to find the closest match. */
      __closest_dist = .;
      __rc= iter.first();
      do while (__rc = 0);
        if abs(__ps - __ps_0) <= &i_caliper then do;
          __dist = abs(__ps - __ps_0);
          if __closest_dist = . or __dist < __closest_dist then do;
            __closest_dist = __dist;
            __closest_id = __id_0;
          end;
        end; 
        __rc = iter.next();
        /* Output closest match. */
        if (__rc ~= 0) and __closest_dist ~= . then do;
          output;
          /* If matching without replacement, remove match from hash-table. */
          %if &replace = n %then %do;
            __rc1 = h.remove(key: __closest_id);
          %end;
        end;
      end;
      keep __by __id __closest_id;
    run;

    /* If the matching results in any warnings or errors,
    the macro is terminated. */
    %if &syserr ne 0 %then %do;
      %put ERROR- Matching resulted in a warning or error!;
      %put ERROR- Check the log for warnings/errors indicating that;
      %put ERROR- the hash-table could not fit in the memory.;
      %goto end_of_macro; 
    %end;
  %end;
  /* If a caliper is not defined in strata, or there are not patients in both
  groups, create an empty dataset. */
  %else %do;
    data __ps_strata_matches;
      set __ps_strata_group_1(obs = 0);
      length __closest_id 8;
      keep __by __id __closest_id;
    run;
  %end;

  /* In some weird cases, using proc append to automatically create the
  base dataset if it does not exist will fail. Therefore we will explictly
  define it here, to make sure everything works as intended. */
  %if &i = 1 %then %do;
    data __ps_all_matches1;
      set __ps_strata_matches;
    run;    
  %end;
  %else %do;
    /* Append matches from strata to dataset with all matches. */
    proc append base = __ps_all_matches1 data = __ps_strata_matches;
    run;
  %end;

  %local time_stop duration;
  %let time_stop = %sysfunc(datetime());
  %let duration = %sysevalf(&time_stop - &time_start);

  /* Estimate time until all matching is done, based on the median
  matching time in the stratas so far. */
  %local duration_all duration_median est_finish;
  %if &i = 1 %then %let duration_all = &duration;
  %else %let duration_all = &duration_all, &duration;
  %let duration_median = %sysfunc(median(&duration_all));
  %let est_finish = 
    %left(%qsysfunc(
      putn(
        %sysevalf(&time_stop + &duration_median * (&n_strata - &i)), 
        datetime32.
      )
    ));

  /* Make dataset with info */

  %local n_matches;
  proc sql noprint;
    select count(*) into :n_matches 
    from __ps_strata_matches;
  quit;

  data __ps_strata_info;
    retain __by __n_matches __n_group_1 __n_group_0 __n_total __caliper
           __time __start_time __stop_time;
    format __time time10. __start_time __stop_time datetime32.;
    __by = &i;
    __n_matches = &n_matches;
    __n_group_1 = max(0, &n_strata_group_1);
    __n_group_0 = max(0, &n_strata_group_0);
    __n_total = __n_group_1 + __n_group_0;
    __caliper = &i_caliper;
    __start_time = &time_start;
    __stop_time = &time_stop;
    __time = &duration;
    output;
  run;

  %if &i = 1 %then %do;
    data __ps_all_info1;
      set __ps_strata_info;
    run;    
  %end;
  %else %do;
    /* Append matches from strata to dataset with all matches. */
    proc append base = __ps_all_info1 data = __ps_strata_info;
    run;
  %end;
 
  /* Print matching progress info to log. */
  %local j j_strata j_pct;
  %do j = 1 %to %sysfunc(countw(&progress_strata, $));
    %let j_strata = %scan(&progress_strata, &j, $);
    %let j_pct = %scan(&progress_pct, &j, $);
    %if &i = &j_strata %then %do;
      %if &i ne &n_strata %then %do;
        %put %sysfunc(datetime(), datetime32.): %str( &j_pct) (est. finish: &est_finish);
      %end;
      %else %do;
        %put %sysfunc(datetime(), datetime32.): &j_pct (est. finish: &est_finish);
      %end;
    %end;
  %end; /* End of j-loop */
%end; /* End of i-loop */

%if &print_notes = y %then %do;
  options notes;
%end;


/*******************************************************************************  
RESTRUCTURE AND SAVE MATCHED DATA
*******************************************************************************/ 
 
%if &verbose = y %then %do;
  %put ps_match: *** Make matches output ***;
%end;

data __ps_all_matches2;
  set __ps_all_matches1;
  __match = _n_;
  &group_var = 1;
  output;
  &group_var = 0;
  __id = __closest_id;
  output;
  drop __closest_id;
run;

/* Merge with variables from input data */
proc sql;
  create table __ps_all_matches3 as
    select a.__match, b.*
      from __ps_all_matches2 as a
      left join __ps_dat1 as b
      on 
      a.__id = b.__id
      order by __match, &group_var descending;
quit;

data &out_pf._matches;
  set __ps_all_matches3;
  %if &by = __by_dummy %then %do;
    drop __by_dummy;
  %end;
  drop __id __ps __rand_order;
run;

/*******************************************************************************  
MAKE NON-MATCHED OUTPUT DATA
*******************************************************************************/ 

%if &verbose = y %then %do;
  %put ps_match: *** Make non-matches output ***;
%end;

/* Merge matched id's to patients pre matching */
proc sql;
  create table __ps_no_matches1 as 
    select a.*, b.__id as __id_match
    from __ps_dat1(where = (&group_var = 1)) as a
    left join
    __ps_all_matches1 as b
    on a.__id = b.__id;
quit;

/* Restrict to treated patients not included in the matched data. */
data &out_pf._no_matches;
  set __ps_no_matches1;
  where __id_match = .;
  drop __id __id_match __ps __rand_order;
  %if &by = __by_dummy %then %do; drop __by_dummy; %end;
run;
  

/*******************************************************************************  
MAKE INFO OUTPUT DATA
*******************************************************************************/ 

%if &verbose = y %then %do;
  %put ps_match: *** Make info output ***;
%end;

/* Merge by-variables to info */
%local i i_var;
proc sql;
  create table __ps_all_info2 as
    select 
    %do i = 1 %to %sysfunc(countw(&by, %str( )));
      %let i_var = %scan(&by, &i, %str( ));
      b.&i_var,
    %end;
    a.*
    from __ps_all_info1 as a
    left join
    __ps_by_key2 as b
    on a.__by = b.__by;
quit;

data &out_pf._info;
  set __ps_all_info2;
  drop __by;
  %if &by = __by_dummy %then %do; drop __by_dummy; %end;
run;


%end_of_macro:

/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __ps_:;
  run;
  quit;
%end; 

/* Restore value of notes option */
options &opt_notes;

%put ps_match: end execution;

%mend ps_match;
