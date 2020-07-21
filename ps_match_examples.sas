/* Simulate data */
data dat;
  call streaminit(123);
  do i = 1 to 1000;
    id = i;
    exposure = rand("bernoulli", 0.2);
    ps = rand("uniform");
    output;
  end;
  drop i;
run;

/* ps pair matching using nearest neighbor matching with the default caliper. */
%ps_match(
  in_ds = dat,
	out_pf = out,
	group_var = exposure,
	ps_var = ps,
  seed = 1
  );

