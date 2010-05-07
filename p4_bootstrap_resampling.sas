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
