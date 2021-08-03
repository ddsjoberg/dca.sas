/*Source SAS DCA Macros*/
LIBNAME  data    "C:/Users/SjobergD/GitHub/dca.sas/example-data";
LIBNAME  results "C:/Users/SjobergD/GitHub/dca.sas/unit-testing/results"; 
FILENAME report  "C:/Users/SjobergD/GitHub/dca.sas/unit-testing/unit-test-report.html";
FILENAME dca     "C:/Users/SjobergD/GitHub/dca.sas/dca.sas";
FILENAME stdca   "C:/Users/SjobergD/GitHub/dca.sas/stdca.sas";
%INCLUDE dca;
%INCLUDE stdca;

ODS HTML FILE = report;

/*DCA() MACRO CHECKS -----------------------------------------------------*/
ODS EXCLUDE ALL;
%DCA(data=data.origdca, outcome=cancer, predictors=marker, probability=no, xstart=0.05,
       xstop=0.35, xby=0.05, graph=no, out=dca_check_1);
ODS EXCLUDE NONE;

PROC COMPARE BASE = results.dca_check_1 COMPARE = dca_check_1 CRITERION=0.0001;
RUN; 
QUIT;

/*STDCA() MACRO CHECKS ---------------------------------------------------*/
ODS EXCLUDE ALL;
%STDCA(data=data.origdca, out=stdca_check_1, outcome=cancer, ttoutcome=ttcancer,
         probability=no, timepoint=1.5, predictors=marker, xstop=0.5, graph=no); 
ODS EXCLUDE NONE;

PROC COMPARE BASE = results.stdca_check_1 COMPARE = stdca_check_1;
RUN; 
QUIT;

/*copmeting risks endpoint*/
ODS EXCLUDE ALL;
DATA stdca_competerisk; 
 SET data.origdca;
 status = 0;
 IF cancer=1 THEN status=1;
 ELSE IF cancer=0 & dead=1 THEN status=2;
RUN; 

%STDCA(data=stdca_competerisk, out=stdca_check_2, outcome=status, ttoutcome=ttcancer,
         probability=no, timepoint=1.5, predictors=marker, xstop=0.5, competerisk=YES, graph=no); 
ODS EXCLUDE NONE;

PROC COMPARE BASE = results.stdca_check_2 COMPARE = stdca_check_2;
RUN; 
QUIT;
ODS HTML CLOSE;



