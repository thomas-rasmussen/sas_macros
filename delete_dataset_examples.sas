/*******************************************************************************
EXAMPLE: SPECIFY LIST OF DATASETS TO DELETE
*******************************************************************************/

/* Delete datasets (in the work directory) by specifyin them using 
<dataset> parameter */
data ds1 ds2 some_other_ds;
run;

%delete_dataset(
  dataset = ds1 ds2 some_other_ds
);


/*******************************************************************************
EXAMPLE: USE REGULAR EXPRESSIONS TO DELETE DATASETS
*******************************************************************************/

/* Use regular expressions to identify datsets to delete */

data ds_1 ds_2 ds_3;
run;

%delete_dataset(
  pattern = "/ds_/"
);

/*******************************************************************************
EXAMPLE: DELETE DATASETS IN A SPECIFIED LIBNAME
*******************************************************************************/

/* By default datasets are searched for and deleted in the work directory, but
other libnames can be specified */

proc sql noprint;
  select path into :path
    from sashelp.vslib
    where libname = "WORK";
quit;

libname tmp "%trim(&path)";

data tmp.ds1;
run;

%delete_dataset(
  libname = tmp,
  dataset = ds1
);

libname tmp clear;
