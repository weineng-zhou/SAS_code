/*==========================================================================================*
Sponsor Name        : 杭州翰思生物医药有限公司
Study   ID          : HX009-II-02
Project Name        : 重组人源化抗 CD47/PD-1 双功能抗体 HX009 注射液治疗中国复发/难治性淋巴瘤患者的多中心、 开放、 单臂的Ⅰ /Ⅱ 期临床研究
Program Name        : t-14-3-4-1-2.sas
Program Path        : E:\Project\HX009-II-02\csr\val\pg\tables
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output T-14-03-04-01-02.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\HX009-II-02\csr\dev\output\tables\T-14-03-04-01-02.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-09-16     weineng.zhou              Creation
 
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
%let pgmname = t-14-3-4-1-2.sas;
%let outname = T1403040102;


proc format;
    invalue sig
	"未查"=1
	"正常"=2
    "异常无临床意义"=3
    "异常有临床意义"=4
	"合计"=5
	;
 	invalue seq	
	"正常"=1
    "异常无临床意义"=2
    "异常有临床意义"=3
	"未查"=4
	"合计"=5
	;
	value seqc
	1="正常"
    2="异常无临床意义"
    3="异常有临床意义"
	4="未查"
	5="合计"
	;
quit;


%let lib=ads;
%let AnaSet=SAFFL;
%let adam=adlb;


%if &AnaSet.=ENRLFL %then %do;
	%let trtvar=trt01p;
%end;
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


*以治疗后最严重的一次结果进入分析，严重程度按 异常有临床意义>异常无临床意义>正常>未查 的顺序分析(包括计划外访视检查);
data adlb;
	set ads.adlb(where=(&AnaSet.='Y' & ANL02FL="Y" & PARCAT1="血常规" and ADT<=CUTOFFDT));
	if ACLSIG='' then ACLSIG='未查';
	if BCLSIG='' then BCLSIG='未查';
	ACLSIGN=input(aclsig,sig.);
	BCLSIGN=input(BCLSIG,sig.);
run;


data adlb1;
	set adlb;
	output;
	&trtvar.N=&trtmax.; &trtvar.='合计';
	output;
run;
data adlb2;
	set adlb1; 
	output;
	BCLSIGN=5; BCLSIG='合计';
	output;
run;
data adlb3;
	set adlb2;
	output;
	ACLSIGN=5; ACLSIG='合计';
	output;
run;


* 分母;
proc freq data=adlb3 noprint;
	where BCLSIG='合计' and ACLSIG='合计';
	tables &trtvar.N*&trtvar.*parcat1n*parcat1*paramn*param
	/list out=shift_denominator(rename=(count=denominator) drop=percent);
run;

* 分子;
proc sort data=adlb3; by &trtvar.N &trtvar. parcat1n parcat1 paramn param; run;
proc freq data=adlb3 noprint;
	by &trtvar.N &trtvar. parcat1n parcat1 paramn param ;
	tables BCLSIGN*BCLSIG*ACLSIGN*ACLSIG 
	/ list out=shift_numerator(rename=(count=numerator) drop=percent);
run;


data shift;
	merge shift_numerator shift_denominator;
	by &trtvar.N &trtvar. parcat1n parcat1 paramn param ;
	pct=strip(put(numerator, best.))||" ("||strip(put(100*numerator/denominator, pct.))||")";
	proc sort;
	by &trtvar.N &trtvar. parcat1n parcat1 paramn param BCLSIGn BCLSIG; 
run;

proc transpose data=shift out=shift_table(drop=_name_) prefix=sig;
	by &trtvar.N &trtvar. parcat1n parcat1 paramn param BCLSIGn BCLSIG;
	var pct;
	id ACLSIGN;
run;

data shift_table;
	set shift_table;
	seq=input(BCLSIG,??seq.);
	drop BCLSIGn;
run;


proc freq data=shift_table noprint;
	table &trtvar.N*&trtvar.*parcat1n*parcat1*paramn*param / out=dummy(drop=count percent);
run;

data dummy;
	set dummy;
	do seq=1 to 5;
		output;
	end;
run;

data shift_table;
	set shift_table dummy;
	proc sort;
	by &trtvar.N &trtvar. parcat1n parcat1 paramn param seq BCLSIG; 
run;

data shift_table;
	set shift_table;
	by &trtvar.N &trtvar. parcat1n parcat1 paramn param seq BCLSIG; 
	if last.seq;
	if missing(BCLSIG) then BCLSIG=put(seq,seqc.);
run; 


data all;
	length paramn &trtvar.N seq 8;
	set shift_table;
	array s _char_;
	do over s;
		if s='' then s='0';
	end;
	proc sort;	
	by paramn param &trtvar.N &trtvar. seq;
run;


data all2;
	set all;
	pagen=ceil(_N_/20);
	proc sort;
	by paramn param pagen &trtvar.N &trtvar. seq;
run;

proc contents data=all2 out=exist_var noprint;
run;
proc sql noprint;
	select name into :exist_var_list separated by ' '
	from exist_var;
run;
%put &exist_var_list.;

data final;
	set all2;
	by paramn param pagen &trtvar.N &trtvar. seq;
	if not first.paramn then do;
		call missing(param);
	end;
	if seq>1 then do;
		call missing(&trtvar.);
	end;
	param=scan(param,1,"()");
	t1=param;
	if not prxmatch("/合计/",&trtvar.) then t2=scan(&trtvar.,2," "); 
	else t2=&trtvar.;
	t3=BCLSIG;
	%if %sysfunc(prxmatch(/SIG2/i,&exist_var_list)) %then %do;
		c1=sig2;
	%end;
	%else %do;
		c1='0';
	%end;
	%if %sysfunc(prxmatch(/SIG3/i,&exist_var_list)) %then %do;
		c2=sig3;
	%end;
	%else %do;
		c2='0';
	%end;
	%if %sysfunc(prxmatch(/SIG4/i,&exist_var_list)) %then %do;
		c3=sig4;
	%end;
	%else %do;
		c3='0';
	%end;
	%if %sysfunc(prxmatch(/SIG1/i,&exist_var_list)) %then %do;
		c4=sig1;
	%end;
	%else %do;
		c4='0';
	%end;
	%if %sysfunc(prxmatch(/SIG5/i,&exist_var_list)) %then %do;
		c5=sig5;
	%end;
run;


proc contents data=final out=column_var noprint;
run;
proc sql noprint;
	select count(*) into :column separated by ''
	from column_var where prxmatch("/\bT\d|\bC\d/i",name);
quit;
%put &column.;
data _null_;
	set column_var(where=(prxmatch("/\bT\d/i",name))) end=last;
	if last then call symputx("Tn",_N_);
run;
%put &Tn.;

/*x1 + 3x2=100;*/
/*x1 - 2x2=0;*/

proc iml;
	a = {1  4,
	     1  -2};
	b = {100, 0};
	x = inv(a) * b;
	x = solve(a, b);
	create width from x[colname={'X'}]; 
	append from x;  
quit;

data _null_;
	set width;
	call symputx('width'||strip(put(_N_,best.)), int(X));
run;

data width;
	do i=1 to &column.;
		if i<=&Tn. then do;
			width = &width1.;
			just='l';
			output;
		end;
		else do;
			width = &width2.;
			just='c'; 
			output;
		end;
	end;
run;

proc sql noprint;
	select width into :width_list separated by '|'
	from width;
	select just into :just_list separated by '|'
	from width;
quit;
%put &width_list.;
%let width_list=16|12|12|12|12|12|12|12;
%put &just_list.;


*Role for QC;
data vtabdat.&outname.;
	length t1-t&Tn. c1-c5 $200;
	set final;
	keep t1-t&Tn. c1-c5;
run;


%if %sysfunc(exist(tabdat.&outname.)) %then %do;
	%Compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


%let header_list = 指标|组别|治疗前|正常|异常无临床意义|异常有临床意义|未查|合计;

options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline; 
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@"; 
ods listing close;

%Mstrtrtf3(pgmname=&pgmname, pgmid=1, style=tables_8_pt); 

proc report data=final missing center nowd headline headskip split = '~'; 

	column pagen t1-t&Tn. c1-c&trtmax.; 

	define pagen /order noprint;
 
	%macro define_loop;
	%do i = 1 %to %eval(%sysfunc(countc(&width_list,%str(|)))+1);
		%let header = %qscan(&header_list, &i, %str(|));
		%let width = %qscan(&width_list, &i, %str(|));
		%let just = %qscan(&just_list, &i, %str(|));
		%if &i<=&Tn. %then %do;
			define t&i   / "&header."  &line2. style(header)=[just=&just.] style(column)=[cellwidth=&width.% just=&just. asis=on]; 
		%end;
		%else %do;
			define c%eval(&i-&Tn.)   / "&header."  &line2. style(header)=[just=&just.] style(column)=[cellwidth=&width.% just=&just. asis=on];
		%end; 
	%end;
	%mend;
	%define_loop;

	break after pagen / page; 

	compute before _page_;
		line &line.;
	endcomp;

	%footloop;

run; 
ods _all_ close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
