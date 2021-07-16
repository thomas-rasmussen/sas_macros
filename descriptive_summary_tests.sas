/*******************************************************************************
BASIC TESTS
*******************************************************************************/

data __data1;
  call streaminit(1);
  do i = 1 to 1000;
    by_num = rand("bernoulli", 0.3);
    by_rand = rand("uniform");
    format by_char $40.;
    if by_rand < 0.3 then by_char = "value 1";
    else if by_rand < 0.5 then by_char = "and or %nrstr(&)var %nrstr(%macro()) n(%) ,'""`´";
    else by_char = ".";
    strata_num = rand("bernoulli", 0.7);
    strata_char = put(strata_num, 1.);
    if rand("uniform") < 0.5 then strata_num_miss = .;
    else strata_num_miss = strata_num;
    if rand("uniform") < 0.5 then strata_char_miss = "";
    else strata_char_miss = strata_char;
    bin_var = rand("bernoulli", 0.4);
    if rand("uniform") < 0.5 then bin_var_miss = bin_var;
    else bin_var_miss = .;
    cat_var_num = rand("binomial", 0.5, 2);
    cat_var_char = put(cat_var_num, 1.);
    cont_var = rand("uniform");
    if rand("uniform") < 0.5 then cont_var_miss = cont_var;
    else cont_var_miss = .;
    weight_num = rand("uniform");
    weight_char = put(rand("uniform"), 5.2);
    if rand("uniform") < 0.5 then weight_neg = 0.5;
    else weight_neg = -0.5;
    if weight_num < 0.5 then weight_miss = .;
    else weight_miss = weight_num;
    cat_var_many_groups = round(cont_var, 0.01);
    __bin_var = rand("uniform");
    by_max_sas_name_length_012345678 = bin_var;
    var_max_sas_name_length_01234567 = bin_var;
    strata_max_sas_name_length_01234 = bin_var;
    null = bin_var;
    output;
  end;
  drop i;
run;

/* Check that the macro gives an error if any of the macro parameters 
(except "where") are empty. */
%descriptive_summary;
%descriptive_summary(in_ds = __data1);
%descriptive_summary(in_ds = __data1, out_ds = __out1);

%macro test1;
%let opt_vars =
  by strata var_types var_stats stats_cont stats_d weight cat_groups_max 
  decimals_d decimals_cont decimals_pct decimal_mark big_mark overall_pos    
  add_pct_symbol add_num_comp report_dummy allow_d_miss allow_cont_miss
  print del;            

%do i = 1 %to %sysfunc(countw(&opt_vars, %str( )));
  %let i_var = %scan(&opt_vars, &i, %str( ));
  %put ERROR: "&i_var = ";
  option nonotes;
  %descriptive_summary(
    in_ds = __data1, 
    out_ds = __out1, 
    var_list = bin_var, 
    &i_var = 
  );
  option notes;
%end;
%mend test1;
%test1;

/* Check unintended use of quotes can be handled. */
%descriptive_summary(
  in_ds           = __data1,
  out_ds          = __out1,
  var_list        = "bin_var" 'cont_var' "cat_var_char",
  by              = 'null',
  strata          = "null",
  where           = %bquote(),
  var_types       = "auto",
  var_stats       = 'auto',
  stats_cont      = "median_q1q3",
  stats_d         = "n_pct",
  weight          = "null",
  cat_groups_max  = 20,
  decimals_d      = 0,
  decimals_cont   = 1,
  decimals_pct    = 1,
  decimal_mark    = "point",
  big_mark        = "comma",
  overall_pos     = "first",
  add_pct_symbol  = "n",
  add_num_comp    = "y",
  report_dummy    = 'y',
  allow_d_miss    = "n",
  allow_cont_miss = "n",
  print           = "n",
  del             = "y"
);

/* Check unintended use of uppercase can be handled. */
%descriptive_summary(
  in_ds           = __data1,
  out_ds          = __out1,
  var_list        = bin_var cont_var cat_var_char,
  by              = NULL,
  strata          = NULL,
  where           = %bquote(),
  var_types       = AUTO,
  var_stats       = AUTO,
  stats_cont      = MEDIAN_q1q3,
  stats_d         = N_PCT,
  weight          = NULL,
  cat_groups_max  = 20,
  decimals_d      = 0,
  decimals_cont   = 1,
  decimals_pct    = 1,
  decimal_mark    = POINT,
  big_mark        = COMMA,
  overall_pos     = FIRST,
  add_pct_symbol  = N,
  add_num_comp    = Y,
  report_dummy    = Y,
  allow_d_miss    = N,
  allow_cont_miss = N,
  print           = N,
  del             = Y
);

/* Check macro gives error if any specified variable has "__" prefix. */
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list  = bin_var __bin_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list  = bin_var, strata = __bin_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list  = bin_var, by = __bin_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list  = bin_var, weight = __bin_var);


/*** in_ds and out_ds tests ***/

/* Check macro gives error if empty in_ds. */
data __data1_0;
  set __data1(obs = 0);
run;

%descriptive_summary(
  in_ds     = __data1_0, 
  out_ds    = __out1, 
  var_list  = bin_var
  );

/* Check that the macro gives helpful error messages if in_ds is not 
correctly specified. */
%descriptive_summary(in_ds = abcd, out_ds = __out1, var_list  = bin_var);
%descriptive_summary(in_ds = 1abcd, out_ds = __out1, var_list  = bin_var );
%descriptive_summary(in_ds = notlib.abcd, out_ds = _out1, var_list  = bin_var);
%descriptive_summary(in_ds = "abcd", out_ds = __out1, var_list = bin_var);


/*** Test "var_list" macro parameter ***/
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var$cont_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var var_not_in_data);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var bin_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = var_max_sas_name_length_01234567);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = by_char);


/*** Test "by" macro parameter ***/
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, by = by_num);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, by = by_char);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, by = by_num by_char);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, by = not_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, by = by_num, strata = by_num);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, by = by_max_sas_name_length_012345678);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, by = null);


/*** Test "strata" macro parameter ***/
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = strata_num);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = strata_char);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = strata_num_miss);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = strata_char_miss);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = not_var);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = strata_max_sas_name_length_01234);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = null);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = by_char);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, strata = strata_num, weight = weight_num);

/* test that a variable called "case" can be used in strata. */
data __data1_case;
  set __data1;
  case = strata_num;
run;

%descriptive_summary(in_ds = __data1_case, out_ds = __out1_case, var_list = bin_var, strata = case);



/*** Test "where" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var,
  where = %str(bin_var > 0.5)
);

%let macro_var = bin_var;
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var,
  where = %str(&macro_var > 0.5)
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var,
  where = %nrstr(by_char = ".")
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var,
  where = %nrstr(by_char = "and or &var %macro() n(%%) ,'%"`´")
);


/*** Test "var_types" macro parameter */
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cont_var bin_var cat_var_num by_char, 
  var_types = cont cat cat cat
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cont_var bin_var, 
  var_types = cont
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cont_var bin_var, 
  var_types = d d
);


/*** Test "var_stats" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_num cont_var bin_var cat_var_char, 
  var_types = cat cont d cat,
  var_stats = n_pct median_q1q3 n_pct n_pct
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_num cont_var bin_var cat_var_char, 
  var_types = invalid_type cont d cat,
  var_stats = n_pct median_q1q3 n_pct n_pct
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_num cont_var bin_var cat_var_char, 
  var_types = cont d cat,
  var_stats = n_pct median_q1q3 n_pct n_pct
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_num cont_var bin_var cat_var_char, 
  var_types = cont cont d cat,
  var_stats = mean_stderr median_q1q3 n_pct n_pct
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_num cont_var bin_var cat_var_char, 
  var_types = cat cont d cat,
  var_stats = mean_stderr median_q1q3 n_pct n_pct
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_num cont_var bin_var cat_var_char, 
  var_types = cont cont d cat,
  var_stats = mean_stderr median_q1q3 mean_stderr n_pct
);


/** Test "stats_cont" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var cont_var cat_var_num,
  stats_cont = median_q1q3
); 
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var cont_var cat_var_num,
  stats_cont = mean_stderr
); 
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var cont_var cat_var_num,
  stats_cont = not_valid
); 


/** Test "stats_d" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var cont_var cat_var_num,
  stats_d = n_pct
); 
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var cont_var cat_var_num,
  stats_d = pct_n
); 
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var cont_var cat_var_num,
  stats_d = not_valid
); 


/*** Test "weight" macro parameter ***/
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, weight = weight_num);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, weight = weight_char);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, weight = weight_neg);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, weight = weight_num weight num);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, weight = weight_miss);


/*** Test "cat_groups_max" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_many_groups
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_many_groups, 
  cat_groups_max = 1000
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cat_var_many_groups, 
  cat_groups_max = 5.5
);


/*** Test "decimals_d", "decimals_cont", and "decimals_pct" macro 
parameters ***/
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = cont_var, decimals_cont = 0);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = cont_var, decimals_cont = 2.5);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, decimals_d = 2);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, decimals_d = 2.5);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, decimals_pct = 0);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, decimals_pct = 2.5);


/*** Test "decimal_mark" and "big_mark" macro parameters ***/
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, decimal_mark = comma);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, decimal_mark = space);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, decimal_mark = invalid);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, big_mark = point);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, big_mark = space);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, big_mark = remove);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, big_mark = invalid);


/*** Test "overall_pos" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var,
  strata = strata_num, 
  overall_pos = last
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var,
  strata = strata_num, 
  overall_pos = invalid
);


/*** Test "add_pct_symbol" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var, 
  add_pct_symbol = y
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var, 
  add_pct_symbol = invalid
);


/*** Test "add_num_comp" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var, 
  add_num_comp = n
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var, 
  add_num_comp = invalid
);


/*** Test "report_dummy" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var, 
  report_dummy = n
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var, 
  report_dummy = invalid
);


/*** Test "allow_d_miss" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var_miss, 
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var_miss, 
  allow_d_miss = y
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = bin_var_miss, 
  allow_d_miss = invalid
);


/*** Test "allow_cont_miss" macro parameter ***/
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cont_var_miss
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cont_var_miss, 
  allow_cont_miss = y
);
%descriptive_summary(
  in_ds = __data1, 
  out_ds = __out1, 
  var_list = cont_var_miss, 
  allow_cont_miss = invalid
);

/*** Test "print" and "del" macro parameter ***/
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, print = y);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, print = invalid);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, del = n);
%descriptive_summary(in_ds = __data1, out_ds = __out1, var_list = bin_var, del = invalid);
 

/*******************************************************************************
NO DATA IN SOME STRATA
*******************************************************************************/

/* Test the behavior of the macro if categorical variables only have certain
values in some stratas of "by" and "strata" variables. */
data __data2;
  call streaminit(3);
  do i = 1 to 1000;
    strata_var = rand("bernoulli", 0.5);
    cat_var = rand("binomial", 0.5, 2);
    if ^(strata_var = 0 and cat_var = 1) then output;
  end;
run;

%descriptive_summary(
	in_ds = __data2,
  out_ds = __out2,
	var_list = cat_var,
  strata = strata_var
	);

%descriptive_summary(
	in_ds = __data2,
  out_ds = __out2,
	var_list = cat_var,
  by = strata_var
	);

/* We see that even though some categories does not exist in some strata of 
grouping or by-variables, datalines are still made. This is not the case when
using by-statements in SAS procedures (right?), but is the case here as a consequence 
of recoding the categorial variables with dummy variables. The behavior is most
likely benificient to the user. */


/*******************************************************************************
BENCHMARK TESTS
*******************************************************************************/

/* 
Computer specifications:
OS:           Windows 10
System type:  x64-based PC
Processor:    Intel(R) Core(TM) i5-3470T CPU 2.90GHz, 2 Core(s), 4 Logical 
              Processor(s)
RAM:          8 GB
  */

data __data3;
  call streaminit(3);
  do i = 1 to 10**7;
    bin_var = rand("bernoulli", 0.5);
    cat_var = rand("binomial", 0.5, 2);
    cont_var = rand("normal", 0, 1);
    group = ceil(rand("uniform") * 2);
    output;
  end;
run;

/* 10,000 obs */
data __subset; set __data3(where = (i <= 10**4)); run;
option nonotes;
%put %sysfunc(time(), time12.);
%descriptive_summary(
  in_ds = __subset, 
  out_ds = __out3,
  var_list = bin_var cat_var cont_var, 
  strata  = group
);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: ca 1 sec */

/* 100,000 obs */
data __subset; set __data3(where = (i <= 10**5)); run;
option nonotes;
%put %sysfunc(time(), time12.);
%descriptive_summary(
  in_ds = __subset, 
  out_ds = __out3,
  var_list = bin_var cat_var cont_var, 
  strata  = group
);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: ca 1 sec */

/* 1,000,000 obs */
data __subset; set __data3(where = (i <= 10**6)); run;
option nonotes;
%put %sysfunc(time(), time12.);
%descriptive_summary(
  in_ds = __subset, 
  out_ds = __out3,
  var_list = bin_var cat_var cont_var, 
  strata  = group
);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: ca 8 sec */

/* 10,000,000 obs */
data __subset; set __data3(where = (i <= 10**7)); run;
option nonotes;
%put %sysfunc(time(), time12.);
%descriptive_summary(
  in_ds = __subset, 
  out_ds = __out3,
  var_list = bin_var cat_var cont_var, 
  strata  = group
);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: ca 4 mins */

/* For very large populations, the extra run-throughs, sorts, and aggregations of
the data results in some very long run-times which is not optimal, but is 
probably rarely an issue for the intended group of users. Also, the used
computer was a regular work pc. The run-time was 1 min. on a more powerful 
server.




