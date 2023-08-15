

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
%let pgmname = t-14-3-5-1.sas;
%let outname = T14030501;


proc format;
	value seq 
	1='例数（缺失数）' 
	2='均数（标准差）' 
	3='中位数' 
	4='四分位数' 
	5='最小值，最大值' 
	; 
quit;
 

%let lib=ads;
%let AnaSet=SAFFL;
%let adam=adeg;


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
	table &trtVar.N*&trtVar. / out=BigN(rename=(count=bigN) drop=percent);
run;

data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2 &N3;


data &adam.;
	set ads.&adam.(where=(&AnaSet.="Y" & ANL01FL="Y" & paramcd="QTAG" & ADT<=CUTOFFDT));
	output;
	&trtVar.N=&trtmax.; 
	&trtVar.='合计';
	output;
run;


%macro means(dsin=, dsout=, screen=, dec_var=, var=, ord=); 

data dec; 
	set &dsin.; 
	dec=lengthn(scan(strip(put(&dec_var.,best.)),2,'.')); 
	keep usubjid &trtVar.N &trtVar. paramn param &dec_var. dec; 
	proc sort; 
	by &trtVar.N &trtVar. paramn param; 
run; 

proc sql noprint; 
	create table max_dec as 
	select paramn, param, max(dec) as maxx 
	from dec
	group by paramn, param; 
quit;

proc sql noprint; 
	create table dec123 as 
	select paramn, param, maxx, min(maxx,3) as raw0 , min(maxx+1,3) as raw1, min(maxx+2,3) as raw2
	from max_dec
	order by paramn, param;
quit;


data BDS; 
	set &dsin.; 
	where &screen.; 
	keep usubjid &trtVar.N &trtVar. paramn param avisitn avisit &var.; 
	proc sort; 
	by &trtVar.N &trtVar. paramn param avisitn avisit; 
run; 

proc means data=BDS noprint; 
	by &trtVar.N &trtVar. paramn param avisitn avisit;
	var &var.;
	output out=stat_&var.(drop= _type_ _freq_) n=n nmiss=nmiss mean=mean std=std q1=q1 q3=q3 median=median min=min max=max; 
run;

proc sort data=stat_&var.;
	by paramn param;
run;
data stat_&var.; 
	merge stat_&var.(in=a) dec123; 
	by paramn; 
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
	by paramn param avisitn avisit;
run;

proc transpose data=stat_&var. out=trans_&var. prefix=trt; 
	by paramn param avisitn avisit; 
	var row1-row5; 
	id &trtVar.N; 
run;

data &dsout.; 
	length ord seq 8;
	set trans_&var.; 
	ord=&ord.; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run; 

%mend; 
%means(dsin=&adam., dsout=base, screen=%str(avisitn=0),  dec_var=aval, var=base, ord=1); 
%means(dsin=&adam., dsout=aval, screen=%str(avisitn>0),  dec_var=aval, var=aval, ord=2); 
%means(dsin=&adam., dsout=chg,  screen=%str(avisitn>0),  dec_var=chg,  var=chg,  ord=3); 


data chg1; 
	set chg; 
	avisitn = avisitn + 0.1; 
	proc sort; 
	by paramn avisitn seq; 
run;

data all;
	length ord seq paramn 8 param $200 avisitn 8 avisit text $200;
	set base aval chg1;
	array charvar _char_;	
	do over charvar;
		if missing(charvar) then charvar='-';
	end;
	text=put(seq,seq.); 
	proc sort;
	by paramn param avisitn avisit seq;
run;


data all;
	set all;
	%macro ifloop;
	%do i=1 %to &trtmax.;
		if seq=1 and trt&i="-" then trt&i='0';
	%end;
	%mend;
	%ifloop;
	if not missing(avisitn);
run;


*page分页小技巧;
%macro split_page(dsin=, dsout=);
proc sql noprint;
	*分析参数个数;
	select count(distinct paramn) into :param_count separated by ''
	from &dsin.;
	*分析访视个数;
	select count(distinct avisit) into :avisit_count separated by ''
	from &dsin.;
quit;

%put &param_count;
%put &avisit_count;
*每个参数应该分的页数;
%let pages_each_param = %sysfunc(ceil(&avisit_count / 2)); %put &pages_each_param;
*应该分的总页数;
%let pages_total = %eval(&pages_each_param*&param_count);  %put &pages_total;
*每个参数占的行数;
%let rows_each_param = %eval(6 + 10*(&avisit_count.-1));   %put &rows_each_param;

data &dsout.;
	retain pages_mod 0 paramn_seq 0;
	set &dsin.;
	by paramn;
	if first.paramn then pages_mod=1;
	else pages_mod = pages_mod+1;
	if pages_mod<=15 then pagen_each_param=1;
	else if pages_mod>15 then pagen_each_param=ceil((pages_mod-15)/20+1);
	if paramn^=lag(paramn) then paramn_seq + 1;
	if paramn_seq = 1 then pagen = pagen_each_param;
	else if paramn_seq > 1 then pagen = pagen_each_param + &pages_each_param * (paramn_seq-1);
	proc sort;
	by pagen paramn param avisitn avisit seq;
run;

%mend;
%Split_page(dsin=all, dsout=final_pagen);


data final;
	length c1-c&trtmax. avisit $200;
	set final_pagen;
	format _all_;
    informat _all_;
	by pagen paramn param avisitn avisit seq;
	if mod(avisitn,1)^=0 then avisit=strip(avisit)||"较基线变化";
	if seq>1 then call missing(avisit);
/*	if not first.pagen then call missing(param);*/
	avisitn=avisitn*10;
	t1=param;
	t2=avisit;
	t3=text;
	c1=trt1;
	c2=trt2;
	c3=trt3;
	proc sort;
	by pagen paramn avisitn seq;
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
	length t1-t&Tn. c1-c%eval(&trtmax.) $200;
	set final;
	keep t1-t&Tn. c1-c%eval(&trtmax.);
run;


%if %sysfunc(exist(tabdat.&outname.)) %then %do;
	%Compare_tfl(devlib=tabdat,vallib=vtabdat,ds=&outname., var_list=%str(*));
%end;


%let header_list = 指标@n|访视@n|统计量@n|7.5mg/kg~N=&N1|15mg/kg~N=&N2|合计~N=&N3;


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
