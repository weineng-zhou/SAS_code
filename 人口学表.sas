/*==========================================================================================*
Sponsor Name        : 珐博进（中国） 医药技术开发有限公司（珐博进中国）
Study   ID          : FGCL-4592-858
Project Name        : 一项评估罗沙司他低起始剂量给药方案治疗慢性肾脏病非透析贫血患者的有效性和安全性的随机、 对照、 开放标签、 多中心研究
Program Name        : t-14-1-2-1.sas
Program Path        : E:\Project\FGCL-4592-858\csr\dev\pg\tables
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output T-14-01-02-01.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\FGCL-4592-858\csr\dev\output\tables\T-14-01-02-01.rtf
 
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
%let pgmname = t-14-1-2-1.sas;


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
	value ordc
	1='年龄（岁）'
	2='年龄分组'
	3='性别'
	4='民族'
	5='体重 (kg)'
	6='身高 (cm)'	
	7='体质指数（kg/m@{super 2}）'
	8='体质指数分组（n%）'
	;
	value seqc
	1='例数（缺失数）' 
	2='均数（标准差）' 
	3='中位数' 
	4='四分位数' 
	5='最小值，最大值' 
	;
	invalue seq
	'<65'=1
	'>=65'=2 
	'男'=1
	'女'=2 
	'汉族'=1
	'其他'=2
	"<18.5"=1
	"18.5-<24"=2
	"24-<28"=3
	">=28"=4
	;
	value seq2c
	1='<65'
	2='≥65'
	;
	value seq3c
	1='男'
	2='女'
	;
	value seq4c
	1='汉'
	2='其他'
	;
	value seq8c
	1= "<18.5"
	2= "18.5-<24"
	3= "24-<28"
	4= "≥28"
	;
quit;


proc sql noprint;
	select max(&TrtVar.N)+1 into :trtmax separated by ''
	from &lib..adsl;
quit;
%put &trtmax.;


data adsl;
	set &lib..adsl(in=a where=(&AnaSet.="Y")) end=last;
	if last then call symputx('total', _N_);
	output;
	&trtVar.N=&trtmax.;
	&trtVar="Total";
	output;
run;


* calculate BigN;
proc freq data=adsl noprint;
	table &trtVar.N*&trtVar. / out=BigN(rename=(count=BigN) drop=percent);
run;
data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), BigN);
run;
%put &N1 &N2 &N3;


*design the dummy matrix dataset;
data matrix;
	do &trtVar.N=1 to &trtmax.;
		do ord=1 to 8;
			if ord in (1 5 6 7) then do;
				do seq=1 to 5;
					output;
				end;
			end;
			else if ord in (2 3 4 )  then do;
				do seq=1 to 2;
					output;
				end;
			end;
			else if ord in (8 )  then do;
				do seq=1 to 4;
					output;
				end;
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
proc transpose data=matrix out=dummy(drop=_name_ _label_) prefix=BigN;
	by ord seq;
	id &trtVar.N;
run;


data dummy;
	length t1 $200;
	set dummy;
	if seq=0 then t1=put(ord,ordc.);
	if ord in(2 ) & seq>0 then t1="    "||put(seq,seq2c.);
	if ord in(3 ) & seq>0 then t1="    "||put(seq,seq3c.);
	if ord in(4 ) & seq>0 then t1="    "||put(seq,seq4c.);
	if ord in(8 ) & seq>0 then t1="    "||put(seq,seq8c.);
run;


proc sort data=adsl; by usubjid &trtVar.N &trtVar.; run;
proc transpose data=adsl out=adsl_param(rename=(_name_=paramcd _label_=param col1=base));
	by usubjid &trtVar.N &trtVar.;
	var AGE HEIGHTBL WEIGHTBL BMIBL;
run;
data adsl_param;
	set adsl_param;
	if paramcd="AGE" then paramn=1;
	if paramcd="WEIGHTBL" then paramn=5;
	if paramcd="HEIGHTBL" then paramn=6;
	if paramcd="BMIBL" then paramn=7;
run;


%macro subject_level_means(dsin=, dsout=, screen=, var=, ord=); 
/*

%let dsin=BDS;
%let dsout=base;
%let var=base;
%let ord=1;

*/

data BDS; 
	set &dsin.; 
	where &screen.; 
	dec=lengthn(scan(strip(put(&var.,best.)),2,'.')); 
	keep usubjid &trtVar.N &trtVar. paramn param &var. dec; 
	proc sort; 
	by &trtVar.N &trtVar. paramn param; 
run;

proc sql noprint; 
	create table max_dec as 
	select paramn, param, max(dec) as maxx 
	from BDS
	group by paramn, param; 
quit;

proc sql noprint; 
	create table dec123 as 
	select paramn, param, maxx, min(maxx,3) as raw0 , min(maxx+1,3) as raw1, min(maxx+2,3) as raw2
	from max_dec
	order by paramn, param;
quit;

proc means data=BDS noprint; 
	by &trtVar.N &trtVar. paramn param;
	var &var.;
	output out=stat_&var.(drop= _type_ _freq_) n=n nmiss=nmiss mean=mean std=std q1=q1 q3=q3 median=median min=min max=max; 
run;
proc sort data=stat_&var.;
	by paramn param ;
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
	merge stat_&var.(in=a) BigN; 
	by &trtVar.N; 
	if a;
run;

data stat_&var.;
	length row1-row5 $100;
	set stat_&var.; 
	dec0 = cats(12,'.',raw0);
	dec1 = cats(12,'.',raw1);
	dec2 = cats(12,'.',raw2);
	row1=strip(put(n,best.))||" ("||strip(put(BigN-n,best.))||")"; 	

/*	if cmiss(mean,std)=0 then row2=strip(putn(round(mean,10**((-1)*raw1)), dec1))||" ("||strip(putn(round(std,10**((-1)*raw2)),dec2))||")"; */
/*	else if mean^=. and std=. then row2=strip(putn(round(mean,10**((-1)*raw1)), dec1))||" (-)"; */
/*	else if cmiss(mean,std)=2 then row2="-"; */
/*	if median ne . then row3=strip(putn(round(median,10**((-1)*raw1)),dec1));*/
/*	else row3="-"; */
/*	if cmiss(Q1,Q3)=0 then row4=strip(putn(round(Q1,10**((-1)*raw0)), dec0))||", "||strip(putn(round(q3,10**((-1)*raw0)), dec0)); */
/*	else row4="-"; */
/*	if min^=. then row5=strip(putn(round(min,10**((-1)*raw0)), dec0))||", "||strip(putn(round(max,10**((-1)*raw0)), dec0)); */
/*	else if min=. then row5="-"; */

	if cmiss(mean,std)=0 then row2=strip(putn(mean, dec1))||" ("||strip(putn(std,dec2))||")"; 
	else if mean^=. and std=. then row2=strip(putn(mean, dec1))||" (-)"; 
	else if cmiss(mean,std)=2 then row2="-"; 
	if median ne . then row3=strip(putn(median,dec1));
	else row3="-"; 
	if cmiss(Q1,Q3)=0 then row4=strip(putn(Q1, dec0))||", "||strip(putn(q3, dec0)); 
	else row4="-"; 
	if min^=. then row5=strip(putn(min, dec0))||", "||strip(putn(max, dec0)); 
	else if min=. then row5="-"; 

	proc sort;
	by paramn param;
run;

proc transpose data=stat_&var. out=trans_&var. prefix=c; 
	by paramn param; 
	var row1-row5; 
	id &trtVar.N; 
run;

data &dsout.; 
	length ord seq 8 c1-c&trtmax. $200;
	set trans_&var.; 
	ord=paramn; 
	seq=input(substr(_name_,4,1),best.); 
	keep ord seq c1-c&trtmax.;
run; 

%mend; 
%subject_level_means(dsin=adsl_param, dsout=trans_base, screen=%str(not missing(usubjid)), var=base); 


%macro CountByCatVar(CATVAR=, ORD=);
proc sql noprint;
	create table seq&ord. as 
	select &TrtVar.N,&ord. as ord, input(&CATVAR., seq.) as seq, count(subjid) as n
	from adsl where &CATVAR. is not missing
	group by ord,seq,&TrtVar.N
	order by ord,seq,&TrtVar.N
	;
quit;
proc transpose data=seq&ord out=trans_seq&ord(drop=_name_ ) prefix=n;
	by ord seq;
	var n;
	id &TrtVar.N;
run;
%mend;
%CountByCatVar(CATVAR=AGEGR1,ORD=2);
%CountByCatVar(CATVAR=SEX,ORD=3);
%CountByCatVar(CATVAR=ETHNIC,ORD=4);
%CountByCatVar(CATVAR=BMIGR1,ORD=8);


data all_trans;
	set trans_:;
	proc sort;
	by ord seq ;
run;

data all_merge;
	merge dummy all_trans;
	by ord seq;
	array numvar _numeric_;
	do over numvar;
		if numvar=. then numvar=0;
	end;
run;

data final;
	length ord seq 8 t1 t2 c1-c&trtmax. $200;
	set all_merge;
	t1=put(ord,ordc.);
	if ord in(1 5 6 7) then do;
		t2=put(seq,seqc.);
	end;
	else do;
		if ord=2 then t2=strip(put(seq,seq2c.));
		if ord=3 then t2=strip(put(seq,seq3c.));
		if ord=4 then t2=strip(put(seq,seq4c.));
		if ord=8 then t2=strip(put(seq,seq8c.));
	end;
	%macro trtloop;
	%do i=1 %to &trtmax.;
		c&i=strip(put(n&i,best.))||" ("||strip(put(100*n&i/BigN&i., pct.))||")";
	%end;
	%mend;
	if ord in (2 3 4 8 ) then do;
		%trtloop;
	end;
	array charvar _char_;
	do over charvar;
		if charvar='0 (0.0)' then charvar='0';
	end;
	if ord in (1 5 6 7) then do;
		if seq=4 then delete;
	end;
	proc sort;
	by ord seq;
run;
data final;
	set final;
	by ord seq;
	if not first.ord then call missing(t1);
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

/*
2x1 + 3x2=100
x1  - 2x2 =0
*/

proc iml;
	b = {2 3,
	     1 -2};
	y = {100, 0};
	x = inv(b) * y;
	x = solve(b, y);
	create width from x[colname={'X'}]; 
	append from x;  
quit;

data _null_;
	set width;
	call symputx('width'||strip(put(_N_,best.)), floor(X));
run;
%put &width1.;
%put &width2.;

data width;
	do i=1 to &column.;
		if i<=&Tn. then do;
			width = %eval(&width1.+1);
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
%put &just_list.;


data tabdat.&outname.;
	length t1-t&Tn. c1-c&trtmax. $200;
	set final;
	keep t1-t&Tn. c1-c&trtmax.;
run;


*空行算法;
proc freq data=final noprint;
	table ord / out=block;
run;
data blank;
	set block end=last;
	ord=ord+0.5;
	if last then delete;
	keep ord;
run;


data final;
	set final blank;
	if ord<=5 then pagen=1;
	else pagen=2;
	if ord=5.5 then delete;
	proc sort;
	by ord seq;
run;


%if %sysfunc(exist(vtabdat.&outname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


%let header_list = 指标~@w|@w|剂量组1~N=&N1|剂量组2~N=&N2|合计~N=&N3;


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
			define t&i   / "&header."  &line2. style(header)=[just=l] style(column)=[cellwidth=&width.% just=&just. asis=on]; 
		%end;
		%else %do;
			define c%eval(&i-&Tn.)   / "&header."  &line2. style(header)=[just=c] style(column)=[cellwidth=&width.% just=&just. asis=on]; 
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


