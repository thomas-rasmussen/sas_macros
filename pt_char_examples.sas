/*******************************************************************************
EXAMPLES
*******************************************************************************/

/* Standard use of macro using a group variable. */
data ex1_data;
  call streaminit(1);
  do i = 1 to 1000;
    group = rand("bernoulli", 0.5);
    bin_var = rand("bernoulli", 0.5);
    cont_var = rand("normal", 0, 1);
    cat_var = rand("binomial", 0.5, 3);
    output;
  end;
  drop i;
run;

%pt_char(
	in_ds = ex1_data,
  out_ds = ex1_table,
	var_list =  cont_var cat_var bin_var,
  group_var = group
	);

proc format;
  value _group_fmt 
    0 = "Group 0 label"
    1 = "Group 1 label"
    . = "Total"
    ;
  value $_var_fmt
    "n" = "Number of patients"
    "bin_var" = "Binary variable, n (%)"
    "cont_var" = "Continuous variable, median (Q1-Q3)"
    "cat_var" = "Categorical variable, n (%):"
    "cat_var: 0" = "  0"
    "cat_var: 1" = "  1"
    "cat_var: 2" = "  2"
    "cat_var: 3" = "  3"
    ;
run;

proc report data = ex1_table missing;
  columns __var_name group, (__stat_char __report_dummy);
  define __var_name / "" group format = $_var_fmt. order = data;
  define group / "" across format = _group_fmt. order = data;
  define __stat_char / "" display;
  define __report_dummy / noprint;
run;


/* A more advanced example using a by variable to make a wide
output table with columns for each by-value, and utilizing some
of the optional parameters to:
1) Calculate mean(stderr) statistics for continuous variables
instead of median(Q1-Q3)
2) Make % (n) instead of n (%) statistics for dichotomous and
categorical variables
3) Change the number of decimals that are included in the output
for means/stderr and percentages
4) Change the decimal and digit group separator symbols
5) Allow missing values of continuous variables
6) Put the total groups as the first group instead of the last
7) Include each part of the output statistics as numereric variables
and use these variables to censor person-sensitive data.
*/
data ex2_data;
  call streaminit(2);
  do i = 1 to 1000;
    if rand("uniform") < 0.01 then by_var = "A";
    else by_var = "B";
    group = rand("bernoulli", 0.5);
    bin_var = rand("bernoulli", 0.5);
    cont_var = rand("normal", 0, 1);
    if rand("uniform") < 0.3 then cont_var = .;
    output;
  end;
  drop i;
run;

%pt_char(
  in_ds = ex2_data,
  out_ds = ex2_table1,
  var_list = bin_var cont_var,
  group_var         = group,
  by_vars           = by_var,
  median_mean       = mean,
  npct_pctn         = pctn,
  dec_cont          = 1,
  dec_pct           = 1,
  sep_dec           = ",",
  sep_digit         = ".",
  allow_cont_miss   = y,
  total_group_last  = n,
  inc_num_stat_vars = y
);

data ex2_table2;
  set ex2_table1;
  if __var_name = "bin_var" and 0 < __stat_num2 < 5 
    then __stat_char = "n/a";
  drop __stat_num:;
run;

proc report data = ex2_table2 missing;
  columns __var_name by_var, group, (__stat_char __report_dummy);
  define __var_name / "" group order = data;
  define by_var / across order = data;
  define group / "" across order = data;
  define __stat_char / "" display;
  define __report_dummy / noprint;
run;


 
