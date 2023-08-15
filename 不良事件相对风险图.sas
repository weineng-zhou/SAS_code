/*==========================================================================================*
Sponsor Name        : 
Study   ID          : 
Project Name        : 
Program Name        : f-ae-risk.sas
Program Path        : E:\Project
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output 
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-11-04     weineng.zhou              Creation
 
============================================================================================*/


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
%let pgmname = f-ae-risk.sas;


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
	select &trtvar.N, aedecod, count(distinct usubjid) as count
	from screen_&adam. where &trtvar.N in (1 2)
	group by &trtvar.N, aedecod
	order by &trtvar.N, aedecod
	;
quit;


proc sort data=freq;
	by &trtvar.N;
run;
proc sort data=BigN;
	by &trtvar.N;
run;

data freq;
	merge freq(in=a) BigN;
	by &trtvar.N;
	if a;
	proc sort;
	by aedecod;
run;


proc transpose data=freq out=freq1(rename=(_1=NA _2=NB) drop=_name_ );
	by aedecod;
	var count;
	id &trtvar.N;
run; 

proc transpose data=freq out=freq2(rename=(_1=SNA _2=SNB) drop=_name_ );
	by aedecod;
	var BigN;
	id &trtvar.N;
run;

data ae;
	merge freq1 freq2;
	by aedecod;
run;


data ae;
	length pref $200 NA NB SNA SNB 8;
	set ae;
	pref=aedecod;
	array numvar _numeric_;
	do over numvar;
		if numvar=. then numvar=0;
	end;
	if NA>=10;
	keep pref NA NB SNA SNB;
	proc sort;
	by descending NA;
run;


/*--Compute Proportions for treatment A & B, Mean and Risk--*/
data ae_risk;
  set ae;
  keep pref a b mean lcl ucl;
  a=na/sna;
  b=nb/snb;
  factor=1.96*sqrt(a*(1-a)/sna + b*(1-b)/snb);
  lcl=a-b+factor;
  ucl=a-b-factor;
  mean=0.5*(lcl+ucl);
run;

/*--Sort by mean value--*/
proc sort data=ae_risk out=ae_sort;
  by mean;
run;

/*--Add alternate reference lines--*/
data ae_ref;
  set ae_sort;
  if mod(_n_, 2) eq 0 then ref=pref;
run;

 
options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=11.0cm imagename='AEbyRelativeRisk';
ods listing gpath="&root.output\figures" image_dpi=400; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


/*--Create template for AE graph--*/
proc template;
    define statgraph AEbyRelativeRisk;
    dynamic _thk _grid;
    begingraph;

      entrytitle 'Most Frequent On-Therapy Adverse Events Sorted by Risk Difference';

      layout lattice / columns=2 rowdatarange=union columngutter=5;
	  
          /*--Row block to get common external row axes--*/
		  rowaxes;
		      rowaxis / griddisplay=_grid display=(tickvalues) tickvalueattrs=(size=5);
		  endrowaxes;

		  /*--Column headers with filled background--*/
		  column2headers;
		    layout overlay / border=true backgroundcolor=cxdfdfdf opaque=true; 
	            entry "Proportion"; 
	        endlayout;
		    layout overlay / border=true backgroundcolor=cxdfdfdf opaque=true; 
	            entry "Risk Difference with 0.95 CI"; 
	        endlayout;
	      endcolumn2headers;

		  /*--Left side cell with proportional values--*/
	      layout overlay / xaxisopts=(display=(ticks tickvalues)  tickvalueattrs=(size=7));
		      referenceline y=ref / lineattrs=(thickness=_thk) datatransparency=0.9;
	          scatterplot y=pref x=a / markerattrs=graphdata2(symbol=circlefilled) name='a' legendlabel="利妥昔单抗注射液（美罗华）联合CHOP方案（R-CHOP） (N=&N1)";
		      scatterplot y=pref x=b / markerattrs=graphdata1(symbol=trianglefilled) name='b' legendlabel="TQB2303联合CHOP方案（T-CHOP） (N=&N2)";
		  endlayout;

		  /*--Right side cell with Relative Risk values--*/
		  layout overlay / xaxisopts=(label='Less Risk                    More Risk' labelattrs=(size=8)  tickvalueattrs=(size=7));
		      referenceline y=ref / lineattrs=(thickness=_thk) datatransparency=0.9;
	          scatterplot y=pref x=mean / xerrorlower=lcl xerrorupper=ucl markerattrs=(symbol=circlefilled size=5);
		      referenceline x=0 / lineattrs=graphdatadefault(pattern=shortdash);
		  endlayout;

		  /*--Centered side bar for legend--*/
		  sidebar / spacefill=false;
		      discretelegend 'a' 'b' / border=false;
		  endsidebar;

    endlayout;
    endgraph;
    end;
run;


/*--Render the graph with grid lines without horizontal bands--*/
/*proc sgrender data=ae_ref template=AEbyRelativeRisk;*/
/*    dynamic _thk='0' _grid='on';*/
/*run;*/


/*--Render the graph without grid lines and with horizontal bands--*/
proc sgrender data=ae_ref template=AEbyRelativeRisk;
    dynamic _thk='9' _grid='off';
run;

ods rtf close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);


