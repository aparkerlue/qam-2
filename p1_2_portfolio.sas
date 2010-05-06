* ====================================================================
  Execute one-year buy-and-hold minimum variance and tangent portfolio
  strategies for &mFirstYear to &mFinalYear.
  ==================================================================== ;

* --------------------------------------------------------------------
  Use preceding 5 years to compute portfolio weights.
  -------------------------------------------------------------------- ;
%LET lookback = 5;
%execute_mv_and_tn_strategies(from=&mFirstYear., to=&mFinalYear., each=&lookback.,
    data_prefix=ws.Top&mStockLimit._daily,
    data_index=ws.Top&mStockLimit._by_year, work_prefix=work.Period,
    out_prefix=ws.Hist&lookback.yr)
RUN;

* --------------------------------------------------------------------
  Use preceding 2 years to compute portfolio weights.
  -------------------------------------------------------------------- ;
%LET lookback = 2;
%execute_mv_and_tn_strategies(from=&mFirstYear., to=&mFinalYear., each=&lookback.,
    data_prefix=ws.Top&mStockLimit._daily,
    data_index=ws.Top&mStockLimit._by_year, work_prefix=work.Period,
    out_prefix=ws.Hist&lookback.yr)
RUN;

* ====================================================================
  Bootstrap resampling.
  ==================================================================== ;

%LET lookback = 5;
%execute_bootstrap_tn_strategy(from=&mFirstYear., to=&mFinalYear.,
    each=&lookback.,
    daily_data_prefix=ws.Top&mStockLimit._daily,
    data_index=ws.Top&mStockLimit._by_year, work_prefix=work.Period,
    out_prefix=ws.Bootstrap5yr)
RUN;
