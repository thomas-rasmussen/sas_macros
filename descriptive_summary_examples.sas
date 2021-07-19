/*******************************************************************************
EXAMPLE - INTENDED USE WITH PROC REPORT
*******************************************************************************/

/* Example of intended use of the macro with proc report, to make a standard
"table 1" of a population with patient characteristics of the whole population
and in stratas of an exposure variable. */

data studypop;
  call streaminit(1);
  do i = 1 to 1000;
    exposure = rand("bernoulli", 0.5);
    bin_var = rand("bernoulli", 0.5);
    cont_var = rand("normal", 0, 1);
    cat_var = rand("binomial", 0.5, 3);
    output;
  end;
run;

%descriptive_summary(
	in_ds = studypop,
  out_ds = table1,
	var_list = cont_var cat_var bin_var,
  strata = exposure
);

proc format;
  value exp_fmt
    . = "All patients" 
    0 = "Non-exposed"
    1 = "Exposed"
  ;
  value $__label
    "__n" = "^S = {font_weight = bold}Number of patients"
    "cont_var" = "^S = {font_weight = bold}Continuous variable, median (Q1-Q3)"
    "cat_var: title" = "^S = {font_weight = bold}Categorical variable, N (%):"
    "cat_var: 0" = "  Value: 0"
    "cat_var: 1" = "  Value: 1"
    "cat_var: 2" = "  Value: 2"
    "cat_var: 3" = "  Value: 3"
    "bin_var" = "^S = {font_weight = bold}Binary variable, N (%)"
  ;
run;

ods escapechar = "^";
ods rtf file = "example.rtf"
  style = journal ;
proc report data = table1 missing
    style(report) = {font_size = 14pt}
    style(header) = {font_size = 14pt font_weight = bold}
    style(column) = {font_size = 14pt just = c};
  columns __label exposure, (__stat_char __report_dummy);
  define __label / "" group format = $__label. order = data
    style(column) = {just = l asis = on};
  define exposure / "" across format = exp_fmt. order = data;
  define __stat_char / "" display;
  define __report_dummy / noprint;
run;
ods rtf close;



/*******************************************************************************
EXAMPLE - MANUAL SPECIFICATION OF VARIABLE TYPES
*******************************************************************************/

/* In some cases the macro can not correctly guess the types of variables in
"var_list". Here we show how "var_types" and "cat_groups_max" can be used to
override the default algorithm used by the macro. */

data studypop;
  call streaminit(1234);
  do i = 1 to 1000;
    cat_many_groups = round(rand("uniform"), .01);
    cat_bin_values = rand("bernoulli", 0.5);
    cont_few_values = round(rand("uniform"), .1);
    output;
  end;
run;

/* If only cat_many_groups is of interest, we can see that the default 
behavior of the macro treats the variable as a continuous variable. In this
case, we can remedy the situation by fine-tuning the algorithm used to guess
the type of the variable by using the "cat_groups_max" macro parameter. */
%descriptive_summary(
	in_ds = studypop,
  out_ds = table1,
	var_list = cat_many_groups
);
%descriptive_summary(
	in_ds = studypop,
  out_ds = table1,
	var_list = cat_many_groups,
  cat_groups_max = 110
);

/* But if we simultaneously want to include cont_few_values this solution
will not work. Futhermore, cat_bin_values can not be properly recognized
as a categorical variable no matter the value of "cat_groups_max". Instead,
we specify the variable types of each variable manually using "var_types". */
%descriptive_summary(
	in_ds = studypop,
  out_ds = table1,
	var_list = cat_bin_values cont_few_values cat_many_groups,
  var_types = cat cont cat
);
