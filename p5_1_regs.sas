/* REGRESSION CODE */

/* Import Fama French, market return data */
DATA ws.FF_factors(drop=dateff);
	set dw.Ff_factors;
	year = YEAR(dateff);
	month = MONTH(dateff);
	*days = DAY(dateff);
	if year>=&mFirstYear and year<=&mFinalYear;
RUN;

/* Import SP500 return data */
DATA ws.SP500_ret(keep=year month VWRETD VWRETX SPRTRN);
	set dw.SP500_ret;
	month=month(CALDT);
	year=year(CALDT);
	if year>=&mFirstYear and year<=&mFinalYear;
RUN;


%macro reg_sp500(portfolio=, yearLength=);

*import portfolio return data;
data port_ret;
	set rs.&portfolio&yearLength;
	if year>=&mFirstYear and year<=&mFinalYear;
run;

proc sort data=ws.SP500_ret;
	by year month;
run;

proc sort data=port_ret;
	by year month;
run;

proc sort data=ws.ff_factors;
	by year month;
run;

data RegRet;
	merge ws.sp500_ret(in=k) port_ret(in=l) ws.ff_factors(in=m);
	by year month;
	*excess return of portfolio, total w/ dividends;
	XS_ret_Rf = TR - rf;
	XS_ret_SP = SPRTRN - rf;
	if k and l and m;
run;


/* Open excel for regression */
ODS TAGSETS.EXCELXP
file="C:\SAS data\Output\HW2Reg&portfolio&yearLength..xls"
STYLE=minimal
OPTIONS ( Orientation = 'landscape'
FitToPage = 'yes'
Pages_FitWidth = '1'
Pages_FitHeight = '100' );

/* Market factor regression */
proc reg data=RegRet;
	model XS_ret_Rf = XS_ret_SP;
	output out = xx;
run;

ods tagsets.excelxp close;

%mend;

%reg_sp500(portfolio=mvwPortfolio, yearLength=2);
%reg_sp500(portfolio=mvwPortfolio, yearLength=5);
%reg_sp500(portfolio=TangPortfolio, yearLength=2);
%reg_sp500(portfolio=TangPortfolio, yearLength=5);
*Black-Litterman portfolios;
%reg_sp500(portfolio=Blport1_, yearLength=5);
%reg_sp500(portfolio=Blport2_, yearLength=5);
*'b' for bootstrapped portfolio;
%reg_sp500(portfolio=TangPortfolio, yearLength=b);





%macro reg_fff(portfolio=, yearLength=);

*Fama French data already imported as ff_factors;

*import portfolio return data;
data port_ret;
	set rs.&portfolio&yearLength;
	if year>=&mFirstYear and year<=&mFinalYear;
run;

proc sort data=port_ret;
	by year month;
run;

proc sort data=ws.ff_factors;
	by year month;
run;

data RegRetFFF;
	merge port_ret(in=k) ws.ff_factors(in=l);
	by year month;
	*excess returns of portfolio, using TOTAL RETURNS;
	XS_ret_Rf = TR - rf;
	if k and l;
run;


/* Open excel for regression */
ODS TAGSETS.EXCELXP
file="C:\SAS data\Output\HW2FFreg&portfolio&yearLength..xls"
STYLE=minimal
OPTIONS ( Orientation = 'landscape'
FitToPage = 'yes'
Pages_FitWidth = '1'
Pages_FitHeight = '100' );

/*3 Factor regression */
proc reg data=RegRetFFF;
	model XS_ret_Rf = MKTRF SMB HML;
	output out = xx;
run;

ods tagsets.excelxp close;

%mend;


%reg_fff(portfolio=mvwPortfolio, yearLength=2);
%reg_fff(portfolio=mvwPortfolio, yearLength=5);
%reg_fff(portfolio=TangPortfolio, yearLength=2);
%reg_fff(portfolio=TangPortfolio, yearLength=5);
*Black-Litterman portfolios;
%reg_fff(portfolio=Blport1_, yearLength=5);
%reg_fff(portfolio=Blport2_, yearLength=5);
*'b' for bootstrapped portfolio;
%reg_fff(portfolio=TangPortfolio, yearLength=b);
