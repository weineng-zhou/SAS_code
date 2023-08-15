
/*==========================================================================================*
Sponsor Name        : 福建海西新药创制有限公司
Study   ID          : HXP019-CTPI-01
Project Name        : 一项评价口服 C019199 片单次和多次给药在中国局部晚期或转移性实体瘤患者中的安全性、 耐受性、 药代动力学特征和抗肿瘤活性的多中心、 开放、 剂量递增的 I 期临床研究
Program Name        : F-5-1.sas
Program Path        : E:\Project\HXP019-CTPI-01\csr\dev\pg\figures
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output F-05-01.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : ADSL,ADPC
Output File         : E:\Project\HXP019-CTPI-01\csr\dev\output\figures\F-05-01.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-06-13     weineng.zhou              Creation
 
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
%let pgmname = F-5-1.sas;
%let outname = F0501;


%let ytext1=%str('Ln(C'{sub "max"}')');
%let ytext2=%str('Ln(AUC'{sub "0-t"}')');
%let ytext3=%str('Ln(AUC'{sub "0-inf"}')');


proc format;
	invalue paramn
	"CMAX"=1
	"AUCLST"=2
	"AUCIFO"=3
	;
quit;


data adpp;
	set ads.adpp;
	where PKPSFL='Y' and parcat1="C019199" and avisit="单次给药" and paramcd in("CMAX" "AUCLST" "AUCIFO") ;
	paramn=input(paramcd,paramn.);
	lnDose = log(input(scan(trt01a,2,' '),best.));
	ln_Y = log(aval);
	keep subjid trt01an trt01a paramn param lnDose ln_Y;
	proc sort;
	by paramn param;
run;

proc sql noprint;
	select max(paramn) into :maxiter separated by ''
	from adpp;
quit;
%put &maxiter;


ods results off;
ods output summary=minmax;
proc means data=adpp n min max;
	by paramn param;
	var LNDOSE ln_Y;
run;

data _null_;
	set minmax;
	call symputx("LNDOSE_MIN",int(LNDOSE_MIN));
	call symputx("LNDOSE_MAX",ceil(LNDOSE_MAX));
	call symputx("ln_Y_MIN"||strip(put(_N_,best.)),int(ln_Y_MIN));
	call symputx("ln_Y_MAX"||strip(put(_N_,best.)),ceil(ln_Y_MAX));
run;
%put &LNDOSE_MIN.;
%put &ln_Y_MIN1.;


*一元线性回归模型;
ods output ParameterEstimates=ParameterEstimates FitStatistics=FitStatistics;
proc reg data=adpp outest=model_param;
	by paramn;
	model ln_Y=lnDose / alpha=0.1 b;
    output out=model
	predicted=pred;
quit;

data _null_;
	set FitStatistics;
	if LABEL2="R 方";
	call symputx("_RSQ_"||strip(put(paramn,best.)), put(NVALUE2,8.4)); *回归系数;
run;
%put &_RSQ_1.;
%put &_RSQ_2.;
%put &_RSQ_3.;


*混合效应模型;
ods output Estimates=_slope_from_MIXED solutionf=_solutionf_from_MIXED;
proc mixed data=adpp;
	by paramn;
	model ln_Y=lnDose / s;
	estimate 'slope (beta) and 90% Confidence Interval' LnDose 1 / alpha=0.10;
run;

data _null_;
	set _solutionf_from_MIXED;
	if EFFECT="Intercept" then call symputx("Intercept"||strip(put(paramn,best.)),put(ESTIMATE,8.4));
	else call symputx("Slope"||strip(put(paramn,best.)),put(ESTIMATE,8.4));
run;


data _null_;
	set _slope_from_MIXED;
	call symputx("LOWERCL"||strip(put(paramn,best.)), put(LOWER,8.2));
	call symputx("UPPERCL"||strip(put(paramn,best.)), put(UPPER,8.2));
run;


data figdat.&outname.;
	set adpp;
	informat _all_;
	format _all_;
	keep subjid trt01an trt01a paramn param lnDose ln_Y;
	proc sort;
	by trt01an trt01a paramn;
run;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=8in height=4in;
ods listing gpath="&outdir.\figures" image_dpi=300;
ods results off;
ods listing close;  /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/

%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 

%macro figloop;
%let i=0;
%do %while (&i<&maxiter.);
%let i=%eval(&i+1);

proc template;
	define statgraph RegPlot;
		begingraph / border=false backgroundcolor = white /* datacontrastcolors=( white ) datacolors=( ) */;	

			entrytitle "Rsq=&&_RSQ_&i, Intercept=&&Intercept&i, Slope=&&Slope&i";
			entrytitle "90% CI (&&LOWERCL&i, &&UPPERCL&i)";

			discreteattrmap name='trt';
				value 'C019199 50 mg QD'  / markerattrs=(symbol=trianglefilled color=cx0000FF size=8) ;
				value 'C019199 100 mg QD' / markerattrs=(symbol=squarefilled color=cxFF0000 size=8)   ;
				value 'C019199 200 mg QD' / markerattrs=(symbol=circlefilled color=cxB2251E size=8)   ;
				value 'C019199 300 mg QD' / markerattrs=(symbol=starfilled color=cx008200 size=8)     ;
				value 'C019199 450 mg QD' / markerattrs=(symbol=diamondfilled color=cxFF7F0E size=8)  ;
				value 'C019199 600 mg QD' / markerattrs=(symbol=homedownfilled color=cx00C2C0 size=8) ;
			enddiscreteattrmap;
			discreteattrvar attrvar=trt_map var=trt01a attrmap='trt';

			legendItem type=text name="group" / text="Treatment" ;
			legendItem type=MARKER  name="item1" / markerattrs=(symbol=trianglefilled color=cx0000FF size=8) label="50 mg"  ;
			legendItem type=MARKER  name="item2" / markerattrs=(symbol=squarefilled color=cxFF0000 size=8)   label="100 mg" ;
			legendItem type=MARKER  name="item3" / markerattrs=(symbol=circlefilled color=cxB2251E size=8)   label="200 mg" ;
			legendItem type=MARKER  name="item4" / markerattrs=(symbol=starfilled color=cx008200 size=8)     label="300 mg" ;
			legendItem type=MARKER  name="item5" / markerattrs=(symbol=diamondfilled color=cxFF7F0E size=8)  label="450 mg" ;
			legendItem type=MARKER  name="item6" / markerattrs=(symbol=homedownfilled color=cx00C2C0 size=8) label="600 mg" ;

			layout overlay / cycleattrs=true walldisplay = none 

				xaxisopts=(
					griddisplay=off label="Ln(Dose)"
					labelattrs=(family="Times New Roman" size=10pt weight=bold)
					tickvalueattrs=(size=8pt family="Times New Roman") 
					linearopts=(viewmin=3.8 viewmax=6.8 tickvaluesequence=(start=3.8 end=6.8 increment=1) ) 
				)
				yaxisopts=(
					griddisplay=off 
/*					label=""*/
					labelattrs=(family="Times New Roman" color=cxffffff size=12pt weight=bold)
					tickvalueattrs=(size=8pt family="Times New Roman") 
					linearopts=(viewmin=&&LN_Y_MIN&i viewmax=&&LN_Y_MAX&i tickvaluesequence=(start=&&LN_Y_MIN&i end=&&LN_Y_MAX&i increment=1 ) ) 
				);

				seriesplot  x=lnDose y=pred / name="line" lineattrs=(color=cx282828 pattern=solid thickness=2);
				scatterplot x=lnDose y=Ln_Y / name="dot" group=trt_map;			
				
				%if &i=1 %then %do;
					drawtext textattrs=(family="Times New Roman" size=10pt weight=bold)  &&ytext&i / x=-5 y=6 anchor=left width=200 xspace=wallpercent yspace=datavalue rotate=90;
				%end;
				%if &i=2 %then %do;
					drawtext textattrs=(family="Times New Roman" size=10pt weight=bold) &&ytext&i / x=-5 y=9 anchor=left width=200 xspace=wallpercent yspace=datavalue rotate=90;
				%end;
				%if &i=3 %then %do;
					drawtext textattrs=(family="Times New Roman" size=10pt weight=bold) &&ytext&i / x=-5 y=9 anchor=left width=200 xspace=wallpercent yspace=datavalue rotate=90;
				%end;
				
				discretelegend "item1" "item2" "item3" "item4" "item5" "item6"/ valueattrs=(family="Times New Roman" size=8pt) 
				title="Dosage" location=outside opaque=true halign=center valign=center border=true pad=(left=0px right=0px);

			endlayout;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=model(where=(paramn=&i)) template=RegPlot;
run;

%end;

%mend;
%figloop;

ods rtf close;
ods listing;
ods results on;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
