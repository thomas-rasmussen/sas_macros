
/* Simulate data */
data dat;
  call streaminit(1);
  do i  = 1 to 10000;
    bin_var = rand("bernoulli", 0.5);
    if bin_var = 1 then group = rand("bernoulli", 0.4);
    else group = rand("bernoulli", 0.6);
    cont_var = rand("normal", 0, 1);
    cat_var_num = rand("binomial", 0.5, 2);
    cat_var_char = "val_" || put(rand("binomial", 0.5, 2), 1.);
    cat_var_large = round(rand("uniform") * 100);
    output;
  end;
  drop i;
run;

/* Standard use */
%calculate_sd(
  in_ds = dat,
  out_ds = out,
  group_var = group,
  var = bin_var cont_var cat_var_num cat_var_char
);

/* Example where a numerical categorical variable is incorrectly 
guessed to be continuous variable because it has a large number of 
categories */
%calculate_sd(
  in_ds = dat,
  out_ds = out,
  group_var = group,
  var = cat_var_large
);

/* Manually specifying the variable type to ensure the categorical
variable is handled correctly. */
%calculate_sd(
  in_ds = dat,
  out_ds = out,
  group_var = group,
  var = cat_var_large/cat
);
