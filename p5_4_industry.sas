

DATA ws.indust_label(keep=permno year HSICMG);
	set dw.industry;
	year = YEAR(date);
	*month = MONTH(date);
	*days = DAY(date);
	if year>=&mFirstYear and year<=&mFinalYear;
	if missing(HSICMG) = 1 then delete;
RUN;

DATA ws.indust_label(drop=year);
	set ws.indust_label;
	by permno;
	if first.permno = 1;
RUN;

%MACRO industry_wt(length=, port= );

%do yr=&mFirstYear %to &mFinalYear;	

DATA ws.indust_weight;
	*merge portfolio weights with industry weights, MACRO INTEGRATION NEEDED;
	MERGE ws.Hist&length.yr_&port._weights_&yr(in=k) ws.indust_label;
	BY PERMNO;
	IF k;
RUN; 

DATA ws.indust_weight;
	SET ws.indust_weight;
	*Agriculture, forestry, fishing;
	IF HSICMG >= 1 AND HSICMG <= 9 THEN ind = 'Ag';
	*Mining;
	ELSE IF HSICMG >= 10 AND HSICMG <= 14 THEN ind = 'Mn';
	*Construction;
	ELSE IF HSICMG >= 15 AND HSICMG <= 17 THEN ind = 'Cn';
	*Manufacturing;
	ELSE IF (HSICMG >= 20 AND HSICMG <= 27) OR 
		(HSICMG >= 31 AND HSICMG <= 35) OR HSICMG = 39 THEN ind = 'Mu';
	*Chemical/Plastics;
	ELSE IF HSICMG >= 28 AND HSICMG <= 30 THEN ind = 'Ch';
	*Technology;
	ELSE IF HSICMG >= 36 AND HSICMG <= 38 THEN ind = 'Tc';
	*Transportation;
	ELSE IF HSICMG >= 40 AND HSICMG <= 47 THEN ind = 'Tr';
	*Communications;
	ELSE IF HSICMG = 48 THEN ind = 'Cm';
	*Utilities;
	ELSE IF HSICMG = 49 THEN ind = 'Ut';
	*Durable goods;
	ELSE IF HSICMG = 50 THEN ind = 'Du';
	*Non-Durable goods;
	ELSE IF HSICMG = 51 THEN ind = 'Nd';
	*Retail;
	ELSE IF HSICMG >= 52 AND HSICMG <= 59 THEN ind = 'Rl';
	*Finance, Insurance, Real Estate;
	ELSE IF HSICMG >= 60 AND HSICMG <= 67 THEN ind = 'Fi';
	*Service Industries;
	ELSE IF HSICMG >= 70 AND HSICMG <= 89 THEN ind = 'Sv';
	*Public Admin;
	ELSE IF HSICMG >= 70 AND HSICMG <= 89 THEN ind = 'Pa';
	ELSE ind = 'Ot'; 
	
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
	outfile="C:\SAS Data\Output\Industry_Wts.xls"
	DBMS = EXCEL2000 replace;
	sheet="Ind_Wt&port&length";
run;



%MEND;

%industry_wt(length= 2, port=tn);
%industry_wt(length= 5, port=tn);
%industry_wt(length= 2, port=mv);
%industry_wt(length= 5, port=mv);
*%industry_wt(length=5, port=blport1);
*%industry_wt(length=5, port=blport2);


