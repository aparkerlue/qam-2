%INCLUDE 'My Documents\My SAS Files\config.sas'; * Define SASHOME;
%INCLUDE "&sashome\mlib.sas";           * Include macro library;

LIBNAME dw "&sasdata\Data";             * dw: data warehouse;
LIBNAME ws "&sasdata\Workspace";        * ws: workspace;
LIBNAME rs "&sasdata\Results";          * rs: results;

%LET mStockLimit = 500;                 * Total stocks in universe;
%LET mMaxLookBackInYears = 5;
%LET mFirstYear = 1970;                 * First and final years for which ;
%LET mFinalYear = 2009;                 * to generate portfolios.         ;

%INCLUDE "&sashome\p1_1_setup.sas";     * Construct requisite data sets. ;
%INCLUDE "&sashome\p1_2_portfolio.sas"; * Build portfolios. ;
