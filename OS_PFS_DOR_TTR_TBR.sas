/*==========================================================================================*
Sponsor Name        : 亘喜生物科技（上海）有限公司
Study   ID          : GC012F-321
Project Name        : GC012F 注射液治疗适合移植的高危型新诊断多发性骨髓瘤患者的临床研究
Program Name        : t-14-2-1-3.sas
Program Path        : E:\Project\GC012F-321\csr\dev\pg\tables
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output T-14-02-01-03.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\GC012F-321\csr\dev\output\tables\T-14-02-01-03.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2023-03-09     weineng.zhou              Creation
 
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
%let pgmname = t-14-2-1-3.sas;
%let outname = T14020103;


%macro SumTable(lib=ads, ADaM=adtte, AnaSet=FASFL, cond=%str(paramcd="PFS"), tabord=1, outputname=T14020103);

/*

%let lib=ads;
%let adam=adtte;
%let AnaSet=FASFL;
%let cond=%str(paramcd="PFS");
%let tabord=1;
%let outputname=T14020103;

*/


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
	1="合计，n(%)"
	2="无进展生存期"
	3='第6个月'
	4='第12个月'
	5='第24个月'
	;
    value seq1c
    1="事件数，n(%)"
	2="    首次疾病进展"
	3="    死亡"
	4="删失数，n(%)"
	;
	value seq2c
	1="25分位数(95% CI)"
	2="中位数(95% CI)"
	3="75分位数(95% CI)"
	4="最小值，最大值"
	;
	value seqc
	1='风险人数'
	2='累计发生率（95% CI）'
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
	if not missing(&trtVar.N);
	if last then call symputx('合计', _N_);
	output;
	&trtVar="合计";
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
%put &N1 &N2 ;


*design the dummy matrix dataset;
data matrix;
	do &trtVar.N=1 to &trtmax.;
		do ord=1 to 5;

			if ord=1 then do;
				do seq=0 to 4;
					output;
				end;
			end;

			else if ord in(2 ) then do;
				do seq=0 to 4;
					output;
				end;
			end;

			else if ord in(3 4 5 ) then do;
				do seq=0 to 2;
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
	if ord=1 & seq>0 then t1="    "||put(seq,seq1c.);
	if ord=2 & seq>0 then t1=put(seq,seq2c.);
	if ord in(3 4 5) & seq>0 then t1="    "||put(seq,seqc.);
	%macro nloop;
	%do i=1 %to &trtmax.;
		N&i=0;
	%end;
	%mend;
	%nloop;
run;


data output_&adam.;
	set &lib..&adam.(where=(&AnaSet.="Y" and &cond. ));
	if not missing(&trtVar.N);
	output;
	&trtVar="合计";
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
%CountByCond(dsin=output_&adam., cond=%str(cnsr in(0 1)), ord=1, seq=0);
%CountByCond(dsin=output_&adam., cond=%str(cnsr=0), ord=1, seq=1);
%CountByCond(dsin=output_&adam., cond=%str(cnsr=0 and prxmatch("/疾病进展/i",EVNTDESC)), ord=1, seq=2);
%CountByCond(dsin=output_&adam., cond=%str(cnsr=0 and prxmatch("/死亡/i",EVNTDESC)), ord=1, seq=3);
%CountByCond(dsin=output_&adam., cond=%str(cnsr=1 ), ord=1, seq=4);


*疗效指标;
ods output ProductLimitEstimates=ProductLimitEstimates Means = Means Quartiles = Quartiles HomTests=HomTests ;
proc lifetest data = output_&adam. alpha=0.05 ;
	time AVAL*CNSR(1);
	strata &TrtVar.N &TrtVar.;
	survival out=_survival conftype=LOGLOG;
run;


*点估计与区间估计;
%macro point_CI(dsin=,dsout=,var_list=);

%if &dsout= %then %do;
	%let dsout=&dsin.;
%end;

proc format;
    value point_ci
	.="NE"
	low-<0.001 ='<0.001'
	999.999< -high='>999.999'
	;
quit;

data &dsout.;
	set &dsin.;
	array point_CI &var_list.;
    array charvar $20 point lower upper;
    do i = 1 to dim(point_CI);
        if 0.001<= point_CI[i] <= 999.999 then charvar[i] = strip(put(point_CI[i], 8.2));
        else charvar[i] = strip(put(point_CI[i], point_ci.));
    end;
	C = cat(strip(point), " (", strip(lower), ", ", strip(upper), ")");

run;
%mend;
%point_CI(dsin=Quartiles,dsout=Quartiles,var_list=ESTIMATE LOWERLIMIT UPPERLIMIT);


data Quartiles;
	set Quartiles;
	proc sort;
	by percent;
run;
proc transpose data=Quartiles prefix=c out=trans_Quartiles(drop=_:);
	by percent;
	var c;
	id &trtvar.N;
run;
data trans_Quartiles;
	length ord seq 8;
	set trans_Quartiles;
	ord=2;
	if percent=25 then seq=1;
	if percent=50 then seq=2;
	if percent=75 then seq=3;
run;

proc format;
	value p_value
	.="NE"
	low-<0.0001 ='<0.0001'
	0.9999<-high='>0.9999'
	;
quit;


*估计的可信度P值;
/*data trans_pvalue;*/
/*	set HomTests;*/
/*	if TEST="对数秩";*/
/*	ord=3;*/
/*	seq=0;*/
/*	if 0.0001<=PROBCHISQ<=0.9999 then c1=strip(put(PROBCHISQ,pvalue6.4));*/
/*	else c1=strip(put(PROBCHISQ,p_value.));*/
/*	proc sort;*/
/*	by ord seq;*/
/*run;*/


*min, max;
proc sort data=output_&adam.;
	by &TrtVar.N &TrtVar.; 
run;

proc means data=output_&adam. noprint;
	by &TrtVar.n &TrtVar.;
	var aval;
	output out=minmax min=min max=max;
run;

data minmax;
	set minmax;
	c = catx(", ",put(min,8.2),put(max,8.2));
	ord=2;
	seq=4;
	proc sort;
	by ord seq;
run;

proc transpose data=minmax prefix=c out=trans_minmax(drop=_:);
	by ord seq;
	var c;
	id &trtvar.N;
run;


*CIF;
ods graphics on;
ods output ProductLimitEstimates=_ProductLimitEstimates;
proc lifetest data=output_&adam. method=KM timelist=6 12 24 atrisk ;
	time aval*cnsr(1);
	strata &TrtVar.N &TrtVar.;
	survival out=_survival conftype=LOGLOG;
run;


data atrisk;
	set _ProductLimitEstimates;
	if NUMBERATRISK^=. then C=strip(put(NUMBERATRISK,best.));
	else if missing(NUMBERATRISK) then C="NE";
	if &TrtVar.N=1 then do;
		ord=_N_+2;
	end;
	else if &TrtVar.N=2 then do;
		ord=_N_-1;
	end;
	else if &TrtVar.N=3 then do;
		ord=_N_-4;
	end;
	else if &TrtVar.N=4 then do;
		ord=_N_-7;
	end;
	seq=1;
	proc sort;
	by ord seq;
run;


proc transpose data=atrisk prefix=c out=trans_atrisk;
	by ord seq;
	var c;
	id &TrtVar.N;
run;


%if &outputname ne T14020105 %then %do;

proc lifetest data=output_&adam. method=KM outcif=_OUTCIF timelist=6 12 24 reduceout;
	time aval*cnsr(1) /eventcode=0;
	strata &TrtVar.N &TrtVar.;
run;

data CIF;
	set _OUTCIF;
	if cmiss(CIF,CIF_LCL,CIF_UCL)=0 then C=cats(put(CIF*100,10.2),'(',put(CIF_LCL*100,10.2),",",put(CIF_UCL*100,10.2),')');
	else if CIF=0 then C="0(NE,NE)";
	else C="NE(NE,NE)";
	C=tranwrd(C,'(',' (');
	C=tranwrd(C,',',', ');
	if &TrtVar.N=1 then do;
		ord=_N_+2;
	end;
	else if &TrtVar.N=2 then do;
		ord=_N_-1;
	end;
	else if &TrtVar.N=3 then do;
		ord=_N_-4;
	end;
	else if &TrtVar.N=4 then do;
		ord=_N_-7;
	end;
	seq=2;
	proc sort;
	by ord seq;
run;

proc transpose data=CIF prefix=c out=trans_CIF;
	by ord seq;
	var c;
	id &TrtVar.N;
run;
%end;


%if &outputname=T14020105 %then %do;

data trans_cif;
	do ord=3 to 5;
		seq=2; 
		c1="NE (NE, NE)";
		c2="NE (NE, NE)";
		c3="NE (NE, NE)";
		c4="NE (NE, NE)";
		output;
	end;
run;

%end;


data all_trans;
	length ord seq 8 c1-c&trtmax. $200; 
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
	*per shell revise;
	if ord=1 and seq in (2 3) then delete;
	if ord=2 and seq in (0 ) then delete;
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
%let width_list=36|16|16|16|16;
%put &just_list.;


data tabdat.&outputname.;
	length t1-t&Tn. c1-c%eval(&trtmax.) $200;
	set final;
	keep t1-t&Tn. c1-c%eval(&trtmax.);
run;


%if %sysfunc(exist(vtabdat.&outputname.)) %then %do;
	%compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outputname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline; 
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods listing close;


%let header_list = @w@n|1×10@{super 5}/kg组~N=&N1|2×10@{super 5}/kg组~N=&N2|3×10@{super 5}/kg组~N=&N3|合计~N=&N4;


%Mstrtrtf3(pgmname=&pgmname, pgmid=&tabord., style=tables_8_pt); 


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
		line &line.;
	endcomp;

	%footloop;

run; 

ods _all_ close;
ods listing;

%* %preview(pgmname=%str(&pgmname.), pgmid=&tabord., part=2);

%mend;

%SumTable(lib=ads, ADaM=adtte, AnaSet=FASFL, cond=%str(paramcd="PFS"), tabord=1, outputname=T14020103);
%SumTable(lib=ads, ADaM=adtte, AnaSet=FASFL, cond=%str(paramcd="DOR"),  tabord=2, outputname=T14020104);
%SumTable(lib=ads, ADaM=adtte, AnaSet=FASFL, cond=%str(paramcd="OS"), tabord=3, outputname=T14020105);
%SumTable(lib=ads, ADaM=adtte, AnaSet=FASFL, cond=%str(paramcd="TTR"), tabord=4, outputname=T14020106);
%SumTable(lib=ads, ADaM=adtte, AnaSet=FASFL, cond=%str(paramcd="TBR"), tabord=5, outputname=T14020107);
