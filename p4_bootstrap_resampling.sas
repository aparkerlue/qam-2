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

* ====================================================================
  Compute returns.
  ==================================================================== ;

%MACRO bootstrap_cat(first=, final=, out=);
    %DO i = &first. %TO &final.;
        * For year i, build PermNos with weights and monthly data;
        DATA ws.Bootstrap5yr_tn_&i(KEEP=permno date year month wt ret retx
            dyn_wt lag_retx);
            MERGE ws.Bootstrap5yr_tn_weights_&i.(IN=bWeightsIn)
                ws.Crsp_monthly(WHERE=(year EQ &i.));
            BY permno;
            IF bWeightsIn;
            RETAIN dyn_wt;
            lag_retx = LAG(retx);
            IF FIRST.permno THEN DO;
                lag_retx = 0;
                dyn_wt = wt;
                END;
            ELSE dyn_wt = dyn_wt * (1 + lag_retx);
        PROC SORT DATA=ws.Bootstrap5yr_tn_&i;
            BY date permno;
        PROC MEANS DATA=ws.Bootstrap5yr_tn_&i NOPRINT;
            BY year month;
            VAR ret retx;
            WEIGHT dyn_wt;
            OUTPUT OUT=ws.Bootstrap5yr_tn_&i._returns MEAN=tr pr;
        PROC SORT DATA=ws.Bootstrap5yr_tn_&i._returns;
            BY year month;
        DATA ws.Bootstrap5yr_tn_&i._returns;
            SET ws.Bootstrap5yr_tn_&i._returns;
            IF NOT MISSING(year);
        RUN;
        %END;
    DATA &out.;
        SET %DO i = &first. %TO &final.; ws.Bootstrap5yr_tn_&i._returns %END; ;
    RUN;
    %MEND bootstrap_cat;

%bootstrap_cat(first=&mFirstYear., final=&mFinalYear., out=ws.Bootstrap5yr_tn)
RUN;

PROC EXPORT DATA=ws.Bootstrap5yr_tn OUTFILE="&sasdata\Results\michaud_boot.xls"
    REPLACE;
RUN;
