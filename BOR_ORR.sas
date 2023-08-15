/*==========================================================================================*
Sponsor Name        : 亘喜生物科技（上海）有限公司
Study   ID          : GC012F-321
Project Name        : GC012F 注射液治疗适合移植的高危型新诊断多发性骨髓瘤患者的临床研究
Program Name        : t-14-2-1-1.sas
Program Path        : E:\Project\GC012F-321\csr\dev\pg\tables
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output T-14-02-01-01.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\GC012F-321\csr\dev\output\tables\T-14-02-01-01.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2023-03-02     weineng.zhou              Creation
 
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
%let pgmname = t-14-2-1-1.sas;
%let outname = T14020101;


%let lib=ads;
%let AnaSet=FASFL;
%let adam=adrs;


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


proc format;
	value ordc
	1="最佳疗效"
	2="客观缓解率（sCR+CR+VGPR+PR）"
/*	3="疾病控制率（sCR+CR+VGPR+PR+MR+SD）"*/
	;
    value seq1c
	1='严格意义完全缓解（sCR），n(%)'
	2='完全缓解（CR），n(%)'
	3='非常好的部分缓解（VGPR），n(%)'
	4='部分缓解（PR），n(%)'
	5='微小缓解（MR），n(%)'
	6='疾病稳定（SD），n(%)'
	7='疾病进展（PD）或复发（CR），n(%)'
	8='尚未判定，n(%)'
	9='合计，n(%)'
	;
	invalue seq
    "sCR"=1
	"CR"=2
	"VGPR"=3
	"PR"=4
	"MR"=5
	"SD"=6
	"疾病进展或复发"=7
	"尚未判定"=8
	"合计"=9
	;
	value seq2c
	1='n(%)'
	2='95% CI'
	;
	value seq3c
	1='n(%)'
	2='95% CI'
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
	&trtVar="Total";
	&trtVar.N=&trtmax.;
	output;
run;


* calculate BigN;
proc freq data=adsl noprint;
	where not missing(&trtVar.N);
	table &trtVar.N / out=BigN(rename=(count=bigN) drop=percent);
run;


data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2;


*design the dummy matrix dataset;
data matrix;
	do &trtVar.N=1 to &trtmax.;
		do ord=1 to 2;

			if ord=1 then do;
				do seq=1 to 9;
					output;
				end;
			end;

			else if ord in(2 3 ) then do;
				do seq=1 to 2;
					output;
				end;
			end;

			else do;
				seq=0;
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


data dummy;
	length t1 t2 $200;
	set dummy;
	if seq=1 then t1=put(ord,ordc.);
	if ord=1 & seq>0 then t2=put(seq,seq1c.);
	if ord=2 & seq>0 then t2=put(seq,seq2c.);
	if ord=3 & seq>0 then t2=put(seq,seq3c.);
	%macro nloop;
	%do i=1 %to &trtmax.;
		N&i=0;
	%end;
	%mend;
	%nloop;
run;


data output_&adam.;
	set &lib..&adam.(where=(&AnaSet.="Y" and paramcd="BESTRESP" ));
	aval=input(avalc,??seq.);
	output;
	&trtVar="Total";
	&trtVar.N=&trtmax.;
	output;
run;


%macro CountByCond(dsin=, cond=, ord=, seq=);
proc sql noprint;
	create table ord&ord as 
	select &TrtVar.N, &ord as ord, &seq as seq, count(distinct usubjid) as n
	from &dsin. where &cond.
	group by ord,seq,&TrtVar.N
	order by ord,seq,&TrtVar.N
;
quit; 
proc transpose data=ord&ord out=trans_&ord._&seq(drop=_name_) prefix=n;
	by ord seq;
	var n;
	id &TrtVar.N;
run;
%mend;
/*%CountByCond(dsin=&adam., cond=%str( ), ord=1, seq=0);*/


%macro CountByCatVar(dsin=, CatVar=, ord=, seq=);
%if &seq= %then %do;
	proc sql noprint;
		create table seq&ord. as 
		select &TrtVar.N,&ord. as ord, input(&CatVar., seq.) as seq, count(usubjid) as n
		from &dsin. where &CatVar. is not missing
		group by ord,seq,&TrtVar.N
		order by ord,seq,&TrtVar.N
		;
	quit;
	proc transpose data=seq&ord out=trans_&ord._seq(drop=_name_ ) prefix=n;
		by ord seq;
		var n;
		id &TrtVar.N;
	run;
%end;
%else %do;
	proc sql noprint;
		create table count as 
		select &TrtVar.N,&ord. as ord, &seq. as seq, count(usubjid) as n
		from &dsin. where &CatVar. is not missing
		group by ord,seq, &TrtVar.N
		order by ord,seq, &TrtVar.N
		;
	quit;
	proc transpose data=count out=trans_&ord._&seq.(drop=_name_ ) prefix=n;
		by ord seq;
		var n;
		id &TrtVar.N;
	run;
%end;
%mend;
%CountByCatVar(dsin=output_&adam., CatVar=avalc,  ORD=1);
%CountByCatVar(dsin=output_&adam., CatVar=avalc,  ORD=1, seq=9);


%macro Clopper_Pearson(dsin=,flag=,ord=);

proc freq data=&dsin. noprint;
	table &trtvar.N*&flag. / out=freq_&flag.(drop=percent);
run;

data &flag._Y;
	set freq_&flag.(rename=(count=&flag._Y));
	where &flag.="Y";
	proc sort;
	by &trtvar.N &flag.; 
run;

data dummy1;
	do &trtvar.N=1 to &trtmax.;
		do &flag.="Y";
			&flag._Y=0; 
			output;
		end;
	end;
	proc sort;
	by &trtvar.N &flag.; 
run;

data &flag._Y;
	merge dummy1 &flag._Y ;
	by &trtvar.N &flag.;
	proc sort;
	by &trtvar.N &flag.;
run;

data dummy2;
	do &trtvar.N=1 to &trtmax.;
		do &flag.="N", "Y";
			count=0;
			output;
		end;
	end;
run;

data freq_bin;
	merge dummy2 freq_&flag.;
	by &trtvar.N &flag.;
	proc sort;
	by &trtvar.N;
run;

proc freq data=freq_bin;
	by &trtvar.N;
	table &flag. / binomial(level='Y' cl=all) alpha=0.05;
	weight count / zeros;
	ods output binomialcls=&flag._CI(where=(prxmatch("/Pearson/",type)));
run;

data &flag.;
	merge &flag._Y(in=a) &flag._CI bigN;
	by &trtvar.N;
	if cmiss(&flag._Y,PROPORTION)=0 then n_pct=strip(put(&flag._Y,best.))||" ("||strip(put(100*PROPORTION, pct.))||")";
	if cmiss(LOWERCL,UPPERCL)=0 then CI=strip(put(LOWERCL*100,8.1))||", "||strip(put(UPPERCL*100,8.1));
	proc sort;
	by &flag.; 
run;

proc transpose data=&flag. prefix=c out=trans_&flag._Y(drop=_:);
	var n_pct;
	id &trtvar.N;
run;

proc transpose data=&flag. prefix=c out=trans_&flag._CI(drop=_:);
	var CI;
	id &trtvar.N;
run;

data trans_&flag._Y;
	length ord seq 8 c1-c&trtmax. $200;
	set trans_&flag._Y;
	ord=&ord.;
	seq=1;
run;

data trans_&flag._CI;
	length ord seq 8 c1-c&trtmax. $200;
	set trans_&flag._CI;
	ord=&ord.;
	seq=2;
run;
%mend;
%Clopper_Pearson(dsin=output_&adam., flag=ORRFL, ord=2);


data all_trans;
	set trans_:;
	if not missing(seq);
	proc sort;
	by ord seq;
run;


data all_merge;
	merge dummy(in=a) all_trans ;
	by ord seq;
	if a;
	array numvar _numeric_;
	do over numvar;
		if numvar=. then numvar=0;
	end;
run;


data final;
	length ord seq 8 t1 c1-c&trtmax. $200;
	set all_merge;
	%macro trtloop;
	%do i=1 %to &trtmax.;
		c&i=strip(put(n&i,best.))||" ("||strip(put(100*n&i/BigN&i., pct.))||")";
	%end;
	%mend;
	if ord=1 then do;
		%trtloop;
	end;
	array charvar _char_;
	do over charvar;
		if charvar="0 (0.0)" then charvar="0";
		*charvar=tranwrd(charvar,'100.0','100');
	end;
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
	pagen=1;
	proc sort;
	by ord seq;
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


proc iml;
	a = {2  4,
	     1  -2};
	b = {100, 0};
	x = inv(a) * b;
	x = solve(a, b);
	create width from x[colname={'X'}]; 
	append from x;  
quit;

data _null_;
	set width;
	call symputx('width'||strip(put(_N_,best.)), floor(X));
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
%let width_list=26|26|12|12|12|12;
%put &just_list.;


data tabdat.&outname.;
	length t1-t&Tn. c1-c%eval(&trtmax.) $200;
	set final;
	keep t1-t&Tn. c1-c%eval(&trtmax.);
run;


%if %sysfunc(exist(vtabdat.&outname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline; 
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods listing close;

%let header_list = 指标@n|统计量@n|1×10@{super 5}/kg组~N=&N1|2×10@{super 5}/kg组~N=&N2|3×10@{super 5}/kg组~N=&N3|合计~N=&N4;


%Mstrtrtf3(pgmname=&pgmname, pgmid=1, style=tables_8_pt);
 

proc report data=final missing center nowd headline headskip split = '~'; 

	column pagen t1-t&Tn. c1-c%eval(&trtmax.); 

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
		*text1 = "&header1 ("||strip(put(pagen,best.))||"/"||strip(put(&totpage.,best.))||")";
		*line text1 $200.;
		line &line.;
	endcomp;

	%footloop;

run; 
ods _all_ close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
