* --------------------------------------------------------------------
  Import Fama-French data.
  -------------------------------------------------------------------- ;
DATA ws.Ff_monthly;
    INFILE "&sashome.\Data\F-F_Research_Data_Factors_daily.txt"
        FIRSTOBS=6 OBS=11773 MISSOVER;
    INPUT date YYMMDD8. +2 mktprm 6.2 +2 smb 6.2 +2 hml 6.2 +2 rf 6.3;
RUN;

* --------------------------------------------------------------------
  Build data set for period.
  -------------------------------------------------------------------- ;
%build_period_data(prefix=ws.Top&mStockLimit._daily, for=1970, preceding=5,
    index=ws.Top&mStockLimit._by_year, indexout=work.Period_index, 
    out=work.Period_daily);
RUN;

* --------------------------------------------------------------------
  Construct portfolio and compute returns.
  -------------------------------------------------------------------- ;
%portfolio_buy_hold_one_year(year=1970, preceding=5,
    histdata=work.Period_daily, prefix=work.Period,
    mvout=work.Mv_returns_1970, tnout=work.Tn_returns_1970);
RUN;
