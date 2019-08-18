/*******************************************************************************
BASIC TESTS
*******************************************************************************/

data _data1;
  call streaminit(1);
  do i = 1 to 1000;
    by_var_num = rand("bernoulli", 0.3);
    by_var_char = put(by_var_num, 1.);
    group_var_num = rand("bernoulli", 0.7);
    group_var_char = put(group_var_num, 1.);
    bin_var = rand("bernoulli", 0.4);
    if rand("uniform") < 0.5 then bin_var_miss = bin_var;
    else bin_var_miss = .;
    cat_var_num = rand("binomial", 0.5, 2);
    cat_var_char = put(cat_var_num, 1.);
    cont_var = rand("uniform");
    if rand("uniform") < 0.5 then cont_var_miss = cont_var;
    else cont_var_miss = .;
    weight_num = rand("uniform");
    weight_char = put(rand("uniform"), 10.8);
    if rand("uniform") < 0.5 then weight_weird = 0.5;
    else weight_weird = -0.5;
    __bin = rand("bernoulli", 0.5);
    cat_var_many = round(cont_var, 0.01);
    output;
  end;
  drop i;
run;

/* Check that the macro gives an error if any of the macro parameters are empty. */
%pt_char;
%pt_char(in_ds = _data1);
%pt_char(in_ds = _data1, out_ds = _out1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, var_types = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, group_var = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, by_vars = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, cont_cutoff = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, median_mean = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, npct_pctn = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_n = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_d_cat = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_cont = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_pct = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_dec = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_digit = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, allow_d_miss = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, allow_cont_miss = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, total_group_last = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, inc_num_stat_vars = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, inc_report_dummy = );
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, del = );
          
/* Check that the macro correctly removes quotes in macro parameters where the
inattentive user might think quotes are needed. */
%pt_char(
  in_ds             = _data1,
  out_ds            = _out1,
  var_list          = "bin_var" 'cont_var',
  var_types         = "auto",
  group_var         = 'null',
  by_vars           = "null",
  weight            = '1',
  median_mean       = "median",
  npct_pctn         = 'npct',
  allow_d_miss      = "n",
  allow_cont_miss   = "n",
  total_group_last  = "y",
  inc_num_stat_vars = "n",
  inc_report_dummy  = "y",
  del               = "y"
);

/* Check that the macro can handle input/output datasets given as
libname.member-name and also as a filepath. */
libname _tests "S:\Thomas Rasmussen\github_dev\pt_char";
data _tests._data1;
  set _data1;
run;

%pt_char(
  in_ds     = _tests._data1, 
  out_ds    = _tests._out1, 
  var_list  = bin_var
  );

%pt_char(
  in_ds     = "S:\Thomas Rasmussen\github_dev\pt_char\_data1", 
  out_ds    = "S:\Thomas Rasmussen\github_dev\pt_char\_out1", 
  var_list  = bin_var
  );

libname _tests clear;

/* Check that the macro gives helpful error messages if in_ds or out_ds 
is not correctly specified. */
%pt_char(in_ds = abcd, out_ds = _out1, var_list  = bin_var);
%pt_char(in_ds = 1abcd, out_ds = _out1, var_list  = bin_var );
%pt_char(in_ds = notlib.abcd, out_ds = _out1, var_list  = bin_var);
%pt_char(in_ds = "abcd", out_ds = tests1_out, var_list = bin_var);

data _data1_0;
  set _data1(obs = 0);
run;

%pt_char(
  in_ds     = _data1_0, 
  out_ds    = _out1, 
  var_list  = bin_var
  );

/* Test var_list misspecifications. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var$cont_var);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var1 cont_var);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var cont_var n);

/* Test manual specification of var_types. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_num, var_types = cont);
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var , var_types = dd);
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var , var_types = d d);

/* Test group_var. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var, group_var = var1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var, group_var = group_var_num bin_var);
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var, group_var = group_var_char);

/* Test by_vars. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var, by_vars = var1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var, by_vars = by_var_char by_var_num);
%pt_char(in_ds = _data1, out_ds = _out1, var_list  = bin_var, by_vars = a by_var_num);

/* Check specification of weight */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = 0.5);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = -0.5);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = 0);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = 1 2);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = weight_num);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = weight_char);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = weight_weird);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = weight_num weight_char);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = abcd);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = var2$var2);

/* Check that the macro does not allow variables with a "__" prefix. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = __bin);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, group_var = __bin);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, by_vars = __bin);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, weight = __bin);

/* Test cont_cutoff misspecifications. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_many);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_many, cont_cutoff = 1000);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_many, cont_cutoff = 2.5);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_many, cont_cutoff = -1);

/* Test median_mean misspecifications. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, median_mean = test);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, median_mean = median);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, median_mean = mean);

/* Test npct_pctn misspecifications. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var, npct_pctn = test);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_num, npct_pctn = npct);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_char, npct_pctn = pctn);

/* Tes dec_n, dec_d_cat, dec_cont and dec_pct macro parameter */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_n = 1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_n = 10);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_n = -1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_n = 2.5);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_num, dec_d_cat = 1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_char, dec_d_cat = 10);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_num, dec_d_cat = -1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cat_var_char, dec_d_cat = 2.5);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_cont = 1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, median_mean = mean, dec_cont = 1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_cont = 10);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_cont = -1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var, dec_cont = 2.5);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_pct = 1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, npct_pctn = pctn, dec_pct = 1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_pct = 10);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_pct = -1);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, dec_pct = 2.5);

/* Test of sep_dec and sep_digit macro parameters */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_dec = ',');
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_dec = .);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_dec = "$");
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_dec = remove);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_dec = " ");
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_dec = "remove");
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_digit = ',');
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_digit = .);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_digit = "$");
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_digit = remove);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_digit = " ");
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, sep_digit = "remove");

/* Test the allow_d_miss and allow_cont miss macro parameter. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var_miss);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var_miss, allow_d_miss = y);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var_miss, allow_d_miss = yes);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var_miss);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var_miss, allow_cont_miss = y);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = cont_var_miss, allow_cont_miss = yes);

/* Test total_group_last macro parameter. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, group_var = group_var_num);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, group_var = group_var_num, total_group_last = n);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, group_var = group_var_num, total_group_last = no);

/* Test inc_num_stat_vars macro parameter. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var cont_var, inc_num_stat_vars = y);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, inc_num_stat_vars = y);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, inc_num_stat_vars = yes);

/* Test inc_report_dummy macro paramters. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, inc_report_dummy = n);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, inc_report_dummy = yes);

/* Test del macro parameter. */
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, del = n);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, del = y);
%pt_char(in_ds = _data1, out_ds = _out1, var_list = bin_var, del = yes);


/*******************************************************************************
CATEGORICAL VARIABLE VALUES
*******************************************************************************/

/* The macro is supposed to be able to handle every kind of categorical
variable, especially character categorical variables with crazy values. */
data _data2;
  format char_cat_var $50.;
  call streaminit(2);
  do i = 1 to 1000;
    bin_cat_var = rand("bernoulli", 0.5);
    int_cat_var = rand("binomial", 0.5, 2);
    if rand("uniform") < 0.5 then miss_cat_var = rand("binomial", 0.5, 3);
    else miss_cat_var = .;
    char_cat_var_temp = rand("binomial", 0.5, 5);
    if char_cat_var_temp = 0 then char_cat_var = ".";
    if char_cat_var_temp = 1 then char_cat_var = "";
    if char_cat_var_temp = 2 then char_cat_var = "Value ,;: ' '' "" """" not$allowed@as(dataset)'name";
    if char_cat_var_temp = 3 then char_cat_var = %nrstr("&not_a_macro_var %not_a_macro");
    if char_cat_var_temp = 4 then char_cat_var = "1,234.00";
    if char_cat_var_temp = 5 then char_cat_var = "not or eq leq geq and";
    output;
  end;
  drop i char_cat_var_temp;
run;

%pt_char(
	in_ds = _data2,
  out_ds = _out2,
	var_list = bin_cat_var int_cat_var miss_cat_var char_cat_var,
  var_types = cat cat cat cat
	);

proc report data = _out2;
  columns __var_name __stat_char;
  define __var_name / "" display order = data;
  define __stat_char / "" display;
run;

/*******************************************************************************
GROUP VARIABLES
*******************************************************************************/

/* Test that the macro can handle group variables with character values and
that it correctly terminates the macro if the specified variable has missing 
values. */

%pt_char(
	in_ds = _data2,
  out_ds = _out2,
	var_list = int_cat_var,
  group_var = miss_cat_var
	);

%pt_char(
	in_ds = _data2,
  out_ds = _out2,
	var_list = int_cat_var,
  group_var = char_cat_var
	);

data _data2_nomiss;
  set _data2;
  where char_cat_var ne "";
run;

%pt_char(
	in_ds = _data2_nomiss,
  out_ds = _out2,
	var_list = int_cat_var,
  group_var = char_cat_var
	);

/*******************************************************************************
NO DATA IN SOME STRATA
*******************************************************************************/

/* Test the behavior of the macro if categorical variables only have certain
value in
some group/by-variable strata. */
data _data3;
  call streaminit(3);
  do i = 1 to 1000;
    group_var = rand("bernoulli", 0.5);
    cat_var = rand("binomial", 0.5, 2);
    if ^(group_var = 0 and cat_var = 1) then output;
  end;
run;

%pt_char(
	in_ds = _data3,
  out_ds = _out3,
	var_list = cat_var,
  group_var = group_var
	);

%pt_char(
	in_ds = _data3,
  out_ds = _out3,
	var_list = cat_var,
  by_vars = group_var
	);

/* We see that even though some categories does not exist in some strata of 
grouping or by-variables, datalines are still made. This is not the case when
using by-statements in SAS procedures (right?), but is the case as a consequence 
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

data _data4;
  call streaminit(100);
  do i = 1 to 1e7;
    bin_var = rand("bernoulli", 0.5);
    cat_var = rand("binomial", 0.5, 2);
    cont_var = rand("normal", 0, 1);
    group = ceil(rand("uniform") * 2);
    output;
  end;
  drop i;
run;

/* 10,000 obs */
data _data4_subset; set _data4(obs = 10000); run;
option nonotes;
%put %sysfunc(time(), time12.);
%pt_char(in_ds =  _data4_subset, out_ds = _out4, var_list = bin_var cat_var cont_var, group_var  = group);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: 2 sec */

/* 100,000 obs */
data _data4_subset; set _data4(obs = 100000); run;
option nonotes;
%put %sysfunc(time(), time12.);
%pt_char(in_ds =  _data4_subset, out_ds = _out4, var_list = bin_var cat_var cont_var, group_var  = group);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: 2 sec */

/* 1,000,000 obs */
data _data4_subset; set _data4(obs = 1000000); run;
option nonotes;
%put %sysfunc(time(), time12.);
%pt_char(in_ds =  _data4_subset, out_ds = _out4, var_list = bin_var cat_var cont_var, group_var  = group);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: 8 sec */

/* 10,000,000 obs */
data _data4_subset; set _data4(obs = 10000000); run;
option nonotes;
%put %sysfunc(time(), time12.);
%pt_char(in_ds =  _data4_subset, out_ds = _out4, var_list = bin_var cat_var cont_var, group_var  = group);
option notes;
%put %sysfunc(time(), time12.);
/* Run-time: 3-4 mins */

/* For very large populations, the extra run-troughs, sorts, and aggregations of
the data results in some very long run-times which is not optimal, but is 
probably rarely an issue for the intended group of users. 




