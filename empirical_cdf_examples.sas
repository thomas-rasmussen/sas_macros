/* Simulate data */
data dat;
  call streaminit(1);
  do i  = 1 to 10**4;
    group = rand("bernoulli", 0.5);
    if group = 0 then var_normal = rand("normal", 0, 1);
    else if group = 1 then var_normal = rand("normal", 1, 2);
    if group = 0 then var_weibull = rand("weibull", 1, 1);
    else if group = 1 then var_weibull = rand("weibull", 2, 2);
    output;
  end;
  drop i;
run;

/* Calculate empirical CDf for each variable in each strata. */
%empirical_cdf(
  in_ds       = dat,
  out_ds      = out,
  var         = var_normal var_weibull,
  strata      = group,
  del = y
);

/* Plot CDF. */
proc sgpanel data = out;
  panelby __variable / onepanel;
  step x = __x y = __cdf / group = group;
run;

