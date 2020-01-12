/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.1.0
DATE:       2020-01-12
LICENCE:    Creative Commons CC0 1.0 Universal  
            (https://www.tldrlegal.com/l/cc0-1.0)
********************************************************************************
DESCRIPTION:
See examples for how to use the macro.

Developed using SAS 9.4.

Find the newest version of the macro and accompanying examples at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
NOTES:
Version 0.1.0:
- First initial attempt at making macro using a hash-table merge to do matching.
  Should work as intended, should be used with caution.
********************************************************************************
TODO:
- Formulas used to estimate the approximate number of iterations used in
  hash-table merge::
  https://math.stackexchange.com/questions/1155615/probability-of-picking-each-
  of-m-elements-at-least-once-after-n-trials 
  Seems to be working, but maybe look into the math.
- Documentation. See pt_char for inspiration.
- input tests. See pt_char for inspiration.
- tests of macro. See pt_char for inspiration.
- Macro should also produce a dataset with diagnostics of each strata, eg
  number of cases, control, max_ite_val, max_ite made to find all controls or
  other stat, and so on.
- Macro should also produce a list of ids and match var values, for which
  no matched could be found?
- Make by statement as in pt_char?
********************************************************************************
PARAMETERS:
*** REQUIRED ***

*** OPTIONAL ***

******************************************************************************/
%macro hash_match(
  in_ds = ,
  out_ds = ,
  id_var = ,
  index_date = ,
  match_vars = ,
  fu_start = ,
  fu_end = ,
  case_as_control = y,
  n_matches = 10,
  ite_max_val = 10**6,
  seed = 0,
  del = y
);

/* Save value of the NOTES option*/
%local opt_notes_value;
%let opt_notes_value = %sysfunc(getoption(notes));

data _null_;
  set &in_ds(obs = 1);
  %do i = 1 %to %sysfunc(countw(&match_vars, %str( )));
    %let i_var = %scan(&match_vars, &i, %str( )); 
    call symput("match_var_vt_&i", vtype(&i_var));
  %end;
run;

%do i = 1 %to %sysfunc(countw(&match_vars, %str( )));
  %let i_var = %scan(&match_vars, &i, %str( )); 
  %put &i_var var type: &&match_var_vt_&i;
%end;


data __hm_data1;
  set data1;
  __id = &id_var;
  __index = &index_date;
  __start = &fu_start;
  __end = &fu_end;
  __match_on =
  %do i = 1 %to %sysfunc(countw(&match_vars, %str( )));
    %let i_var = %scan(&match_vars, &i, %str( )); 
    %if &i = 1 %then %do;
      %if &&match_var_vt_&i = N %then %do;
        strip(put(&i_var, best12.))
      %end;
      %else %if &&match_var_vt_&i = C %then %do;
        strip(&i_var)
      %end;
    %end;
    %else %do;
      %if &&match_var_vt_&i = N %then %do;
        || "_" || strip(put(&i_var, best12.))
      %end;
      %else %if &&match_var_vt_&i = C %then %do;
        || "_" || strip(&i_var)
      %end;
    %end;
  %end;
  ;
  keep __: &match_vars;
run;

/* Create index. Read up on SAS options like ibufsize to see if something
could be tweaked. */
proc sort data = __hm_data1 out = __hm_data2(index = (__match_on));
	by __match_on;
run;
/*data __hm_data2;*/
/*  set __hm_data1;*/
/*run;*/


/* Find unique combinations of macthing variables values and save them
in macro variables. */
proc sort data = __hm_data2(keep = __match_on &match_vars) 
    out = __hm_match_values nodupkeys;
  by __match_on;
run;

proc sql noprint;
  select count(*) into :n_strata
    from __hm_match_values;
quit;

/* Make sure that there are no matched datasets from a previous run of
the macro in the work directory before we run the macro. */
proc datasets nolist nodetails;
  delete __hm_match1_:;
run;
quit;

/* Find matches for each value of the set of matching variables. */
options nonotes;
%do i = 1 %to &n_strata;
  proc sql noprint;
    select __match_on
      into :i_match_on
      from __hm_match_values(firstobs = &i obs = &i);
    %do j = 1 %to %sysfunc(countw(&match_vars, %str( ))); 
      %let j_var = %scan(&match_vars, &j, %str( ));
      select &j_var
      into : val_&j
      from __hm_match_values(firstobs = &i obs = &i);  
    %end;
  quit;
/*  %put Ite &i/%sysfunc(strip(&n_strata)): strata = &i_match_on;*/

  /* Restrict data strata. */
  data __hm_match_strata;
    set __hm_data2(keep = __:);
    where __match_on = "&i_match_on";
  run;

  /* Find cases in matching strata */
  data __hm_cases;
    set __hm_match_strata;
    where __start <= __index <= __end;
    drop __start __end;
  run;

  /* Make a dataset with potential controls, and add a
  variable with the observation number. */
  data __hm_controls(rename=(
          __id = __id_control
          __index = __index_control
          __start = __start_control
          __end = __end_control
          )); 
    set __hm_match_strata;
  %if &case_as_control = n %then %do;
    where __index = .;
  %end;
    format __obs 10.;
    __obs=_n_;
  run;

  /* Find number of cases and controls in strata. */
  proc sql noprint;
    select count(*) 
      into :n_cases
      from __hm_cases;
    select count(*) 
      into :n_controls
      from __hm_controls;
  quit;

/* Find controls for each case using a hash-table merge. */
%if &n_controls > 0 %then %do;
  data __hm_match1_&i;
  	call streaminit(&seed.);
  	length	__obs 8 __id_control $12 __index_control 8;
  	format	__match_id __obs 10. __id_control $12.
            __index_control date9.;
  	/* Load potential control dataset into the hash object */	
  	if _n_ = 1 then do;
  		declare hash h(dataset: "__hm_controls");
  		declare hiter iter("h");
  		h.defineKey("__obs");
  		h.defineData(
  			"__obs", "__id_control", "__index_control", "__start_control",
        "__end_control"
  			);
  		h.defineDone();
  		call missing(
  			__obs, __id_control, __index_control, __start_control, __end_control
  			);

      /* make match id. We need this later while restructuring the matched datat
      to handles cases wher the same person is included multiple times as a case
      in the same match_on strata. */
      __match_id = 0; 

      /* formula from link in start of file */
      retain __nobs __k __p __ite_max;
 	    __nobs = h.num_items;
      __k = __nobs;
      __p = 0.99;
      __ite_max = min(round(__k*log(__k) - log(-log(__p))), &ite_max_val);
      call symput("ite_max", __ite_max);
  	end;

    __match_id + 1;

  	/* Open case dataset */
  	set __hm_cases;
  	
  	/* Find the total number of potential controls*/
 
  	__stop = 0;
  	__n = 0;
  	__cnt = 0;
  	do while (__stop = 0);
  		__cnt+1;
  		/* Pick a random potential control */
  		__rc=h.find(key:max(1,round(rand("uniform")*__nobs)));
  		/* Check if valid control */
      if __id ne __id_control and __start_control <= __index <= __end_control
        
  		/* If the control is valid we add one to the counter 
  		keeping track of the number of found valid controls
  		and output the obervation */
  		then do;
  			__n+1; 
        drop  __start_control __end_control __rc __obs __nobs __stop 
              __n __cnt __k __p __ite_max;
  			output;
  		end;
  		/* When we have found 10 valid controls we stop the loop */ 
  		if __n = &n_matches then __stop = 1;
  		/* Exit condition to avoid infinite loops. */
      if __cnt >__ite_max then __stop = 1;
    end;
  run;
  
  %end;
  /* Else make empty dataset */
  %else %do;
  data __hm_match1_&i;
    format __index_control date9. __match_id 10.;
    set __hm_cases(obs = 0);
    __id_control = __id;
  run;

  %end;

  %put %sysfunc(time(), time12.) ite &i/%sysfunc(strip(&n_strata)) (%sysfunc(strip(&i_match_on))) / cases: %sysfunc(strip(&n_cases)) / pot. ctrls: %sysfunc(strip(&n_controls)) / ite_max: %sysfunc(strip(&ite_max));

%end; /* End of i-loop */
/* Restore the value of the NOTES option*/
options &opt_notes_value;

/* Combined matches */
data __hm_match2;
  set __hm_match1_:;
run;

/* Rearrange data */
proc sort data = __hm_match2;
  by __match_on __match_id __id __id_control;
run;

/* Cases */
data __hm_match3_cases;
	set __hm_match2(
    rename = (__match_id = temp) 
    drop = __id_control __index_control
  );
	length __match_id 8 __case 3;
	format __match_id 10. __case 1.;
	by __match_on temp;
	retain __match_id;
	if _n_ = 1 then __match_id = 0;
	if first.temp then do;
		__match_id + 1;
		__case = 1;
		output;
	end;
  drop temp;
run;

/* Controls */
data __hm_match3_controls(
    rename = (
      __id_control = __id 
      __index_control = __index)
  );
	set __hm_match2(rename = (__match_id = temp));
	length __match_id 8 __case 3;
	format __match_id 10. __case 1.;
	by __match_on temp;
	retain __match_id;
	if _n_ = 1 then __match_id = 0;
	if first.temp then do;
		__match_id = __match_id + 1;
	end;	
	__case = 0;
  drop temp __id __index;
run;

/* Combine */
data __hm_match4;
	set __hm_match3_cases __hm_match3_controls;
run;

proc sql;
  create table &out_ds(
      rename = (__index = &index_date __id = &id_var)    
    ) as
    select a.__match_id, a.__case, a.__id,a.__index
      %do i = 1 %to %sysfunc(countw(&match_vars, %str( )));
        %let i_var = %scan(&match_vars, &i, %str( )); 
      , b.&i_var
      %end;
    from __hm_match4 as a
    left join __hm_match_values as b
    on a.__match_on = b.__match_on
    order by __match_id, __case descending, a.__id;
quit;

%if &del = y %then %do;
  proc datasets nolist nodetails;
    delete __hm_:;
  run;
  quit;
%end;

%mend hash_match;
