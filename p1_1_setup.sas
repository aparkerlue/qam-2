* ====================================================================
  Set up data for tractable analysis.
  ==================================================================== ;

* --------------------------------------------------------------------
  Create a data set consisting of PermNo, year and market cap for all
  stocks in CRSP data set.

NOTE: There were 3359695 observations read from the data set DW.CRSP_MONTHLY.
NOTE: The data set WS.MKTCAP_ANNUAL has 275134 observations and 3 variables.
NOTE: DATA statement used (Total process time):
      real time           7.32 seconds
      cpu time            7.10 seconds
  -------------------------------------------------------------------- ;
DATA ws.Mktcap_annual(KEEP=permno portfolioyear mktcap);
    SET dw.crsp_monthly;
    month = MONTH(date);
    IF month EQ 12 AND NOT MISSING(prc) AND NOT MISSING(shrout);
    DROP month;
    portfolioyear = YEAR(date) + 1;     * For following year, ;
    mktcap = ABS(prc) * ABS(shrout);    * compute market cap. ;
RUN;

* --------------------------------------------------------------------
  Produce data sets of top 500 stocks by market cap for each portfolio
  year.
  -------------------------------------------------------------------- ;
PROC SORT DATA=ws.Mktcap_annual;
    BY portfolioyear DESCENDING mktcap;
DATA ws.Top&mStockLimit._mktcap_annual(KEEP=permno portfolioyear mktcap)
    ws.Top&mStockLimit._by_year(KEEP=permno portfolioyear rankname);
    SET ws.Mktcap_annual;
    BY portfolioyear;
    rank + 1;
    IF FIRST.portfolioyear THEN rank = 1;
    IF rank <= &mStockLimit;
    rankname = 'permno_'||LEFT(rank);
PROC TRANSPOSE DATA=ws.Top&mStockLimit._by_year
    OUT=ws.Top&mStockLimit._by_year(DROP=_NAME_ _LABEL_);
    BY portfolioyear;
    ID rankname;
    VAR permno;
RUN;

* --------------------------------------------------------------------
  Create index of hypothetical stock-year combinations that we use to
  generate the covariance matrices for all portfolio years.
  -------------------------------------------------------------------- ;
DATA ws.Top&mStockLimit._index(KEEP=permno year);
    SET ws.Top&mStockLimit._mktcap_annual(DROP=mktcap);
    IF portfolioyear >= &mFirstYear. AND portfolioyear <= &mFinalYear.;
    firstdatayear = portfolioyear - &mMaxLookBackInYears.;
    finaldatayear = portfolioyear - 1;  * Do not include portfolio year;
    DO i = firstdatayear TO finaldatayear;
        year = i;
        OUTPUT;
        END;
PROC SORT DATA=ws.Top&mStockLimit._index NODUPKEY;
    BY permno year;
RUN;

* --------------------------------------------------------------------
  Produce copy of CRSP daily data set with year variable.

NOTE: There were 69598021 observations read from the data set DW.CRSP_DAILY.
NOTE: The data set WS.CRSP_DAILY has 69598021 observations and 12 variables.
NOTE: DATA statement used (Total process time):
      real time           7:05.68
      cpu time            6:18.20
  -------------------------------------------------------------------- ;
DATA ws.Crsp_daily;
    SET dw.crsp_daily;
    year = YEAR(date);
RUN;

* --------------------------------------------------------------------
  Produce data set of daily data only for relevant stocks and years.

  ws.Top&mStockLimit._index is already sorted by permno and year.

  We would sort ws.Crsp_daily here--but sorting this data set would
  take forever, and moreover it seems to already be sorted to our
  needs (i.e., by permno and year).

NOTE: There were 29872 observations read from the data set WS.TOP500_INDEX.
NOTE: There were 69598021 observations read from the data set WS.CRSP_DAILY.
NOTE: The data set WS.TOP500_DAILY has 6810031 observations and 12 variables.
NOTE: DATA statement used (Total process time):
      real time           2:55.08
      cpu time            2:51.12
  -------------------------------------------------------------------- ;
DATA ws.Top&mStockLimit._daily;
    MERGE ws.Top&mStockLimit._index(IN=bIndexIn) ws.Crsp_daily(IN=bDailyIn);
    BY permno year;
    IF bIndexIn AND bDailyIn;
* --------------------------------------------------------------------
NOTE: There were 6810031 observations read from the data set WS.TOP500_DAILY.
NOTE: The data set WS.TOP500_DAILY has 6810031 observations and 12 variables.
NOTE: PROCEDURE SORT used (Total process time):
      real time           10:09.52
      cpu time            1:25.68
  -------------------------------------------------------------------- ;
PROC SORT DATA=ws.Top&mStockLimit._daily;
    BY permno date;
RUN;

* --------------------------------------------------------------------
  Determine the first and final years of data in the index.
  -------------------------------------------------------------------- ;
DATA _NULL_;
    SET ws.Top&mStockLimit._index END=EODS;
    RETAIN minyear;
    RETAIN maxyear;
    minyear = MIN(minyear, year);
    maxyear = MAX(maxyear, year);
    IF EODS THEN DO;
        CALL SYMPUT('mMinYear', minyear);
        CALL SYMPUT('mMaxYear', maxyear);
        END;
RUN;

* --------------------------------------------------------------------
NOTE: There were 6810031 observations read from the data set WS.TOP500_DAILY.
NOTE: The data set WS.TOP500_DAILY_1965 has 110034 observations and 11 variables.
NOTE: The data set WS.TOP500_DAILY_1966 has 121113 observations and 11 variables.
  ...
NOTE: The data set WS.TOP500_DAILY_2008 has 125867 observations and 11 variables.
NOTE: DATA statement used (Total process time):
      real time           4:10.05
      cpu time            56.60 seconds
  -------------------------------------------------------------------- ;
%annual_seq(ds=ws.Top&mStockLimit._daily, from=&mMinYear., to=&mMaxYear.)
RUN;
