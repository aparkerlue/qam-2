DATA ws.Hist5yr_tn_annualreturn_1970(KEEP=year month tr pr cumtr cumpr);
	SET ws.Hist5yr_tn_returns_1970;
	RETAIN cumtr 1;
	cumtr = cumtr * (1 + tr);
	RETAIN cumpr 1;
	cumpr = cumpr * (1 + pr);
RUN;

DATA ws.past_wt;
	set ws.Hist5yr_tn_weights_1970;
	rename wt = lag_wt;
	by PERMNO;
DATA ws.current_wt;
	set ws.Hist5yr_tn_weights_1971;
	by PERMNO;
RUN;

DATA ws.diff_weights;
	MERGE ws.past_wt ws.current_wt;
	by PERMNO;
RUN;


*%MACRO turnover(length=, port= );

*%do yr=&mFirstYear+1 %to &mFinalYear;	



DATA ws.diff_weight;
	*merge portfolio weights with industry weights, MACRO INTEGRATION NEEDED;
	*MERGE ws.Hist&length.yr_&port._weights_&(yr-1) ws.Hist&length.yr_&port._weights_&yr;
	MERGE ws.Hist5yr_tn_weights_1970 ws.Hist5yr_tn_weights_1971;
	BY PERMNO;

RUN;

* ====================================================================
  Turnover
  ==================================================================== ;

%MACRO turnover_single_year(ds=, year=, out=);
    DATA &out.;
        SET &ds.;
        IF MISSING(wt) THEN wt = 0;
        IF MISSING(endwt) THEN endwt = 0;
        turn2way = ABS(endwt - wt);
    PROC MEANS DATA=&out. NOPRINT;
        VAR turn2way;
        OUTPUT OUT=&out. SUM=turnover2way;
    DATA &out.(KEEP=year turnover2way);
        SET &out.;
        year = &year.;
    RUN;
    %MEND turnover_single_year;

* NOTE: from must be strictly less than to. ;
%MACRO turnover_avg_over_period(dsprefix=, from=, to=, out=);
    %turnover_single_year(ds=&dsprefix._&from., year=&from.,
        out=&dsprefix._totmp)
    RUN;
    DATA &dsprefix._tocum;
        SET &dsprefix._totmp;
    RUN;
    %DO year = &from. + 1 %TO &to.;
        %turnover_single_year(ds=&dsprefix._&year., year=&year.,
            out=&dsprefix._totmp)
        RUN;
        DATA &dsprefix._tocum;
            SET &dsprefix._tocum &dsprefix._totmp;
        RUN;
        %END;
    PROC MEANS DATA=&dsprefix._tocum NOPRINT;
        VAR turnover2way;
        OUTPUT OUT=&out. MEAN=avgturnover2way;
    DATA &out.;
        SET &out.;
        avgturnover1way = avgturnover2way / 2;
    RUN;
    %MEND turnover_avg_over_period;

%turnover_avg_over_period(dsprefix=ws.Hist5yr_mv_weights,
    from=&mFirstYear., to=&mFinalYear.,
    out=ws.Hist5yr_mv_avgturnover)
RUN;
%turnover_avg_over_period(dsprefix=ws.Hist5yr_tn_weights,
    from=&mFirstYear., to=&mFinalYear.,
    out=ws.Hist5yr_tn_avgturnover)
RUN;

%turnover_avg_over_period(dsprefix=ws.Hist2yr_mv_weights,
    from=&mFirstYear., to=&mFinalYear.,
    out=ws.Hist2yr_mv_avgturnover)
RUN;
%turnover_avg_over_period(dsprefix=ws.Hist2yr_tn_weights,
    from=&mFirstYear., to=&mFinalYear.,
    out=ws.Hist2yr_tn_avgturnover)
RUN;

%turnover_avg_over_period(dsprefix=ws.Bootstrap5yr_tn_weights,
    from=&mFirstYear., to=&mFinalYear.,
    out=ws.Bootstrap5yr_tn_avgturnover)
RUN;

* ====================================================================
  Industry Weights
  ==================================================================== ;

PROC SORT DATA=ws.indust_weight;
	BY ind;
RUN;

PROC MEANS DATA=ws.indust_weight NOPRINT;
	VAR wt;
	BY ind;
	OUTPUT OUT=ws.sum_indust_wt SUM=indust_wt;
RUN;

DATA ws.sum_indust_wt(drop= _TYPE_);
	set ws.sum_indust_wt;
	year = &yr;
	*&yr = indust_wt;
RUN;

%IF &yr = &mFirstYear %THEN %DO;
	DATA ws.Port_&port&length.yr_indust_wt;
		set ws.sum_indust_wt;
	RUN;
%END;
%ELSE %IF &yr > &mFirstYear %THEN %DO;
	PROC APPEND base=ws.Port_&port&length.yr_indust_wt data=ws.sum_indust_wt;
	RUN;	
%END;



%END;


proc export data=ws.Port_&port&length.yr_indust_wt
	outfile="C:\SAS Data\Output\Turnover.xls"
	DBMS = EXCEL2000 replace;
	sheet="Turnover&port&length";
run;



*%MEND;

*%turnover(length= 2, port=tn);
*%turnover(length= 5, port=tn);
*%turnover(length= 2, port=mv);
*%turnover(length= 5, port=mv);
*%turnover(length=5, port=blport1);
*%turnover(length=5, port=blport2);
