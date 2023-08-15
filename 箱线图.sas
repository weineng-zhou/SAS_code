/*==========================================================================================*
Sponsor Name        : 珐博进（中国） 医药技术开发有限公司（珐博进中国）
Study   ID          : FGCL-4592-858
Project Name        : 一项评估罗沙司他低起始剂量给药方案治疗慢性肾脏病非透析贫血患者的有效性和安全性的随机、 对照、 开放标签、 多中心研究
Program Name        : t-14-2-1-10.sas
Program Path        : E:\Project\FGCL-4592-858\csr\dev\pg\tables
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output T-14-02-01-10.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\FGCL-4592-858\csr\dev\output\tables\T-14-02-01-10.rtf

_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-11-14     weineng.zhou              Creation
 
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
%let pgmname = f-14-2-1-13.sas;
%let outname = f14020113;


%let lib=ads;
%let AnaSet=FASFL;
%let adam=adlb;


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


%let trt1=低起始剂量组;
%let trt2=标准起始剂量组;


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
	1="基线至第4周总和"
	2="基线至第8周总和"
	3="基线至第16周总和"
	;
quit;


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
	if &AnaSet.="Y" then do;
		&trtVar="Total";
		&trtVar.N=&trtmax.;
		output;
	end;
run;


* calculate BigN;
proc freq data=adsl noprint;
	table &trtVar.N*&trtVar. / out=BigN(rename=(count=bigN) drop=percent);
run;
data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2 &N3;


*design the dummy matrix dataset;
data matrix;
	do &trtVar.N=1 to &trtmax.;
		do ord=1 ;
			do seq=0 to 3;
				output;
			end;
		end;
	end;
run;
data matrix;
	merge matrix bigN;
	by &trtVar.N;
	proc sort;
	by ord seq;
run;
proc transpose data=matrix out=dummy(drop=_name_ _label_) prefix=bigN;
	by ord seq;
	id &trtVar.N;
run;


data &adam.;
	set ads.&adam.(where=(&AnaSet.="Y" & ANL01FL="Y" & paramcd in ("HGB") ));
	if avisitn in (0 2 4 6 8 12 16);
	if avisitn=0 then ady=1;
	output;
	*&trtVar.N=&trtmax.; 
	*&trtVar.='合计';
	*output;
	keep usubjid &trtVar.N &trtVar. paramn paramcd param avisitn avisit ady aval base chg;
	proc sort; 
	by usubjid &trtVar.N &trtVar. paramn param;
run;


*协变量;
data temp;
	set &adam.;
run;
proc sql noprint;
	create table &adam. as 
	select a.*, b.HGBBL, input(b.GFR,best.) as eGFR
	from temp a left join ads.adsl b on a.usubjid=b.usubjid
	order by usubjid,paramn
;
quit;


*基线至第4周个体的各个时间点切点的斜率之和;
ods output  ParameterEstimates=ParameterEstimates_1;
proc glmselect data=&adam.;
	where avisitn in (0 2 4);
	by usubjid paramn param;	
	effect y=poly( ady / degree=3); *f(x)=x+x**2+x**3;
	model aval = y / selection=none;
	output out=PolyOut pred=Fit;
quit;

proc transpose data=ParameterEstimates_1 out=Estimate_beta(drop=_name_ _label_) prefix=beta; 
	where EFFECT^="Intercept";
	by usubjid paramn param; 
	var ESTIMATE; 
run;
proc sort data=&adam. out=avisit0_4; 
	where avisitn in (0 2 4);
	by usubjid paramn param;
run;
data avisit0_4;
	merge avisit0_4 Estimate_beta;
	by usubjid paramn param;
run;

proc sql noprint;
	create table sum_slope1 as
	select distinct usubjid, 1 as avisitn, "基线至第4周总和" as avisit, &trtVar.N, &trtVar., paramn, param, HGBBL, eGFR, 
	sum(abs(3*beta3*ady**2 + 2*beta2*ady + beta1)) as sum_slope
	from avisit0_4
	group by usubjid
;
quit;


proc sort data=sum_slope1;by paramn param avisitn avisit; run;
ods output Estimates=Estimates LSMeanDiffCL=LSMeanDiffCL;
proc glm data=sum_slope1;
	by paramn param avisitn avisit; *当是汇总subject level所有访视的数据: avisitn=999;
	class &trtVar.N;
	model sum_slope=&trtVar.N HGBBL EGFR / solution;
	lsmeans &trtVar.N/cl pdiff=control("2") e ;
	estimate "Slope Change Diff (LOW-STD)" &trtVar.N 2 -2 / divisor=2 ; 
run;


*均值间差值;
data LSMeanDiffCL1;
	set LSMeanDiffCL;
	row6=strip(put(DIFFERENCE,8.2))||" ("||strip(put(LOWERCL,8.2))||", "||strip(put(UPPERCL,8.2))||")";
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=LSMeanDiffCL1 out=trans_LSMeanDiffCL1 prefix=c; 
	by paramn param avisitn; 
	var row6; 
run;
data trans_LSMeanDiffCL1; 
	length ord seq 8;
	set trans_LSMeanDiffCL1; 
	ord=1; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;

*pvalue;
data Estimates1;
	set Estimates;
	row7=strip(put(PROBT,pvalue6.4));
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=Estimates1 out=trans_Estimates1 prefix=c; 
	by paramn param avisitn; 
	var row7; 
run;
data trans_Estimates1; 
	length ord seq 8;
	set trans_Estimates1; 
	ord=1; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;


*基线至第8周个体的各个时间点切点的斜率之和;
ods output  ParameterEstimates=ParameterEstimates_2;
proc glmselect data=&adam.;
	where avisitn in (0 2 4 6 8);
	by usubjid paramn param;	
	effect y=poly(ady / degree=3);
	model aval = y / selection=none;
	output out=PolyOut pred=Fit;
quit;

proc transpose data=ParameterEstimates_2 out=Estimate_beta(drop=_name_ _label_) prefix=beta; 
	where EFFECT^="Intercept";
	by usubjid paramn param; 
	var ESTIMATE; 
run;
proc sort data=&adam. out=avisit0_8; 
	where avisitn in (0 2 4 6 8);
	by usubjid paramn param;
run;
data avisit0_8;
	merge avisit0_8 Estimate_beta;
	by usubjid paramn param;
run;

proc sql noprint;
	create table sum_slope2 as
	select distinct usubjid, 2 as avisitn, "基线至第8周总和" as avisit, &trtVar.N, &trtVar., paramn, param, HGBBL, eGFR, 
	sum(abs(3*beta3*ady**2 + 2*beta2*ady + beta1)) as sum_slope
	from avisit0_8
	group by usubjid
;
quit;


proc sort data=sum_slope2;by paramn param avisitn avisit; run;
ods output Estimates=Estimates LSMeanDiffCL=LSMeanDiffCL;
proc glm data=sum_slope2;
	by paramn param avisitn avisit; *当是汇总subject level所有访视的数据: avisitn=999;
	class &trtVar.N;
	model sum_slope=&trtVar.N HGBBL EGFR / solution;
	lsmeans &trtVar.N/cl pdiff=control("2") e ;
	estimate "Slope Change Diff (LOW-STD)" &trtVar.N 2 -2 / divisor=2 ; 
run;


*均值间差值;
data LSMeanDiffCL2;
	set LSMeanDiffCL;
	row6=strip(put(DIFFERENCE,8.2))||" ("||strip(put(LOWERCL,8.2))||", "||strip(put(UPPERCL,8.2))||")";
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=LSMeanDiffCL2 out=trans_LSMeanDiffCL2 prefix=c; 
	by paramn param avisitn; 
	var row6; 
run;
data trans_LSMeanDiffCL2; 
	length ord seq 8;
	set trans_LSMeanDiffCL2; 
	ord=2; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;

*pvalue;
data Estimates2;
	set Estimates;
	row7=strip(put(PROBT,pvalue6.4));
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=Estimates2 out=trans_Estimates2 prefix=c; 
	by paramn param avisitn; 
	var row7; 
run;
data trans_Estimates2; 
	length ord seq 8;
	set trans_Estimates2; 
	ord=2; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;


*基线至第16周个体的各个时间点切点的斜率之和;
ods output  ParameterEstimates= ParameterEstimates_3;
proc glmselect data=&adam.;
	where avisitn in (0 2 4 6 8 12 16);
	by usubjid paramn param;	
	effect y=poly(ady / degree=3);
	model aval = y / selection=none;
	output out=PolyOut pred=Fit;
quit;

proc transpose data=ParameterEstimates_3 out=Estimate_beta(drop=_name_ _label_) prefix=beta; 
	where EFFECT^="Intercept";
	by usubjid paramn param; 
	var ESTIMATE; 
run;
proc sort data=&adam. out=avisit0_16; 
	where avisitn in (0 2 4 6 8 12 16);
	by usubjid paramn param;
run;
data avisit0_16;
	merge avisit0_16 Estimate_beta;
	by usubjid paramn param;
run;

proc sql noprint;
	create table sum_slope3 as
	select distinct usubjid, 3 as avisitn, "基线至第16周总和" as avisit, &trtVar.N, &trtVar., paramn, param, HGBBL, eGFR, 
	sum(abs(3*beta3*ady**2 + 2*beta2*ady + beta1)) as sum_slope
	from avisit0_16
	group by usubjid
;
quit;


proc sort data=sum_slope3;by paramn param avisitn avisit; run;
ods output Estimates=Estimates LSMeanDiffCL=LSMeanDiffCL;
proc glm data=sum_slope3;
	by paramn param avisitn avisit; *当是汇总subject level所有访视的数据: avisitn=999;
	class &trtVar.N;
	model sum_slope=&trtVar.N HGBBL EGFR / solution;
	lsmeans &trtVar.N/cl pdiff=control("2") e ;
	estimate "Slope Change Diff (LOW-STD)" &trtVar.N 2 -2 / divisor=2 ; 
run;


*均值间差值;
data LSMeanDiffCL3;
	set LSMeanDiffCL;
	row6=strip(put(DIFFERENCE,8.2))||" ("||strip(put(LOWERCL,8.2))||", "||strip(put(UPPERCL,8.2))||")";
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=LSMeanDiffCL3 out=trans_LSMeanDiffCL3 prefix=c; 
	by paramn param avisitn; 
	var row6; 
run;
data trans_LSMeanDiffCL3; 
	length ord seq 8;
	set trans_LSMeanDiffCL3; 
	ord=3; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;

*pvalue;
data Estimates3;
	set Estimates;
	row7=strip(put(PROBT,pvalue6.4));
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=Estimates3 out=trans_Estimates3 prefix=c; 
	by paramn param avisitn; 
	var row7; 
run;
data trans_Estimates3; 
	length ord seq 8;
	set trans_Estimates3; 
	ord=3; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;



%macro means(dsin=, dsout=, screen=, dec_var=, var=, ord=); 

data dec; 
	set &dsin.; 
	dec=lengthn(scan(strip(put(&dec_var.,best.)),2,'.')); 
	keep usubjid &trtVar.N &trtVar. paramn param &dec_var. dec; 
	proc sort; 
	by &trtVar.N &trtVar. paramn param; 
run; 

proc sql noprint; 
	create table max_dec as 
	select paramn, param, max(dec) as maxx 
	from dec
	group by paramn, param; 
quit;

proc sql noprint; 
	create table dec123 as 
	select paramn, param, maxx, min(maxx,3) as raw0 , min(maxx+1,3) as raw1, min(maxx+2,3) as raw2
	from max_dec
	order by paramn, param;
quit;


data BDS; 
	set &dsin.; 
	where &screen.; 
	keep usubjid &trtVar.N &trtVar. paramn param avisitn avisit &var.; 
	proc sort; 
	by &trtVar.N &trtVar. paramn param avisitn avisit; 
run; 

proc means data=BDS noprint; 
	by &trtVar.N &trtVar. paramn param avisitn avisit;
	var &var.;
	output out=stat_&var.(drop= _type_ _freq_) n=n nmiss=nmiss mean=mean stddev=std stderr=se q1=q1 q3=q3 median=median min=min max=max; 
run;

proc sort data=stat_&var.;
	by paramn param;
run;
data stat_&var.; 
	merge stat_&var. dec123; 
	by paramn; 
	proc sort;
	by &trtVar.N;
run;

data stat_&var.;
	merge stat_&var.(in=a) bigN;
	by &trtVar.N;
	if a;
run;

data stat_&var.;
	length row1-row5 $100;
	set stat_&var.; 
	row1=strip(put(n,best.))||" ("||strip(put(BigN-n,best.))||")"; 	
	if cmiss(mean,std)=0 then row2=strip(putn(round(mean,10**((-1)*raw1)), cats(8,'.',raw1)))||" ("||strip(putn(round(std,10**((-1)*raw2)),cats(8,'.',raw2)))||")"; 
	else if mean^=. and std=. then row2=strip(putn(round(mean,10**((-1)*raw1)), cats(8,'.',raw1)))||" (-)"; 
	else if cmiss(mean,std)=2 then row2="-"; 
	if se ne . then row3=strip(putn(round(se,10**((-1)*raw2)),cats(8,'.',raw2)));
	else row3="-";
	if median ne . then row4=strip(putn(round(median,10**((-1)*raw1)),cats(8,'.',raw1)));
/*	if cmiss(Q1,Q3)=0 then row4=strip(putn(round(Q1,10**((-1)*raw0)), cats(8,'.',raw0)))||", "||strip(putn(round(q3,10**((-1)*raw0)), cats(8,'.',raw0))); */
/*	else row4="-"; */
	if min^=. then row5=strip(putn(round(min,10**((-1)*raw0)), cats(8,'.',raw0)))||", "||strip(putn(round(max,10**((-1)*raw0)), cats(8,'.',raw0))); 
	else if min=. then row5="-"; 
	proc sort;
	by paramn param avisitn avisit;
run;

proc transpose data=stat_&var. out=means_&var. prefix=c; 
	by paramn param avisitn avisit; 
	var row1-row5; 
	id &trtVar.N; 
run;

data &dsout.; 
	length ord seq 8;
	set means_&var.; 
	ord=&ord.; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run; 

%mend; 
%means(dsin=sum_slope1, dsout=trans_sum_slope1, screen=%str(not missing(usubjid)), dec_var=sum_slope, var=sum_slope, ord=1);
%means(dsin=sum_slope2, dsout=trans_sum_slope2, screen=%str(not missing(usubjid)), dec_var=sum_slope, var=sum_slope, ord=2);
%means(dsin=sum_slope3, dsout=trans_sum_slope3, screen=%str(not missing(usubjid)), dec_var=sum_slope, var=sum_slope, ord=3);


data final;
	length avisit $200;
	set sum_slope1 sum_slope2 sum_slope3;	
	keep &trtvar.N &trtvar. avisitn avisit SUM_SLOPE;
	proc sort;
	by &trtvar.N avisitn;
run;


data figdat.&outname.;
	set final;
	informat _all_;
	format _all_;
	attrib _all_ label='';
	proc sort;
	by &trtvar.N avisitn;
run;


/*%if %sysfunc(exist(vfigdat.&outname.)) %then %do;*/
/*	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));*/
/*%end;*/


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=6in height=4in;
ods listing gpath="&outdir.\figures" image_dpi=300; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


%let color1=cx00b8e5;
%let color2=cxF92672;


proc template;
	define statgraph Boxplot;
		begingraph / border=false backgroundcolor = white datacolors=(&color1. &color2.) datacontrastcolors=( black );	

			discreteattrmap name='grp';
				value '1' / markerattrs=(symbol=squarefilled color=&color1. size=4) lineattrs=(color=&color1. pattern=solid);
				value '2' / markerattrs=(symbol=squarefilled color=&color2. size=4) lineattrs=(color=&color2. pattern=dash);
			enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar._map var=&trtvar.N attrmap='grp';

			discreteattrmap name = "smalln" / ignorecase = true;
                value "1"  / textattrs=(color = &color1. size=8);
                value "2"  / textattrs=(color = &color2. size=8);
            enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar._legend var=&trtvar.N attrmap='smalln';			
			
			legendItem type=MARKER  name="item1" / markerattrs=(symbol=squarefilled color=&color1. size=8) lineattrs=(color=&color1. pattern=solid) label="&trt1. (N=&N1.)" ;
			legendItem type=MARKER  name="item2" / markerattrs=(symbol=squarefilled color=&color2. size=8) lineattrs=(color=&color2. pattern=dash) label="&trt2. (N=&N2.)" ;
			
			legendItem type=MARKER  name="circle" / markerattrs=(symbol=circle color=cx000000 size=8) lineattrs=(color=cx000000 pattern=solid) label="均值或离群值";
			legendItem type=MARKER  name="plus" / markerattrs=(symbol=plus color=cx000000 size=8) lineattrs=(color=cx000000 pattern=solid) label="均值或离群值";
			
			layout lattice / columns=1 rows=2 Rowweights=(1.0 0) columngutter=2.0cm rowgutter=0.5cm border=false;

			cell;
				  cellheader;
           	   	    entry " " / border=false;
          		  endcellheader;

				    layout overlay/cycleattrs=true walldisplay = (fill outline)
						xaxisopts=(
							griddisplay=off 
							label="访视"
							labelattrs=(family="宋体" size=8pt weight=bold)							
							tickvalueattrs=(size=8pt family="宋体") 
							discreteopts=(tickvaluefitpolicy=splitalways tickvaluesplitchar="*")
							linearopts=(
								viewmin=0 viewmax=3 tickvaluelist=( 1 2 3 )						
							)
						)
						yaxisopts=(
							griddisplay=off
							offsetmax=0.2
							label="血红蛋白变化率绝对值"
							labelattrs=(family="宋体" size=8pt weight=bold )		
							labelfitpolicy=split
							tickvalueattrs=(size=8pt family="宋体") 
							linearopts=(viewmin=0 viewmax=15 tickvaluesequence=(start=0 end=15 increment=3 ) ) 
						);

/*						drawtext textattrs=(family="Arial" size=8pt weight=bold) "Mean (+/- SE) Change from Baseline in Hemoglobin (Hb)" */
/*						/ x=-10 y=-25 anchor=left width=200 xspace=wallpercent yspace=datavalue rotate=90;*/
						
						boxplot x = avisitn y = sum_slope / group=&trtvar.N groupdisplay = cluster
						;

						*seriesplot  x=avisitn y=linear_mean / name="line" group=&trtvar._map ;
						*scatterplot x=avisitn y=linear_mean / name="dot" group=&trtvar._map yerrorlower=linear_lower yerrorupper=linear_upper
/*						datalabel=linear_mean datalabelattrs=(color=black)*/
						;

/*						drawtext textattrs=(size=8pt) "Number of Subjects" /anchor=bottomleft width=22 widthunit=percent*/
/*						xspace=wallpercent yspace=wallpercent x=5 y=15 justify=center;*/

/*						innermargin/align=bottom pad=0.8;*/
/*							axistable x=avisitn value=n / name='smalln' class=&trtvar. colorgroup=&trtvar._legend valueattrs=(size=8pt );*/
/*						endinnermargin;*/

/*						layout gridded /valign=0.95 halign=right border=false;  */
/*							entry halign=right "斜率变化值总和组间差值（95% CI）: &diff."   /  textattrs=(family="宋体" size=8pt );*/
/*							entry halign=right "P值:              &pvalue."   / textattrs=(family="宋体" size=8pt);*/
/*				        endlayout;*/

						discreteLegend "circle" "plus" / title='' valueattrs=(family="宋体" size=8pt) 
                        location=inside opaque=true valign=top halign=right border=false pad=(left=0px right=0px) across=1;

				    endlayout;
				endcell;

/*				cell;*/
/*				    cellheader;*/
/*	           	   	  entry "" / border=false;*/
/*	          	    endcellheader;*/
/*				    layout overlay / walldisplay=NONE xaxisopts=(display=none */
/*				        linearopts=(viewmin=2 viewmax=20 tickvaluelist=( 2 4 6 8 12 16 20 ) )) border=false ;*/
/*				        entry halign=left "Proportion (%)" / location=outside valign=top textattrs=(size=8pt ) ; */
/*				        axistable x=avisitn value=linear_mean / display=(label) valueattrs=(size=8pt) class=&trtvar. colorgroup=&trtvar._map;*/
/*				    endlayout;*/
/*				endcell;*/

				sidebar / align=bottom;
					discretelegend  "item1" "item2" / valueattrs=(family="宋体" size=8pt ) 
					title="治疗组"  titleattrs=(family="宋体" size=8pt ) 
					location=outside opaque=true valign=bottom halign=center border=false across=2; *across用来显示legend,pad=(left=20px right=20px);
			    endsidebar;

			endlayout; *layout lattice / columns=1 rows=2 Rowweights=(0.80 0.2) columngutter=2cm rowgutter=0.5cm border=false;;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final template=Boxplot;
	format avisitn avisit. ;
run;

ods rtf close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
