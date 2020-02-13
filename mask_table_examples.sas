/*** Example using output from pt_char macro ***/

/* Simulate data */
data ptchar1;
  call streaminit(1);
  do i = 1 to 100;
    E = rand("bernoulli", 0.2);
    bin_var = rand("bernoulli", 0.1);
    cont_var = rand("normal", 0, 1);
    cat_var = rand("binomial", 0.5, 3);
    output;
  end;
run;

/* Aggregate data using the pt_char macro */
%pt_char(
	in_ds = ptchar1,
  out_ds = ptchar2,
	var_list = bin_var cat_var cont_var,
  strata = E,
  report_dummy = n
);

/* Mask person-sensitive counts in the table. */
%mask_table(
  in_ds       = ptchar2,
  out_ds      = ptchar3,
  class_vars  = E,
  cont_vars   = "cont_var"
 );

/* Mask the concatnated character variable to be used in the output table,
if the count was masked. */
data ptchar4;
  set ptchar3;
  if __stat_num1 = .m then __stat_char = "*";
  drop __stat_num:;
run;


/*** Example where data is manually aggregated and structured so that it can 
be used with the macro ***/
data manual1;
  call streaminit(1);
  do i = 1 to 100;
    class = rand("bernoulli", 0.2);
    bin_var = rand("bernoulli", 0.1);
    cont_var = rand("normal", 0, 1);
    cat_var = rand("binomial", 0.5, 3);
    output;
  end;
run;
 
/* Replace the categorical variable with a set of indicator functions */
data manual2;
  set manual1;
  cat_var_0 = (cat_var = 0);
  cat_var_1 = (cat_var = 1);
  cat_var_2 = (cat_var = 2);
  cat_var_3 = (cat_var = 3);
  drop i cat_var;
run;

%macro test1;
  %let vars = bin_var cont_var cat_var_0 cat_var_1 cat_var_2 cat_var_3;
  /* Aggregate and add total category */
  proc means data = manual2 noprint;
    class class;
    var &vars;
    output out = manual3(drop = _type_ _freq_) 
      n(bin_var) = n
      sum(&vars) = &vars
      / noinherit;
  run;

  %let vars = n &vars;

  /* Restucture data */
  data manual4;
    format var_name var_value $50.;
    set manual3;
    %do i = 1 %to %sysfunc(countw(&vars, %str( )));
      %let i_var = %scan(&vars, &i, %str( ));
      var_name = "&i_var";
      var_value = var_name;
      cnt = &i_var;
      if substr(var_value, 1, 3) = "cat" then var_name = "cat_var";
      output;
    %end;
    keep var_name var_value class cnt;
  run;
%mend test1;
%test1;

%mask_table(
  in_ds       = manual4,
  out_ds      = manual5,
  class_vars  = class,
  cnt_var     = cnt,
  id_var      = var_name,
  value_var   = var_value,
  n_value     = "n",
  cont_vars   = "cont_var"
 );
