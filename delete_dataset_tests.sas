/*******************************************************************************
TESTS
*******************************************************************************/

/* Test that empty call of macro works */
%delete_dataset();


/* Test use of multiple patterns */
data ds1 ds_2;
run;

%delete_dataset(
  pattern = "/ds1/" "/ds_2/"
);


/* Test combined use of <dataset> and <pattern> */
data ds1 ds_2;
run;

%delete_dataset(
  dataset = ds1,
  pattern = "/ds_2/"
);
