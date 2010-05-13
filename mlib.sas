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
            OUTPUT &ds._&from.;
            END;
        %DO i = &from. + 1 %TO &to.;
            ELSE IF year EQ &i. THEN DO;
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
        IF LEFT(ret) IN ('B' 'C') THEN ret = 0;
        IF LEFT(retx) IN ('B' 'C') THEN retx = 0;
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

* --------------------------------------------------------------------
  Construct ordered list of PermNos from covariance matrix.
  -------------------------------------------------------------------- ;
%MACRO permnos_from_covar_matrix(covmat=, out=);
    PROC TRANSPOSE DATA=&covmat. OUT=&out.(KEEP=_NAME_);
        VAR permno_:;
    DATA &out.(KEEP=permno);
        SET &out.;
        permno = INPUT(SUBSTR(_NAME_, 8), 12.);
    RUN;
    %MEND permnos_from_covar_matrix;

* --------------------------------------------------------------------
  Compute risk-free rate for period.
  -------------------------------------------------------------------- ;
%MACRO period_riskfree(ffdata=, year=, preceding=, out=);
    DATA &out.;
        SET &ffdata.(KEEP=date rf);
        year = YEAR(date);
        IF year >= &year. - &preceding. AND year < &year.;
        DROP year;
    RUN;
    %MEND period_riskfree;

* --------------------------------------------------------------------
  Compute minimum variance and tangency portfolio weights, and compute
  returns from one-year buy-and-hold.
  -------------------------------------------------------------------- ;
%MACRO portfolio_buy_hold_one_year(year=, preceding=, histdata=,
    prefix=, mvwout=, mvout=, tnwout=, tnout=);
    * ----------------------------------------------------------------
      Generate sample covariance matrix and average returns, build
      PermNo list, and compute risk-free rate for period.
      ---------------------------------------------------------------- ;
    %returns_sample_covar_and_mean(data=&histdata.,
        outcovar=&prefix._cov, outmean=&prefix._mean)
    RUN;
    %permnos_from_covar_matrix(covmat=&prefix._cov, out=&prefix._permnos)
    RUN;
    %period_riskfree(ffdata=ws.Ff_monthly, year=&year., preceding=&preceding.,
        out=&prefix._riskfree)
    RUN;

    * ----------------------------------------------------------------
      Compute average risk-free rate for period.
      ---------------------------------------------------------------- ;
    PROC MEANS DATA=&prefix._riskfree NOPRINT;
        VAR rf;
        OUTPUT OUT=&prefix._riskfree_mean(KEEP=rf) MEAN=rf;
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
      Add portfolio year year-end weights to weights data set.
      ================================================================ ;

    PROC SORT DATA=&prefix._mv_monthly;
        BY permno date;
    DATA &prefix._mv_weights;
        MERGE &prefix._mv_weights &prefix._mv_monthly(WHERE=(month = 12));
        BY permno;
        endwt = dyn_wt * (1 + retx);
    PROC MEANS DATA=&prefix._mv_weights NOPRINT;
        VAR endwt;
        OUTPUT OUT=Sumwt SUM=wtsum;
    DATA &prefix._mv_weights(KEEP=permno wt endwt);
        SET &prefix._mv_weights;
        IF _N_ EQ 1 THEN SET Sumwt(KEEP=wtsum);
        endwt = endwt / wtsum;
    RUN;

    PROC SORT DATA=&prefix._tn_monthly;
        BY permno date;
    DATA &prefix._tn_weights;
        MERGE &prefix._tn_weights &prefix._tn_monthly(WHERE=(month = 12));
        BY permno;
        endwt = dyn_wt * (1 + retx);
    PROC MEANS DATA=&prefix._tn_weights NOPRINT;
        VAR endwt;
        OUTPUT OUT=Sumwt SUM=wtsum;
    DATA &prefix._tn_weights(KEEP=permno wt endwt);
        SET &prefix._tn_weights;
        IF _N_ EQ 1 THEN SET Sumwt(KEEP=wtsum);
        endwt = endwt / wtsum;
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

%MACRO constrained_portfolio_buy_hold_one_year(year=, preceding=, histdata=,
    prefix=, mvwout=, mvout=, tnwout=, tnout=);
    * ----------------------------------------------------------------
      Generate sample covariance matrix and average returns, build
      PermNo list, and compute risk-free rate for period.
      ---------------------------------------------------------------- ;
    %returns_sample_covar_and_mean(data=&histdata.,
        outcovar=&prefix._cov, outmean=&prefix._mean)
    RUN;
    %permnos_from_covar_matrix(covmat=&prefix._cov, out=&prefix._permnos)
    RUN;
    %period_riskfree(ffdata=ws.Ff_monthly, year=&year., preceding=&preceding.,
        out=&prefix._riskfree)
    RUN;

    * ----------------------------------------------------------------
      Compute average risk-free rate for period.
      ---------------------------------------------------------------- ;
    PROC MEANS DATA=&prefix._riskfree NOPRINT;
        VAR rf;
        OUTPUT OUT=&prefix._riskfree_mean(KEEP=rf) MEAN=rf;
    RUN;

    * ================================================================
      Compute minimum variance and tangency portfolio weights.
      ================================================================ ;

    PROC OPTMODEL;
        * Parameters ;
        number rf init 0.04;
        number n init 500;              * 500 weights ;
        var w{1..n};
        * Model Specification ;
        max f = (sum{i in 1..n}(w[i]*r[i]) - rf)
            / sqrt(sum{i in 1..n, j in 1..n} w[i]*w[j]*cov[i,j]);
        * Solve ;
        solve with nlpc / tech=cgr;     * Nonlinear optim., conj. gradient ;
        QUIT;
    * Input: &prefix._cov, &prefix._riskfree_mean, &prefix._mean ;
    * Output: &prefix._mv_weights, &prefix._tn_weights;

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
      Add portfolio year year-end weights to weights data set.
      ================================================================ ;

    PROC SORT DATA=&prefix._mv_monthly;
        BY permno date;
    DATA &prefix._mv_weights;
        MERGE &prefix._mv_weights &prefix._mv_monthly(WHERE=(month = 12));
        BY permno;
        endwt = dyn_wt * (1 + retx);
    PROC MEANS DATA=&prefix._mv_weights NOPRINT;
        VAR endwt;
        OUTPUT OUT=Sumwt SUM=wtsum;
    DATA &prefix._mv_weights(KEEP=permno wt endwt);
        SET &prefix._mv_weights;
        IF _N_ EQ 1 THEN SET Sumwt(KEEP=wtsum);
        endwt = endwt / wtsum;
    RUN;

    PROC SORT DATA=&prefix._tn_monthly;
        BY permno date;
    DATA &prefix._tn_weights;
        MERGE &prefix._tn_weights &prefix._tn_monthly(WHERE=(month = 12));
        BY permno;
        endwt = dyn_wt * (1 + retx);
    PROC MEANS DATA=&prefix._tn_weights NOPRINT;
        VAR endwt;
        OUTPUT OUT=Sumwt SUM=wtsum;
    DATA &prefix._tn_weights(KEEP=permno wt endwt);
        SET &prefix._tn_weights;
        IF _N_ EQ 1 THEN SET Sumwt(KEEP=wtsum);
        endwt = endwt / wtsum;
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

    %MEND constrained_portfolio_buy_hold_one_year;

%MACRO execute_mv_and_tn_strategies(from=, to=, each=,
    data_prefix=, data_index=, work_prefix=, out_prefix=);
    %DO pyear = &from. %TO &to.;
        * ------------------------------------------------------------
          Build data set for period.
          ------------------------------------------------------------ ;
        %build_period_data(prefix=&data_prefix., for=&pyear., preceding=&each.,
            index=&data_index., indexout=&work_prefix._index,
            out=&work_prefix._daily)
        RUN;

        * ------------------------------------------------------------
          Construct portfolio and compute returns.
          ------------------------------------------------------------ ;
        %portfolio_buy_hold_one_year(year=&pyear., preceding=&each.,
            histdata=&work_prefix._daily, prefix=&work_prefix.,
            mvwout=&out_prefix._mv_weights_&pyear.,
            mvout=&out_prefix._mv_returns_&pyear.,
            tnwout=&out_prefix._tn_weights_&pyear.,
            tnout=&out_prefix._tn_returns_&pyear.)
        RUN;
        %END;
    %MEND execute_mv_and_tn_strategies;

%MACRO bootresample_tangent_portfolio(year=, preceding=,
    histdata_daily=, histdata_monthly=, prefix=, out_wt=, out_ret=);
    * ----------------------------------------------------------------
      Generate covariance matrix and average returns from daily data.
      ---------------------------------------------------------------- ;
    %returns_sample_covar_and_mean(data=&histdata_daily.,
        outcovar=&prefix._&year._&preceding._cov,
        outmean=&prefix._&year._&preceding._mean_daily)
    RUN;
    * ----------------------------------------------------------------
      FIXME: This is a hack.  Change missing values to 0 in covariance
      matrix.
      ---------------------------------------------------------------- ;
    DATA &prefix._&year._&preceding._cov;
        SET &prefix._&year._&preceding._cov;
        ARRAY v (*) _ALL_;
        DO i = 1 TO Dim(v);
            IF MISSING(v(i)) THEN v(i) = 0;
            END;
        DROP i;
    RUN;
    * ----------------------------------------------------------------
      Build PermNo list from daily data.
      ---------------------------------------------------------------- ;
    %permnos_from_covar_matrix(covmat=&prefix._&year._&preceding._cov,
        out=&prefix._permnos)
    RUN;
    * ----------------------------------------------------------------
      Compute risk-free rate for period from monthly data.
      ---------------------------------------------------------------- ;
    %period_riskfree(ffdata=ws.Ff_monthly, year=&year., preceding=&preceding.,
        out=&prefix._&year._&preceding._riskfree)
    RUN;
    * Add monthyear variable. ;
    DATA &prefix._&year._&preceding._riskfree;
        SET &prefix._&year._&preceding._riskfree;
        monthyear = MDY(MONTH(date), 1, YEAR(date));
    RUN;

    %DO i = 1 %TO 20;                   * Resampling iterations;
        * ------------------------------------------------------------
          Prepare randomly selected (monthly) dates for sampling.
          ------------------------------------------------------------ ;
        DATA Dates_sample;
            SET &histdata_monthly.;
            BY monthyear;
            IF FIRST.monthyear;
            order = RANUNI(-1);
        PROC SORT DATA=Dates_sample;
            BY order;
        DATA Dates_sample(KEEP=monthyear);
            SET Dates_sample(OBS=12);   * 12 observations per iteration;
        PROC SORT DATA=Dates_sample;
            BY monthyear;
        RUN;

        * ------------------------------------------------------------
          Compute average (monthly) risk-free rate for period.
          ------------------------------------------------------------ ;
        DATA &prefix._&year._&preceding._riskfree_mean;
            MERGE Dates_sample(IN=bSampleIn)
                &prefix._&year._&preceding._riskfree;
            BY monthyear;
            IF bSampleIn;
        PROC MEANS DATA=&prefix._&year._&preceding._riskfree_mean NOPRINT;
            Var rf;
            OUTPUT OUT=&prefix._&year._&preceding._riskfree_mean(KEEP=rf)
                MEAN=rf;
        RUN;

        * ------------------------------------------------------------
          Compute average (monthly) returns for period.
          ------------------------------------------------------------ ;
        DATA &prefix._&year._&preceding._mean;
            MERGE Dates_sample(IN=bSampleIn) &histdata_monthly.;
            BY monthyear;
            IF bSampleIn;
        PROC SORT DATA=&prefix._&year._&preceding._mean;
            BY permno;
        PROC SORT DATA=&prefix._permnos;
            BY permno;
        DATA &prefix._&year._&preceding._mean;
            MERGE &prefix._&year._&preceding._mean &prefix._permnos;
            BY permno;
            IF MISSING(ret) THEN ret = 0;
        PROC MEANS DATA=&prefix._&year._&preceding._mean NOPRINT;
            BY permno;
            VAR ret;
            OUTPUT OUT=&prefix._&year._&preceding._mean(KEEP=ret) MEAN=ret;
        *DATA _NULL_;
        *    SET &prefix._&year._&preceding._mean NOBS=nobs;
        *    IF nobs NE 500 THEN ABORT RETURN;
        RUN;

        * ------------------------------------------------------------
          Compute tangent portfolio weights.
          ------------------------------------------------------------ ;
        PROC IML;
            RESET NOPRINT;
            USE &prefix._&year._&preceding._cov;
            READ ALL INTO scm;
            USE &prefix._&year._&preceding._riskfree_mean;
            READ ALL INTO rf;
            USE &prefix._&year._&preceding._mean;
            READ ALL INTO mean;
            one = J(500,1);
            sigmainv = GINV(scm);
            tnweights = sigmainv * (mean - rf*one);
            CREATE &prefix._&year._&preceding._tn_weights FROM tnweights;
            APPEND FROM tnweights;
            QUIT;
        DATA &prefix._&year._&preceding._tn_weights;
            MERGE &prefix._permnos
                &prefix._&year._&preceding._tn_weights(RENAME=(COL1 = wt));
            IF wt LT 0 THEN wt = 0;
        PROC MEANS DATA=&prefix._&year._&preceding._tn_weights NOPRINT;
            VAR wt;
            OUTPUT OUT=&prefix._&year._&preceding._tn_weights_sum SUM=wtsum;
        DATA &prefix._&year._&preceding._tn_weights(KEEP=permno wt);
            SET &prefix._&year._&preceding._tn_weights;
            IF _N_ EQ 1 THEN
                SET &prefix._&year._&preceding._tn_weights_sum(KEEP=wtsum);
            wt = wt / wtsum;            * Normalize;
        RUN;

        * ------------------------------------------------------------
          Accumulate resampled portfolios.
          ------------------------------------------------------------ ;
        %IF &i. EQ 1 %THEN %DO;
            DATA &out_wt.;
                SET &prefix._&year._&preceding._tn_weights;
            RUN;
            %END;
        %ELSE %DO;
            DATA &out_wt.;
                SET &out_wt. &prefix._&year._&preceding._tn_weights;
            RUN;
            %END;
        %END;                           * DO loop for resampling;

    * ----------------------------------------------------------------
      Average sample weights.
      ---------------------------------------------------------------- ;
    PROC SORT DATA=&out_wt.;
        BY permno;
    PROC MEANS DATA=&out_wt. NOPRINT;
        BY permno;
        VAR wt;
        OUTPUT OUT=&out_wt. MEAN=wt;
    RUN;

    * ----------------------------------------------------------------
      Compute returns.
      ---------------------------------------------------------------- ;
    PROC SORT DATA=&out_wt.;
        BY permno;
    DATA &prefix._&year._tn_monthly(KEEP=permno date year month wt ret retx
        dyn_wt lag_retx);
        MERGE &out_wt.(IN=bWeightsIn) ws.Crsp_monthly(WHERE=(year EQ &year.));
        BY permno;
        IF bWeightsIn;
        RETAIN dyn_wt;
        lag_retx = LAG(retx);
        IF FIRST.permno THEN DO;
            lag_retx = 0;
            dyn_wt = wt;
            END;
        ELSE dyn_wt = dyn_wt * (1 + lag_retx);
    PROC SORT DATA=&prefix._&year._tn_monthly;
        BY date permno;
    PROC MEANS DATA=&prefix._&year._tn_monthly NOPRINT;
        BY year month;
        VAR ret retx;
        WEIGHT dyn_wt;
        OUTPUT OUT=&out_ret MEAN=tr pr;
    RUN;

    * ----------------------------------------------------------------
      Add endwts to sampled weights.
      ---------------------------------------------------------------- ;
    PROC SORT DATA=&prefix._&year._tn_monthly;
        BY permno date;
    DATA &out_wt.;
        MERGE &out_wt. &prefix._&year._tn_monthly(WHERE=(month = 12));
        BY permno;
        endwt = dyn_wt * (1 + retx);
    PROC MEANS DATA=&out_wt. NOPRINT;
        VAR endwt;
        OUTPUT OUT=Sumwt SUM=wtsum;
    DATA &out_wt.(KEEP=permno wt endwt);
        SET &out_wt.;
        IF _N_ EQ 1 THEN SET Sumwt(KEEP=wtsum);
        endwt = endwt / wtsum;
    RUN;

    %MEND bootresample_tangent_portfolio;

%MACRO build_period_data_monthly(year=, preceding=, index=, out=);
    DATA &out.;
        SET ws.Crsp_monthly;
        IF year >= &year. - &preceding. AND year < &year.;
    DATA &out.;
        MERGE &index.(IN=bIndexIn) &out.;
        BY permno;
        IF bIndexIn;
        IF LEFT(ret) IN ('B' 'C') THEN ret = .;
        monthyear = MDY(month, 1, year);
    PROC SORT DATA=&out.;
        BY date permno;
    %MEND build_period_data_monthly;

%MACRO execute_bootstrap_tn_strategy(from=, to=, each=,
    daily_data_prefix=, data_index=, work_prefix=, out_prefix=);
    %DO pyear = &from. %TO &to.;
        * ------------------------------------------------------------
          Build daily and monthly data sets for period.
          ------------------------------------------------------------ ;
        %build_period_data(prefix=&daily_data_prefix.,
            for=&pyear., preceding=&each.,
            index=&data_index., indexout=&work_prefix._index,
            out=&work_prefix._daily)
        RUN;
        %build_period_data_monthly(year=&pyear., preceding=&each.,
            index=&work_prefix._index, out=&work_prefix._monthly)
        RUN;

        * ------------------------------------------------------------
          Construct portfolio and compute returns.
          ------------------------------------------------------------ ;
        %bootresample_tangent_portfolio(year=&pyear., preceding=&each.,
            histdata_daily=&work_prefix._daily,
            histdata_monthly=&work_prefix._monthly,
            prefix=&work_prefix.,
            out_wt=&out_prefix._tn_weights_&pyear.,
            out_ret=&out_prefix._tn_returns_&pyear.)
        RUN;
        %END;
    %MEND execute_bootstrap_tn_strategy;
