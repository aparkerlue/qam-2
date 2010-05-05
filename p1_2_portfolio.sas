* --------------------------------------------------------------------
  Build data set for period.
  -------------------------------------------------------------------- ;
%build_period_data(prefix=ws.Top&mStockLimit._daily, for=1970, preceding=5,
    index=ws.Top&mStockLimit._by_year, indexout=work.Period_index, 
    out=work.Period_daily);
RUN;

* --------------------------------------------------------------------
  Generate sample covariance matrix and average returns.
  -------------------------------------------------------------------- ;
PROC SORT DATA=work.Period_daily;
    BY date permno;
PROC TRANSPOSE DATA=work.Period_daily(KEEP=permno date ret)
    OUT=work.Period_returns_by_date PREFIX=permno_;
    BY date;
    ID permno;
    VAR ret;
PROC CORR DATA=work.Period_returns_by_date COV OUT=work.Period_stats NOPRINT;
DATA work.Period_cov(DROP=_TYPE_ _NAME_ DATE);
    SET work.Period_stats;
    IF _TYPE_ EQ 'COV' AND _NAME_ NE 'DATE';
DATA work.Period_mean(DROP=_TYPE_ _NAME_ date);
    SET work.Period_stats;
    IF _TYPE_ = 'MEAN';
RUN;

* --------------------------------------------------------------------
  Import Fama-French data.
  -------------------------------------------------------------------- ;
DATA ws.Ff_monthly;
    INFILE "&sashome.\Data\F-F_Research_Data_Factors_daily.txt"
        FIRSTOBS=6 OBS=11773 MISSOVER;
    INPUT date YYMMDD8. +2 mktprm 6.2 +2 smb 6.2 +2 hml 6.2 +2 rf 6.3;
RUN;

* --------------------------------------------------------------------
  Compute risk-free rate for period.
  -------------------------------------------------------------------- ;
DATA work.Period_riskfree;
    SET ws.Ff_monthly(KEEP=date rf);
    year = YEAR(date);
    IF year >= 1970 - 5 AND year < 1970.; * FIXME;
    *IF year >= &i. - &each. AND year < &i.;
    DROP year;
PROC MEANS DATA=work.Period_riskfree NOPRINT;
    VAR rf;
    OUTPUT OUT=work.Period_riskfree_mean MEAN=rf;
DATA work.Period_riskfree_mean;
    SET work.Period_riskfree_mean(KEEP=rf);
RUN;

* --------------------------------------------------------------------
  Compute minimum variance and tangency portfolio weights.
  -------------------------------------------------------------------- ;
PROC IML;
    RESET NOPRINT;
    USE work.Period_cov;
    READ ALL INTO scm;
    USE work.Period_riskfree_mean;
    READ ALL INTO rf;
    USE work.Period_mean;
    READ ALL INTO mean;
    one = J(500,1);
    sigmainv = GINV(scm);
    mvweights = sigmainv * one * GINV(T(one)*sigmainv*one);
    tnweights = sigmainv * (T(mean) - rf*one);
    CREATE Mv_weights FROM mvweights;
    APPEND FROM mvweights;
    CREATE Tn_weights FROM tnweights;
    APPEND FROM tnweights;
    QUIT;