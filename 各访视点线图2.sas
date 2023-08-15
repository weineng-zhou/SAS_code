
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
%let pgmname = f-14-2-1-2.sas;
%let outname = F14020102;


%let lib=ads;
%let AnaSet=PPROTFL;
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
	20="12-16周"
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


ods html close;
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


/*data linear12_16;*/
/*	set LSMEstimates;*/
/*	if label^="diff (LOW-STD)";*/
/*	&trtvar.n=STMTNO;*/
/*	&trtvar.=put(&trtvar.n, trtp.);*/
/*run;*/


proc sort data=&adam.;
	by &trtvar.n &trtvar. paramn param avisitn avisit;
run;
proc means data=&adam.;
	by &trtvar.n &trtvar. paramn param avisitn avisit;
	var linear;
	output out=linear(drop=_type_ _freq_) n=n
	mean=linear_mean stddev=linear_stddev stderr=linear_stderr min=linear_min max=linear_max;
run;


*week 12-16;
proc sort data=&adam.;
	by usubjid &trtvar.n &trtvar. paramn param ;
run;
proc means data=&adam.;
	where avisitn in (12 16);
	by usubjid &trtvar.N &trtvar. paramn param;
	var chg;
	output out=average_week12_16 mean=linear;
run;

data average_week12_16;
	length avisit $200;
	set average_week12_16;
	avisitn=20;
	avisit="12-16周";
	proc sort ;
	by &trtvar.n &trtvar. paramn param avisitn avisit;
run;


proc means data=average_week12_16;
	by &trtvar.n &trtvar. paramn param avisitn avisit;
	var linear;
	output out=linear_12_16(drop=_type_ _freq_) 
	n=n mean=linear_mean stddev=linear_stddev stderr=linear_stderr min=linear_min max=linear_max;
run;


*横坐标刻度;
proc sql noprint;
	select min(avisitn) into :visitmin separated by '' from adlb;
	select max(avisitn) into :visitmax separated by '' from adlb;
quit;
%put &visitmin;
%put &visitmax;

proc sql noprint;
	select min(LINEAR_MIN) into :LINEAR_MIN separated by ''
	from linear;
	select max(LINEAR_MAX) into :LINEAR_MAX separated by ''
	from linear;
quit;
%put &LINEAR_MIN.;


data final;	
	length avisit $200;
	set linear linear_12_16;
	if cmiss(linear_mean,linear_stderr)=0 then do;
		linear_lower=linear_mean-linear_stderr;
		linear_upper=linear_mean+linear_stderr;		
	end;
	linear_mean=round(linear_mean,0.01);
	linear_lower=round(linear_lower,0.01);
	linear_upper=round(linear_upper,0.01);
	if avisitn^=20 then do;
		_linear_mean=linear_mean;
		_linear_lower=linear_lower;
		_linear_upper=linear_upper;
	end;
	keep &trtvar.n &trtvar. avisitn avisit n linear_mean linear_lower linear_upper _:;
	proc sort;
	by &trtvar.n &trtvar. avisitn;
run;


data figdat.&outname.;
	length &trtvar. avisit $200;
	set final;
	informat _all_;
	format _all_;
	attrib _all_ label='';
	proc sort;
	by &trtvar.n avisitn;
run;


ods html close;
ods html;
%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=11.0cm;
ods listing gpath="&outdir.\figures" image_dpi=300; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


%let color1=cx00b8e5;
%let color2=cxF92672;

%let color1=cx0000ff;
%let color2=cxff0000;


proc template;
	define statgraph LINEPlot;
		begingraph / border=false backgroundcolor = white datacontrastcolors=( &color1. &color2. ) datacolors=(&color1. &color2. ) ;	

			discreteattrmap name='grp';
				value '1' / markerattrs=(symbol=trianglefilled color=&color1. size=6) lineattrs=(color=&color1. pattern=solid);
				value '2' / markerattrs=(symbol=circlefilled   color=&color2. size=6) lineattrs=(color=&color2. pattern=solid);
				*value '3' / markerattrs=(symbol=squarefilled color=&color3. size=8) lineattrs=(color=&color3. pattern=solid);
			enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar._map var=&trtvar.n attrmap='grp';

			discreteattrmap name = "smalln" / ignorecase = true;
                value "1"  / textattrs=(color = &color1. size=8);
                value "2"  / textattrs=(color = &color2. size=8);
            enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar._legend var=&trtvar.n attrmap='smalln';			
			
			legendItem type=MARKERLINE  name="item1" / markerattrs=(symbol=trianglefilled color=&color1. size=8) lineattrs=(color=&color1. pattern=solid) label="&trt1. (N=&N1.)" ;
			legendItem type=MARKERLINE  name="item2" / markerattrs=(symbol=circlefilled color=&color2. size=8) lineattrs=(color=&color2. pattern=solid) label="&trt2. (N=&N2.)" ;
			*legendItem type=MARKERLINE  name="item3" / markerattrs=(symbol=squarefilled color=&color3. size=8) lineattrs=(color=&color2. pattern=solid) label="Total" ;
			
			layout lattice / columns=1 rows=2 Rowweights=(0.82 0.18) columngutter=2cm rowgutter=0.5cm border=false;

			cell;
				  cellheader;
           	   	    entry " " / border=false;
          		  endcellheader;

				    layout overlay/cycleattrs=true walldisplay = (fill outline)
						xaxisopts=(
							griddisplay=off 
/*							offsetmin=0*/
							label="访视"
							labelattrs=(family="宋体" size=8pt weight=bold)							
							tickvalueattrs=(size=6pt family="宋体") 
/*							type=discrete*/
							discreteopts=(tickvaluefitpolicy=splitalways tickvaluesplitchar="*")
							linearopts=(
								viewmin=2 viewmax=20 tickvaluelist=( 2 4 6 8 12 16 20 )						
							) 
						)
						yaxisopts=(
							griddisplay=off 
							offsetmax=0.2
/*							label="Mean (+/- SE) Change from Baseline in Hemoglobin (Hb)" */
							label="血红蛋白较基线变化的均值(±标准误)" 
							labelattrs=(family="宋体" size=8pt weight=bold )		
							labelfitpolicy=split	
							tickvalueattrs=(size=8pt family="Arial") 
							linearopts=(viewmin=0 viewmax=30 tickvaluesequence=(start=6 end=30 increment=5 ) ) 
						);

/*						drawtext textattrs=(family="Arial" size=8pt weight=bold) "Mean (+/- SE) Change from Baseline in Hemoglobin (Hb)" */
/*						/ x=-10 y=-25 anchor=left width=200 xspace=wallpercent yspace=datavalue rotate=90;*/

						seriesplot  x=avisitn y=_linear_mean / name="line" group=&trtvar._map ;
						scatterplot x=avisitn y=linear_mean / name="dot" group=&trtvar._map yerrorlower=linear_lower yerrorupper=linear_upper
/*						datalabel=linear_mean datalabelattrs=(color=black)*/
						;

						drawtext textattrs=(size=8pt) "例数" /anchor=bottomleft width=20 widthunit=percent
						xspace=wallpercent yspace=wallpercent x=1 y=15 justify=center;

						innermargin/align=bottom pad=0.8;
							axistable x=avisitn value=n / name='smalln' class=&trtvar. colorgroup=&trtvar._legend valueattrs=(size=8pt );
						endinnermargin;

						layout gridded /valign=0.95 halign=right border=false; 
							entry halign=right "12-16周最小二乘均值差值: &diff_lsm_ci."   /  textattrs=(family="宋体" size=8pt);
							entry halign=right "P值:               &diffp." / textattrs=(family="宋体" size=8pt);
				        endlayout;

/*						discreteLegend "item1" "item2" / valueattrs=(family="Arial" size=8pt) */
/*						title='Treatment' titleattrs=(family="Arial" size=8pt )*/
/*						location=outside opaque=true halign=center valign=bottom border=true*/
/*						pad=(left=0px right=0px) across=2;*/

				    endlayout;
				endcell;

				cell;
				    cellheader;
	           	   	  entry "" / border=false;
	          	    endcellheader;
				    layout overlay / walldisplay=NONE xaxisopts=(display=none 
				        linearopts=(viewmin=2 viewmax=20 tickvaluelist=( 2 4 6 8 12 16 20 ) )) border=false ;
				        entry halign=left "均数" / location=outside valign=top textattrs=(size=8pt ) ; 
				        axistable x=avisitn value=linear_mean / display=(label) valueattrs=(size=8pt) class=&trtvar. colorgroup=&trtvar._map;
				    endlayout;
				endcell;

				sidebar / align=bottom;
					discretelegend  "item1" "item2" / valueattrs=(family="宋体" size=8pt ) 
					title="治疗组"  titleattrs=(family="宋体" size=8pt ) 
					location=outside opaque=true valign=bottom halign=center border=false across=2; *across用来显示legend,pad=(left=20px right=20px);
			    endsidebar;

			endlayout; *layout lattice / columns=1 rows=2 Rowweights=(0.80 0.2) columngutter=2cm rowgutter=0.5cm border=false;;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final template=LINEPlot;
	format avisitn avisit. ; *&trtvar.n  trtp.;
run;

ods rtf close;
ods listing;
ods results on;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);

