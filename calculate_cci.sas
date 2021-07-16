/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.1.0
********************************************************************************
DESCRIPTION:
Calculates the Charlson Comorbidity Index (CCI).

DETAILS:
Implementation of the CCI for use with (Danish) administrative registry data,
using ICD-8 and ICD-10 diagnosis codes. In Danish registries, diagnosis codes
are often coded as SKS codes, which are ICD-10 codes with a "D" prefix. The macro
will automatically handle such codes if they are present in the specified
diagnosis data. 

If a person has both mild and moderate to severe liver disease at the index date,
only the severe liver disease will be included in the CCI. The same is the case
if a person has both diabetes with and without end-organ damage (only diabetes
with end-organ damage is included), and if a person has both non-metastatic and 
metastatic solid tumours (only metastatic solid tumour is included).

This macro was originally inspired by a similar macro by Anders Hammerich Riis
at the Department of Clinical Epidemiology, Aarhus University Hospital.


REFERENCES:
Mary E. Charlson et al
A new method of classifying prognostic comorbidity in longitudinal studies: 
Development and validation
https://doi.org/10.1016/0021-9681(87)90171-8


Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
pop_ds:           (libname.)member-name of input dataset with population. The 
                  population must contain an "id" and "index date" variable.
                  See <id> and <index_date>.
diag_ds:          (libname.)member-name of input dataset with diagnosis data. 
                  The dataset must contain an "id", "diagnosis code" and 
                  "diagnosis date" variable. See <id>, <diag_code> 
                  and  <diag_date>.
out_ds:           Name of output dataset, ie <pop_ds> with an added CCI variable.
*** OPTIONAL ***
codes_ds:         Name of input dataset with disease group definitions that 
                  will overwrite the default codes used in the macro. 
                  Experimental feature. See examples for guidance.
id:               Name of id variable in <pop_ds> and <diag_ds>. 
                  Default is id = id.
index_date:       Name of variable with index dates in <pop_ds>. The CCI is 
                  calculated with respect to this date. Must be a numeric
                  variable with a recognized date format, eg DATEw. or
                  YYMMDDw.. See code for full list of recognized formats.
                  Default is index_date = index_date.
diag_code:        Name of variable with diagnosis codes in <diag_ds>. Note that
                  the variable is expected to hold both ICD-8 and ICD-10/SKS
                  (ICD-10 with "D" prefix used in some Danish registries)
                  codes. The macro will automatically detect and handle SKS
                  codes. Must be a character variable.
                  Default is diag_code = diag_code.
diag_date:        Name of variable with diagnosis dates. Must be a numeric
                  variable with a recognized date format, eg DATEw. or 
                  YYMMDDw.. See code for full list of recognized formats.
                  Default is diag_date = diag_date.
lookback_length:  Lookback length from <index_date> defining the lookback
                  period in which we look for diagnoses to include when 
                  calculating the CCI. By default
                  lookback_length = 200 together with 
                  lookback_unit = year, ie a lookback period of 200 years,
                  in practice meaning that we use all available data on
                  diagnoses before the index date to calculate the CCI. 
                  Must be a non-negative integer. 
lookback_unit:    Unit of the lookback length specified in <lookback_length>.
                  - lookback_unit = year (Default)
                  - lookback_unit = month
                  - lookback_unit = week
                  - lookback_unit = day
exclude_groups:   Disease groups in the definition of the CCI that should be 
                  discarded in the calculation of CCI. Must be a space-separated
                  list of integers corresponding to the numbering of the
                  disease groups. See the "CODED" section of the macro.
                  Default is exclude_groups = null, ie no disease groups are
                  excluded.                
keep_pop_vars:    Should auxiliary variables in <pop_ds>, ie variables not
                  specified in <id> and <index_date> be included in <out_ds>?
                  - Yes: keep_pop_vars = y (default)
                  - No:  keep_pop_vars = n 
keep_cci_vars:    Should the individual disease group variables used in the
                  calculation of the CCI be included in <out_ds>?
                  - Yes: keep_pop_vars = y 
                  - No:  keep_pop_vars = n (default)
print_notes:      Print notes in log?
                  - Yes: print_notes = y
                  - No:  print_notes = n (default)
verbose:          Print info on what is happening during macro execution
                  to the log?
                  - Yes: verbose = y
                  - No:  verbose = n (default)
del:              Delete intermediate datasets created by the macro?
                  - Yes: del = y (default)
                  - no:  del = n   
******************************************************************************/
%macro calculate_cci(
  pop_ds          = ,
  diag_ds         = ,
  out_ds          = ,
  codes_ds        = null,
  id              = id,
  index_date      = index_date,
  diag_code       = diag_code,
  diag_date       = diag_date,
  lookback_length = 200,
  lookback_unit   = year,
  exclude_groups  = null,
  keep_pop_vars   = y,
  keep_cci_vars   = n,
  print_notes     = n,
  verbose         = n,
  del             = y
) / minoperator mindelimiter = ' ';

%put calculate_cci: start execution (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

/* Find value of notes option, save it, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;

/* Make sure there are no intermediate dataset from from a previous 
run of the macro in the work directory before execution. */
proc datasets nolist nodetails;
  delete __cci_:;
run;
quit;


/*******************************************************************************
INPUT PARAMETER CHECKS
*******************************************************************************/

/* verbose: check parameter not empty. */
%if &verbose = %then %do;
  %put ERROR: Macro parameter <verbose> not specified!;
  %goto end_of_macro;  
%end;

/* verbose: check parameter has valid value. */
%if (&verbose in y n) = 0 %then %do;
  %put ERROR: <verbose> does not have a valid value!;
  %goto end_of_macro;  
%end;

%if &verbose = y %then %do;
  %put calculate_cci: *** Input checks ***;
%end;

/* print_notes: check parameter not empty. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> not specified!;
  %goto end_of_macro;  
%end;

/*print_notes: check parameter has valid value. */
%if (&print_notes in y n) = 0 %then %do;
  %put ERROR: <print_notes> does not have a valid value!;
  %goto end_of_macro;  
%end;

%if &print_notes = y %then %do;
  options notes;
%end;   

/* Check remaining macro parameters not empty. */
%local parms i i_parm;
%let parms =  pop_ds diag_ds out_ds codes_ds id index_date diag_code       
              diag_date lookback_length lookback_unit   
              exclude_groups keep_pop_vars keep_cci_vars del;   
%do i = 1 %to %sysfunc(countw(&parms, %str( )));
  %let i_parm = %scan(&parms, &i, %str( ));
  %if %bquote(&&&i_parm) = %then %do;
    %put ERROR: Macro parameter <&i_parm> not specified!;
    %goto end_of_macro;    
  %end;
%end;

/* pop_ds: check dataset exists. */
%if %sysfunc(exist(&pop_ds)) = 0 %then %do;
  %put ERROR: Specified <pop_ds> dataset "&pop_ds" does not exist!;
  %goto end_of_macro;
%end;

/* pop_ds: check dataset not empty. */
%local ds_id rc;
%let ds_id = %sysfunc(open(&pop_ds));
%if %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Specified <pop_ds> dataset "&pop_ds" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* pop_ds: check protected variable names not used. */
proc contents data = &pop_ds(obs = 0) noprint 
  out = __cc_pop_ds_var_names(keep = name);
run;

%local pop_ds_var_names;
proc sql noprint;
  select lower(name) into: pop_ds_var_names separated by " "
  from __cc_pop_ds_var_names
  where name eqt "__" or name eqt "cci";
quit;

%local i i_var;
%do i = 1 %to %sysfunc(countw(&pop_ds_var_names, %str( )));
  %let i_var = %scan(&pop_ds_var_names, &i, %str( ));
  %put ERROR: Input dataset <pop_ds> contains variable "&i_var".;
  %put ERROR: All variables with a "__" and "cci" prefix are protected variable names.;
  %put ERROR: The input dataset is not allowed to contain any such variables;
  %put ERROR: to ensure that the macro will work as intended.;
  %goto end_of_macro; 
%end;

/* diag_ds: check dataset exists. */
%if %sysfunc(exist(&diag_ds)) = 0 %then %do;
  %put ERROR: Specified <diag_ds> dataset "&diag_ds" does not exist!;
  %goto end_of_macro;
%end;

/* diag_ds: check dataset not empty. */
%local ds_id rc;
%let ds_id = %sysfunc(open(&diag_ds));
%if %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Specified <diag_ds> dataset "&diag_ds" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* diag_ds: check protected variable names not used. */
proc contents data = &diag_ds(obs = 0) noprint 
  out = __cc_diag_ds_var_names(keep = name);
run;

%local diag_ds_var_names;
proc sql noprint;
  select lower(name) into: diag_ds_var_names separated by " "
  from __cc_diag_ds_var_names
  where name eqt "__" or name eqt "cci";
quit;

%local i i_var;
%do i = 1 %to %sysfunc(countw(&diag_ds_var_names, %str( )));
  %let i_var = %scan(&diag_ds_var_names, &i, %str( ));
  %put ERROR: Input dataset <diag_ds> contains variable "&i_var".;
  %put ERROR: All variables with a "__" and "cci" prefix are protected variable names.;
  %put ERROR: The input dataset is not allowed to contain any such variables;
  %put ERROR: to ensure that the macro will work as intended.;
  %goto end_of_macro; 
%end; 

/* codes_ds: Not all checks that could be done is implemented yet, since it
is an experimental feature at this point. */
%if &codes_ds ne null %then %do;

  /* check dataset exists. */
  %if %sysfunc(exist(&codes_ds)) = 0 %then %do;
    %put ERROR: Specified <codes_ds> dataset "&codes_ds" does not exist!;
    %goto end_of_macro;
  %end;

  /* check dataset not empty. */
  %local ds_id rc;
  %let ds_id = %sysfunc(open(&codes_ds));
  %if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: Specified <codes_ds> dataset "&codes_ds" is empty!;
    %goto end_of_macro;
  %end;
  %let rc = %sysfunc(close(&ds_id));
        
  /* check correct variable names */
  proc contents data = &codes_ds(obs = 0) noprint 
    out = __cc_codes_ds_vars(keep = name);
  run;

  %local codes_ds_var_names;
  proc sql noprint;
    select lower(name) into: codes_ds_var_names separated by " "
      from __cc_codes_ds_vars;
  quit;

  %local vars i i_var;
  %let vars = group var value;
  %do i = 1 %to 3;
    %let i_var = %scan(&vars, &i, %str( ));
    %if (&i_var in &codes_ds_var_names) = 0 %then %do;
      %put ERROR: <codes_ds> needs to have a variable called "&i_var".;
      %goto end_of_macro; 
    %end;
  %end;

  /* Check correct variable types. */

  /* check group has correct values 1-19. */

  /* check var has correct values label icd8 icd10. */
%end;

/* Check specified variable names are valid and exists in the relevant
input data. */
%local var_list i i_var j j_var ds_id rc;
%let var_list = id index_date diag_code diag_date;
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %let i_var_name = &&&i_var;
  %if %sysfunc(nvalid(&i_var_name)) = 0 %then %do;
    %put ERROR: Variable "&i_var_name" specified in <&i_var>;
    %put ERROR: is not a valid SAS variable name!;
    %goto end_of_macro;
  %end;
  %if &i_var in id index_date %then %do;
    %let ds_id = %sysfunc(open(&pop_ds));
    %if %sysfunc(varnum(&ds_id, &i_var_name)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable "&i_var_name" specified in <&i_var> does;
      %put ERROR: not exist in the input dataset "&pop_ds"!;
      %goto end_of_macro; 
    %end;
    %let rc = %sysfunc(close(&ds_id));
  %end;
  %if &i_var in id diag_code diag_date %then %do;
    %let ds_id = %sysfunc(open(&diag_ds));
    %if %sysfunc(varnum(&ds_id, &i_var_name)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable "&i_var_name" specified in <&i_var> does;
      %put ERROR: not exist in the input dataset "&diag_ds"!;
      %goto end_of_macro; 
    %end;
    %let rc = %sysfunc(close(&ds_id));
  %end;
%end; /*End of i-loop */

/* lookback_length: check non-negative integer */
%if %sysfunc(prxmatch('^\d*$', &lookback_length)) = 0 %then %do;
  %put ERROR: <lookback_length> must be a a non negative integer!;
  %goto end_of_macro; 
%end;

/* lookback_unit: check parameter has valid value. */
%if %eval(&lookback_unit in day week month year) = 0 %then %do;
  %put ERROR: <lookback_unit> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: - day;
  %put ERROR: - week;
  %put ERROR: - month;
  %put ERROR: - year (Default);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

/* diag_code: check character variable */
proc contents data = &diag_ds(obs = 0) noprint out = __cc_diag_info1;
run;

%local type;
data _null_;
  set __cc_diag_info1;
  if lowcase(name) = lowcase("&diag_code") then call symput("type", compress(put(type, 1.)));
run;

%if &type ne 2 %then %do;
  %put ERROR: <diag_code> variable "&diag_code" in dataset "&diag_ds" must be a character variable!;
  %goto end_of_macro;
%end;

/* exclude_groups: check valid value */
%if &exclude_groups ne null %then %do;
  /* Must be a space-separated list of numbers between 1 and 19 */
  %local i i_num;
  %do i = 1 %to %sysfunc(countw(&exclude_groups, %str( )));
    %let i_num = %scan(&exclude_groups, &i, %str( ));
    /* Regular expression: is i_num a number?*/
    %if %sysfunc(prxmatch('^\d*$', &i_num)) = 0 %then %do;
      %put ERROR: <exclude_groups> contain group "%bquote(&i_num)" which is not valid!;
      %put ERROR: <exclude_groups> must be a either "exclude_groups = null";
      %put ERROR: (to exclude no groups) or a space-separated list of numbers;
      %put ERROR: from 1 to 19;
      %goto end_of_macro; 
    %end;
    /* Check that 0 < i_num < 20 */
    %if &i_num < 1 or &i_num > 19 %then %do;
      %put ERROR: <exclude_groups> contain group "%bquote(&i_num)" which is not valid!;
      %put ERROR: <exclude_groups> must be a either "exclude_groups = null";
      %put ERROR: (to exclude no groups) or a space-separated list of numbers;
      %put ERROR: from 1 to 19;
      %goto end_of_macro; 
    %end;
  %end;
%end;

/* keep_pop_vars: check parameter has valid value. */          
%if %eval(&keep_pop_vars in n y) = 0 %then %do;
  %put ERROR: <keep_pop_vars> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = y (Yes);
  %put ERROR: del = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

/* keep_cci_vars: check parameter has valid value. */          
%if %eval(&keep_cci_vars in n y) = 0 %then %do;
  %put ERROR: <keep_cci_vars> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = y (Yes);
  %put ERROR: del = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

/* del: check parameter has valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = y (Yes);
  %put ERROR: del = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

    
/*******************************************************************************
CODES
*******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_cci: *** Define disease groups ***;
%end;

/* Save CCI code definitions in macro variables */
%local i;
%do i = 1 %to 19;
  %local cci_&i._label cci_&i._icd8 cci_&i._icd10;
%end;

%let cci_1_label  = Myocardial infarction;
%let cci_1_icd8   = 410;
%let cci_1_icd10  = I21 I22 I23;

%let cci_2_label  = Congestive heart failure;
%let cci_2_icd8   = 42709 42710 42711 42719 42899 78249;
%let cci_2_icd10  = I50 I110 I130 I132;

%let cci_3_label  = Peripheral vascular disease;
%let cci_3_icd8   = 440 441 442 443 444 445;
%let cci_3_icd10  = I70 I71 I72 I73 I74 I77;

%let cci_4_label  = Cerebrovascular disease;
%let cci_4_icd8   = 430 431 432 433 434 435 436 437 438;
%let cci_4_icd10  = I6 G45 G46;

%let cci_5_label  = Dementia;
%let cci_5_icd8   = 29009 2901 29309;
%let cci_5_icd10  = F00 F01 F02 F03 F051 G30;

%let cci_6_label  = Chronic pulmonary disease;
%let cci_6_icd8   = 490 491 492 493 515 516 517 518;
%let cci_6_icd10  = J40 J41 J42 J43 J44 J45 J46 J47 J60 J61
                    J62 J63 J64 J65 J66 J67 J684 J701 J703 J841 
                    J920 J961 J982 J983;

%let cci_7_label  = Connective tissue disease;
%let cci_7_icd8   = 712 716 734 446 13599;
%let cci_7_icd10  = M05 M06 M08 M09 M30 M31 M32 M33 M34 M35 
                    M36 D86;

%let cci_8_label  = Ulcer disease;
%let cci_8_icd8   = 53091 53098 531 532 533 534;
%let cci_8_icd10  = K221 K25 K26 K27 K28;

%let cci_9_label  = Mild liver disease;
%let cci_9_icd8   = 571 57301 57304;
%let cci_9_icd10  = B18 K700 K701 K702 K703 K709 K71 K73 K74 K760;

%let cci_10_label = Diabetes without end-organ damage;
%let cci_10_icd8  = 24900 24906 24907 24909 25000 25006 25007 25009;
%let cci_10_icd10 = E100 E101 E109 E110 E111 E119;

%let cci_11_label = Hemiplegia;
%let cci_11_icd8  = 344;
%let cci_11_icd10 = G81 G82;

%let cci_12_label = Moderate to severe renal disease;
%let cci_12_icd8  = 403 404 580 581 582 583 584 59009 59319 7531 792;
%let cci_12_icd10 = I12 I13 N00 N01 N02 N03 N04 N05 N07 N11 
                    N14 N17 N18 N19 Q61;

%let cci_13_label = Diabetes with end-organ damage;
%let cci_13_icd8  = 24901 24902 24903 24904 24905 24908 25001 25002 25003 25004 
                    25005 25008;
%let cci_13_icd10 = E102 E103 E104 E105 E106 E107 E108 E112 E113 E114 
                    E115 E116 E117 E118;

%let cci_14_label = Non-metastatic solid tumour;
%let cci_14_icd8  = 14 15 16 17 18 190 191 192 193 194;
%let cci_14_icd10 = C0 C1 C2 C3 C4 C5 C6 C70 C71 C72 C73 C74 C75;

%let cci_15_label = Leukaemia;
%let cci_15_icd8  = 204 205 206 207;
%let cci_15_icd10 = C91 C92 C93 C94 C95;

%let cci_16_label = Lymphoma;
%let cci_16_icd8  = 200 201 202 203 27559;
%let cci_16_icd10 = C81 C82 C83 C84 C85 C88 C90 C96;

%let cci_17_label = Moderate to severe liver disease;
%let cci_17_icd8  = 07000 07002 07004 07006 07008 57300 4560;
%let cci_17_icd10 = B150 B160 B162 B190 K704 K72 K766 I85;

%let cci_18_label = Metastatic solid tumour;
%let cci_18_icd8  = 195 196 197 198 199;
%let cci_18_icd10 = C76 C77 C78 C79 C80;

%let cci_19_label = AIDS;
%let cci_19_icd8  = 07983;
%let cci_19_icd10 = B21 B22 B23 B24;


/*******************************************************************************
OVERWRITE DEFINITIONS
*******************************************************************************/

/* Replace codes manually specified in <codes_ds> */
%if &codes_ds ne null %then %do;

  %if &verbose = y %then %do;
    %put calculate_cci: *** Overwrite disease group definitions ***;
  %end;

  data _null_;
    set &codes_ds;
    call symput(
      "cci_" || compress(put(group, 8.)) || "_" || compress(var),
      value
    );
  run; 
%end;


/*******************************************************************************
MODIFY CODES
*******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_cci: *** Modify and quote codes ***;
%end;

%do i = 1 %to 19;
  /* Quote codes and insert dummy symbols */
  %let cci_&i._icd8 = %sysfunc(prxchange(s/([\w\d]+)/"$1"#/, -1, %str(&&cci_&i._icd8)));
  %let cci_&i._icd10 = %sysfunc(prxchange(s/([\w\d]+)/"$1"#/, -1, %str(&&cci_&i._icd10)));
  /* Remove whitespace characters including tabulators, then replace
  dummy symbols with spaces */
  %let cci_&i._icd8 = %sysfunc(compress(&&cci_&i._icd8));
  %let cci_&i._icd8 = %sysfunc(prxchange(s/#/%str( )/, -1, %str(&&cci_&i._icd8)));
  %let cci_&i._icd10 = %sysfunc(compress(&&cci_&i._icd10));
  %let cci_&i._icd10 = %sysfunc(prxchange(s/#/%str( )/, -1, %str(&&cci_&i._icd10)));
%end;

%if &verbose = y %then %do;
  %put calculate_cci:   Final code list:;
  %do i = 1 %to 19;
    %if &i < 10 %then %do;
      %put calculate_cci:   Group &i       - &&cci_&i._label;
    %end;
    %else %do;
      %put calculate_cci:   Group &i      - &&cci_&i._label;
    %end;
    %put calculate_cci:   ICD-8 codes   - &&cci_&i._icd8;
    %put calculate_cci:   ICD-10 codes  - &&cci_&i._icd10;
  %end;
%end;

/*******************************************************************************
LOAD INPUT DATA
*******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_cci: *** Load input data ***;
%end;

/* Load input population and make a unique observation id */
data __cc_pop1;
  set &pop_ds;
  __obs_id = _n_;
  %if &keep_pop_vars = n %then %do;
    keep __obs_id &id &index_date;
  %end;
run;

proc sql;
  create table __cc_diag1 as
    select &id, &diag_date, &diag_code
    from &diag_ds
    where &id in (select &id from __cc_pop1);
quit;



/*******************************************************************************
INPUT DATA CHECKS
*******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_cci: *** Input data checks ***;
%end;

/*** Check index_date and diag_date are numeric variables with a
recognized date format ***/

/* List of recognized date formats. */
%local date_formats;
%let date_formats = 
  "DATE" "E8601DA" "YYMMDD"
  "DDMMYY" "DDMMYYB" "DDMMYYC" "DDMMYYD" "DDMMYYN" "DDMMYYP" "DDMMYYS" 
  "EURDFDE" "EURDFWDX" "EURDFWKX" "MINGUO" "MMDDYY" "MMDDYYB" 
  "MMDDYYC" "MMDDYYD" "MMDDYYN" "MMDDYYP" "MMDDYYS"
;

proc contents data = __cc_pop1(obs = 0) noprint out = __cc_pop_ds_info1;
run;

proc contents data = __cc_diag1(obs = 0) noprint out = __cc_diag_ds_info1;
run;

%local __fail_index_date_is_num __fail_index_date_is_date __fail_index_date_format;
data __cc_pop_ds_info2;
  set __cc_pop_ds_info1;
  where lowcase(name) = lowcase("&index_date");
  call symput("__fail_index_date_is_num", put((type = 1), 1.));
  call symput("__fail_index_date_is_date", put((upcase(format) in (%upcase(&date_formats))), 1.));
  call symput("__fail_index_date_format", format);
run;

%local __fail_diag_date_is_num __fail_diag_date_is_date __fail_diag_date_format;
data __cc_diag_ds_info2;
  set __cc_diag_ds_info1;
  where lowcase(name) = lowcase("&diag_date");
  call symput("__fail_diag_date_is_num", put((type = 1), 1.));
  call symput("__fail_diag_date_is_date", put((upcase(format) in (%upcase(&date_formats))), 1.));
  call symput("__fail_diag_date_format", format);
run;

%if &__fail_index_date_is_num = 0 %then %do;
  %put ERROR: Variable "&index_date" is not numeric;
  %goto end_of_macro;
%end;

%if &__fail_index_date_is_date = 0 %then %do;
  %put ERROR: Variable "&index_date" has format &__fail_index_date_format..;
  %put ERROR: This format is not recognized as a date format by the macro.;
  %put ERROR: If the variable IS a date variable, use another date format;
  %put ERROR: recognized by the macro (eg DATEw.);
  %goto end_of_macro;
%end;

%if &__fail_diag_date_is_num = 0 %then %do;
  %put ERROR: Variable "&diag_date" is not numeric;
  %goto end_of_macro;
%end;

%if &__fail_diag_date_is_date = 0 %then %do;
  %put ERROR: Variable "&diag_date" has format &__fail_diag_date_format..;
  %put ERROR: This format is not recognized as a date format by the macro.;
  %put ERROR: If the variable IS a date variable, use another date format;
  %put ERROR: recognized by the macro (eg DATEw.);
  %goto end_of_macro;
%end;

/*** Determine if ICD-10 or SKS codes are used in the data ***/

/* Take small random sample of the diagnosis data. */
%local n_diag;
proc sql noprint;
  select count(*) into: n_diag
    from __cc_diag1;
quit;

proc surveyselect data = __cc_diag1 method = srs n = %sysfunc(min(1000, &n_diag))
  out = __cc_codes1 noprint;
run;

data __cc_codes2;
  set __cc_codes1;
  format __code_type $7.;
  if &diag_code = "" then __code_type = "empty";
  else if prxmatch('/^D[a-z]\d*$/i', compress(&diag_code)) 
    then __code_type = "sks";
  else if prxmatch('/^[\d]+$/i', compress(&diag_code)) 
    then __code_type = "icd8";
  else if prxmatch('/^[a-z]\d*$/i', compress(&diag_code)) 
    then __code_type = "icd10";
  else __code_type = "unknown";
  __dummy = 1;
  keep __code_type __dummy;
run;

proc means data = __cc_codes2 nway noprint;
  class __code_type;
  output out = __cc_codes3 sum(__dummy) = n;
run;

%local __n_empty __n_sks __n_icd8 __n_icd10 __n_unknown;
%let __n_empty = 0;
%let __n_sks = 0;
%let __n_icd8 = 0;
%let __n_icd10 = 0;
%let __n_unknown = 0;

data _null_;
  set __cc_codes3;
  if __code_type = "empty" then call symput("__n_empty", put(n, comma12.));
  else if __code_type = "sks" then call symput("__n_sks", put(n, comma12.));
  else if __code_type = "icd8" then call symput("__n_icd8", put(n, comma12.));
  else if __code_type = "icd10" then call symput("__n_icd10", put(n, comma12.));
  else if __code_type = "unknown" then call symput("__n_unknown", put(n, comma12.));
run;

%if &verbose = y %then %do;
  %put calculate_cci: Code types in sample of data:;
  %put calculate_cci: - Empty string: %left(%bquote(&__n_empty));
  %put calculate_cci: - SKS:          %left(%bquote(&__n_sks));
  %put calculate_cci: - ICD-8:        %left(%bquote(&__n_icd8));
  %put calculate_cci: - ICD-10:       %left(%bquote(&__n_icd10));
  %put calculate_cci: - Unknown:      %left(%bquote(&__n_unknown));
%end;

%if &__n_unknown ne 0 %then %do;
  %put ERROR: Variable "&diag_code" has values that;
  %put ERROR: that could not be identified as an empty string, or an;
  %put ERROR: ICD-8/ICD-10/SKS code.;
  %goto end_of_macro;
%end;

/* Convert SKS codes to ICD-10. */
%if &__n_sks ne 0 %then %do;
  data __cc_diag1;
    set __cc_diag1;
    if prxmatch('/^D[a-z]/i', compress(&diag_code)) 
      then &diag_code = substr(&diag_code, 2);
  run;
%end;

/*******************************************************************************
PROCESS INPUT DATA
*******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_cci: *** Process input data ***;
%end;

/* Clean diagnosis data: we only need diagnosis code 
information on the "group" level, not for each individual code. */
data __cc_diag2;
  set __cc_diag1;
  %do i = 1 %to 19;
    if &diag_code in: (&&cci_&i._icd8 &&cci_&i._icd10) then do;
      __group = &i;
      output;
    end;
  %end;
  keep &id __group &diag_date;
run;

proc sort data = __cc_diag2 out = __cc_diag3 nodupkeys;
  by &id __group &diag_date;
run;

/* Exclude codes not to be included in the calculations. */
%if &exclude_groups ne null %then %do;
  data __cc_diag3;
    set __cc_diag3;
    where __group not in (&exclude_groups);
  run;
%end;

/* Merge cleaned diagnosis data to the population. Note that this
is a many-to-many join (as intended) if multiple observations have 
the same id. */
proc sql;
  create table __cc_cci1 as
    select a.*, b.__group, b.&diag_date
      from __cc_pop1 as a
      left join __cc_diag3 as b
      on a.&id = b.&id 
      order by a.__obs_id, __group, &diag_date;
quit;


/*******************************************************************************
CALCULATE CCI
*******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_cci: *** Calculate CCI ***;
%end;

data &out_ds;
  set __cc_cci1;
  /* We are using __obs_id, not <id>, to define by-groups, so that the CCI is 
  calculated for each observation in the input population. */
  by __obs_id;
  length cci 3;
  format cci 2.;
  format __tmp yymmdd10.;

  %do i = 1 %to 19;
    length cci_&i. 3;
    format cci_&i. 1.;
    label cci_&i. = "&&cci_&i._label";
    retain cci_&i;
  %end;

  if first.__obs_id then do;
    %do i = 1 %to 19;
      cci_&i = 0;
    %end;
  end;

  %do i = 1 %to 19;
    /* __tmp is the start date of the lookback period, ie the index date
    minus some number of days/weeks/months/years. */
    __tmp = intnx("&lookback_unit", &index_date, -&lookback_length, "same");
    if __group = &i and __tmp <= &diag_date < &index_date
      then cci_&i = 1;
  %end;

  /* Calculation of CCI. This is properly not the original CCI definition,
  but rather some modification. This should be investigated at some point. */
  if last.__obs_id then do;
    cci = 1*(cci_1 + cci_2 + cci_3 + cci_4 + cci_5 + cci_6 + cci_7 +
             cci_8 + (1 - cci_17)*cci_9 + (1 - cci_13)*cci_10) + 
          2*(cci_11 + cci_12 + cci_13 + (1 - cci_18)*(cci_14) + 
             cci_15 + cci_16) + 
          3*(cci_17) + 
          6*(cci_18 + cci_19)
        ;
    output;
  end;

  drop  __obs_id  __tmp &diag_date __group 
        %if &keep_cci_vars = n %then %do; cci_: %end;
  ;
run;


%end_of_macro:


/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __cc_:;
  run;
  quit;
%end; 

/* Restore value of notes option */
options &opt_notes;

%put calculate_cci: end execution   (%sysfunc(compress(%sysfunc(datetime(), datetime32.))));

%mend calculate_cci;
