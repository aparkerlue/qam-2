/* RELATIVE/ABSOLUTE PERFORMANCE ATTRIBUTION CODE */

*Relative Performance Attribution;
%macro rel_perf(portfolio=, yearLength=);

data perf_data;
	merge ws.sp500_ret(in=k) rs.&portfolio&yearLength(in=l);
	by year month;
	*excess return over SP500, in TOTAL RETURNS;
	XS_ret_TR = TR - SPRTRN;
	if k and l;
run;

proc means data=perf_data mean stddev noprint;
	var XS_ret_TR;
	*mean std dev of excess return over SP500;
	output out=Port_Perf mean=Avg_XS_Ret_TR_mo std=TE;
run;

data Port_Perf(drop=_TYPE_ _FREQ_);
	set Port_Perf;
	*Annualized excess average return;
	Yr_XS_Ret_Over_SP500 = Avg_XS_Ret_TR_mo*12;
	*Annualized tracking error;
	TE = TE*sqrt(12);
	IR = Yr_XS_Ret_Over_SP500/TE;
run;

proc export data=Port_Perf
	outfile="C:\SAS Data\Output\HW2Rel_Port_Perf.xls"
	DBMS = EXCEL2000 replace;
	sheet="Rel&portfolio&yearLength";
run;


%mend rel_perf;


%rel_perf(portfolio=mvwPortfolio, yearLength=2);
%rel_perf(portfolio=mvwPortfolio, yearLength=5);
%rel_perf(portfolio=TangPortfolio, yearLength=2);
%rel_perf(portfolio=TangPortfolio, yearLength=5);
*Black-Litterman portfolios;
%rel_perf(portfolio=Blport1_, yearLength=5);
%rel_perf(portfolio=Blport2_, yearLength=5);
*'B' for bootstrapped portfolio;
%rel_perf(portfolio=TangPortfolio, yearLength=b);



*Absolute Performance Attribution;
%macro abs_perf(portfolio=, yearLength=);

data abs_port_perf;
	merge ws.sp500_ret(in=k) rs.&portfolio&yearLength(in=l) ws.ff_factors(in=m);
	by year month;

	XS_retPR = PR - rf;
	XS_retTR = TR - rf;
	XS_ret_SP_RF = SPRTRN - rf;
	if k and l and m;
run;

proc means data=abs_port_perf mean stddev noprint;
	var PR TR SPRTRN XS_retPR XS_retTR XS_ret_SP_RF;
	output out=abs_port_perf 
	mean=meanPR meanTR meanSP meanXS_PR meanXS_TR meanXS_SP_RF
	std=volPR volTR volSP volXS_PR volXS_TR volXS_SP_RF;
run;

/* Annualize mean and std */
data abs_port_perf(keep=Yr_XS_PortPR Yr_XS_PortTR Yr_XS_SP_RF Yr_vol_PR Yr_vol_TR Yr_vol_SP
 					Port_PR_Sharpe Port_TR_Sharpe SP500_Sharpe);
	set abs_port_perf;
	Yr_XS_PortPR = meanXS_PR*12;
	Yr_XS_PortTR = meanXS_TR*12;
	Yr_XS_SP_RF = meanXS_SP_RF*12; 


	Yr_vol_PR = volPR*sqrt(12);
	Yr_vol_TR = volTR*sqrt(12);
	Yr_vol_SP = volSP*sqrt(12);
	
	Port_PR_Sharpe = Yr_XS_PortPR/Yr_vol_PR;
	Port_TR_Sharpe = Yr_XS_PortTR/Yr_vol_TR;
	SP500_Sharpe = Yr_XS_SP_RF/Yr_vol_SP;

run;

proc export data=abs_port_perf
	outfile="C:\SAS Data\Output\HW2Abs_port_perf.xls"
	DBMS = EXCEL2000 replace;
	sheet="AbsPerf&portfolio&yearLength";
run;

%mend abs_perf;


%abs_perf(portfolio=mvwPortfolio, yearLength=2);
%abs_perf(portfolio=mvwPortfolio, yearLength=5);
%abs_perf(portfolio=TangPortfolio, yearLength=2);
%abs_perf(portfolio=TangPortfolio, yearLength=5);
*Black-Litterman portfolios;
%abs_perf(portfolio=Blport1_, yearLength=5);
%abs_perf(portfolio=Blport2_, yearLength=5);
*'B' for bootstrapped portfolio;
%abs_perf(portfolio=TangPortfolio, yearLength=b);
