
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
%let pgmname = t-14-1-2-4.sas;


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
	invalue seq
	'3期'=1
	'4期'=2 
	'5期'=3
	'是'=1
	'否'=2 
	'<=ULN'=1
	'>ULN'=2
	'>=80'=1
	'<80'=2
	'<5%'=1
	'5-20%'=2
	'>20%'=3
	'NORMAL'=1
	'<1LLN'=2
	'>1ULN'=3
	'<30mg/g'    = 1
	'30-300mg/g' = 2
	'>300mg/g'   = 3
	;
	value ordc
	1='估算肾小球滤过率（mL/min/1.73m^2）'
	2='慢性肾病分期（n%）'
	3='慢性肾病诊断病程（月）'
	4='是否接受过透析(包括腹膜透析和血液透析)（n%）'
	5='C-反应蛋白（mg/dL）'
	6='超敏C-反应蛋白（mg/L）'
	7='C-反应蛋白/超敏C-反应蛋白分组（n%）'
	8='血红蛋白（g/L）'
	9='血红蛋白分组（n%）'
	10='白介素-6'
	11='血清铁（umol/L）'
	12='铁蛋白（ng/mL）'
	13='总铁结合力（umol/L）'
	14='转铁蛋白（g/L）'
	15='转铁蛋白饱和度（%）'
	16='转铁蛋白饱和度分组（n%）'
	16.1='血脂'
	17='    总胆固醇（mmol/L）'
	18='    低密度脂蛋白（mmol/L）'
	19='    高密度脂蛋白（mmol/L）'
	20='    甘油三酯（mmol/L）'
	20.1='肝功能'
	21='    碱性磷酸酶（U/L）'
	22='    丙氨酸转氨酶（U/L）'
	23='    天冬氨酸转氨酶（U/L）'
	24='    总胆红素（umol/L）'
	25='    直接胆红素（umol/L）'
	26='甲状旁腺素全段（pg/mL）'
	27='甲状旁腺激素（pmol/L）'
	28='甲状旁腺素全段/甲状旁腺激素分组（n%）'
	29='尿白蛋白/肌酐比值（mg/g）'
	30='尿白蛋白/肌酐比值分组（n%）'
	;
	value seqc
	1='例数（缺失数）' 
	2='均数（标准差）' 
	3='中位数' 
	4='四分位数' 
	5='最小值，最大值' 
	;
	value seq2c
	1='3期'
	2='4期'
	3='5期'
	;
	value seq4c
	1='是'
	2='否'
	;
	value seq7c
	1='≤正常值上限'
	2='>正常值上限'
	;
	value seq9c
	1='≥80 g/L'
	2='<80 g/L'
	;
	value seq16c
	1='<5%'
	2='5-20%'
	3='>20%'
	;
	value seq28c
	1='正常'
	2='<正常值上限'
	3='>正常值上限'
	;
	value seq30c
	1='≤正常值上限'
	2='>正常值上限'
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
	&trtVar="合计";
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
		do ord=1 to 30;
			if ord in (1 3 5 6 8 10 11 12 13 14 15 17 18 19 20 21 22 23 24 25 26 27 29 ) then do;
				do seq=1 to 5;
					output;
				end;
			end;
			else if ord in (4 7 9 30 )  then do;
				do seq=1 to 2;
					output;
				end;
			end;
			else if ord in (2 16 28 )  then do;
				do seq=1 to 3;
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

data adsl;
	set adsl;
	eGFR=input(GFR,??best.);
	CRPGR1=coalescec(CRPGR1,HSCRPG1);
	CRPGR1N=coalesce(CRPGR1N,HSCRPG1N);
	PTHWGR1=coalescec(PTHWGR1,PTHRPG1);
	PTHWGR1N=coalesce(PTHWGR1N,PTHRPG1N);
	proc sort;
	by usubjid &trtVar.N &trtVar.;
run;
proc transpose data=adsl out=adsl_param(rename=(_name_=paramcd _label_=param col1=base));
	by usubjid &trtVar.N &trtVar.;
	var EGFR PATHDURM CRPBL HSCRPBL HGBBL IL6SRBL 
		IRONBL FERRBL IBCTBL TFERBL TSATBL 
		CHOLBL LDLBL HDLBL TRIGBL
		ALPBL ALTBL ASTBL BILIBL BILDIRBL
		PTHWBL PTHRPBL ACRBL;
run;

data adsl_param;
	set adsl_param;
	if paramcd="EGFR" then paramn=1;
	if paramcd="PATHDURM" then paramn=3;
	if paramcd="CRPBL" then paramn=5;
	if paramcd="HSCRPBL" then paramn=6;
	if paramcd="HGBBL" then paramn=8;
	if paramcd="IL6SRBL" then paramn=10;
	if paramcd="IRONBL" then paramn=11;
	if paramcd="FERRBL" then paramn=12;
	if paramcd="IBCTBL" then paramn=13;
	if paramcd="TFERBL" then paramn=14;
	if paramcd="TSATBL" then paramn=15;
	*血脂;
	if paramcd="CHOLBL" then paramn=17;
	if paramcd="LDLBL" then paramn=18;
	if paramcd="HDLBL" then paramn=19;
	if paramcd="TRIGBL" then paramn=20;
	*肝功能;
	if paramcd="ALPBL" then paramn=21;
	if paramcd="ALTBL" then paramn=22;
	if paramcd="ASTBL" then paramn=23;
	if paramcd="BILIBL" then paramn=24;
	if paramcd="BILDIRBL" then paramn=25;

	if paramcd="PTHWBL" then paramn=26;
	if paramcd="PTHRPBL" then paramn=27;
	if paramcd="ACRBL" then paramn=29;
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
	create table ord&ord. as 
	select &TrtVar.N,&ord. as ord, input(&CATVAR., seq.) as seq, count(subjid) as n
	from adsl where &CATVAR. is not missing
	group by ord,seq,&TrtVar.N
	order by ord,seq,&TrtVar.N
	;
quit;
proc transpose data=ord&ord out=trans_ord&ord(drop=_name_ ) prefix=n;
	by ord seq;
	var n;
	id &TrtVar.N;
run;
%mend;
%CountByCatVar(CATVAR=CKDSTAG,ORD=2);
%CountByCatVar(CATVAR=DIAYN,  ORD=4);
%CountByCatVar(CATVAR=CRPGR1, ORD=7);
%CountByCatVar(CATVAR=HGBGR1, ORD=9);
%CountByCatVar(CATVAR=TSATGR1,ORD=16);
%CountByCatVar(CATVAR=PTHWGR1,ORD=28);
%CountByCatVar(CATVAR=ACRGR1, ORD=30);


data trans_header;
	do ord=16.1, 20.1;
		output;
	end;
run;

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
	if ord in(1 3 5 6 8 10 11 12 13 14 15 17 18 19 20 21 22 23 24 25 26 27 29) then do;
		t2=put(seq,seqc.);
	end;
	else do;
		if ord=2 then t2=strip(put(seq,seq2c.));
		if ord=4 then t2=strip(put(seq,seq4c.));
		if ord=7 then t2=strip(put(seq,seq7c.));
		if ord=9 then t2=strip(put(seq,seq9c.));
		if ord=16 then t2=strip(put(seq,seq16c.));
		if ord=28 then t2=strip(put(seq,seq28c.));
		if ord=30 then t2=strip(put(seq,seq30c.));
	end;
	%macro trtloop;
	%do i=1 %to &trtmax.;
		c&i=strip(put(n&i,best.))||" ("||strip(put(100*n&i/BigN&i., pct.))||")";
	%end;
	%mend;
	if ord not in (1 3 5 6 8 10 11 12 13 14 15 17 18 19 20 21 22 23 24 25 26 27 29 16.1 20.1) then do;
		%trtloop;
	end;
	array charvar _char_;
	do over charvar;
		if charvar='0 (0.0)' then charvar='0';
	end;
	if ord in (1 3 5 6 8 10 11 12 13 14 15 17 18 19 20 21 22 23 24 25 26 27 29 ) then do;
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


data tabdat.&outputname.;
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
	if ord in (16.5 16.6 20.5 20.6) then delete;
	proc sort;
	by ord seq;
run;

data final;
	set final;
	pagen=ceil(_N_/22);
run;


%if %sysfunc(exist(vtabdat.&outputname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outputname., var_list=%str(*));
%end;


%let header_list = 指标~@w|@w|低起始剂量组~N=&N1|标准起始剂量组~N=&N2|合计~N=&N3;

options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline; 
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods listing close;

%Mstrtrtf3(pgmname=&pgmname, pgmid=&tabord., style=tables_8_pt); 

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

	%macro footloop;	
	%if "&foot1." eq " " %then %do;
		compute after _page_ ;
			line &line.;
		endcomp; 
	%end;
	%else %do;
		compute after _page_ / style=[asis=on just=l fontweight=light protectspecialchars=off pretext="\brdrt\brdrs\w20"];

			%let j=0;
			%let j=%eval(&j+1);
			%do %while ( "&&foot&j" ne " ");

			line @1 "&&foot&j.";

			%let j=%eval(&j+1);	
			%end;

		endcomp; 
	%end;
	%mend;
	%footloop;

run; 
ods _all_ close;
ods listing; 


%* %preview(pgmname=%str(&pgmname.), pgmid=1, part=2);

%mend;

%t_baseline(lib=ads, AnaSet=FASFL,tabord=1,outputname=T14010204);
%t_baseline(lib=ads, AnaSet=PPROTFL,tabord=2,outputname=T14010205);
%t_baseline(lib=ads, AnaSet=SAFFL,tabord=3,outputname=T14010206);
