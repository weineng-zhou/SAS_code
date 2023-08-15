
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
%let pgmname = f-14-2-1-3.sas;
%let outname = F14020103;


%let lib=ads;
%let AnaSet=FASFL;
%let adam=adlb;


%let trt1=低起始剂量组;
%let trt2=标准起始剂量组;


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

proc format;
/*	value trtp*/
/*	1="Lower Dose"*/
/*	2="Standard Dose"*/
/*	3="Total"*/
/*	;*/
	/*	value avisit*/
/*	-2="SCREENING"*/
/*	-1="BASELINE, Day 1"*/
/*	0="BASELINE"*/
/*	2="Week 2"*/
/*	4="Week 4"*/
/*	6="Week 6"*/
/*	8="Week 8"*/
/*	12="Week 12"*/
/*	16="Week 16"*/
/*	20="Week 20,Follow-up"*/
/*	;*/
	value trtp
	1="低起始剂量组"
	2="标准起始剂量组"
	3="合计"
	;
	value avisit
	0="基线"
	2="第2周"
	4="第4周"
	6="第6周"
	8="第8周"
	12="第12周"
	16="第16周"
	;
quit;


proc sql noprint;
	select max(&trtvar.N)+1 into :trtmax separated by ''
	from &lib..adsl;
quit;
%put &trtmax.;

data adsl;
	set &lib..adsl(in=a where=(&AnaSet.="Y")) end=last;
	if last then call symputx('total', _N_);
	output;
	&trtvar.="Total";
	&trtvar.N=&trtmax.;
	output;
run;

* calculate BigN;
proc freq data=adsl noprint;
	table &trtvar.N*&trtvar. / out=BigN(rename=(count=bigN) drop=percent);
run;
data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), BigN);
run;
%put &N1 &N2 &N3 ;


data &adam.;
	set ads.&adam.(where=(&AnaSet.="Y" & ANL01FL="Y" & paramcd in("HGB") ));
	&trtvar.=put(&trtvar.n, trtp.);
	if AVISITN in(2 4 6 8 12 16 );
	linear=chg;
	output;
	*&trtvar.n=3;
	*&trtvar.="Total";
	*output;
	keep usubjid &trtvar.n &trtvar. paramn param avisitn avisit base aval chg linear;
	proc sort;
	by usubjid &trtvar.n &trtvar. paramn param avisitn avisit;
run;


*协变量;
data temp;
	set &adam.;
run;
proc sql noprint;
	create table &adam. as 
	select a.*, b.HGBBL, input(b.GFR,best.) as eGFR
	from temp a left join ads.adsl b on a.usubjid=b.usubjid
	order by paramn,param
;
quit;



*非劣效;
ods output lsmeans=lsmeans diffs=diffs LSMEstimates=LSMEstimates;
proc mixed data=&adam. /*method=reml covtest empirical*/;
	where avisitn in(2 4 6 8 12 16);
	by paramn param;
	class usubjid trt01pn avisitn;
	model chg = trt01pn avisitn trt01pn*avisitn base egfr / ddfm=kr;
	repeated avisitn/subject=usubjid type=UN group=trt01pn;
	lsmeans trt01pn/pdiff cl;
	lsmeans trt01pn*avisitn/pdiff cl alpha=0.05;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 LOW" 0 0 0 0 1 1  0 0 0 0 0 0   /cl divisor=2 ; *avisitn=2 4 6 8 12 16;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 STD" 0 0 0 0 0 0  0 0 0 0 1 1   /cl divisor=2 ;
	lsmestimate trt01pn*avisitn "diff (LOW-STD)"    0 0 0 0 1 1  0 0 0 0 -1 -1 /cl divisor=2 testvalue=-5 alpha=0.05 ; 
run;


*组间最小二乘均值差(95%CI)/P值, 做成宏变量,展示在图的右上角;
data _null_;
	set LSMEstimates;
	if label="diff (LOW-STD)";
	call symputx('diff_lsm_ci', strip(put(ESTIMATE,8.2))||" ("||strip(put(LOWER,8.2))||", "||strip(put(UPPER,8.2))||")" );
	call symputx('diffp', strip(put(PROBT,pvalue6.4)) );
run;
%put &diff_lsm_ci; 
%put &diffp;



data Lsmestimates1;
	set Lsmestimates;
	trt01pn=STMTNO;
	C=strip(put(ESTIMATE,8.2))||" ("||strip(put(LOWER,8.2))||", "||strip(put(UPPER,8.2))||")";
	diffp=strip(put(PROBT,pvalue6.4));
	proc sort;
	by paramn param trt01pn;
run;
proc transpose data=Lsmestimates1 out=trans_Lsm prefix=c;
	by paramn param;
	var c;
	id trt01pn;
run;
proc transpose data=Lsmestimates1 out=trans_diffp prefix=p;
	by paramn param;
	var diffp;
	id trt01pn;
run;

data trans_diff_num;
	set Lsmestimates;
	if STMTNO=3;
	keep paramn param ESTIMATE LOWER UPPER;
	proc sort;
	by paramn param;
run;


data final;
	length COL1-COL4 COL6 $200;
	merge trans_:;
	by paramn;
	COL1=param;
	COL2=C1;
	COL3=C2;
	COL4=C3;
	COL6=P3;
	indent=0;
	row=_N_;
	keep indent COL1-COL4 ESTIMATE LOWER UPPER COL6 row;
run;


data figdat.&outname.;
	set final;
	informat _all_;
	format _all_;
	attrib _all_ label='';
	proc sort;
	by COL1;
run;


/*%if %sysfunc(exist(vfigdat.&outname.)) %then %do;*/
/*	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));*/
/*%end;*/


/*--Used for Subgroup labels in column 1--*/
data anno(drop=indent);
	set final(keep=row COL1 indent rename=(row=y1));
	retain Function 'Text ' ID 'id1' X1Space 'DataPercent' Y1Space 'DataValue' x1 x2 2 TextSize 8 Width 100 Anchor 'Left';
	label = tranwrd(COL1, '>=', '(*ESC*){Unicode ''2265''x}');*;
run;


/*--Used for text under x axis of HR scatter plot in column 7--*/
data anno2;
retain Function 'Arrow' ID 'id2' X1Space X2Space 'DataValue' 
FIllTransparency 0 Y1Space Y2Space 'GraphPercent' Scale 1e-40
LineThickness 1 y1 y2 13 Width 100
FillStyleElement 'GraphWalls' LineColor 'Black';

*arrow;
*x1=起点 x2=终点;
x1 = -0.1; x2 = -5; output;
x1 = 0.1;  x2 = 5; output;

function = 'Text'; y1 = 5; y2 = 5;
x1 = 0;
anchor = 'Right'; label = "&trt2.更好"; Textsize=8;output;
x1 = 0;
Anchor = 'Left '; label = "&trt1.更好"; Textsize=8; output;
run;

data anno;
	length anchor Y1Space function $200;
	set anno anno2;
run;

data anno;
	set anno;
	if label=col1 then call missing(label);
run;

data forest2(drop=flag);
	set final nobs=nobs;
	Head = not indent;
	retain flag 0;
	if head then flag = mod(flag + 1, 2);
	if indent then COL1 = ' ';
	ref=-5;
run;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=5.0cm;
ods listing gpath="&outdir.\figures" image_dpi=400; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


/*--Define template for Forest Plot--*/
/*--Template uses a Layout Lattice of 8 columns--*/
proc template;
	define statgraph Forest;
	dynamic /*_show_bands*/ _color _thk;
	begingraph;

	discreteattrmap name='text';
		value '1' / textattrs=(weight=bold); 
		value other;
		enddiscreteattrmap;
	discreteattrvar attrvar=type var=head attrmap='text';
	

	layout lattice /columns=6 columnweights=(0.1 0.13 0.12 0.12 0.32 0.04);*0.21 0.13 0.13 0.12 0.32 0.09;

		/*--Column headers--*/
		sidebar / align=top;
			layout lattice /
				rows=2 columns=5 columnweights=(0.1 0.14 0.14 0.4 0.11);*0.20 0.15 0.15 0.36 0.14;

				entry " ";
				entry textattrs=(size=8) halign=left " &trt1";
				entry textattrs=(size=8) halign=left " &trt2";
				entry " ";
				entry " ";

				entry textattrs=(size=8) halign=left "12-16周";
				entry textattrs=(size=8) halign=left " 最小二乘均值(95% CI)";
				entry textattrs=(size=8) halign=left " 最小二乘均值(95% CI)";
				entry textattrs=(size=8) halign=left " 组间差值 (95% CI)";
				entry halign=right textattrs=(size=8) "P 值*" ;
			endlayout;
		endsidebar;

		/*--First Subgroup column, shows only the Y2 axis--*/
		layout overlay / walldisplay=none xaxisopts=(display=none) yaxisopts=(reverse=true display=none tickvalueattrs=(weight=bold));
			annotate / id='id1';
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=COL1 /display=(values) textgroup=type valueattrs=(size=8pt);
		endlayout;

		/*--Second column showing COL2 --*/
		layout overlay / xaxisopts=(display=none) yaxisopts=(reverse=true display=none tickvalueattrs=(weight=bold)) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=COL2 /display=(values) valuejustify = center valueattrs=(size=8pt);
		endlayout;

		/*--Third column showing COL3 --*/
		layout overlay / xaxisopts=(display=none)
			yaxisopts=(reverse=true display=none tickvalueattrs=(weight=bold)) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=COL3 /display=(values) valuejustify = center valueattrs=(size=8pt);
		endlayout;

		/*--Fourth column showing COL4--*/
		layout overlay / x2axisopts=(display=none)
			yaxisopts=(reverse=true display=none tickvalueattrs=(weight=bold)) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=COL4 / display=(values) valueattrs=(size=8pt);
		endlayout;

		/*--Fixth column showing ratio/diff graph with 95% error bars--*/
		layout overlay / xaxisopts=(type=linear
			label=' ' 
			labelattrs=(size=8) 
			/*logopts=(tickvaluepriority=true tickvaluelist=(-10 -5 0 5))*/ 
			linearopts=(viewmin=-8 viewmax=8 tickvaluesequence=(start=-8 end=8 increment=1 ) ))
			yaxisopts=(reverse=true display=none tickvalueattrs=(weight=bold)) walldisplay=none;
			annotate / id='id2';
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			scatterplot y=row x=ESTIMATE / xerrorlower=LOWER xerrorupper=UPPER
			/*sizeresponse=SquareSize*/ sizemin=4 sizemax=12 markerattrs=(symbol=trianglefilled color=cx282828 );
			referenceline x=-5 / lineattrs=(color=cxFF7F0E pattern=shortdash thickness=2);
			referenceline x=0  / lineattrs=(color=black pattern=solid thickness=2);
			referenceline x=5  / lineattrs=(color=cxFF7F0E pattern=shortdash thickness=2); 
		endlayout;

		/*--Sixth column showing P-Values--*/
		layout overlay / x2axisopts=(display=none) yaxisopts=(reverse=true display=none tickvalueattrs=(weight=bold)) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=COL6 / display=(values) valuejustify = right valueattrs=(size=8pt) showmissing=false; 
			/*false removes . for missing pvalues*/
		endlayout;

	endlayout; *layout lattice /columns=6 columnweights=(0.21 0.13 0.13 0.12 0.32 0.09);

	entryfootnote halign=left textattrs=(size=8) '* 基于（低起始剂量组-标准起始剂量组）≤-5g/L计算P值';
	endgraph; *begingraph;

	end;
run;

proc sgrender data=Forest2 template=Forest sganno=anno;
	dynamic _color='white' _thk=10 ; 
run;

ods rtf close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
