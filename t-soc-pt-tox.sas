/*==========================================================================================*
Sponsor Name        : 博生吉医药科技（苏州）有限公司
Study   ID          : PG-CART-07-001
Project Name        : PA3-17 注射液治疗成人复发/难治性 CD7 阳性血液淋巴系统恶性肿瘤患者的开放标签、剂量递增的 I 期临床研究
Program Name        : t-14-3-2-1-1.sas
Program Path        : E:\Project\PG-CART-07-001\csr\dev\pg\tables
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output T-14-03-02-01-01.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\PG-CART-07-001\csr\dev\output\tables\T-14-03-02-01-01.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2023-06-29     weineng.zhou                  Creation
 
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
%let pgmname = t-14-3-2-1-1.sas;
%let outname = T1403020101;


%let lib=ads;
%let AnaSet=SAFFL;
%let adam=adae;


proc format;
	invalue level3ord
	""=0
	"1级"=1
	"2级"=2
	"3级"=3
	"4级"=4
	"5级"=5
	;
quit;


%let text1=%str(任何与清淋预处理相关的AE);

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
	if AECAT='不良事件' and AEREA2="Y";
	if AESOC='' then AESOC='Uncoded';
	if AEDECOD='' then AEDECOD='Uncoded';
	keep usubjid &trtvar.N AESOC AEDECOD AETOXGR;
	proc sort;
	by &trtvar.N AESOC;
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
	select &trtvar.N, count(usubjid) as M, count(distinct usubjid) as N
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
	select &trtvar.N, AESOC, count(usubjid) as M, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, AESOC
	;
quit;
data level1ord;
	set level_1;
	if &trtvar.N=&trtmax.;
	if prxmatch("/Uncoded/i",aesoc) then N=0;
	proc sort;
	by N descending AESOC;
run;
data level1ord;
	set level1ord;
	ord=_N_;
run;


*level 2;
proc sql noprint;
	create table level_2 as
	select &trtvar.N, AESOC, AEDECOD, count(usubjid) as M, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, AESOC, AEDECOD
	;
quit;

data level2ord;
	set level_2;
	if &trtvar.N=&trtmax.;
	if prxmatch("/Uncoded/i",AEDECOD) then N=0;
	proc sort;
	by N descending AEDECOD;
run;
data level2ord;
	set level2ord;
	ord=_N_;
run;


*level 3;
proc sql noprint;
	create table level_3 as
	select &trtvar.N, AESOC, AEDECOD, AETOXGR, count(usubjid) as M, count(distinct usubjid) as N
	from output_&adam.
	group by &trtvar.N, AESOC, AEDECOD, AETOXGR
	;
quit;
data level3ord;
	set level_3;
	if &trtvar.N=&trtmax.;
	proc sort;
	by N descending AETOXGR;
run;
data level3ord;
	set level3ord;
	ord=_N_;
run;


data all;
	set level_:;
	proc sort nodupkey dupout=_dups ;
	by AESOC AEDECOD AETOXGR &trtvar.N;
run;


data temp;
	set all;
run;
proc sql noprint;
	create table all as 
	select a.*, b.BigN
	from temp as a left join BigN as b
	on a.&trtvar.N=b.&trtvar.N
	order by AESOC, AEDECOD, AETOXGR
	;
quit;


proc transpose data=all prefix=N out=trans_N(drop=_:);
	by AESOC AEDECOD AETOXGR;
	var N;
	id &trtvar.N;
run;


proc transpose data=all prefix=M out=trans_M(drop=_:);
	by AESOC AEDECOD AETOXGR;
	var M;
	id &trtvar.N;
run;


proc transpose data=all prefix=BigN out=trans_BigN(drop=_:);
	by AESOC AEDECOD AETOXGR;
	var BigN;
	id &trtvar.N;
run;


data trans_all;
	merge trans_M trans_N trans_BigN;
	by AESOC AEDECOD AETOXGR;
run; 


data trans_all;
	length t1 AESOC AEDECOD AETOXGR $200 N1-N&trtmax. 8;
	set trans_all;
	if missing(AESOC) then do;
		t1="&text1.";
	end;
	if not missing(AESOC) then do;
		t1=strip(AESOC);
	end;
	if not missing(AEDECOD) then do;
		t1="    "||strip(AEDECOD);
	end;
	if not missing(AETOXGR)  then do;
		t1="        "||strip(AETOXGR);
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
		left join level1ord as b on a.AESOC=b.AESOC
		left join level2ord as c on a.AESOC=c.AESOC and a.AEDECOD=c.AEDECOD
		left join level3ord as d on a.AESOC=d.AESOC and a.AEDECOD=d.AEDECOD and a.AETOXGR=d.AETOXGR
		order by level1ord desc, level2ord desc, level3ord desc
	;
quit;



proc freq data=trans_all2 noprint;
	table AESOC*level1ord*AEDECOD*level2ord / out=dummy(keep=level1ord AESOC level2ord AEDECOD);
run;
data dummy;
	length AESOC AEDECOD AETOXGR $200;
	set dummy;
	if not missing(AEDECOD) then do;
		do AETOXGR="", "1级", "2级", "3级", "4级", "5级";
			output;
		end;
	end;
	else do;
		AETOXGR=""; output;
	end;
	proc sort;
	by AESOC AEDECOD AETOXGR;
run;


proc sort data=trans_all2;
	by AESOC AEDECOD AETOXGR;
run;


data all_merge;
	length AESOC AEDECOD AETOXGR $200;
	merge dummy(in=a) trans_all2;
	by AESOC AEDECOD AETOXGR;
	if a;
	if missing(t1)  then do;
		t1="        "||strip(AETOXGR);
	end;
	level3ord=input(AETOXGR, level3ord.);
	proc sort;
	by descending level1ord descending level2ord level3ord;
run;


data final;
	length t1 c1-c%eval(&trtmax.) $200;
	set all_merge;
	array numvar _numeric_;
	do over numvar;
		if numvar=. then numvar=0;
	end;

	array M[4];
	array N[4];
	array BigN[4];
	array c[12] $20;

	do i = 1 to dim(c);
		if mod(i+2,3)=0 then do;
			c[i] = strip(put(M[(i+2)/3],best.));
		end;
		else if mod(i+1,3)=0 then do;
			c[i] = strip(put(N[(i+1)/3],best.));
		end;
		else if mod(i,3)=0 then do;
			if BigN[i/3] not in(.,0) then c[i]=strip(put(100*N[i/3]/BigN[i/3], pct.));
		end;
	end;
	array charvar _char_;
	do over charvar;
		if charvar='' then charvar='0';
	end;
run;


*blank row;
proc freq data=final noprint;
	table level1ord / out=block;
run;
data blank;
	set block end=last;
	level1ord=level1ord-0.5;
	*if last then delete;
	keep level1ord;
run;


data final;
	set final blank;
	proc sort;
	by descending level1ord descending level2ord level3ord;
run;


data final;
	set final;
	pagen=ceil(_N_/15);
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
%let width_list=26|6|5.5|7|6|5.5|7|6|5.5|7|6|5.5|7;
%put &just_list.;


data tabdat.&outname.;
	length t1-t&Tn. c1-c&trtmax. $200;
	set final;
	keep t1-t&Tn. c1-c&trtmax.;
run;


%if %sysfunc(exist(vtabdat.&outname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


%let header_list = %nrstr(@w@w@w@w@w@w@w@w毒性分级|例次|例数|发生率（%）|例次|例数|发生率（%）|例次|例数|发生率（%）|例次|例数|发生率（%）);
%put &header_list;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline; 
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods listing close;

%Mstrtrtf3(pgmname=&pgmname, pgmid=1, style=tables_8_pt); 
 
proc report data=final missing center nowd headline headskip split = '~'; 

	column  
	("@R/RTF'\ql'  系统器官分类~@w@w@w@w首选术语" t1)
    ("@R/RTF'\qc'  0.5×10@{super 6} CAR-T~cells/kg~N=&n1 @R/RTF'\brdrb\brdrs\brdrw10'" c1 c2 c3)
    ("@R/RTF'\qc'  2.0×10@{super 6} CAR-T~cells/kg~N=&n2 @R/RTF'\brdrb\brdrs\brdrw10'" c4 c5 c6)
    ("@R/RTF'\qc'  4.0×10@{super 6} CAR-T~cells/kg~N=&n3 @R/RTF'\brdrb\brdrs\brdrw10'" c7 c8 c9)
    ("@R/RTF'\qc'  合计~N=&n4 @R/RTF'\brdrb\brdrs\brdrw10'" c10 c11 c12)
	pagen ;

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
