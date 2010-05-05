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

%MACRO a(prefix=, from=, to=, each=);
    %DO i = &from. %TO &to.;
        %END;
    %MEND a;
