### empirical_cdf

**Version 0.1.0**

First version of empirical_cdf macro that calculates the empirical cumulative distribution function for a variable.

### export_to_csv

Export datasets to CSV.

**Version 0.0.1**

First version.

### calculate_cci

Calculates the Charlson Comorbidity Index(CCI).

**Version 0.1.1**

- Updated the examples.

- Removed format constraints on the input date variables, since this seemed more likely to hurt than help users.

- Updated how diagnosis codes in the input data are checked, so that unrecognized codes no longer trigger an error,
  but are instead discarded the same way other codes not included in the CCI are. This error-throwing behaviour
  when finding unrecognized codes was causing a lot of problems with real world data, forcing users to either do
  non-trivial pre-cleaning of data, or hot-fixing the macro to not throw errors, in scenarios where the macro should
  just work. In hindsight, validating the input data also seems inappropriate and out of scope of the macro.


**Version 0.1.0**

Overhaul of entire macro. 

- Specified <index_date> and <diag_date> variables are now tested explitcly to make sure they have a recognized
  date format. The documentation have been made more clear about this requirement as well (issue #39)
  
- All specified variables are now case-insensitive (issue #39)

- The <lookback_period> parameter has been renamed <lookback_length>.

- The <lookback_type> parameter has been removed. The macro now automatically determines if <diag_code> contains
  ICD-10 or SKS (ICD-10 with "D" prefix) codes.
  
- Documentation and references have been improved. It is now more clear how this implementation corresponds to the 
  original definition of the comorbidity score by Charlson et al.

**Version 0.0.1**

First version of macro, based on old syntax.


### calculate_sd

**Version 0.1.1**

- Changed how missing data is intepreted for numeric variables. Numeric variables with missing values
  are now treated as categorical variables by default.

**Version 0.1.0**

First version of calculate_sd macro that calculates standardized differences (SD) of variables between two groups.


### compress

Compress a dataset

**Version 0.0.1

First version


### descriptive_summary

Produces a descriptive summary, a so-called "table 1", of variables in a dataset. This macro is a renamed version
of the deprecated pt_char macro.

**Version 0.1.1**

- Fixed bug introduced in #40

- Fixed standard deviation / standard error confusion with respect to statistics for continuous variables. 
  stats_cont = mean_stderr should have been called mean_stddev, which has now been fixed.

**Version 0.1.0**

First version

### hash_match

Matching using a hash-table merge approach

**Version 0.4.0**

- Updated documentation, examples, and tests.

- Fixed a bug, where inexact matching criterias would be evaluated incorrectly(#42)

- Changed the prefix used to refer to variable values for controls in the hash-table from "_ctrl_" to "_".

- Changed how input and output datasets are named and specified as macro parameters, to make the macro parametermore alike to how data arguments are normally specified in SAS procedures. This will hopefully make using the macro feel more natural. See documentation for more information.

- The macro will now throw an error if a variable in <match_inexact> is misspelled, given the misspelled name is not a variable name in <data>. This should hopefully help make it easier to detect misspecified inexact matching criterias.

- The formula used to select a random potential control from the hash-table has been updated, so that it correctly selects among all potential controls with equal probability. This was not the case previously, where the probability of selecting some controls was notably higher/lower if matching was done with replacement and th set of potential controls was very small.

- Removed the <by> parameter from the macro. Variables can be included in <match_exact> to achieve the same result. This is essentially also how <by> variabels were handled by the macro: as additional <match_exact> variables.

- Removed <where> parameter. The input data is almost always fully cleaned before calling the macro. As it should be. WHERE statements are handy, but the implementation in the macro feels forced.

**Version 0.3.4**

- Fixed issue with variables being case-sensitive in some cases. (#37)

**Version 0.3.3**

- Hotfix of edge-case bug introduced in version 0.3.2

**Version 0.3.2**

- Matching with "mixed" replacement can now be done using replace = m, see documentation.

- Macro parameter "inexact_vars" added to macro, to make it possible to manually specify
the exact variables used in "match_inexact" in cases where the macro incorrectly
identifies too many.

- The limit_tries parameter has been renamed to max_tries and the underlying way the 
macro sets the maximum number of tries to find controls have been slightly modified to
make it less convoluted. 

**Version 0.3.1**

- Fixed a bug where the macro would fail in certain scenarios if no potential controls exists.


**Version 0.3.0**

- Inexact matching can now be done using the match_inexact parameter. 

- Extensive changes to how the macro work to make the match_inexact parameter
a natural part of using the macro. 

- Overhaul of used terminology. Hopefully it is now more clear how the macro works.

- Made a new set of examples that highlight the flexibility of the match_inexact 
parameter, but also highlight that mistakes can easily be made that are not
necessarily easy to see.


**Version 0.2.1**

- Minor language and code revisions.

- Macro parameter "print_notes" can now be used to toggle whether or not notes are 
printed in the log. By default notes are now disabled. 

- Added a verbose macro parameter that can be used to make the macro print what 
is happening during macro execution to the log. This is primarily thought to be 
useful during development and debugging, but it might also help the interested
user to understand what is happening in the macro during execution.

- Added macro parameter keep_add_vars, making it possible to specify variables from
the input dataset that should be included in the output data that is not already
automatically included.

- Added a __match_date variable to the output, to make it more intuitive and
explicit what the matching date is.
  
  
**Version 0.2.0**

Further development of the macro. 

**Version 0.1.0**

First initial attempt at making macro using a hash-table merge to do matching.
Should work as intended, but should be used with caution.



### mask_table

Masks/suppresses/censors a table of aggregated counts, if the table contains
counts that are deemed person-sensitive.

**Version 0.1.2**

Removed functionality to mask large numbers (#54)

**Version 0.1.1**

Refined how masking of large counts are done. 

**Version 0.1.0**

First attempt of generalized implementation of masking algorithm. So far the 
macro expects input data with the same structure as the output from the pt_char 
macro. Default macro parameters are set to facilitate the use of this macro in 
connection with the pt_char macro, but if the table data if not output from 
pt_char it might still be easy to modify it so that it can be used with the
macro. See examples. 


### ps_match

Efficient propensity score pair matching using a hash-table merge.

**Version 0.1.3**

- It is now possible to specify the match ID variable name in the output using the match_id_name parameter.

- Default values have been added to out_pf (_ps_match), group_var(group), and ps_var(ps) to facilitate use of macro.

- A jitter_ps parameter has been added that can be used to control whether or not small amounts of random noise is added to the ps values. This is done by default to ensure that random matches are made in scenarios where there are multiple persons with the same ps. This is important if the ps only takes discrete values, but this can now be disabled if the user does not want this behavior.

**Version 0.1.2**

- Fixed bug causing matching without replacement (replace = n) to not work as intended.


### pt_char

MACRO IS DEPRECATED. Use the descriptive_summary macro instead!

Produces a so-called "table 1" with aggregated patient characteristics

**Version 0.2.1**

- Fixed a bug where the macro would fail if both the strata and the weight
  macro parameters were used.
  
- Included a few more tests.

**Version 0.2.0**

- Changed version numbering to reflect that the macro is still under active
  development and most changes will likely not be backwards-compatible.
  This change will hopefully not cause too much confusion. Few people (if any) 
  are using the macro at this point.
  
- Extensive renaming of macro parameters to (hopefully) make the macro more
  intuitive to understand and use.
  
- Added a macro parameter controlling whether or not percentage signs are 
  included for percentage statistics in the output.
  
- Added a where-condition.

- Fixed a bug, where if a variable was included in more than one of var_list,
  strata, and by, the macro would break down.
  
- It is now possible to choose what statistics to calculate for each separate
  variable in var_list using the var_stats macro parameter.
  
  
### risk_time
  
Stratification and summarization of risk-time
  

**Version 0.1.1**

- yymmddw. is now accepted as a valid date format.

- Macro now prints the time at start and end of execution.

- Changed how stratification variables are specified. The <stratify_year> and <stratify_age> 
  have been removed, and <stratify_by> now has default value stratify_by = _year_ _age_, 
  which specifies that the specified <birth_date>, <fu_start> and <fu_end> variables are used to
  stratify by calender year and age. Additional (constant) variables can still be specified to
  make additional stratifications. (issue #31)
  
- Macro is now considerably faster, especially when stratification is not done on both age and
  calendar year. (issue #31)

- Changed how days of risk-time is counted in (age/year) stratas. Before, if a person entered and exited the
  strata on the same day, then this would count as zero days of risk-time. This has now been changed to count as 
  one day of follow-up.
   

**Version 0.1.0**

- Made complete overhaul of old macro and added it to this repository 

### smooth_periods

Smooth time periods.

**Version 0.0.2**

- Fixed bug caused by option varinitchk = error. (#59)

**Version 0.0.1**

- First version


