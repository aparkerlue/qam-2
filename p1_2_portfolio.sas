* --------------------------------------------------------------------
  Build data set for period.
  -------------------------------------------------------------------- ;
DATA work.Period_daily;
    SET ws.Top&mStockLimit._daily_1965 ws.Top&mStockLimit._daily_1966
        ws.Top&mStockLimit._daily_1967 ws.Top&mStockLimit._daily_1968
        ws.Top&mStockLimit._daily_1969;
RUN;

* --------------------------------------------------------------------
  Generate sample covariance matrix.
  -------------------------------------------------------------------- ;
PROC TRANSPOSE DATA=work.Period_daily(KEEP=permno date ret)
    OUT=work.Period_returns_by_date PREFIX=permno_;
    BY date;
    ID permno;
    VAR ret;
PROC CORR DATA=work.Period_returns_by_date COV OUT=work.Period_stats NOPRINT;
DATA work.Period_scm(DROP=_TYPE_ _NAME_ DATE)
    SET work.Period_stats;
    IF _TYPE_ EQ 'COV' AND _NAME_ NE 'DATE';
RUN;
