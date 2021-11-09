
/************************************************************************************************************
PROGRAM:	DCA.sas
PROGRAMMER:	Daniel Sjoberg
DATE:		6/10/2013
UPDATED:	2/2/2015 Emily Vertosick
NOTE:		dca.sas calculates the points on a decision curve and optionally
			plots the decision curve, where <yvar> is a binary response and
			<xvars> are predictors of the binary response.
			The default is that all <xvars> specified are probabilities. If this
			is not the case, then the user must specify the <prob> option. 
*************************************************************************************************************/

%MACRO DCA(	
	data=,					/*Name of input dataset*/
	out=,					/*Name of output dataset containing calculated net benefit*/
	outcome=, 				/*outcome variable, 1=event, 0=nonevent*/
	predictors=,			/*List variables with the predicted probabilities separated by a space*/
	xstart=0.01,			/*Low Threshold Value, this is the lowest probability the Net Benefit will be calculated for*/
	xstop=0.99,				/*High Threshold, this is the largest probability the Net Benefit will be calculated for*/
	xby=0.01,				/*By Value for Threshold Values, this is length of the interval at which the Net Benefit is calculated.*/
	harm=,					/*list of harms to apply to each predictor*/
	intervention=no,		/*calculate number of interventions avoided (yes/no)*/
	interventionper=100,	/*Number of intervention per xx patients*/
	probability=,			/*list indicating whether each predictor is a probability (e.g. if checking two variables and one is a probability and the other is not, then one would write: probability=yes no  */
	graph=yes,				/*indicates if graph is requested or suppressed (yes/no)*/
	ymin=-0.05,				/*minimum net benefit that will be plotted*/
	interventionmin=0,		/*minimum reduction in interventions that will be plotted*/
	smooth=no,				/*use loess smoothing on decision curve graph (yes/no)*/
	prevalence=,            /*specify the prevalence of the outcome when working with case-control data*/
	/*GPLOT OPTIONS*/
	vaxis=,
	haxis=,
	legend=,
	plot_options=,
	plot_statements=
	);	

DATA _NULL_;
	*removing multiple spaces in a row;
	CALL SYMPUTX("predictors",COMPBL("&predictors."));
	CALL SYMPUTX("harm",COMPBL("&harm."));
	CALL SYMPUTX("probability",UPCASE(COMPBL("&probability.")));

	*saving out number of predictors, harms, and probs specified;
	CALL SYMPUTX("varn",COUNTW("&predictors."," "));
	CALL SYMPUTX("harmn",COUNTW("&harm."," "));
	CALL SYMPUTX("probn",COUNTW("&probability."," "));
RUN;

/*Assigns a macro with a variable name for each predictor.*/
DATA _NULL_;
	%DO predvars=1 %TO &varn.;
		CALL SYMPUTX("var"||strip(put(&predvars.,9.0)),SCAN(COMPBL("&predictors."),&predvars.," "));
	%END;
RUN;

/* These error messages deal with necessary information being missing from the macro call.
This stops the macro if: data= is missing, outcome= is missing, predictors= is missing,
graph= is not "yes" or "no", intervention= is not "yes" or "no", model variable names are "all" or "none",
or if harm or probability is specified but there is not a harm or probability assigned for each predictor
referenced.*/

/*Checking that all required variables are defined*/
%IF %LENGTH(&data.)=0 or %LENGTH(&outcome.)=0 or %LENGTH(&predictors.)=0 %THEN %DO;
	%PUT ERR%STR()OR:  data, outcome, and predictors must be specified in the macro call.;
	%GOTO QUIT;
%END;

/*Checking that graph and intervention options are correctly specified*/
%IF %UPCASE(&graph)^=NO & %UPCASE(&graph)^=YES %THEN %DO;
	%PUT ERR%STR()OR:  graph option must be YES or NO;
	%GOTO QUIT;
%END;

%IF %UPCASE(&intervention)^=NO & %UPCASE(&intervention)^=YES %THEN %DO;
	%PUT ERR%STR()OR:  intervention option must be YES or NO;
	%GOTO QUIT;
%END;

/*Check that the smooth option is correctly specified*/
%IF %UPCASE(&smooth)^=NO & %UPCASE(&smooth)^=YES & %LENGTH(&smooth)^=0 %THEN %DO;
	%PUT ERR%STR()OR:  smooth option must be YES or NO;
	%GOTO QUIT;
%END;

*If harm or probabilities specified, then the dimension must match predictors;
%IF (&harmn.^=&varn. AND &harmn.^=0) OR (&probn.^=&varn. AND &probn.^=0) %THEN %DO;
	%PUT ERR%STR()OR:  The specified number of harms and indicators of probability must be equal to the number of predictors specified.;
	%GOTO QUIT;
%END;

*Model variable names being checked cannot be equal to "all" or "none";
%DO name=1 %TO &varn.;
 	%IF %SYSFUNC(UPCASE(&&var&name.))=NONE OR %SYSFUNC(UPCASE(&&var&name.))=ALL %THEN %DO;
		%PUT ERR%STR()OR:  Variable names cannot be equal to "all" or "none";
		%GOTO QUIT;
	%END;
%END;

/*This code will generate an error message for incorrect values input for the "xstart", "xstop",
and "xby" options in the macro call. None of these values should be below 0 or above 1.*/
%IF %SYSEVALF(&xstart. < 0) OR %SYSEVALF(&xstart. > 1) OR %SYSEVALF(&xstop. < 0) OR %SYSEVALF(&xstop. > 1)
	OR %SYSEVALF(&xby. < 0) OR %SYSEVALF(&xby. > 1) %THEN %DO;
	%PUT ERR%STR()OR:  Values specified in xstart, xstop and xby options must be greater than 0 and less than 1.;
	%GOTO QUIT;
%END;

/*These error messages deal with situations where all necessary information is specified in the
macro call but dataset, outcome and/or predictor variables do not exist as specified. This stops
the macro if: dataset does not exist, outcome variable does not exist in dataset, or any predictor
does not exist in dataset.*/

/*First, this checks that the dataset specified exists.*/
%IF %SYSFUNC(EXIST(&data)) %THEN %DO;

	/*If the dataset does exist, this checks that the outcome variable exists in this data.*/
	%LET dsid=%SYSFUNC(OPEN(&data,i));
	%LET outcomecheck=%SYSFUNC(VARNUM(&dsid,&outcome));
	%LET close=%SYSFUNC(CLOSE(&dsid));

	/*If dataset exists but outcome variable is not in the data, print error and exit macro.*/
	%IF &outcomecheck.=0 %THEN %DO;
		%PUT ERR%STR()OR:  The outcome variable &outcome is missing from dataset &data.;
		%GOTO QUIT;
	%END;

	/*If dataset and outcome variable exists, this checks that all predictor variables exist in this data.*/
	%ELSE %DO check = 1 %TO &varn.;
		%LET dsid=%SYSFUNC(OPEN(&data,i));
		%LET predcheck=%SYSFUNC(VARNUM(&dsid,&&var&check.));
		%LET rc=%SYSFUNC(CLOSE(&dsid));

		/*If dataset and outcome variable exist but any predictor variable is not in the data,
		print error and exit macro.*/
		%IF &predcheck.=0 %THEN %DO;
			%PUT ERR%STR()OR:  The predictor variable &&var&check. is missing from dataset &data.;
			%GOTO QUIT;
		%END;
	%END;
%END;

/*If the dataset does not exist, print error and exit macro.*/
%ELSE %DO;
	%PUT ERR%STR()OR: dataset &data does not exist.;
	%GOTO QUIT;
%END;

/*First, this checks that the dataset specified exists.*/
%IF %LENGTH(&out)>0 & %SYSFUNC(MVALID(work,&out,data))^=1 %THEN %DO;
	%PUT ERR%STR()OR:  The name specified for the outcome dataset (&out) is not a valid SAS dataset name.;
	%GOTO QUIT;
%END;

/*After checking that all required variables have been specified in the macro call and that the
dataset and outcome and predictor variables referenced all exist, continue with the rest of the
decision curve analysis.*/

*assigning each predictor, harm, and probability an ID and default value if not specified;
DATA _NULL_;
	%DO abc=1 %TO &varn.;
		CALL SYMPUTX("harm"||strip(put(&abc.,9.0)),COALESCE(SCAN(COMPBL("&harm."),&abc.," "),0));
		CALL SYMPUTX("prob"||strip(put(&abc.,9.0)),UPCASE(COALESCEC(SCAN(COMPBL("&probability."),&abc.," "),"YES")));
	%END;
RUN;

*deleting missing observations;
DATA dcamacro_data;
	SET &data;
	IF NOT MISSING(&outcome.);
	%DO abc=1 %TO &varn.;
		IF NOT MISSING(&&var&abc.);
	%END;
	KEEP &outcome. &predictors.;
RUN;

*creating dataset and macro variables with variable labels;
	PROC CONTENTS DATA=dcamacro_data OUT=dcamacro_contents NOPRINT;
	RUN;
	DATA _NULL_ dcamacro_test;
		SET dcamacro_contents;
		%DO abc=1 %TO &varn.;
			if STRIP(UPCASE(name))=STRIP(UPCASE("&&var&abc..")) then id=&abc.;
		%END;
		IF NOT MISSING(id);
		CALL SYMPUTX("varlab"||strip(put(id,9.0)),COALESCEC(label,name));
	RUN;

PROC SQL NOPRINT;

	*Getting number of observations;
	SELECT COUNT(*) INTO :n FROM dcamacro_data;

	*Getting min and max of outcome;
	SELECT MAX(&outcome.) INTO :outcomemax FROM dcamacro_data;
	SELECT MIN(&outcome.) INTO :outcomemin FROM dcamacro_data;
QUIT;

*Asserting outcome is coded as 0 or 1;
%IF &outcomemax.>1 OR  &outcomemin.<0 %THEN %DO;
	%PUT ERR%STR()OR:  &outcome. cannot be less than 0 or greater than 1.;
	%GOTO QUIT;
%END;

*asserting all inputs are between 0 and 1 OR specified as non-probabilities.  
If not a probability, then converting it to a probability with logistic regression;
%DO abc=1 %TO &varn.;

	*checking range for probabilities;
	%IF &&prob&abc..=YES %THEN %DO;
	 	PROC SQL NOPRINT;
			SELECT MAX(&&var&abc..) INTO :varmax&abc. FROM dcamacro_data;
			SELECT MIN(&&var&abc..) INTO :varmin&abc. FROM dcamacro_data;
		QUIT;

		*any probabilities not between 0 and 1, then printing error;
	 	%IF %SYSEVALF(&&varmax&abc..>1) OR %SYSEVALF(&&varmin&abc..<0) %THEN %DO;
			%PUT ERR%STR()OR:  &&var&abc.. must be between 0 and 1 OR specified as a non-probability in the probability option;
			%GOTO QUIT;
		%END;
	%END;

	*if not probability, converting to prob with logistic regression, and replacing original value with probability;
	%IF &&prob&abc..=NO %THEN %DO;
		*estimating predicted probabilities;
		PROC LOGISTIC DATA=dcamacro_data DESCENDING NOPRINT;
			MODEL &outcome.=&&var&abc..;
			OUTPUT OUT=dcamacro_&&var&abc.._pred (keep=&&var&abc.._pred) PREDICTED=&&var&abc.._pred;
		RUN;

		*replacing original variable with probability.;
		DATA dcamacro_data;
			MERGE 	dcamacro_data
					dcamacro_&&var&abc.._pred;
			DROP &&var&abc..;
			RENAME &&var&abc.._pred=&&var&abc..;

		RUN;
		%PUT WARN%STR()ING:  &&var&abc.. converted to a probability with logistic regression.  Due to linearity assumption, miscalibration may occur.;
	%END;
%END;

*This creates a new "xstop" so that when using "xstop" and "xby" options, the net benefit values for "treat all" and
	"treat none" on the graph extend to the value of "xstop" even if the last value of "xstart + xby" is greater than
	"xstop".;

DATA _NULL_;
	CALL SYMPUTX("xstop2",&xstop.);
	IF MOD((&xstop.-&xstart.),&xby.)~=0 THEN DO;
		CALL SYMPUTX("xstop2",&xstop.+&xstart.);
	END;	
RUN;

*creating dataset that is one line per threshold for the treat all and treat none strategies;
DATA dcamacro_nblong (DROP=t);
	LENGTH model $100.;

	DO t=&xstart. TO &xstop2. BY &xby.;
		threshold=ROUND(t,0.00001);

		*creating the TREAT ALL row;
		model="all";
		nb=&prevalence. - (1 - &prevalence.) * (threshold/(1-threshold));
		output;

		*creating the TREAT NONE row;
		model="none";
		nb=0;
		output;
	END;

RUN;

*ensure dcamacro_models: datasets are empty;
PROC DATASETS LIB=WORK NOPRINT;
	DELETE dcamacro_models:;
RUN;
QUIT;

/*calculate prev if not supplied by user*/
%IF %LENGTH(&prevalence.) = 0 %THEN %DO;
	*calculating number of true and false positives;
	 PROC SQL NOPRINT;
		*counting number of patients above threshold;
		SELECT MEAN(&outcome.) INTO :prevalence FROM dcamacro_data
	QUIT;
%END;
%IF %SYSEVALF(&prevalence. < 0) OR %SYSEVALF(&prevalence. > 1) %THEN %DO;
	%PUT ERR%STR()OR:  Value specified in prevalence must be between 0 and less than 1.;
	%GOTO QUIT;
%END;

*Looping over predictors and calculating net benefit for each of them.;
%DO abc=1 %TO &varn.;

	*Create dcamacro_models&abc. dataset to start. These datasets were deleted above so that
	old datasets are not combined but an error is given if the dataset does not exist when
	trying to append data.;
	PROC SQL NOPRINT;
		CREATE TABLE WORK.dcamacro_models&abc.
		 (model CHARACTER(80), threshold NUMERIC, nb NUMERIC);
	QUIT;

	%DO thresholdid=1 %TO %EVAL(%SYSFUNC(CEIL(%SYSEVALF((&xstop.-&xstart.)/&xby.)))+1);
		%LET threshold=%SYSEVALF((&xstart.-&xby.)+(&xby.*&thresholdid.));

		*calculating number of true and false positives;
	 	PROC SQL NOPRINT;
			*test_pos rate among cases;
			SELECT MEAN(&&var&abc..>=&threshold.) INTO :test_pos_case FROM dcamacro_data WHERE &outcome.;
			*test_pos rate among non-cases;
			SELECT MEAN(&&var&abc..>=&threshold.) INTO :test_pos_noncase FROM dcamacro_data WHERE ^&outcome.;
		QUIT;
		%LET tp_rate = %SYSEVALF(&test_pos_case.    * &prevalence.);
		%LET fp_rate = %SYSEVALF(&test_pos_noncase. * (1 - &prevalence.));
		
		*creating one line dataset with nb.;
		DATA dcamacro_temp;
			length model $100.;
			model = "&&var&abc..";
			threshold = ROUND(&threshold.,0.00001);
			nb = &tp_rate. - &fp_rate. * &threshold. / (1 - &threshold.);
		RUN;

		*creating dataset with nb for models only.;
		DATA dcamacro_models&abc.;
			SET dcamacro_models&abc. dcamacro_temp;
		RUN;

		*deleting results dataset;
		PROC DATASETS LIB=WORK NOPRINT;
			DELETE dcamacro_temp;
		RUN;
		QUIT;

	%END;

	/*After running for all thresholds for each predictor and saving each predictor dataset separately, then smooths*/

	%IF %UPCASE(&smooth.)=YES %THEN %DO;

		PROC LOESS DATA=dcamacro_models&abc.;
			MODEL nb=threshold / ALL;
			ODS OUTPUT OutputStatistics=smooth_&abc.;
		RUN;

		PROC DATASETS LIB=WORK NOPRINT;
			DELETE dcamacro_models&abc.;
		RUN;

		DATA dcamacro_models&abc.(keep=threshold nb model);
			SET smooth_&abc.(rename=(Pred=nb));
			model="&&var&abc..";
			FORMAT nb 5.2;
		RUN;

		PROC SORT DATA=dcamacro_models&abc. NODUPKEY;
			BY threshold;
		RUN;

	%END;

%END;

/*Merge data from predictors together.*/
DATA dcamacro_nblong_final;
	SET dcamacro_nblong dcamacro_models:;
RUN;

*making NB dataset one line per threshold probability;
PROC SORT DATA=dcamacro_nblong_final;
	BY threshold;
RUN;

PROC TRANSPOSE DATA=dcamacro_nblong_final OUT=dcamacro_nbT (DROP=_name_);
	BY threshold;
	ID model;
	VAR nb;
RUN;

/*Adjusting for harms/interventions avoided.*/

DATA dcamacro_nb &out.;
	SET dcamacro_nbT;

	*applying variable labels;
	label threshold="Threshold Probability";
	label all="Net Benefit: Treat All";
	label none="Net Benefit: Treat None";

	%DO abc=1 %TO &varn.;

		*correcting NB if harms are specified and labelling Net Benefit;
		label &&var&abc..="Net Benefit: &&varlab&abc..";
		%IF %LENGTH(&harm.)>0 %THEN %DO;
			&&var&abc..=&&var&abc.. - &&harm&abc..;
			label &&var&abc..="Net Benefit: &&varlab&abc.. (&&harm&abc.. harm applied)";
		%END;
		
		*transforming to interventions avoided;
		&&var&abc.._i=(&&var&abc.-all)*&interventionper./(threshold/(1-threshold));
		label &&var&abc.._i="Intervention: &&varlab&abc..";
		%IF %LENGTH(&harm.)>0 %THEN %DO;
			label &&var&abc.._i="Intervention: &&varlab&abc.. (&&harm&abc.. harm applied)";
		%END;

		*label smoothed net benefit;
		%IF %UPCASE(&smooth)=YES & %LENGTH(&harm.)>0 %THEN %DO;
			label &&var&abc..="Smoothed Net Benefit: &&varlab&abc.. (&&harm&abc.. harm applied)";
		%END;
		%ELSE %IF %UPCASE(&smooth)=YES & %LENGTH(&harm.)=0 %THEN %DO;
			label &&var&abc..="Smoothed Net Benefit: &&varlab&abc..";
		%END;

	%END;

RUN;


*quitting macro if no graph was requested;
%IF %UPCASE(&graph.)=NO %THEN %GOTO QUIT;

***************************************;
********  PLOTTING DCA    *************;
***************************************;

*CREATING VARIABLE LIST FOR GPLOT;
%IF %UPCASE(&intervention.)=NO %THEN %DO;
	%LET plotlist=all none &predictors.;
	%LET ylabel=Net Benefit;
	%LET plotrange=&ymin. <= col1;
%END;
%ELSE %DO;
	%LET ylabel=Net reduction in interventions per &interventionper. patients;
	%LET plotrange=col1 >= &interventionmin.;
	%DO g=1 %TO &varn.;
		%IF &g.=1 %THEN %LET plotlist=&&var&g.._i;
		%ELSE %LET plotlist=&plotlist. &&var&g.._i;
	%END;
%END;

*transposing data to one line per threshold for model type;
PROC TRANSPOSE DATA=dcamacro_nb OUT=dcamacro_plot;
	BY threshold;
	VAR &plotlist.;
RUN;

**** ORDERING CATEGORIES IN GPLOT ****;

*labeling transpose variables;
DATA dcamacro_plot2;
	SET dcamacro_plot;
	label	col1="&ylabel."
			_label_="Model Label"
			_name_="Model";

	*setting variables outside plotrange to missing;
	IF NOT (&plotrange.) THEN col1=.;

	*This creates a numeric variable that corresponds to the order that the variables were
	entered into the DCA macro command.;
	%DO order=1 %TO &varn.+2;
		piece&order.=SCAN("all none &predictors.",&order.,' ');
		IF _name_=piece&order. THEN ordernum=&order.;
	%END;

RUN;

*create dataset to hold format for "ordernum" variable for graph;
DATA cntlin(
	KEEP=fmtname start label);
	SET dcamacro_plot2(RENAME=(_LABEL_=label ordernum=start));
	fmtname="order";
RUN;

*sort format dataset and keep unique observations only;
PROC SORT DATA=cntlin OUT=cntlin NODUPKEYS;
	BY start;
RUN;

*load format for order number variable;
PROC FORMAT CNTLIN=cntlin;
RUN;

*drop unnecessary "piece*" variables and format "ordernum" variable for graph legend;
DATA dcamacro_plot2(DROP=piece:); SET dcamacro_plot2;
	FORMAT ordernum $order.;
RUN;

PROC SORT DATA=dcamacro_plot2;
	BY threshold ordernum;
RUN;

/*Plotting DCA*/

PROC GPLOT DATA=dcamacro_plot2;
	AXIS1 &vaxis. LABEL=(ANGLE=90) MINOR=NONE;
	AXIS2 &haxis. MINOR=NONE;
	LEGEND1 &legend. LABEL=NONE FRAME;

	PLOT col1*threshold=ordernum / SKIPMISS LEGEND=LEGEND1 VAXIS=AXIS1 HAXIS=AXIS2 &plot_options.;
	SYMBOL INTERPOL=JOIN;

	&plot_statements.;
RUN;
QUIT;

%PUT _USER_;

*location label for quitting macro early;
%QUIT:

/*deleting all macro datasets*/
PROC DATASETS LIB=WORK NOPRINT;
	DELETE dcamacro_:;
RUN;
QUIT;

%MEND;

