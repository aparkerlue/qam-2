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
