
dm "log;clear;"; 
proc datasets lib=work kill nolist memtype=data; 
quit;
%macro currentroot; 
%global currentroot pgmname; 
%let currentroot = %sysfunc(getoption(sysin)); 
%if "&currentroot" eq "" %then %do; 
%let currentroot = %sysget(sas_execfilepath); 
%let currentpath = %sysfunc(prxchange(s/(.*)\\.*/\1/, -1, &currentroot));
%end; 
%let pgmname=%scan(&currentroot, -1, \); 
%mend; 
%currentroot; 
%let root=%substr(%str(&currentroot),1,%index(%str(&currentroot), %str(\pg\))); 
%include "&root.pg\other\setup.sas";
%let pgmname = f-ae-volcano.sas;


%let lib=ads;
%let AnaSet=SAFFL;
%let adam=adae;


%if &AnaSet.=ITTFL %then %do;
	%let trtvar=trt01p;
%end;
%if &AnaSet.=FASFL %then %do;
	%let trtvar=trt01p;
%end;
%if &AnaSet.=SAFFL %then %do;
	%let trtvar=trt01a;
%end;
%if &AnaSet.=PPROTFL %then %do;
	%let trtvar=trt01p;
%end;


proc sql noprint;
	select max(&TrtVar.N)+1 into :trtmax separated by ''
	from &lib..adsl;
quit;
%put &trtmax.;


* output dataset;
data adsl;
	set &lib..adsl(in=a where=(&AnaSet.="Y")) end=last;
	if last then call symputx('total', _N_);
	output;
	&trtVar="Total";
	&trtVar.N=&trtmax.;
	output;
run;


* calculate BigN;
proc freq data=adsl noprint;
	table &trtVar.N*&trtVar. / out=BigN(rename=(count=bigN) drop=percent);
run;

data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2;


data screen_&adam.;
	set &lib..&adam.(where=(&AnaSet.="Y" and ANL05FL="Y"));
	if not missing(aedecod);
	keep usubjid &trtvar.N &trtvar. aesoc aedecod ;
run;


proc sql noprint;
	create table freq as
	select &trtvar.N, aesoc, aedecod, count(distinct usubjid) as Y
	from screen_&adam. where &trtvar.N in (1 2)
	group by &trtvar.N, aesoc, aedecod
	order by &trtvar.N, aesoc, aedecod
	;
quit;


data freq;
	merge freq(in=a) BigN;
	by &trtvar.N;
	if a;
	if cmiss(BigN,Y)=0 then N=BigN-Y;
run;


proc transpose data=freq out=trans_freq(rename=(_name_=AEYN col1=count));
	by &trtvar.N aesoc aedecod;
	var N Y;
run;


proc sort data=trans_freq;
	by aesoc aedecod;
run;



ods output FishersExact=FishersExact RelativeRisks=RelativeRisks OddsRatioExactCL=OddsRatioExactCL;
proc freq data=trans_freq order=data;
	by aesoc aedecod;
    tables &trtvar.N*AEYN / chisq relrisk;
    exact pchi or;
    weight count;
run;


data RelativeRisks1;
	set RelativeRisks;
	if STATISTIC="��Է��գ��� 1 �У�";
	AEPT=aedecod;
	RR=value;
	keep AESOC AEPT RR;
	proc sort;
	by AESOC AEPT;
run;


data FishersExact1;
	set FishersExact;
	if NAME1="XP2_FISH";
	AEPT=aedecod;
	P_RR=NVALUE1;
	keep AESOC AEPT P_RR;
	proc sort;
	by AESOC AEPT;
run;


data sample;
	merge RelativeRisks1 FishersExact1;
 	by AESOC AEPT;
run;



/*--Define Format with Unicode for the left and right arrows--*/
proc format;;
  value $txt
  "P" = "Favors R-CHOP (*ESC*){Unicode '2192'x}"
  "T" = "(*ESC*){Unicode '2190'x} Favors T-CHOP";
run;


/*--Add axis annotation text to data--*/
data sample2;
	set sample end=last;
	if p_rr < 0.05 and rr > 1 then label=aept;
	output;
	if last then do;
	ylbl=1.0; xlbl=0.8; text="T"; output;
	ylbl=1.0; xlbl=1.5; text="P"; output;
	end;
run;


%let inset1=n/159 (xx.x%); *n???;
%let inset2=n/161 (xx.x%); *n???;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=11cm imagename='Volcano_RR';
ods listing gpath="&root.output\figures" image_dpi=400; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods listing close;


title 'P-risk (Odds Ratio) Plot of Treatment Emergent Adverse Events at PT Level';
proc sgplot data=sample2;
  format aesoc $100. text $txt.;
  label p_rr='Fisher Exact p-value';
  label rr='Odds Ratio';
  scatter x=rr y=p_rr / group=aesoc datalabel=label name='a';
  refline 1 / axis=x lineattrs=(pattern=shortdash);
  refline 0.05 / axis=y lineattrs=(pattern=shortdash);
  inset ("R-CHOP:" = "n/N(%)=&inset1"
         "T-CHOP:" = "n/N(%)=&inset2") / noborder position=topleft;
  text x=xlbl y=ylbl text=text / position=bottom contributeoffsets=(ymax);
  yaxis reverse type=log values=(1.0 0.1 0.05 0.01 0.001) offsetmin=0.1;
  xaxis type=log values=(0.1 1 2 5 10) valueshint;
  keylegend 'a' / across=1 position=right valueattrs=(size=6);
run;

ods _all_ close;
ods listing ;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);


