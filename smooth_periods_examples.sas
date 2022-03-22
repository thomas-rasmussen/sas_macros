/* Example 1 */
data dat;
  input id start end;
  datalines;
  1 1 2
  1 3 4
  2 1 2
  2 4 5
  ;
run;

/* Note that the macro by defaults assume that there is a "start" and "end"
variable, that is to be used. */
%smooth_periods(data = dat, out = out, by = id);


/* Example 2 */

/* Use of keep_first and keep_last parameters to keep values of variables
in the first and last line of smoothed periods. */
data dat;
  format start1 end1 yymmdd10.;
  informat start1 end1 yymmdd10.;
  input id start1 end1 var1 var2;
  datalines;
  1 2000-01-01 2000-01-02 1 2
  1 2000-01-03 2000-01-04 2 3
  2 2000-01-01 2000-01-02 1 2
  2 2000-01-04 2000-01-05 2 3
  ;
run;

%smooth_periods(
  data       = dat,
  out        = out,
  start      = start1,
  end        = end1,
  by         = id,
  keep_first = var1,
  keep_last  = var2
);
