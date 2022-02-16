/*******************************************************************************
BASIC EXAMPLE
*******************************************************************************/

/* Paths to folder where SAS datasets are located, and where the exported
data is to be saved. Here we simply save the exported datasets in the same
folder */
%let path_from = S:\Thomas Rasmussen\github_repos\example;
%let path_to = &path_from;

/* Make dummy datasets and save in folder. */
data "&path_from\dat1.sas7bdat" "&path_from\dat2.sas7bdat";
  format date_var date9.;
  do i = 1 to 10;
  num_var = i;
  char_var = put(i, 2.);
  date_var = i;
  output;
  end;
  drop i;
run;

/* Export both datasets to CSV. Note that the format of date variables are
automatically changed to yyyy-mm-dd by default, to facilitate importing them in
in other programs as dates. For example, the DATE format is popular in SAS, but a
date on the format 01JAN2000, is not necesarily automatically recognized as a
date by other programs. */
%export_to_csv(
  datasets = dat1 dat2, 
  from = &path_from,
  to = &path_to
);
