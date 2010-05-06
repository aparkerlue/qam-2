* --------------------------------------------------------------------
  Split ds into smaller data sets by year of observation.

  Assumptions:
    - ds is a data set that includes a year variable.
    - from and to are whole numbers that denote years.
  -------------------------------------------------------------------- ;
%MACRO annual_seq(ds=, from=, to=);
    DATA %DO i = &from. %TO &to.; &ds._&i. %END; ;
        SET &ds.;
        IF year EQ &from. THEN DO;
            DROP year;
            OUTPUT &ds._&from.;
            END;
        %DO i = &from. + 1 %TO &to.;
            ELSE IF year EQ &i. THEN DO;
                DROP year;              * year variable no longer necessary;
                OUTPUT &ds._&i.;
                END;
            %END;
    %MEND annual_seq;

* --------------------------------------------------------------------
  For example, to build 1965-1969 data for the 1970 top 500 stock
  portfolio:

    %build_period_data(prefix=ws.Top&mStockLimit._daily, for=1970, preceding=5,
        index=ws.Top&mStockLimit._by_year, indexout=work.Period_index, 
        out=work.Period_daily)
  -------------------------------------------------------------------- ;
%MACRO build_period_data(prefix=, for=, preceding=, index=, indexout=, out=);
    DATA &indexout.;
        SET &index.;
        IF portfolioyear EQ &for.;      * portolioyear is var of &index.;
    PROC TRANSPOSE DATA=&indexout.
        OUT=&indexout.(DROP=portfolioyear _NAME_ RENAME=(COL1 = permno));
        BY portfolioyear;
        VAR permno_:;                   * Reference all vars starting w/permno_;
    PROC SORT DATA=&indexout.;
        BY permno;
    DATA &out.;
        SET %DO i = &for. - &preceding. %TO &for. - 1; &prefix._&i. %END; ;
        BY permno date;                 * Each DS is sorted by permno and date;
    DATA &out.;
        MERGE &indexout.(IN=bIndexIn) &out.(IN=bDailyIn);
        BY permno;
        IF bIndexIn AND bDailyIn;
        IF LEFT(ret) IN ('B' 'C') THEN ret = .;
    %MEND build_period_data;

* --------------------------------------------------------------------
  Compute sample covariance matrix and mean for returns data.
  -------------------------------------------------------------------- ;
%MACRO returns_sample_covar_and_mean(data=, outcovar=, outmean=);
    %LET mTmpDsPrefix = M_scm;
    PROC SORT DATA=&data.;
        BY date permno;
    PROC TRANSPOSE DATA=&data.(KEEP=permno date ret)
        OUT=&mTmpDsPrefix._returns_by_date PREFIX=permno_;
        BY date;
        ID permno;
        VAR ret;
    PROC CORR DATA=&mTmpDsPrefix._returns_by_date COV
        OUT=&mTmpDsPrefix._stats NOPRINT;
    DATA &outcovar.(DROP=_TYPE_ _NAME_ DATE);
        SET &mTmpDsPrefix._stats;
        IF _TYPE_ = 'COV' AND _NAME_ ^= 'DATE';
    DATA &outmean.(DROP=_TYPE_ _NAME_ date);
        SET &mTmpDsPrefix._stats;
        IF _TYPE_ = 'MEAN';
    PROC DATASETS LIBRARY=work NOLIST;
        DELETE &mTmpDsPrefix._returns_by_date &mTmpDsPrefix._stats;
    RUN;
    %MEND returns_sample_covar_and_mean;

%MACRO permnos_from_covar_matrix(covmat=, out=);
    PROC TRANSPOSE DATA=&covmat. OUT=&out.(KEEP=_NAME_);
        VAR permno_:;
    DATA &out.(KEEP=permno);
        SET &out.;
        permno = INPUT(SUBSTR(_NAME_, 8), 12.);
    RUN;
    %MEND permnos_from_covar_matrix;

* --------------------------------------------------------------------
  Compute minimum variance and tangency portfolio weights, and compute
  returns from one-year buy-and-hold.
  -------------------------------------------------------------------- ;
%MACRO portfolio_buy_hold_one_year(year=, preceding=, histdata=,
    prefix=, mvwout=, mvout=, tnwout=, tnout=);
    * ----------------------------------------------------------------
      Generate sample covariance matrix and average returns, and build
      PermNo list.
      ---------------------------------------------------------------- ;
    %returns_sample_covar_and_mean(data=&histdata.,
        outcovar=&prefix._cov, outmean=&prefix._mean)
    %permnos_from_covar_matrix(covmat=&prefix._cov, out=&prefix._permnos)
    RUN;

    * ----------------------------------------------------------------
      Compute risk-free rate for period.
      ---------------------------------------------------------------- ;
    DATA &prefix._riskfree;
        SET ws.Ff_monthly(KEEP=date rf);
        year = YEAR(date);
        IF year >= &year. - &preceding. AND year < &year.;
        DROP year;
    PROC MEANS DATA=&prefix._riskfree NOPRINT;
        VAR rf;
        OUTPUT OUT=&prefix._riskfree_mean MEAN=rf;
    DATA &prefix._riskfree_mean;
        SET &prefix._riskfree_mean(KEEP=rf);
    RUN;

    * ================================================================
      Compute minimum variance and tangency portfolio weights.
      ================================================================ ;

    PROC IML;
        RESET NOPRINT;
        USE &prefix._cov;
        READ ALL INTO scm;
        USE &prefix._riskfree_mean;
        READ ALL INTO rf;
        USE &prefix._mean;
        READ ALL INTO mean;
        one = J(500,1);
        sigmainv = GINV(scm);
        mvweights = sigmainv * one * GINV(T(one)*sigmainv*one);
        tnweights = sigmainv * (T(mean) - rf*one);
        CREATE &prefix._mv_weights FROM mvweights;
        APPEND FROM mvweights;
        CREATE &prefix._tn_weights FROM tnweights;
        APPEND FROM tnweights;
        QUIT;

    * ----------------------------------------------------------------
      Minimum variance portfolio weights.
      ---------------------------------------------------------------- ;
    DATA &prefix._mv_weights;
        MERGE &prefix._permnos &prefix._mv_weights(RENAME=(COL1 = wt));
        IF wt LT 0 THEN wt = 0;
    PROC MEANS DATA=&prefix._mv_weights NOPRINT;
        VAR wt;
        OUTPUT OUT=&prefix._mv_weights_sum SUM=wtsum;
    DATA &prefix._mv_weights(KEEP=permno wt);
        SET &prefix._mv_weights;
        IF _N_ EQ 1 THEN SET &prefix._mv_weights_sum(KEEP=wtsum);
        wt = wt / wtsum;                    * Normalize;
    RUN;

    * ----------------------------------------------------------------
      Tangency portfolio weights.
      ---------------------------------------------------------------- ;
    DATA &prefix._tn_weights;
        MERGE &prefix._permnos &prefix._tn_weights(RENAME=(COL1 = wt));
        IF wt LT 0 THEN wt = 0;
    PROC MEANS DATA=&prefix._tn_weights NOPRINT;
        VAR wt;
        OUTPUT OUT=&prefix._tn_weights_sum SUM=wtsum;
    DATA &prefix._tn_weights(KEEP=permno wt);
        SET &prefix._tn_weights;
        IF _N_ EQ 1 THEN SET &prefix._tn_weights_sum(KEEP=wtsum);
        wt = wt / wtsum;                    * Normalize;
    RUN;

    * ================================================================
      Compute dynamic weights.
      ================================================================ ;

    PROC SORT DATA=&prefix._mv_weights;
        BY permno;
    DATA &prefix._mv_monthly(KEEP=permno date year month wt ret retx dyn_wt
        lag_retx);
        MERGE &prefix._mv_weights(IN=bWeightsIn)
            ws.Crsp_monthly(WHERE=(year EQ &year.));
        BY permno;
        IF bWeightsIn;
        RETAIN dyn_wt;
        lag_retx = LAG(retx);
        IF FIRST.permno THEN DO;
            lag_retx = 0;
            dyn_wt = wt;
            END;
        ELSE dyn_wt = dyn_wt * (1 + lag_retx);
    PROC SORT DATA=&prefix._mv_monthly;
        BY date permno;
    RUN;

    PROC SORT DATA=&prefix._tn_weights;
        BY permno;
    DATA &prefix._tn_monthly(KEEP=permno date year month wt ret retx dyn_wt
        lag_retx);
        MERGE &prefix._tn_weights(IN=bWeightsIn)
            ws.Crsp_monthly(WHERE=(year EQ &year.));
        BY permno;
        IF bWeightsIn;
        RETAIN dyn_wt;
        lag_retx = LAG(retx);
        IF FIRST.permno THEN DO;
            lag_retx = 0;
            dyn_wt = wt;
            END;
        ELSE dyn_wt = dyn_wt * (1 + lag_retx);
    PROC SORT DATA=&prefix._tn_monthly;
        BY date permno;
    RUN;

    * ================================================================
      Compute monthly returns.
      ================================================================ ;

    PROC MEANS DATA=&prefix._mv_monthly NOPRINT;
        BY year month;
        VAR ret retx;
        WEIGHT dyn_wt;
        OUTPUT OUT=&prefix._mv_monthly_return MEAN=tr pr;
    PROC MEANS DATA=&prefix._tn_monthly NOPRINT;
        BY year month;
        VAR ret retx;
        WEIGHT dyn_wt;
        OUTPUT OUT=&prefix._tn_monthly_return MEAN=tr pr;
    RUN;

    * ================================================================
      Output results.
      ================================================================ ;

    DATA &mvwout.;
        SET &prefix._mv_weights;
    DATA &mvout.;
        SET &prefix._mv_monthly_return;
    DATA &tnwout.;
        SET &prefix._tn_weights;
    DATA &tnout.;
        SET &prefix._tn_monthly_return;
    RUN;

    %MEND portfolio_buy_hold_one_year;

%MACRO execute_mv_and_tn_strategies(from=, to=, each=,
    data_prefix=, data_index=, work_prefix=, out_prefix=);
    %DO i = &from. %TO &to.;
        * ------------------------------------------------------------
          Build data set for period.
          ------------------------------------------------------------ ;
        %build_period_data(prefix=&data_prefix., for=&i., preceding=&each.,
            index=&data_index., indexout=&work_prefix._index,
            out=&work_prefix._daily);

        * ------------------------------------------------------------
          Construct portfolio and compute returns.
          ------------------------------------------------------------ ;
        %portfolio_buy_hold_one_year(year=&i., preceding=&each.,
            histdata=&work_prefix._daily, prefix=&work_prefix.,
            mvwout=&out_prefix._mv_weights_&i.,
            mvout=&out_prefix._mv_returns_&i.,
            tnwout=&out_prefix._tn_weights_&i.,
            tnout=&out_prefix._tn_returns_&i.);
        %END;
    %MEND execute_mv_and_tn_strategies;
