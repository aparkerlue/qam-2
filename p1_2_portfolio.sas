* ====================================================================
  Execute one-year buy-and-hold minimum variance and tangent portfolio
  strategies for 1970 to 2009.
  ==================================================================== ;

* --------------------------------------------------------------------
  Use preceding 5 years to compute portfolio weights.
  -------------------------------------------------------------------- ;
%execute_mv_and_tn_strategies(from=1970, to=2009, each=5,
    data_prefix=ws.Top&mStockLimit._daily,
    data_index=ws.Top&mStockLimit._by_year, work_prefix=work.Period,
    out_prefix=ws.Hist5yr);
RUN;

* --------------------------------------------------------------------
  Use preceding 2 years to compute portfolio weights.
  -------------------------------------------------------------------- ;
%execute_mv_and_tn_strategies(from=1970, to=2009, each=2,
    data_prefix=ws.Top&mStockLimit._daily,
    data_index=ws.Top&mStockLimit._by_year, work_prefix=work.Period,
    out_prefix=ws.Hist2yr);
RUN;
