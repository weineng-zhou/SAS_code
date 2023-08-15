
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
%let pgmname = t-ae-soc-pt.sas;


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
	if TRTEMFL="Y";
	if aesoc='' then aesoc='Uncoded';
	if aedecod='' then aedecod='Uncoded';
	keep usubjid &trtvar.N aesoc aedecod;
	proc sort;
	by &trtvar.N aesoc;
run;


*---output for treatment---;
data output_&adam.;
	set screen_&adam.;
	output;
	&trtvar.N=&trtmax.;
	&trtvar="Total";
	output;
run;


*level 1;
proc sql noprint;
	create table level_1 as
	select &trtvar.N, aesoc, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, aesoc
	;
quit;
data level1ord;
	set level_1;
	if &trtvar.N=&trtmax.;
	if prxmatch("/Uncoded/i",aesoc) then N=0;
	proc sort;
	by N descending aesoc;
run;
data level1ord;
	set level1ord;
	ord=_N_;
run;


*level 2;
proc sql noprint;
	create table level_2 as
	select &trtvar.N, aesoc, aedecod, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, aesoc, aedecod
	;
quit;

data level2ord;
	set level_2;
	if &trtvar.N=&trtmax.;
	if prxmatch("/Uncoded/i",aedecod) then N=0;
	proc sort;
	by N descending aedecod;
run;
data level2ord;
	set level2ord;
	ord=_N_;
run;


data all;
	set level_:;
	proc sort;
	by aesoc aedecod &trtvar.N;
run;

proc transpose data=all prefix=N out=trans_all(drop=_:);
	by aesoc aedecod;
	var N;
	id &trtvar.N;
run;


data trans_all;
	length t1 aesoc aedecod $200 N1-N&trtmax. 8;
	set trans_all;
	if not missing(aesoc) then do;
		t1=strip(aesoc);
	end;
	if not missing(aedecod) then do;
		t1="    "||strip(aedecod);
	end;
run;


proc sql noprint;
	create table trans_all2 as
	select a.*, b.ord as level1ord
	, case when not missing(c.ord) then c.ord
	  else 999999 end as level2ord
	from trans_all as a
		left join level1ord as b on a.aesoc=b.aesoc
		left join level2ord as c on a.aesoc=c.aesoc and a.aedecod=c.aedecod
		order by level1ord desc, level2ord desc
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
	if 1<=_N_<=20 then pagen=1;
	else if 21<=_N_<=39 then pagen=2;
	else if 40<=_N_<=57 then pagen=3;
	else pagen=4;
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
%let width_list=20|20|20|20|20;
%put &just_list.;


data tabdat.&outname.;
	length t1-t&Tn. c1-c&trtmax. $200;
	set final;
	keep t1-t&Tn. c1-c&trtmax.;
run;


%if %sysfunc(exist(vtabdat.&outname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


%let header_list =   ϵͳ   ٷ   ~@w@w@w@w  ѡ    | ͼ     ~N=&N1~n(%)| м     ~N=&N2~n(%)| ߼     ~N=&N3~n(%)| ϼ ~N=&N4~n(%);


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
