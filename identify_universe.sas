* dw is short for "data warehouse";
LIBNAME dw 'SASHOME\Data';
* ws is short for "workspace";
LIBNAME ws 'SASHOME\Workspace';
* rs is short for "results";
LIBNAME rs 'SASHOME\Results';

DATA ws.crsp;
    SET dw.crsp_daily (KEEP = Date PermNo Ticker Prc ShrOut);
    Year = YEAR(Date);
    MktCap = ABS(Prc) * ABS(ShrOut);

* Set up data to compute tangency portfolio for 1970.  Determine the
  top 500 stocks by average market cap from 1965-1969.;

* Create subset that includes data from 1965-1969, and compute average
  market cap.;
DATA ws.universe_1970_daily;
    SET ws.crsp;
    IF Year >= 1965 AND Year < 1970;
PROC MEANS NOPRINT DATA = ws.universe_1970_daily;
    VAR MktCap;
    BY PermNo;
    OUTPUT OUT = summarydata MEAN(MktCap) = AvgMktCap;

* Create PermNo-Ticker index.;
DATA ws.universe_1970_index;
    SET ws.universe_1970_daily (KEEP = PermNo Ticker);
    BY PermNo;
    IF FIRST.PermNo = 1;

* Create table to show permno, ticker, and average market cap for top
  500 stocks.;
DATA ws.universe_1970;
    MERGE ws.universe_1970_index summarydata (KEEP = PermNo AvgMktCap);
    BY PermNo;
PROC SORT DATA = ws.universe_1970;
    BY DESCENDING AvgMktCap;
DATA ws.universe_1970;
    SET ws.universe_1970 (OBS = 500);

PROC PRINT DATA = ws.universe_1970;
    TITLE 'Top 500 Stocks by Market Cap, 1965-1969';
RUN;
