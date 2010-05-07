* ====================================================================
  Clean data for eventual use.

  We use the year and month variables for many computations, so we
  create them here.  We also use the delisting return whenever it is
  present.
  ==================================================================== ;

* --------------------------------------------------------------------
  Sample running time: 9:21.03 / 7:12.60 (real/cpu)
  -------------------------------------------------------------------- ;
DATA ws.Crsp_daily(DROP=dlret dlretx);
    SET dw.Crsp_daily;
    IF NOT MISSING(dlret) THEN ret = dlret;
    IF NOT MISSING(dlretx) THEN ret = dlretx;
    year = YEAR(date);
    month = MONTH(date);
* --------------------------------------------------------------------
  Sample running time: 23.19 / 19.06 (real/cpu)
  -------------------------------------------------------------------- ;
DATA ws.Crsp_monthly(DROP=dlret dlretx);
    SET dw.Crsp_monthly;
    IF NOT MISSING(dlret) THEN ret = dlret;
    IF NOT MISSING(dlretx) THEN ret = dlretx;
    year = YEAR(date);
    month = MONTH(date);
RUN;

* --------------------------------------------------------------------
  Handle special cases.

  Sample running time: 16.43 / 15.35 (real/cpu)
  -------------------------------------------------------------------- ;
DATA ws.Crsp_monthly;
    SET ws.Crsp_monthly;
    IF permno EQ 38287 AND date EQ '30JAN1970'D THEN DELETE;
    * The following is from the QAM manual and has not been verified
      by us. ;
    IF permno = 64629 AND year = 1982 THEN DELETE;
    IF ((permno = 53532) OR (permno = 53831) OR (permno = 53858))
        AND (year = 1971) THEN DELETE;
    IF ((permno = 55223) OR (permno = 56223)) AND (year = 1972) THEN DELETE;
    IF ((permno = 68697) OR (permno = 68451)) AND (year = 1985) THEN DELETE;
RUN;

* --------------------------------------------------------------------
  Import Fama-French data.
  -------------------------------------------------------------------- ;
DATA ws.Ff_monthly;
    INFILE "&sasdata.\Data\F-F_Research_Data_Factors_daily.txt"
        FIRSTOBS=6 OBS=11773 MISSOVER;
    INPUT date YYMMDD8. +2 mktprm 6.2 +2 smb 6.2 +2 hml 6.2 +2 rf 6.3;
RUN;

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
  Sample running time: 4:10.05 / 56.60 (real/cpu)
  -------------------------------------------------------------------- ;
%annual_seq(ds=ws.Top&mStockLimit._daily, from=&mMinYear., to=&mMaxYear.)
RUN;
