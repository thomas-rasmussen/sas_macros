/*******************************************************************************
DATA
*******************************************************************************/

/* Source population with the following variables:
id:           Person ID
index_date:   Date the person is to be matched with a set of controls.
male:         Male gender (1 = yes)
*/
data sourcepop;
  input id$ index_date male;
  informat index_date yymmdd10.;
  format index_date yymmdd10.;
  datalines;
  01 2000-01-01 0
  02 2001-01-01 0
  03 2002-01-01 1
  04 .          0
  05 .          0
  06 .          0
  07 .          0
  08 .          1
  09 .          1
  10 .          1
  ;
run;


/*******************************************************************************
EXAMPLE: STANDARD USE
*******************************************************************************/

/* Usually, a mixture of both exact and inexact matching criterias are used.
Here, we show how do exact matching on gender using the <match_exact> parameter,
and how inexact matching using the <match_inexact> parameter can be used to
further require that cases are not matched to themselves, and that controls
can't be cases themselves at the time of matching. */
%hash_match(
  data = sourcepop,
  out = standard_use,
  match_date = index_date,
  match_exact = male,
  match_inexact = %str(
    id ne _id and (_index_date > index_date or _index_date = .)
  ),
  seed = 1
);


/*******************************************************************************
EXAMPLE: ASSESS MATCHING CRITERIAS
*******************************************************************************/

/* It is a good idea to check that the matching criterias are actually
fulfilled in the matched population. This could be done
as follows for the "standard use" matched population made above. */

data standard_use_check1;
  set standard_use;
  by __match_id;
  retain case_male case_id case_index_date fail_male fail_id fail_not_case;
  if first.__match_id then do;
    /* Retain case variable values */
    case_male = male;
    case_id = id;
    case_index_date = index_date;
    /* Reset number of failed conditions */
    fail_male = 0;
    fail_id = 0;
    fail_not_case = 0;
  end;
  else do;
    if case_male ne male then fail_male = 1;
    if case_id = id then fail_id = 1;
    if (index_date > case_index_date or index_date = .) = 0 then fail_not_case = 1;
  end;
  if last.__match_id;
  keep fail_:;
run;

proc means data = standard_use_check1 sum;
  var fail_:;
run;

/*
     The MEANS Procedure

Variable                  Sum
fail_male                   0
fail_id                     0
fail_not_case               0
*/


/*******************************************************************************
EXAMPLE: MATCHING DIAGNOSTICS
*******************************************************************************/

/* The <out_incomplete> and <out_info> parameters can be used to furhter
assess how well the matching went. 

Information on cases for which no or only some matches could be found, is saved
in the dataset specified in <out_incomplete>. Ideally, this datasets is empty,
meaning that a full set of matches could be found for each case. If not, it can
help identify characteristics for persons for whom it was difficult or
impossible to find matches. 

Diagnostics from the matching process is saved in the datasest specified in
<out_info>. For a full explanation of the information in the dataset, see
<out_info> documentation. 

Here we redo the "standard use" exampel above and look at the diagnostics. */
%hash_match(
  data = sourcepop,
  out = standard_use,
  out_incomplete = incomplete,
  out_info = info,
  match_date = index_date,
  match_exact = male,
  match_inexact = %str(
    id ne _id and (_index_date > index_date or _index_date = .)
  ),
  seed = 1
);

/* We can see that the "incomplete" dataset is empty, so we were able to
find a full set of matches for each case. The "info" dataset gives many
details. Look at the <out_incomplete> documentation for more information. */


/*******************************************************************************
MATCHING ON CHARLSON COMORBIDITY INDEX (CCI)
*******************************************************************************/

/* Matching on disease scores like the CCI is commonly done in an attempt to
match patients with the same level of comorbidity. The CCI summarizes
comorbidities of a patient into a single score, typically categorized as
0/1-2/+3. The CCI is not time-invariant like birth year or gender, but changes
over time as the patient's comorbidities changes. This makes the CCI more
complicated to match on, since it has to be recalculated every time a control
is evaluated as a match, because the matching date is (most likely) different
for each case. Furthermore, the CCI is sometimes defined using a fixed lookback
period of eg 10 years, making the matching even more complicated. For more
information on CCI and how it can be immplemented, see the calculate_cci macro.

Here we will show how extensive use of inexact matching conditions can be
used to match on grouped CCI in the special case where we use all comorbidity
data on patients, not just data in a fixed period before the matching date.
This situation is a little more simple, as we only need to know the first
date (if any) of any relevant dianoses used in the CCI definition, to be able to
define the CCI on any given date. */

/* Simulate data. Add first-ever diagnoses of each of the 19 disease groups
included in the CCI to the data for each id. */
%macro _sim_data;
data dat_cci;
  call streaminit(1);
  format id 3. index_date yymmdd10.;
  do id = 1 to 1000;
    index_date = mdy(1, 1, 2000) + round(rand("uniform")* 5000);
    if rand("uniform") < 0.99 then index_date = .;
    %do i = 1 %to 19;
      format cci_&i yymmdd10.;
      cci_&i = mdy(1, 1, 2000) + round(rand("normal") * 2000);
      if rand("uniform") > 0.05 then do;
        cci_&i = .;
      end;
    %end;
    output;
  end;
run;
%mend _sim_data;
%_sim_data;

/* Grouped CCI definition for cases */
%let cci_case = %str(
  1*(
      (. < cci_1 < index_date) + (. < cci_2 < index_date) +
      (. < cci_3 < index_date) + (. < cci_4 < index_date) +
      (. < cci_5 < index_date) + (. < cci_6 < index_date) +
      (. < cci_7 < index_date) + (. < cci_8 < index_date) +
      (1 - (. < cci_17 < index_date))*(. < cci_9 < index_date) +
      (1 - (. < cci_13 < index_date))*(. < cci_10 < index_date)
     ) +
  2*(
      (. < cci_11 < index_date) + (. < cci_12 < index_date) +
      (. < cci_13 < index_date) +
      (1 - (. < cci_18 < index_date))*(. < cci_14 < index_date) +
      (. < cci_15 < index_date) + (. < cci_16 < index_date)
    ) +
  3*((. < cci_17 < index_date)) +
  6*((. < cci_18 < index_date) + (. < cci_19 < index_date))
);
%let cci_case = %str(
  0*(&cci_case = 0) + 1*(1 <= &cci_case <= 2) + 2*(&cci_case >= 3)
);
%put &cci_case;

/* grouped CCI definition for controls */
%let cci_ctrl = %str(
  1*(
      (. < _cci_1 < index_date) + (. < _cci_2 < index_date) +
      (. < _cci_3 < index_date) + (. < _cci_4 < index_date) +
      (. < _cci_5 < index_date) + (. < _cci_6 < index_date) +
      (. < _cci_7 < index_date) + (. < _cci_8 < index_date) +
      (1 - (. < _cci_17 < index_date))*(. < _cci_9 < index_date) +
      (1 - (. < _cci_13 < index_date))*(. < _cci_10 < index_date)
     ) +
  2*(
      (. < _cci_11 < index_date) + (. < _cci_12 < index_date) +
      (. < _cci_13 < index_date) +
      (1 - (. < _cci_18 < index_date))*(. < _cci_14 < index_date) +
      (. < _cci_15 < index_date) + (. < _cci_16 < index_date)
    ) +
  3*((. < _cci_17 < index_date)) +
  6*((. < _cci_18 < index_date) + (. < _cci_19 < index_date))
);
%let cci_ctrl = %str(
  0*(&cci_ctrl = 0) + 1*(1 <= &cci_ctrl <= 2) + 2*(&cci_ctrl >= 3)
);
%put &cci_ctrl;


/* Make matched population */
%hash_match(
  data = dat_cci,
  out = cci,
  out_incomplete = cci_incomplete,
  out_info = cci_info,
  match_date = index_date,
  match_inexact = %str(
    id ne _id
    and (_index_date > index_date or _index_date = .)
    and &cci_case = &cci_ctrl
  ),
  n_controls = 10,
  seed = 1
);

data cci_check1;
  set cci;
  by __match_id;
  retain case_cci_g;
  /* Calculate grouped CCI on matching date */
  cci = 
    1*(
      (. < cci_1 < __match_date) + (. < cci_2 < __match_date) +
      (. < cci_3 < __match_date) + (. < cci_4 < __match_date) +
      (. < cci_5 < __match_date) + (. < cci_6 < __match_date) +
      (. < cci_7 < __match_date) + (. < cci_8 < __match_date) +
      (1 - (. < cci_17 < __match_date))*(. < cci_9 < __match_date) +
      (1 - (. < cci_13 < __match_date))*(. < cci_10 < __match_date)
     ) +
    2*(
        (. < cci_11 < __match_date) + (. < cci_12 < __match_date) +
        (. < cci_13 < __match_date) +
        (1 - (. < cci_18 < __match_date))*(. < cci_14 < __match_date) +
        (. < cci_15 < __match_date) + (. < cci_16 < __match_date)
      ) +
    3*((. < cci_17 < __match_date)) +
    6*((. < cci_18 < __match_date) + (. < cci_19 < __match_date));
  if cci = 0 then cci_g = 0;
  else if 1 <= cci <= 2 then cci_g = 1;
  else if 3 <= cci then cci_g = 2;
  if first.__match_id then case_cci_g = cci_g;
  fail_cci = (case_cci_g ne cci_g);
run;

proc means data = cci_check1 sum;
  var fail_cci;
run;

/*
    The MEANS Procedure

Analysis Variable : fail_cci

                 Sum
                   0
*/
