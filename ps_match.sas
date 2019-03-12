/*******************************************************************************
*	AUTHOR:       Thomas Bøjer Rasmussen (TBR)
* VERSION:      1.0
* DATE:         2019-03-07
********************************************************************************
* NOTES:        
* This macro can be freely used and distributed and comes with NO WARRENTY!
* 
* Version 1.0: First version. Based on macros used in previous projects.
********************************************************************************
*	DESCRIPTION:
*	The macro performs efficient propensity score (PS) pair matching using 
* hash tables. Matching is done on the logit of the PS and by default the macro
* automatically uses a caliper correpsonding to 0.2 times the standard deviation 
*	of the logit of the PS as this has been shown to perform well in various 
* scenarios, see
*	Austin 2001 - Optimal caliper widths for propensity-score matching when 
*   estimating differences in means and differences in proportions in 
*	  observational studies
*
* PARAMETERS:
*	in_ds:      Input dataset with one dataline for each patient.
*	out_ds:     Name of output dataset with the matched population. All variables
*             in the input dataset are included with addition of the  
*             variable _match.
* by:         If the matching is to be done in subsets of the input dataset
*             specify the by-variables. Separate by-variables with " ", or the
*             macro will fail or produce unintended results. 
*	id:         Specify patient ID variable. ID values must be unique in each strata
*             defined by the specified by-variables.
*	ps:         Name of PS variable.
*	E:          Name of the exposure variable. Must be numeric and take the
*             values 1 (exposed) or 0 (unexposed).
*	caliper:	  Caliper to be used. Default value is AUTO (see description).
*             Note that if a caliper is specified manualy , it is used to match 
*             on logit(ps) NOT on the ps's themselves!
*	replace:	  Specify if matching is to be done with (Y) or without (N) 
*					    replacement.
* order:      Specify if matching is done in random order (RAND) or in the order
*             the exposed patients appear in the data (ASIS). 
*	save_info:  Specify if an additional output dataset is to be made with 
*             information on the number of patients before and after matching, 
*             used caliper, and matching run-times. Y=yes (default) N=no.
*             The name of the dataset is [out_ds]_info.
*	seed:			  Specify seed for random number generation. Default is 0.
*	del:			 Specify if the temporary datasets used in the macro is to be
*             deleted at the end of the macro. Y(Yes)/N(No). Default is Y.
*
* EXAMPLE OF USE:
*
* data pop;
*   call streaminit(123);
*   do i = 1 to 1000;
*     id = i;
*     E = rand("bernoulli", 0.2);
*     ps = E*rand("beta", 2, 3) + (1-E) * rand("beta", 2, 6);
*     output;
*   end;
*   drop i;
* run;
* 
* %ps_match(
*   in_ds = pop
* 	,out_ds = pop_matched
* 	,id = id
* 	,E = E
* 	,ps = ps
*   ,seed = 123
*   );
*
* For more advanced examples see the the accompaning ps_match_examples.sas file!
*******************************************************************************/

%macro ps_match(
  in_ds =
	,out_ds =
	,by = 
	,id =
	,E =
	,ps =
	,caliper = AUTO
	,replace = N
  ,order = RAND
	,save_info = N
  ,seed = 0
	,del = Y
) / minoperator;

/*******************************************************************************	
INPUT CHECKS 
*******************************************************************************/
/* Check that the specified input dataset exists */
%if %sysfunc(exist(&in_ds)) = 0 %then %do;
  %put ERROR: Input dataset &in_ds does not exist!;
  %goto end_of_macro;
%end;

/* Check that the input dataset is not empty and if the specified BY, ID, E and 
PS variables exists in the input dataset */
%local rc ds_id i i_by;
%let ds_id = %sysfunc(open(&in_ds));

%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put WARNING: Input dataset &in_ds is empty!;
  data &out_ds;
    format _match best12.;
    set &in_ds;
  run;
  %goto end_of_macro;
%end;

%if &by. NE %then %do;
  %do i = 1 %to %sysfunc(countw(&by, %str( )));
    %let i_by = %scan(&by, &i, %str( ));
    %if %sysfunc(varnum(&ds_id, &i_by)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable &i_by does not exist in input dataset &in_ds!;
      %goto end_of_macro; 
    %end;
  %end;
%end;

%if %sysfunc(varnum(&ds_id, &id)) = 0 %then %do; 
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Variable &id does not exist in input dataset &in_ds!;
  %goto end_of_macro; 
%end;

%if %sysfunc(varnum(&ds_id, &E)) = 0 %then %do; 
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Variable &E does not exist in input dataset &in_ds!;
  %goto end_of_macro; 
%end;

%if %sysfunc(varnum(&ds_id, &ps)) = 0 %then %do; 
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Variable &ps does not exist in input dataset &in_ds!;
  %goto end_of_macro; 
%end;

%let rc = %sysfunc(close(&ds_id));

/* Check that the replace macro parameter has a valid value */
%if (&replace in N Y) = 0 %then %do;
  %put ERROR: Macro parameter "replace" has to be specified as Y or N!;
  %goto end_of_macro; 
%end;

/* Check that the order macro parameter has a valid value */
%if (&order in ASIS RAND) = 0 %then %do;
  %put ERROR: Macro parameter "order" has to be specified as RAND or ASIS!;
  %goto end_of_macro; 
%end;

/* Check that the caliper macro parameter is a numeric value or the 
default AUTO value */
%if %sysevalf((&caliper NE AUTO and %datatyp(&caliper) = CHAR) 
  or &caliper. =  ) %then %do;
  %put ERROR: Macro parameter "caliper" has to be a numeric value or the default value AUTO!;
  %goto end_of_macro; 
%end;

/* Check that the save_info macro parameter has a valid value */
%if (&save_info in N Y) = 0 %then %do;
  %put ERROR: Macro parameter "save_info" has to be specifed as Y or N!;
  %goto end_of_macro; 
%end;

/* Check that the specified E and ps variables are of the correct type */
%local E_type ps_type;
data _NULL_;
  set  &in_ds(obs=1);
  call symput("E_type", vtype(&E));
  call symput("ps_type", vtype(&ps));
run;

%if ^(%upcase(&E_type) = N) %then %do;
  %put ERROR: The specifed E variable &E is not numeric!;
  %goto end_of_macro; 
%end;

%if ^(%upcase(&ps_type) = N) %then %do;
  %put ERROR: The specified ps variable &ps is not numeric!;
  %goto end_of_macro; 
%end;

/* Check that the specified seed is an an integer */
%if %sysfunc(int(&seed)) NE &seed %then %do;
  %put ERROR: The specified seed &seed is not an integer!;
  %goto end_of_macro; 
%end;

/* Check that the exposure only takes the values zero and/or one,
and that the PS values lie in the interval (0;1) */
%local E_values ps_min ps_max;
proc sql noprint;
  select distinct &E, min(&ps), max(&ps) 
          into :E_values separated by "$"
               , :ps_min separated by "$"
               , :ps_max separated by "$"
    from &in_ds;
quit;

%do i = 1 %to %sysfunc(countw(&E_values, $));
  %if (%scan(&E_values., &i, $) in 0 1) = 0 %then %do;
    %put ERROR: The specified E variable &E has invalid values!;
    %goto end_of_macro; 
  %end;
%end;

%if %sysevalf(%scan(&ps_min, 1, $) <= 0 or %scan(&ps_max, 1, $) >= 1) %then %do;
  %put ERROR: The specified ps variable &ps takes values outside the interval (0%str(;)1)!;
  %goto end_of_macro; 
%end;

/* Check that there are no dublicate id values (in each strata defined by
the specified by-variables) */
proc sort data=&in_ds out = _ps_dup_dummy dupout=_ps_dup_id nodupkeys;
  by %if &by NE %then %do; &by %end; &id;
run;

%local dup_N;
proc sql noprint;
  select count(*) into :dup_N
    from _ps_dup_id;
quit;

%if &dup_N NE 0 %then %do;
  %if &by NE %then %do;
  %put ERROR: The specified id variable &id has duplicate values in one or more stratas of the specified by-variable(s)!;
  %end;
  %else %do;
  %put ERROR: The specified id variable &id has duplicate values!;
  %end;
  %goto end_of_macro; 
%end;


/*******************************************************************************	
MAKE NEW BY-VARIABLE AND LOAD INPUT DATA
*******************************************************************************/
/* We make a new (combined) by-variable so that all different scenarios
of by-variable specifications can be handled in a manageable way */
%if &by NE %then %do;
  proc sort data=&in_ds(keep=&by) out=_ps_by_new1 nodupkeys;
    by &by;
  run;

  data _ps_by_new2;
    set _ps_by_new1;
    format _by_dummy _by_new 10.;
    _by_new = _n_;
    _by_dummy = 1;
  run;
%end;
%else %do;
  data _ps_by_new2;
    format _by_dummy _by_new 10.;
    _by_new = 1;
    _by_dummy = 1;
    output;
  run;
%end;

data _ps_data1;
  set &in_ds;
  format _keep_order 20. _by_dummy 1.;
  _keep_order = _n_;
  _by_dummy = 1;
run;

proc sql;
  create table _ps_data2 as
    select b._by_new, a.*
    from _ps_data1 as a
    left join 
    _ps_by_new2 as b
    on a._by_dummy = b._by_dummy 
    %if &by NE %then %do;
      %do i = 1 %to %sysfunc(countw(&by, %str( )));
        %let i_by = %scan(&by, &i, %str( ));
        and a.&i_by = b.&i_by
      %end;
    %end;
    order by _by_new, _keep_order;
quit;


/*******************************************************************************	
ID VARIABLE INFORMATION
*******************************************************************************/	
/* Determining the type, length, and format of the id variable */
%local id_type id_length id_format;
proc sql noprint;
	select type into: id_type
		from sashelp.vcolumn
		where libname="WORK" and memname="_PS_DATA1" and upcase(name)="%upcase(&id)";
	select length into: id_length
		from sashelp.vcolumn
		where libname="WORK" and memname="_PS_DATA1" and upcase(name)="%upcase(&id)";
	select format into: id_format
		from sashelp.vcolumn
		where libname="WORK" and memname="_PS_DATA1" and upcase(name)="%upcase(&id)";
quit;
%if &id_type = char %then %let id_length = %sysfunc(compress($&id_length));

/*******************************************************************************	
CACLULATE LOGIT(PS) AND SORT DATA
*******************************************************************************/
/* Calculate logit(ps) and randomly sort patients if specified. We make a 
new ps variable where a very small random number has been added. Doing this 
will ensure that if multiple exposed and/or unexposed patients have the same 
ps, a random match is made among the closest matches instead of the same match 
every time. */
data _ps_data3;
  call streaminit(&seed);
  set _ps_data2(rename=(&E = _E &id = _id &ps = _ps));
  _ps = _ps + rand("uniform") * 10**(-10);
  _ps_logit = log(_ps / (1 - _ps));
  _u = rand("uniform");
  keep _by_new _id _E _ps_logit _u;
run;

%if &order = RAND %then %do;
  proc sort data = _ps_data3 out = _ps_data3;
    by _by_new _u;
  run;
%end;

/*******************************************************************************	
CALCULATE CALIPER WIDTH
*******************************************************************************/	
/* Calculate the caliper width automatically if it has not been specified. The 
caliper is chosen as 0.2 times the standard deviation of logit(ps). 
See description for explanation. */
proc means data=_ps_data3 noprint nway;
  class _by_new _E;
	var _ps_logit;
	output out=_ps_caliper1 var=var;
run;

data _ps_caliper2;
  set _ps_caliper1;
  by _by_new;
  retain n_total n_E0 n_E1 var_E0 var_E1;
  if first._by_new then do;
    n_total = .;
    n_E0 = .;
    n_E1 = .;
    var_E0 = .;
    var_E1 = .;
  end;
  if _E = 0 then do;
    var_E0 = var;
    n_E0 = _freq_;
  end;
  if _E = 1 then do;
    var_E1 = var;
    n_E1 = _freq_;
  end;
  if last._by_new then do;
    n_total = max(n_E0, 0) + max(n_E1, 0);
    %if &caliper = AUTO %then %do;
      caliper = 0.2 * sqrt((var_E0 + var_E1) / 2);
    %end;
    %else %do;
      caliper=&caliper;
    %end;
    output;
  end;
  drop _E var: _type_ _freq_;
run;

/* Make macro variable with caliper values */
%local calipers;
proc sql noprint;
  select caliper into :calipers separated by "$"
    from _ps_caliper2;
quit;

/* If the calipers are automatically calculated but one or more are missing 
because one or more variances could not be estimated, we write a warning in 
the log */
%local miss_caliper;
%let miss_caliper = 0;
%do i = 1 %to %sysfunc(countw(&calipers, $));
  %if %scan(&calipers, &i, $) = . %then %let miss_caliper = 1;
%end;

%if &miss_caliper %then %do;
  %if &by = %then %do;
    %put WARNING: The caliper could not be calculated!;
  %end;
  %if &by NE %then %do;
    %put WARNING: One or more calipers could not be calculated!;
    %put WARNING: No matching will be done in the corresponding by-variable stratas!;
  %end;
%end;

/*******************************************************************************	
MATCH
*******************************************************************************/
%local  by_values i_caliper i_start i_stop i_match_time match_start p points 
        props p_point p_prop n_by;

/* Save by-values in macro variable */
proc sql noprint;
    select _by_new into :by_values separated by "$"
      from _ps_caliper2;
quit;

%let n_by = %sysfunc(countw(&by_values, $));

/* Make macro variables with progress information */
data _ps_progress;
  format prop $20.;
  do i = 1 to 10;
    point = ceil(i * &n_by / 10);
    prop=compress(put(point, 10.) || "/" || "&n_by");
    output;
  end;
  drop i;
run;

proc sql noprint;
  select distinct point, prop
    into :points separated by "$" 
         ,:props separated by "$"
    from _ps_progress;
quit;

/* Do matching in each by-variable strata */
%let match_start = %sysfunc(datetime());
%do i = 1 %to %sysfunc(countw(&by_values, $));
  %let i_by = %scan(&by_values, &i, $);
  %let i_caliper = %scan(&calipers, &i, $);
  %let i_start = %sysfunc(datetime());

  %if %eval(&by NE and &i = 1) %then %do;
    %put WARNING- Datasets matched (total run-time hh:mm:ss):;
  %end;

  data _ps_i_matched;
    length _ps_logit _closest_dist 8 _id _id_E0 &id_length.;
    /* Load the subset of unexposed patients into the hash object */
    if _n_= 1 then do;
      declare hash h( dataset: "_ps_data3(where = (_by_new = &i_by and _E = 0))"
        ,ordered: "no");
      declare hiter iter("h");
      h.defineKey("_id");
      h.defineData("_id", "_ps_logit");
      h.defineDone();
      call missing(_id, _ps_logit);
    end;
    /* Read observations from the subset of exposed patients */
    set _ps_data3(where = (_by_new = &i_by and _E = 1) 
                  rename = (_id = _id_E1 _ps_logit = _ps_logit_E1));
    /* Iterate over the hash to find the closest match */
    _closest_dist = .;
    _rc= iter.first();
    do while (_rc = 0);
      if abs(_ps_logit_E1 - _ps_logit) <= &i_caliper and &i_caliper NE . then do;
        _dist=abs(_ps_logit_E1 - _ps_logit);
        if _closest_dist = . or _dist < _closest_dist then do;
          _closest_dist = _dist;
          _id_E0 = _id;
        end;
      end; 
      _rc = iter.next();
      /* Output the best match and remove the matched patient from the pool
       of potential matches if matching is done without replacement. */
      if (_rc ~= 0) and _closest_dist ~= . then do;
        output;
        %if %upcase(&replace) = N %then %do;
          _rc1 = h.remove(key: _id_E0);
        %end;
      end;
    end;
    keep _by_new _id_E1 _id_E0;
  run;

  /* Combine matched data and info */
  %if &i = 1 %then %do;
    data _ps_matched1;
      set _ps_i_matched;
    run;
  %end;
  %else %do;
    proc append base=_ps_matched1 data=_PS_i_matched;
    run;
  %end;

  %let i_stop = %sysfunc(datetime());
  %let i_match_time = %left(%qsysfunc(putn(%sysevalf(%sysevalf(&i_stop - &i_start)), time20.)));

  data _ps_i_info; 
    format _by_new 10. match_time $50.;
    _by_new=&i_by;
    match_time="&i_match_time";
  run;
  %if &i = 1 %then %do;
    data _ps_info_time;
      set _ps_i_info;
    run;
  %end;
  %else %do;
    proc append base=_ps_info_time data=_ps_i_info;
    run;
  %end;

  /* Print progress information to the log */
  %if &by NE %then %do;
    %do p = 1 %to %sysfunc(countw(&points, $));
      %let p_point = %scan(&points, &p, $);
      %let p_prop = %scan(&props, &p, $);
      %if &i = &p_point %then %do;
        %put WARNING- &p_prop (%left(%qsysfunc(putn(%sysevalf(%sysevalf(&i_stop - &match_start)), time20.))));
      %end;
    %end;
  %end;

%end; /* end of i-loop */


/*******************************************************************************	
RESTRUCTURE AND SAVE MATCHED DATA
*******************************************************************************/	
data _ps_matched2;
  length _match 8 _id &id_length.;
  format _match best12. _id &id_format.;
  %if &by NE %then %do;
    merge _ps_matched1(in = q1) _ps_by_new2;
    if q1;
  %end;
  %else %do;
    set _ps_matched1;
  %end;
  by _by_new;
  retain _match;
  if first._by_new then _match = 0;
  _match = _match + 1;
  _id = _id_E1; output;
  _id = _id_E0; output;
  keep _by_new _match _id
  %if &by NE %then %do; &by %end;
  ;
run;

proc sql;
  create table &out_ds as
    select a._match, b.*
      from _ps_matched2 as a
      left join &in_ds as b
      on 
      a._id=b.&id
      %if &by NE %then %do;
          %do i = 1 %to %sysfunc(countw(&by, %str( )));
            %let i_by = %scan(&by, &i, %str( ));
            and a.&i_by= b.&i_by
          %end;
      %end;
      order by a._by_new, a._match, b.&E desc;
quit;


/*******************************************************************************	
SAVE INFO
*******************************************************************************/
%if &save_info = Y %then %do;	
  proc means data=_ps_matched2 noprint nway;
    class _by_new;
    var _match;
    output out = _ps_info_n_match(drop=_type_ _freq_) 
      N(_match) = n_match / noinherit;
  run;

  data _ps_out_info1;
    merge 
      %if &by NE %then %do; _ps_by_new2(drop = _by_dummy) %end; 
      _ps_caliper2 _ps_info_n_match _ps_info_time;
    by _by_new;
    label n_total = "Total number of patients"
          n_E0 = "Number of unexposed patients"
          n_E1 = "Number of exposed patients"
          caliper = "Caliper used to match on logit(ps)"
          n_match = "Number of matched exposed patients"
          match_time = "Matching time (hh:mm:ss)"
          ;
    /* We need to divide n_match by two to get the correct number */
    if n_match = . then n_match = 0;
    n_match = n_match/2;
  run;

  proc sort data = _ps_out_info1 out = &out_ds._info(drop = _by_new);
    by _by_new;
  run;
%end;


%end_of_macro:


%if &del = Y %then %do;
	proc datasets nodetails nolist;
		delete _ps_:;
	run;
	quit;
%end;

%mend ps_match;
