/*******************************************************************************
BASIC EXAMPLE
*******************************************************************************/

/* Basic example showing how date variables with the SAS DATE format are
reformatted to a yyyy-mm-dd format. */

data dat01;
  format date_var1 date9. date_var2 mmddyy10.;
  do i = 1 to 10;
  num_var = i;
  char_var = put(i, 2.);
  date_var1 = i;
  date_var2 = i;
  output;
  end;
  drop i;
run;

%export_to_txt(
  data = dat01, 
  file = "C:\export_to_txt_example\dat01.txt"
);
