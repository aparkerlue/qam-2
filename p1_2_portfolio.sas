* --------------------------------------------------------------------
  Execute one-year buy-and-hold minimum variance and tangent portfolio
  strategies for 1970 to 2009.
  -------------------------------------------------------------------- ;
%execute_mv_and_tn_strategies(from=1970, to=2009, each=5,
    data_prefix=ws.Top&mStockLimit._daily,
    data_index=ws.Top&mStockLimit._by_year, work_prefix=work.Period,
    out_prefix=ws.P1);
RUN;
