/*==========================================================================================*
Sponsor Name        : 苏州西克罗制药有限公司
Study   ID          : EDP125P3101
Project Name        : 评价 EDP125 治疗儿童和青少年注意缺陷/多动障碍安全性和有效性的多中心、随机、双盲、安慰剂平行对照 III期临床研究
Program Name        : f-14-2-2-7.sas
Program Path        : E:\Project\EDP125P3101\csr\dev\pg\figures
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output F-14-02-02-07.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\EDP125P3101\csr\dev\output\figures\F-14-02-02-07.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-10-24     weineng.zhou              Creation
 
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
%let pgmname = f-14-2-2-7.sas;
%let outname = F14020207;



%let lib=ads;
%let AnaSet=FASFL;
%let adam=adqs;

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
	value avisit
	7  = "D7"
	14 = "D14"
	28 = "D28"
	42 = "D42"
	56 = "D56/提前退出"
	;
	value trt
	1  = "EDP125"
	2 = "安慰剂"
	;
quit;


proc sql noprint;
	select max(&TrtVar.N)+1 into :trtmax separated by ''
	from &lib..adsl;
quit;
%put &trtmax.;


data adsl;
	set &lib..adsl(in=a where=(&AnaSet.="Y")) end=last;
	keep usubjid &TrtVar.N &TrtVar. EFF8FL AGEGRN;
	if last then call symputx('total', _N_);
	output;
	*&trtVar="Total";
	*&trtVar.N=&trtmax.;
	*output;
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


*二分类变量的频数;
proc freq data=adsl noprint;
	table &trtvar.N*EFF8FL / out=freq_bin8(drop=percent);
run;
data freq_bin8;
	set freq_bin8(rename=(EFF8FL=EFFFL));
	avisitn=56;
run;


data &adam.;
	length avisit $200;
	set ads.&adam.(where=(&AnaSet.="Y" & paramcd="AITSCOT3" & ADT<=CUTOFFDT));
	if DTYPE='';
	if avisitn in (7 14 28 42 );
/*	if AVISITN in(56 99) then do;*/
/*		avisitn=56;*/
/*		avisit="D56/提前退出";*/
/*	end;*/
	*不要提前退出的受试者-->要提前退出的受试者;
	if avisitn in (7 14 28 42 );
	if .<pchg<=-40 then efffl='Y'; else efffl='N';
	keep usubjid siteid &trtVar.N &trtVar. paramn param avisitn avisit base aval chg pchg efffl;
	proc sort; 
	by usubjid paramn param; 
run;


*组内各访视内的有效率;
proc freq data=&adam. noprint;
	table &trtvar.N*AVISITN*EFFFL / out=freq_bin(drop=percent);
run;
data freq_bin;
	set freq_bin;
	*modified by lili.qin in 2023-01-19;
/*	if missing(EFFFL) then EFFFL="N";*/
	*modified by lili.qin in 2023-01-19;
	proc sort;
	by &trtvar.N avisitn EFFFL;
run;


*7 14 28 42 56/99;
data freq_bin;
	set freq_bin freq_bin8;
	proc sort;
	by &trtvar.N avisitn EFFFL;
run;


data dummy;
	do &trtvar.N=1 to %eval(&trtmax.-1);
		do avisitn=7,14,28,42,56;
			do EFFFL="Y","N";
				count=0;
				output;
			end;
		end;
	end;
	proc sort;
	by &trtvar.N avisitn EFFFL;
run;


data freq_bin;
	merge dummy freq_bin;
	by &trtvar.N avisitn EFFFL;
run;


data EFFFL_Y;
	set freq_bin(rename=(count=EFFFL_Y));
	where EFFFL="Y";
	proc sort;
	by &trtvar.N;
run;


proc sort data=freq_bin; 
	by &trtvar.N AVISITN; 
run;
proc freq data=freq_bin;
	by &trtvar.N AVISITN;
	table EFFFL / binomial(level='Y' cl=all) alpha=0.05;
	weight count / zeros;
	ods output binomialcls=rate_CI(where=(prxmatch("/Pearson/",type)));
run;


data rate_CI;
	merge rate_CI EFFFL_Y;
	by &trtvar.N AVISITN;
	n_pct=strip(put(EFFFL_Y,best.))||" ("||strip(put(100*PROPORTION, pct.))||")";
	if cmiss(LOWERCL,UPPERCL)=0 then CI=strip(put(LOWERCL*100,8.1))||", "||strip(put(UPPERCL*100,8.1));
run;

data final;
	set rate_CI;
	PROPORTION=round(100*PROPORTION,0.1);
	keep &trtvar.N avisitn PROPORTION;
run;


proc datasets lib=work noprint;
	modify final;
	attrib _all_ label='';
run;
quit;


data figdat.&outname.;
	set final;
	proc sort;
	by &trtVar.N;
run;


ods html close;
ods html;
%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=11cm;
ods listing gpath="&root.output\figures" image_dpi=400; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


proc template;
	define statgraph barchart;
		begingraph /  border=false backgroundcolor = white
		datacolors=( cx6F7FB2 cxD95B5C ) datacontrastcolors=( cx6F7FB2 cxD95B5C );

			entrytitle "各时间点有效率柱状图";
			
			layout overlay/ cycleattrs=true walldisplay = none 
				yaxisopts=(
					griddisplay=off label='有效率（%）'
					labelattrs=(family="宋体" size=7pt weight=bold)
					tickvalueattrs=(size=7pt family="Times New Roman") 
				)
				xaxisopts=(
					griddisplay=off label="组别" 
					labelattrs=(family="宋体" size=10pt weight=bold)
					tickvalueattrs=(size=8pt family="宋体") 
				);
				
				barchartparm category=avisitn response=PROPORTION / name="BAR" group=&trtVar.N
				groupdisplay=cluster orient=vertical barwidth=0.9 
				dataskin=none datalabel=PROPORTION 
				outlineattrs=(color=white) segmentlabeltype=none
				;

				discreteLegend "BAR"/ valueattrs=(family="宋体" size=8pt) title='组别'
				location=outside opaque=true valign=bottom halign=center border=true
				pad=(left=0px right=0px);

			endlayout;
		endgraph;
	end;
run;

proc sgrender data=final template=barchart;
	format avisitn avisit. &trtVar.N trt.;
run;

ods rtf close;
ods listing;
ods results on;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
