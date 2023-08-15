
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
%let pgmname = t-14-1-3-3.sas;
%let outname = T14010303;


%let lib=ads;
%let AnaSet=SAFFL;
%let adam=adcm;

%let text1=%str(至少有一个特别关注的研究期间的合并用药);


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
	set &lib..adsl(where=(&AnaSet.="Y")) end=last;
	if last then call symputx('total', _N_);
	output;
	&trtVar="Total";
	&trtVar.N=&trtmax.;
	output;
run;


* calculate BigN;
proc freq data=adsl noprint;
	table &trtVar.N / out=BigN(rename=(count=bigN) drop=percent);
run;

data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2 &N3;



data screen_&adam.;
	set &lib..&adam.(where=(&AnaSet.="Y"));
	if CONMEDFL="Y" and CMSIFL="Y";
	if cmdecod='' then cmdecod='Uncoded_PT';
	keep usubjid &trtvar.N CMSICAT CMSISCAT CMDECOD;
	proc sort;
	by &trtvar.N CMSICAT;
run;


data output_&adam.;
	set screen_&adam.;
	output;
	&trtvar.N=&trtmax.;
	&trtvar="Total";
	output;
run;


*level 0;
proc sql noprint;
	create table level_0 as
	select &trtvar.N, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N
	;
quit;
data level0ord;
	set level_0;
	if &trtvar.N=&trtmax.;
	proc sort;
	by N;
run;
data level0ord;
	set level0ord;
	ord=_N_;
run;


*level 1;
proc sql noprint;
	create table level_1 as
	select &trtvar.N, CMSICAT, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, CMSICAT
	;
quit;
data level1ord;
	set level_1;
	if &trtvar.N=&trtmax.;
	proc sort;
	by N descending CMSICAT;
run;
data level1ord;
	set level1ord;
	ord=_N_;
run;


*level 2;
proc sql noprint;
	create table level_2 as
	select &trtvar.N, CMSICAT, CMSISCAT, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, CMSICAT, CMSISCAT
	;
quit;

data level2ord;
	set level_2;
	if &trtvar.N=&trtmax.;
	proc sort;
	by N descending CMSISCAT;
run;
data level2ord;
	set level2ord;
	ord=_N_;
run;


*level 3;
proc sql noprint;
	create table level_3 as
	select &trtvar.N, CMSICAT, CMSISCAT, CMDECOD, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, CMSICAT, CMSISCAT, CMDECOD
	;
quit;
data level3ord;
	set level_3;
	if &trtvar.N=&trtmax.;
	proc sort;
	by N descending CMDECOD;
run;
data level3ord;
	set level3ord;
	ord=_N_;
run;


data all;
	set level_:;
	proc sort nodupkey;
	by CMSICAT CMSISCAT CMDECOD &trtvar.N;
run;


proc transpose data=all prefix=N out=trans_all(drop=_:);
	by CMSICAT CMSISCAT CMDECOD;
	var N;
	id &trtvar.N;
run;


data trans_all;
	length t1 CMSICAT CMSISCAT CMDECOD $200 N1-N&trtmax. 8;
	set trans_all;
	if missing(CMSICAT) then do;
		t1="&text1.";
	end;
	if not missing(CMSICAT) then do;
		t1=strip(CMSICAT);
	end;
	if not missing(CMSISCAT) then do;
		t1="    "||strip(CMSISCAT);
	end;
	if not missing(CMDECOD)  then do;
		t1="        "||strip(CMDECOD);
	end;
run;


proc sql noprint;
	create table trans_all2 as
	select a.*
	, case when not missing(b.ord) then b.ord
	  else 999999 end as level1ord
	, case when not missing(c.ord) then c.ord
	  else 999999 end as level2ord
	, case when not missing(d.ord) then d.ord
	  else 999999 end as level3ord
	from trans_all as a
		left join level1ord as b on a.CMSICAT=b.CMSICAT
		left join level2ord as c on a.CMSICAT=c.CMSICAT and a.CMSISCAT=c.CMSISCAT
		left join level3ord as d on a.CMSICAT=d.CMSICAT and a.CMSISCAT=d.CMSISCAT and a.CMDECOD=d.CMDECOD
		order by level1ord desc, level2ord desc, level3ord desc
	;
quit;


data trans_all3;
	set trans_all2;
	array numvar _numeric_;
	do over numvar;
		if numvar=. then numvar=0;
	end;
run;


data final;
	length t1 c1-c%eval(&trtmax.) $200;
	set trans_all3;
	%macro trtloop;
	%do i=1 %to &trtmax.;
		c&i=strip(put(n&i,best.))||" ("||strip(put(100*n&i/&&N&i., pct.))||")";
	%end;
	%mend;
	%trtloop;
	array charvar _char_;
	do over charvar;
		if charvar='0 (0.0)' then charvar='0';
	end;
run;


data final;
	set final;
	*pagen=ceil(_N_/20);
/*	if 1<=_N_<=20 then pagen=1;*/
/*	else if 21<=_N_<=39 then pagen=2;*/
/*	else if 40<=_N_<=57 then pagen=3;*/
/*	else pagen=4;*/
	pagen=ceil(_N_/20);
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
	a = {1  3,
	     1  -2};
	b = {100, 0};
	x = inv(a) * b;
	x = solve(a, b);
	create width from x[colname={'X'}]; 
	append from x;  
quit;

data _null_;
	set width;
	call symputx('width'||strip(put(_N_,best.)), X);
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
%put &just_list.;


data tabdat.&outname.;
	length t1-t&Tn. c1-c&trtmax. $200;
	set final;
	keep t1-t&Tn. c1-c&trtmax.;
run;


%if %sysfunc(exist(vtabdat.&outname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


%let header_list = 分类~@w@w@w@w首选术语|低起始剂量组~N=&N1~n(%)|标准起始剂量组~N=&N2~n(%)|合计~N=&N3~n(%);


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
