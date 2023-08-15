
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
%let pgmname = t-14-1-1-1.sas;
%let outname = T14010101;


proc format;
	value ordc 
	1="筛选期受试者数"
	2="筛选失败受试者数"
	3="筛选失败原因"
	4="入组受试者数"
	5="仍在治疗中"
	6="治疗结束"
	7="仍在随访中"
	8="研究结束"
	;
	value seq3c
	1="不符合入选标准和/或符合排除标准"
	2="受试者撤回知情"
	99="其他"
	;
	value seq4c
	1="队列1：复发/难治性弥漫大B细胞淋巴瘤患者"
	2="队列2：复发/难治性外周T细胞淋巴瘤"
	3="队列3：复发/难治性经典霍奇金淋巴瘤"
	4="队列4：复发/难治性套细胞淋巴瘤"
	5="队列5：复发/难治性滤泡性淋巴瘤或边缘区淋巴瘤"
	;
	value seq6c
	1="因不良事件退出研究（死亡和疾病进展除外）"
	2="严重违背方案"
	3="失访"
	4="受试者自行撤回知情同意"
	5="研究者认为受试者需要退出"
	6="死亡"
	7="接受其他抗肿瘤治疗"
	8="疾病进展（疾病进展导致的死亡除外）"
	9="随访至1年"
	10="申办方终止临床试验"
	99="其他"
	;
	value seq8c
	1="因不良事件退出研究（死亡和疾病进展除外）"
	2="严重违背方案"
	3="失访"
	4="受试者自行撤回知情同意"
	5="研究者认为受试者需要退出"
	6="死亡"
	7="接受其他抗肿瘤治疗"
	8="疾病进展（疾病进展导致的死亡除外）"
	9="随访至1年"
	10="申办方终止临床试验"
	99="其他"
	;
	invalue seq
	"不符合入选标准和/或符合排除标准"=1
	"受试者撤回知情"=2	
	"队列1：复发/难治性弥漫大B细胞淋巴瘤患者"=1
	"队列2：复发/难治性外周T细胞淋巴瘤"=2
	"队列3：复发/难治性经典霍奇金淋巴瘤"=3
	"队列4：复发/难治性套细胞淋巴瘤"=4
	"队列5：复发/难治性滤泡性淋巴瘤或边缘区淋巴瘤"=5
	"因不良事件退出研究（死亡和疾病进展除外）"=1
	"严重违背方案"=2
	"失访"=3
	"受试者自行撤回知情同意"=4
	"研究者认为受试者需要退出"=5
	"死亡"=6
	"接受其他抗肿瘤治疗"=7
	"疾病进展（疾病进展导致的死亡除外）"=8
	"随访至1年"=9
	"申办方终止临床试验"=10
	other=99
	;
quit;


%let lib=ads;
%let AnaSet=ENRLFL;
%let adam=adsl;

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


*筛选期受试者N_SCREEN与筛选失败受试者;
proc sql noprint;
	*筛选期受试者=N_SCREEN;
	select count(distinct usubjid) into :N_screen separated by '' from ads.adsl;
	*筛选期受试者数;
	create table trans_1_0 as 
	select 1 as ord, 0 as seq, count(distinct usubjid) as n&trtmax.
	from ads.adsl
	group by ord,seq
	order by ord,seq
	;
	*筛选失败受试者数;
	create table trans_2_0 as 
	select 2 as ord, 0 as seq, count(distinct usubjid) as n&trtmax.
	from ads.adsl where ARMNRS="筛选失败"
	group by ord,seq
	order by ord,seq
	;
	*筛选失败原因分类;
	create table trans_3_seq as 
	select 3 as ord, input(SFREAS, seq.) as seq, count(distinct usubjid) as n&trtmax.
	from ads.adsl where ARMNRS="筛选失败" and SFREAS is not missing
	group by ord,seq
	order by ord,seq
	;
	*入组受试者=N_ENRL;
	select count(distinct usubjid) into :N_ENRL1 from ads.adsl where ENRLFL="Y" and trt01pn=1;
	select count(distinct usubjid) into :N_ENRL2 from ads.adsl where ENRLFL="Y" and trt01pn=2;
	select count(distinct usubjid) into :N_ENRL3 from ads.adsl where ENRLFL="Y" and trt01pn=3;
	select count(distinct usubjid) into :N_ENRL4 from ads.adsl where ENRLFL="Y";
quit;
%put &N_screen;


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
	table &trtVar.N*&trtVar. / out=BigN(rename=(count=bigN) drop=percent);
run;
data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2 &N3 &N4;


*design the dummy matrix dataset;
data matrix;
	do &trtVar.N=1 to &trtmax.;
		do ord=1 to 8;

			if ord=3 then do;
				do seq=0 to 2,99;
					output;
				end;
			end;
			
			else if ord=4 then do;
				do seq=0 to 5;
					output;
				end;
			end;

			else if ord in(6 8) then do;
				do seq=0 to 10,99;
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
	length t1 $200;
	set dummy;
	if seq=0 then t1=put(ord,ordc.);
	if ord=3 & seq>0 then t1="    "||strip(put(seq,seq3c.));
	if ord=4 & seq>0 then t1="    "||strip(put(seq,seq4c.));
	if ord in(6 8) & seq>0 then t1="    "||strip(put(seq,seq6c.));
run;


%macro CountByCond(cond=, ord=,seq=);
proc sql noprint;
	create table ord&ord as 
	select &TrtVar.N, &ord as ord, &seq as seq, count(distinct usubjid) as n
	from adsl where &cond.
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
%CountByCond(cond=%str(ENRLFL="Y"), ord=4, seq=0);
%CountByCond(cond=%str( prxmatch("/继续|进行/",EOTSTT) ), ord=5, seq=0);
%CountByCond(cond=%str( prxmatch("/提前|终止|退出/",EOTSTT) ), ord=6, seq=0);
%CountByCond(cond=%str( prxmatch("/继续|进行/",EOSSTT) ), ord=7, seq=0);
%CountByCond(cond=%str( prxmatch("/提前|终止|退出/",EOSSTT) ), ord=8, seq=0);


%macro CountByCatVar(CatVar=, ORD=);
proc sql noprint;
	create table seq&ord. as 
	select &TrtVar.N,&ord. as ord, input(&CatVar., seq.) as seq, count(subjid) as n
	from adsl where &CatVar. is not missing
	group by ord,seq,&TrtVar.N
	order by ord,seq,&TrtVar.N
	;
quit;
proc transpose data=seq&ord out=trans_&ord._seq(drop=_name_ ) prefix=n;
	by ord seq;
	var n;
	id &TrtVar.N;
run;
%mend;
%CountByCatVar(CatVar=COHORT,  ORD=4);
%CountByCatVar(CatVar=DCTREAS, ORD=6);
%CountByCatVar(CatVar=DCSREAS, ORD=8);


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
	*筛选期受试者;
	if ord=1 then c&trtmax.=strip(put(n&trtmax,best.));
	*筛选失败受试者;
	else if ord=2 then c&trtmax.=strip(put(n&trtmax,best.))||" ("||strip(put(100*N&trtmax./&N_screen., pct.))||")";
	else if ord=3 and seq>0 then c&trtmax.=strip(put(n&trtmax,best.))||" ("||strip(put(100*N&trtmax./&N_screen., pct.))||")";
	*入组人群;
	%macro trtloop;
	%do i=1 %to &trtmax.;
		c&i=strip(put(n&i,best.))||" ("||strip(put(100*n&i/&N_screen., pct.))||")";
	%end;
	%mend;
	if ord=4 then do;
		%trtloop;
	end;
	*其他人群及其百分比;
	%macro trtloop2;
	%do i=1 %to &trtmax.;
		c&i=strip(put(n&i,best.))||" ("||strip(put(100*n&i/&&N_ENRL&i., pct.))||")";
	%end;
	%mend;
	if 5<=ord then do;
		%trtloop2;
	end;
	array charvar _char_;
	do over charvar;
		if charvar='0 (0.0)' then charvar='0';
	end;
	if ord=4 and seq=0 then do;
		c1=scan(c1,1,'()');
		c2=scan(c2,1,'()');
		c3=scan(c3,1,'()');
	end;
	run;
	proc sort;
	by ord seq;
run;


data final;
	length block ord seq 8 t1 c1-c%eval(&trtmax.) $200;
	set final;
	if ord=1 then block=1;
	else if 2<=ord<=3 then block=2;
	else if ord=4 then block=3;
	else if 5<=ord<=6 then block=4;
	else if 7<=ord<=8 then block=5;
	keep block ord seq t1 c1-c%eval(&trtmax.);
	proc sort;
	by block ord seq;
run;


*空行算法;
proc freq data=final noprint;
	table block / out=block;
run;
data blank;
	set block end=last;
	block=block+0.5;
	if last then delete;
	keep block;
run;


data final;
	set final blank;
	if block<4 then pagen=1;
	else pagen=2;
	proc sort;
	by block ord seq;
run;


*output qc dataset; 
data tabdat.&outname.; 
	length t1 c1-c&trtmax. $200; 
	set final; 
	keep t1 c1-c&trtmax.; 
run;


%if %sysfunc(exist(vtabdat.&outname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


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
%let width_list=36|16|16|16|16;
%put &just_list.;


%let header_list = 受试者分布|7.5mg/kg~N=&N1~n(%)|10mg/kg~N=&N2~n(%)|15mg/kg~N=&N3~n(%)|合计~N=&N_screen~n(%);


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline; 
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods listing close;


%Mstrtrtf3(pgmname=&pgmname, pgmid=1, style=tables_7_pt); 


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

	compute before _page_ ;
		line &line.;
	endcomp;

	%footloop;

run; 
ods _all_ close;
ods listing; 


%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
