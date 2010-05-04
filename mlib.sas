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
                DROP year;
                OUTPUT &ds._&i.;
                END;
            %END;
    %MEND annual_seq;

%MACRO a();
    %MEND a;
