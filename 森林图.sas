
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
%let pgmname = f-14-2-1-11.sas;
%let outname = F14020111;


%let lib   = ads;
%let AnaSet= PPROTFL;
%let adam  = adlb;

%let trt1=低起始剂量组;
%let trt2=标准起始剂量组;

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
	value seqc
	1="例数（缺失数）"
	2="均数（标准差）"
	3="标准误"
	4="中位数"
	5="最小值，最大值"
	;
	value seq2c
	1="最小二乘均值"
	2="95% CI"
	3="组间差值"
	4="95% CI"
	5="P值[3]"
	;
	value avisit
	0 = "基线[1]"
	2 = "第2周"
	4 = "第4周"
	6 = "第6周"
	8 = "第8周"
	12 = "第12周"
	16 = "第16周"
	99 = "第12-16周均值"
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
	CKDSTAGN=input(compress(CKDSTAG,'','kd'),??best.);
	if not missing(CKDSTAGN) then CKDSTAGN=CKDSTAGN-2;
	if CKDDMFL="Y" then CKDDMFLN=1;
	else if CKDDMFL="N" then CKDDMFLN=2;
	if CKDCVFL="Y" then CKDCVFLN=1;
	else if CKDCVFL="N" then CKDCVFLN=2;
	output;
	*&trtVar.N=&trtmax.;
	*&trtVar="Total";
	*output;
run;


data &adam.;
	set ads.&adam.(where=(&AnaSet.="Y" & ANL01FL="Y" & paramcd="HGB" ));
	if AVISITN in(0 2 4 6 8 12 16);
	output;
	*&trtVar.N=&trtmax.; 
	*&trtVar.='合计';
	*output;
	keep usubjid &trtVar.N &trtVar. paramn param avisitn avisit base aval chg;
	proc sort; 
	by usubjid paramn param; 
run;


*亚组变量;
data temp;
	set &adam.;
run;
proc sql noprint;
	create table &adam. as 
	select a.*, b.CKDSTAGN, b.TSATGR2N, b.CKDDMFLN, b.CKDCVFLN, b.CRPGR1N, b.ACRGR1N, b.IL6GR1N
	from temp a left join adsl b on a.usubjid=b.usubjid
	order by usubjid, paramn, param
;
quit;



%macro means_subgrp(dsin=, dsout=, screen=, dec_var=, var=, ord=, subgrp=, grp=); 

/*

%let dsin=adlb;
%let dsout=chg_TSAT;
%let screen=%str(avisitn>0);
%let dec_var=chg;
%let var=chg;
%let ord=3;
%let subgrp=TSATBL;

*/


* calculate BigN;
proc freq data=adsl noprint;
	where not missing(&subgrp.N);
	table &subgrp.N*&trtVar.N*&trtVar. / out=BigN(rename=(count=bigN) drop=percent);
run;

data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2 ;

data dec; 
	set &dsin.; 
	dec=lengthn(scan(strip(put(&dec_var.,best.)),2,'.')); 
	keep usubjid &subgrp.N &trtVar.N &trtVar. paramn param &dec_var. dec; 
	proc sort; 
	by &subgrp.N &trtVar.N &trtVar. paramn param; 
run;

proc sql noprint; 
	create table max_dec as 
	select paramn, param, max(dec) as maxx 
	from dec group by paramn, param; 
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
	keep usubjid &subgrp.N &trtVar.N &trtVar. paramn param avisitn avisit &var.; 
	proc sort; 
	by &subgrp.N &trtVar.N &trtVar. paramn param avisitn avisit; 
run; 

proc means data=BDS noprint; 
	by &subgrp.N &trtVar.N &trtVar. paramn param avisitn avisit;
	var &var.;
	output out=stat_&var.(drop= _type_ _freq_) n=n nmiss=nmiss mean=mean stddev=std stderr=se q1=q1 q3=q3 median=median min=min max=max; 
run;

proc sort data=stat_&var.;
	by paramn param;
run;
data stat_&var.; 
	merge stat_&var. dec123; 
	by paramn; 
	proc sort;
	by &subgrp.N &trtVar.N;
run;

proc sort data=BigN; by &subgrp.N &trtVar.N;run;
data stat_&var.;
	merge stat_&var.(in=a) BigN(in=b);
	by &subgrp.N &trtVar.N;
	if a and b;
run;

data stat_&var.;
	length row1-row5 $100;
	set stat_&var.; 
	row1=strip(put(n,best.))||" ("||strip(put(BigN-n,best.))||")"; 	
	if cmiss(mean,std)=0 then row2=strip(putn(round(mean,10**((-1)*raw1)), cats(8,'.',raw1)))||" ("||strip(putn(round(std,10**((-1)*raw2)),cats(8,'.',raw2)))||")"; 
	else if mean^=. and std=. then row2=strip(putn(round(mean,10**((-1)*raw1)), cats(8,'.',raw1)))||" (-)"; 
	else if cmiss(mean,std)=2 then row2="-"; 
	if se ne . then row3=strip(putn(round(se,10**((-1)*raw2)),cats(8,'.',raw2)));
	else row3="-";
	if median ne . then row4=strip(putn(round(median,10**((-1)*raw1)),cats(8,'.',raw1)));
/*	if cmiss(Q1,Q3)=0 then row4=strip(putn(round(Q1,10**((-1)*raw0)), cats(8,'.',raw0)))||", "||strip(putn(round(q3,10**((-1)*raw0)), cats(8,'.',raw0))); */
/*	else row4="-"; */
	if min^=. then row5=strip(putn(round(min,10**((-1)*raw0)), cats(8,'.',raw0)))||", "||strip(putn(round(max,10**((-1)*raw0)), cats(8,'.',raw0))); 
	else if min=. then row5="-"; 
	GROUPN = &subgrp.N*10+&trtVar.N;
	proc sort;
	by paramn param avisitn avisit;
run;

proc transpose data=stat_&var. out=means_&var. prefix=trt; 
	by paramn param avisitn avisit; 
	var row1-row5; 
	id GROUPN; 
run;

data &dsout.; 
	length grp ord seq 8;
	set means_&var.; 
	grp=&grp.;
	ord=&ord.; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run; 

%mend; 
%means_subgrp(dsin=&adam., dsout=base_TSAT,   screen=%str(avisitn=0),  dec_var=base, var=base,ord=1, subgrp=TSATGR2,grp=1); 
%means_subgrp(dsin=&adam., dsout=aval_TSAT,   screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=TSATGR2,grp=1); 
%means_subgrp(dsin=&adam., dsout=chg_TSAT,    screen=%str(avisitn>0),  dec_var=chg, var=chg,ord=3, subgrp=TSATGR2,grp=1); 

%means_subgrp(dsin=&adam., dsout=base_CKDSTAG, screen=%str(avisitn=0),  dec_var=base, var=base,ord=1, subgrp=CKDSTAG,grp=2); 
%means_subgrp(dsin=&adam., dsout=aval_CKDSTAG, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=CKDSTAG,grp=2); 
%means_subgrp(dsin=&adam., dsout=chg_CKDSTAG, screen=%str(avisitn>0),  dec_var=chg, var=chg,ord=3, subgrp=CKDSTAG,grp=2); 

%means_subgrp(dsin=&adam., dsout=base_ACRGR1,  screen=%str(avisitn=0),  dec_var=base, var=base,ord=1, subgrp=ACRGR1,grp=3);
%means_subgrp(dsin=&adam., dsout=aval_ACRGR1,  screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=ACRGR1,grp=3); 
%means_subgrp(dsin=&adam., dsout=chg_ACRGR1,  screen=%str(avisitn>0),  dec_var=chg, var=chg,ord=3, subgrp=ACRGR1,grp=3); 

%means_subgrp(dsin=&adam., dsout=base_CKDDM,   screen=%str(avisitn=0),  dec_var=base, var=base,ord=1, subgrp=CKDDMFL,grp=4); 
%means_subgrp(dsin=&adam., dsout=aval_CKDDM,   screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=CKDDMFL,grp=4); 
%means_subgrp(dsin=&adam., dsout=chg_CKDDM,   screen=%str(avisitn>0),  dec_var=chg, var=chg,ord=3, subgrp=CKDDMFL,grp=4); 

%means_subgrp(dsin=&adam., dsout=base_CKDCV,   screen=%str(avisitn=0),  dec_var=base, var=base,ord=1, subgrp=CKDCVFL,grp=5);
%means_subgrp(dsin=&adam., dsout=aval_CKDCV,   screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=CKDCVFL,grp=5); 
%means_subgrp(dsin=&adam., dsout=chg_CKDCV,   screen=%str(avisitn>0),  dec_var=chg, var=chg,ord=3, subgrp=CKDCVFL,grp=5); 

%means_subgrp(dsin=&adam., dsout=base_CRPGR1,  screen=%str(avisitn=0),  dec_var=base, var=base, ord=1, subgrp=CRPGR1,grp=6); 
%means_subgrp(dsin=&adam., dsout=aval_CRPGR1,  screen=%str(avisitn>0),  dec_var=aval, var=aval, ord=2, subgrp=CRPGR1,grp=6); 
%means_subgrp(dsin=&adam., dsout=chg_CRPGR1,  screen=%str(avisitn>0),  dec_var=chg, var=chg, ord=3, subgrp=CRPGR1,grp=6); 

%means_subgrp(dsin=&adam., dsout=base_CRPGR1,  screen=%str(avisitn=0),  dec_var=base, var=base, ord=1, subgrp=IL6GR1,grp=7); 
%means_subgrp(dsin=&adam., dsout=aval_CRPGR1,  screen=%str(avisitn>0),  dec_var=aval, var=aval, ord=2, subgrp=IL6GR1,grp=7); 
%means_subgrp(dsin=&adam., dsout=chg_CRPGR1,  screen=%str(avisitn>0),   dec_var=chg,  var=chg,  ord=3, subgrp=IL6GR1,grp=7); 


proc means data=&adam.;
	where avisitn in (12 16);
	by usubjid &trtVar.N &trtVar. paramn param;
	var aval;
	output out=average_week12_16 n=n mean=aval;
run;

data average_week12_16;
	set average_week12_16;
	avisitn=99;
	avisit="第12-16周均值[2]";
run;

*亚组变量;
data temp;
	set average_week12_16;
run;
proc sql noprint;
	create table average_week12_16 as 
	select a.*, b.CKDSTAGN, b.TSATGR2N, b.CKDDMFLN, b.CKDCVFLN, b.CRPGR1N, b.ACRGR1N, b.IL6GR1N
	from temp a left join adsl b on a.usubjid=b.usubjid
	order by usubjid, paramn, param
;
quit;

%means_subgrp(dsin=average_week12_16, dsout=aval_12_16_TSAT, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=TSATGR2,grp=1); 
%means_subgrp(dsin=average_week12_16, dsout=aval_12_16_CKDSTAG, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=CKDSTAG,grp=2); 
%means_subgrp(dsin=average_week12_16, dsout=aval_12_16_ACRGR1, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=ACRGR1,grp=3); 
%means_subgrp(dsin=average_week12_16, dsout=aval_12_16_CKDDM, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=CKDDMFL,grp=4); 
%means_subgrp(dsin=average_week12_16, dsout=aval_12_16_CKDCV, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=CKDCVFL,grp=5); 
%means_subgrp(dsin=average_week12_16, dsout=aval_12_16_CRPGR1, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=CRPGR1,grp=6); 
%means_subgrp(dsin=average_week12_16, dsout=aval_12_16_IL6GR1, screen=%str(avisitn>0),  dec_var=aval, var=aval,ord=2, subgrp=IL6GR1,grp=7); 


/*To Programmer: 协方差结构首先考虑采用无结构协方差(UN)。
如果在UN结构下模型不收敛，将依次使用如下协方差结构直到收敛: TOEPH,ARH(1),TOEP,AR(1),CS.
*/

*协变量;
%macro mixed_subgrp(subgrp=, k=);

data temp;
	set &adam.;
	where &subgrp.N=&k.;
run;
proc sql noprint;
	create table &adam.2 as 
	select a.*, input(b.GFR,best.) as eGFR, b.HGBBL
	from temp a left join adsl b on a.usubjid=b.usubjid
	order by paramn,param,trt01pn,avisitn
;
quit;

%if &subgrp.=ACRGR1 and &k.=1 %then %do;
ods output lsmeans=lsmeans diffs=diffs LSMEstimates=LSMEstimates;
proc mixed data=&adam.2(where=(avisitn>0)) /*method=REML covtest empirical*/;
	by paramn param;
	class usubjid trt01pn avisitn;
	model chg = trt01pn avisitn trt01pn*avisitn HGBBL egfr / ddfm=kr;
	repeated avisitn/subject=usubjid type=ARH(1) group=trt01pn;
	lsmeans trt01pn/pdiff cl;
	lsmeans trt01pn*avisitn/pdiff cl alpha=0.05;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 LOW" 0 0 0 0 1 1  0 0 0 0 0 0   /cl divisor=2 ; *avisitn=2 4 6 8 12 16;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 STD" 0 0 0 0 0 0  0 0 0 0 1 1   /cl divisor=2 ;
	lsmestimate trt01pn*avisitn "diff (LOW-STD)"    0 0 0 0 1 1  0 0 0 0 -1 -1 /cl divisor=2 testvalue=-5 alpha=0.05 ; 
run;
%end;
%else %if &subgrp.=CKDCVFL and &k.=2 %then %do;
ods output lsmeans=lsmeans diffs=diffs LSMEstimates=LSMEstimates;
proc mixed data=&adam.2(where=(avisitn>0)) /*method=REML covtest empirical*/;
	by paramn param;
	class usubjid trt01pn avisitn;
	model chg = trt01pn avisitn trt01pn*avisitn HGBBL egfr / ddfm=kr;
	repeated avisitn/subject=usubjid type=ARH(1) group=trt01pn;
	lsmeans trt01pn/pdiff cl;
	lsmeans trt01pn*avisitn/pdiff cl alpha=0.05;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 LOW" 0 0 0 0 1 1  0 0 0 0 0 0   /cl divisor=2 ; *avisitn=2 4 6 8 12 16;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 STD" 0 0 0 0 0 0  0 0 0 0 1 1   /cl divisor=2 ;
	lsmestimate trt01pn*avisitn "diff (LOW-STD)"    0 0 0 0 1 1  0 0 0 0 -1 -1 /cl divisor=2 testvalue=-5 alpha=0.05 ; 
run;
%end;
%else %if &subgrp.=CRPGR1 and &k.=2 %then %do;
ods output lsmeans=lsmeans diffs=diffs LSMEstimates=LSMEstimates;
proc mixed data=&adam.2(where=(avisitn>0)) /*method=REML covtest empirical*/;
	by paramn param;
	class usubjid trt01pn avisitn;
	model chg = trt01pn avisitn trt01pn*avisitn HGBBL egfr / ddfm=kr;
	repeated avisitn/subject=usubjid type=ARH(1) group=trt01pn;
	lsmeans trt01pn/pdiff cl;
	lsmeans trt01pn*avisitn/pdiff cl alpha=0.05;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 LOW" 0 0 0 0 1 1  0 0 0 0 0 0   /cl divisor=2 ; *avisitn=2 4 6 8 12 16;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 STD" 0 0 0 0 0 0  0 0 0 0 1 1   /cl divisor=2 ;
	lsmestimate trt01pn*avisitn "diff (LOW-STD)"    0 0 0 0 1 1  0 0 0 0 -1 -1 /cl divisor=2 testvalue=-5 alpha=0.05 ; 
run;
%end;
%else %do;
ods output lsmeans=lsmeans diffs=diffs LSMEstimates=LSMEstimates;
proc mixed data=&adam.2(where=(avisitn>0)) /*method=REML covtest empirical*/;
	by paramn param;
	class usubjid trt01pn avisitn;
	model chg = trt01pn avisitn trt01pn*avisitn HGBBL egfr / ddfm=kr;
	repeated avisitn/subject=usubjid type=UN group=trt01pn;
	lsmeans trt01pn/pdiff cl;
	lsmeans trt01pn*avisitn/pdiff cl alpha=0.05;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 LOW" 0 0 0 0 1 1  0 0 0 0 0 0   /cl divisor=2 ; *avisitn=2 4 6 8 12 16;
	lsmestimate trt01pn*AVISITN "WEEKS 12 - 16 STD" 0 0 0 0 0 0  0 0 0 0 1 1   /cl divisor=2 ;
	lsmestimate trt01pn*avisitn "diff (LOW-STD)"    0 0 0 0 1 1  0 0 0 0 -1 -1 /cl divisor=2 testvalue=-5 alpha=0.05 ; 
run;
%end;


*最小二乘均值;
data LSMeans1;
	set LSMeans;
	where EFFECT="TRT01PN*AVISITN";
	row1=strip(put(ESTIMATE,8.2));
	row2=strip(put(LOWER,8.2))||", "||strip(put(UPPER,8.2));
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=LSMeans1 out=trans_LSMeans prefix=c; 
	by paramn param avisitn; 
	var row1-row2; 
	id &trtVar.N;
run;
data trans_lsmeans; 
	length ord seq 8;
	set trans_lsmeans; 
	ord=3; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;


*最小二乘均值的差分;
data diffs1;
	set diffs;
	if EFFECT="TRT01PN*AVISITN";
	if &trtVar.N=1 & _&trtVar.N=2 & avisitn = _avisitn;
	row3=strip(put(ESTIMATE,8.2));
	row4=strip(put(LOWER,8.2))||", "||strip(put(UPPER,8.2));
	row5=strip(put(PROBT,pvalue6.4));
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=diffs1 out=trans_diffs prefix=c; 
	by paramn param avisitn; 
	var row3-row5; 
	id &trtVar.N; 
run;
data trans_diffs; 
	length ord seq 8;
	set trans_diffs; 
	ord=3; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;


*12-16周的最小二乘均值;
data Trans_lsm_12_16;
	set Lsmestimates;
	where label^="diff (LOW-STD)";
	&trtVar.N=STMTNO;
	avisitn=99;
	row1=strip(put(ESTIMATE,8.2));
	row2=strip(put(LOWER,8.2))||", "||strip(put(UPPER,8.2));
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=Trans_lsm_12_16 out=trans_lsm_12_16 prefix=c; 
	by paramn param avisitn; 
	var row1-row2; 
	id &trtVar.N;
run;
data trans_lsm_12_16; 
	length ord seq 8;
	set trans_lsm_12_16;
	ord=3;
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;


*12-16周的最小二乘均值的差分;
data diffs_12_16;
	set LSMEstimates;
	if LABEL="diff (LOW-STD)";
	&trtVar.N=1;
	avisitn=99;
	row3=strip(put(ESTIMATE,8.2));
	row4=strip(put(LOWER,8.2))||", "||strip(put(UPPER,8.2));
	row5=strip(put(PROBT,pvalue6.4));
	proc sort;
	by paramn param avisitn ;
run;
proc transpose data=diffs_12_16 out=trans_diffs_12_16 prefix=c; 
	by paramn param avisitn; 
	var row3-row5; 
	id &trtVar.N; 
run;
data trans_diffs_12_16; 
	length ord seq 8;
	set trans_diffs_12_16; 
	ord=3; 
	seq=input(substr(_name_,4,1),best.); 
	drop _name_; 
run;


data chg_mixed_&subgrp.N_&k.;
	length ord seq 8 c1-c2 $200;
	set trans_lsmeans trans_diffs trans_lsm_12_16 trans_diffs_12_16;
	avisit=put(avisitn, avisit.);
	avisitn = avisitn + 0.1; 
	proc sort; 
	by paramn avisitn seq; 
run;


%mend;


%mixed_subgrp(subgrp=TSATGR2, k=1); 
%mixed_subgrp(subgrp=TSATGR2, k=2);

data Chg_mixed_TSATGR2N_1;
	set Chg_mixed_TSATGR2N_1;
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_TSATGR2N_2;
	set Chg_mixed_TSATGR2N_2(rename=(c1=c3 c2=c4));
	proc sort;
	by avisitn ord seq;
run;
data Chg__mixed_TSATGR2N;
	merge Chg_mixed_TSATGR2N_1 Chg_mixed_TSATGR2N_2 ;
	by avisitn ord seq;
	grp=1;
run;


%mixed_subgrp(subgrp=CKDSTAG, k=1);
%mixed_subgrp(subgrp=CKDSTAG, k=2);
%mixed_subgrp(subgrp=CKDSTAG, k=3);

data Chg_mixed_ckdstagn_1;
	set Chg_mixed_ckdstagn_1;
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_ckdstagn_2;
	set Chg_mixed_ckdstagn_2(rename=(c1=c3 c2=c4));
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_ckdstagn_3;
	set Chg_mixed_ckdstagn_3(rename=(c1=c5 c2=c6));
	proc sort;
	by avisitn ord seq;
run;
data Chg__mixed_ckdstagn;
	merge Chg_mixed_ckdstagn_1 Chg_mixed_ckdstagn_2 Chg_mixed_ckdstagn_3;
	by avisitn ord seq;
	grp=2;
run;


%mixed_subgrp(subgrp=ACRGR1, k=1); *未收敛;
%mixed_subgrp(subgrp=ACRGR1, k=2);
data Chg_mixed_acrgr1n_1;
	set Chg_mixed_acrgr1n_1;
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_acrgr1n_2;
	set Chg_mixed_acrgr1n_2(rename=(c1=c3 c2=c4));
	proc sort;
	by avisitn ord seq;
run;
data Chg__mixed_acrgr1n;
	merge Chg_mixed_acrgr1n_1 Chg_mixed_acrgr1n_2 ;
	by avisitn ord seq;
	grp=3;
run;

%mixed_subgrp(subgrp=CKDDMFL, k=1);
%mixed_subgrp(subgrp=CKDDMFL, k=2);
data Chg_mixed_ckddmfln_1;
	set Chg_mixed_ckddmfln_1;
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_ckddmfln_2;
	set Chg_mixed_ckddmfln_2(rename=(c1=c3 c2=c4));
	proc sort;
	by avisitn ord seq;
run;
data Chg__mixed_ckddmfln;
	merge Chg_mixed_ckddmfln_1 Chg_mixed_ckddmfln_2 ;
	by avisitn ord seq;
	grp=4;
run;

%mixed_subgrp(subgrp=CKDCVFL, k=1);
%mixed_subgrp(subgrp=CKDCVFL, k=2); *未收敛;
data Chg_mixed_ckdcvfln_1;
	set Chg_mixed_ckdcvfln_1;
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_ckdcvfln_2;
	set Chg_mixed_ckdcvfln_2(rename=(c1=c3 c2=c4));
	proc sort;
	by avisitn ord seq;
run;
data Chg__mixed_ckdcvfln;
	merge Chg_mixed_ckdcvfln_1 Chg_mixed_ckdcvfln_2 ;
	by avisitn ord seq;
	grp=5;
run;


%mixed_subgrp(subgrp=CRPGR1, k=1);
%mixed_subgrp(subgrp=CRPGR1, k=2);

data Chg_mixed_CRPGR1N_1;
	set Chg_mixed_CRPGR1N_1;
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_CRPGR1N_2;
	set Chg_mixed_CRPGR1N_2(rename=(c1=c3 c2=c4));
	proc sort;
	by avisitn ord seq;
run;
data Chg__mixed_CRPGR1N;
	merge Chg_mixed_CRPGR1N_1 Chg_mixed_CRPGR1N_2 ;
	by avisitn ord seq;
	grp=6;
run;


%mixed_subgrp(subgrp=IL6GR1, k=1);
%mixed_subgrp(subgrp=IL6GR1, k=2);

data Chg_mixed_IL6GR1N_1;
	set Chg_mixed_IL6GR1N_1;
	proc sort;
	by avisitn ord seq;
run;
data Chg_mixed_IL6GR1N_2;
	set Chg_mixed_IL6GR1N_2(rename=(c1=c3 c2=c4));
	proc sort;
	by avisitn ord seq;
run;
data Chg__mixed_IL6GR1N;
	merge Chg_mixed_IL6GR1N_1 Chg_mixed_IL6GR1N_2 ;
	by avisitn ord seq;
	grp=7;
run;


data all_base_aval;
	length paramn grp avisitn ord seq 8 param avisit $200;
	set base_: aval_:;
	if not missing(paramn);
	c1=TRT11;
	c2=TRT12;
	c3=TRT21;
	c4=TRT22;
	c5=TRT31;
	c6=TRT32;
	drop trt:;
	proc sort;
	by paramn grp avisitn ord seq;
run;


data all_chg_mixed;
	length paramn grp avisitn ord seq 8 param avisit $200;
	set chg__:;
	if not missing(paramn);
	proc sort;
	by paramn grp avisitn ord seq;
run;


data all;
	length paramn grp avisitn ord seq 8 param avisit c1-c6 $200;
	set all_base_aval all_chg_mixed;
	proc sort;
	by paramn grp avisitn ord seq;
run;


data final;
	length paramn grp avisitn ord seq 8 t1-t2 c1-c6 $200;
	set all;
	by paramn grp avisitn ord seq;
	if avisit="基线" then avisit="基线[1]";
	if mod(avisitn,1)^=0 then t1=strip(avisit)||"较基线变化（MMRM）";
	else t1=strip(avisit);	
	if ord<=2 then t2=strip(put(seq,seqc.));
	else if ord=3 then t2=strip(put(seq,seq2c.));
	if not first.avisitn then call missing(t1);
	proc sort;
	by paramn grp avisitn ord seq;
run;


*--------------------------------------------------------------------------;
*FOREST PLOT;
*--------------------------------------------------------------------------;

*make figure according to source table;
data plotdata;
	set final;
	if ord=3;
run;


data plot_lsmeans;
	set plotdata;
	if avisitn=99.1 and seq=1;
	proc sort;
	by GRP;
run;
proc transpose data=plot_lsmeans out=point(rename=(COL1=point1) where=(not missing(point1)) );
	by GRP;
	var c1 c3 c5;
run;


data column_2_point;
	length grp seq 8 subgroup $200;
	set point;
	if GRP=1 and _name_="C1" then do;seq=1;subgroup="TSAT<=20%";end;
	if GRP=1 and _name_="C3" then do;seq=2;subgroup="TSAT>20%";end;
	if GRP=2 and _name_="C1" then do;seq=1;subgroup="3期";end;
	if GRP=2 and _name_="C3" then do;seq=2;subgroup="4期";end;
	if GRP=2 and _name_="C5" then do;seq=3;subgroup="5期";end;
	if GRP=3 and _name_="C1" then do;seq=1;subgroup="ACR<=ULN";end;
	if GRP=3 and _name_="C3" then do;seq=2;subgroup="ACR>ULN";end;
	if GRP=4 and _name_="C1" then do;seq=1;subgroup="合并糖尿病 ";end;
	if GRP=4 and _name_="C3" then do;seq=2;subgroup="未合并糖尿病";end;
	if GRP=5 and _name_="C1" then do;seq=1;subgroup="合并心血管疾病";end;
	if GRP=5 and _name_="C3" then do;seq=2;subgroup="未合并心血管疾病";end;
	if GRP=6 and _name_="C1" then do;seq=1;subgroup="CRP/HsCRP<=ULN";end;
	if GRP=6 and _name_="C3" then do;seq=2;subgroup="CRP/HsCRP>ULN";end;
	if GRP=7 and _name_="C1" then do;seq=1;subgroup="IL-6<=ULN";end;
	if GRP=7 and _name_="C3" then do;seq=2;subgroup="IL-6>ULN";end;
	keep grp seq subgroup point1;
	proc sort;
	by grp seq;
run;


data plot_lsmeansCI;
	set plotdata;
	if avisitn=99.1 and seq=2;
	proc sort;
	by GRP;
run;
proc transpose data=plot_lsmeansCI out=lsmeansCI(rename=(COL1=CI1) where=(not missing(CI1)));
	by GRP;
	var c1 c3 c5;
run;

data column_2_CI;
	length grp seq 8 subgroup $200;
	set lsmeansCI;
	if GRP=1 and _name_="C1" then do;seq=1;subgroup="TSAT<=20%";end;
	if GRP=1 and _name_="C3" then do;seq=2;subgroup="TSAT>20%";end;
	if GRP=2 and _name_="C1" then do;seq=1;subgroup="3期";end;
	if GRP=2 and _name_="C3" then do;seq=2;subgroup="4期";end;
	if GRP=2 and _name_="C5" then do;seq=3;subgroup="5期";end;
	if GRP=3 and _name_="C1" then do;seq=1;subgroup="ACR<=ULN";end;
	if GRP=3 and _name_="C3" then do;seq=2;subgroup="ACR>ULN";end;
	if GRP=4 and _name_="C1" then do;seq=1;subgroup="合并糖尿病 ";end;
	if GRP=4 and _name_="C3" then do;seq=2;subgroup="未合并糖尿病";end;
	if GRP=5 and _name_="C1" then do;seq=1;subgroup="合并心血管疾病";end;
	if GRP=5 and _name_="C3" then do;seq=2;subgroup="未合并心血管疾病";end;
	if GRP=6 and _name_="C1" then do;seq=1;subgroup="CRP/HsCRP<=ULN";end;
	if GRP=6 and _name_="C3" then do;seq=2;subgroup="CRP/HsCRP>ULN";end;
	if GRP=7 and _name_="C1" then do;seq=1;subgroup="IL-6<=ULN";end;
	if GRP=7 and _name_="C3" then do;seq=2;subgroup="IL-6>ULN";end;
	keep grp seq subgroup CI1;
	proc sort;
	by grp seq;
run;


proc transpose data=plot_lsmeans out=lsmeans(rename=(COL1=point2) where=(not missing(point2)));
	by GRP;
	var c2 c4 c6;
run;

data column_3_point;
	length grp seq 8 subgroup $200;
	set lsmeans;
	if GRP=1 and _name_="C2" then do;seq=1;subgroup="TSAT<=20%";end;
	if GRP=1 and _name_="C4" then do;seq=2;subgroup="TSAT>20%";end;
	if GRP=2 and _name_="C2" then do;seq=1;subgroup="3期";end;
	if GRP=2 and _name_="C4" then do;seq=2;subgroup="4期";end;
	if GRP=2 and _name_="C6" then do;seq=3;subgroup="5期";end;
	if GRP=3 and _name_="C2" then do;seq=1;subgroup="ACR<=ULN";end;
	if GRP=3 and _name_="C4" then do;seq=2;subgroup="ACR>ULN";end;
	if GRP=4 and _name_="C2" then do;seq=1;subgroup="合并糖尿病 ";end;
	if GRP=4 and _name_="C4" then do;seq=2;subgroup="未合并糖尿病";end;
	if GRP=5 and _name_="C2" then do;seq=1;subgroup="合并心血管疾病";end;
	if GRP=5 and _name_="C4" then do;seq=2;subgroup="未合并心血管疾病";end;
	if GRP=6 and _name_="C2" then do;seq=1;subgroup="CRP/HsCRP<=ULN";end;
	if GRP=6 and _name_="C4" then do;seq=2;subgroup="CRP/HsCRP>ULN";end;
	if GRP=7 and _name_="C2" then do;seq=1;subgroup="IL-6<=ULN";end;
	if GRP=7 and _name_="C4" then do;seq=2;subgroup="IL-6>ULN";end;
	keep grp seq subgroup point2;
	proc sort;
	by grp seq;
run;


proc transpose data=plot_lsmeansCI out=lsmeansCI(rename=(COL1=CI2) where=(not missing(CI2)));
	by GRP;
	var c2 c4 c6;
run;
data column_3_CI;
	length grp seq 8 subgroup $200;
	set lsmeansCI;
	if GRP=1 and _name_="C2" then do;seq=1;subgroup="TSAT<=20%";end;
	if GRP=1 and _name_="C4" then do;seq=2;subgroup="TSAT>20%";end;
	if GRP=2 and _name_="C2" then do;seq=1;subgroup="3期";end;
	if GRP=2 and _name_="C4" then do;seq=2;subgroup="4期";end;
	if GRP=2 and _name_="C6" then do;seq=3;subgroup="5期";end;
	if GRP=3 and _name_="C2" then do;seq=1;subgroup="ACR<=ULN";end;
	if GRP=3 and _name_="C4" then do;seq=2;subgroup="ACR>ULN";end;
	if GRP=4 and _name_="C2" then do;seq=1;subgroup="合并糖尿病 ";end;
	if GRP=4 and _name_="C4" then do;seq=2;subgroup="未合并糖尿病";end;
	if GRP=5 and _name_="C2" then do;seq=1;subgroup="合并心血管疾病";end;
	if GRP=5 and _name_="C4" then do;seq=2;subgroup="未合并心血管疾病";end;
	if GRP=6 and _name_="C2" then do;seq=1;subgroup="CRP/HsCRP<=ULN";end;
	if GRP=6 and _name_="C4" then do;seq=2;subgroup="CRP/HsCRP>ULN";end;
	if GRP=7 and _name_="C2" then do;seq=1;subgroup="IL-6<=ULN";end;
	if GRP=7 and _name_="C4" then do;seq=2;subgroup="IL-6>ULN";end;
	keep grp seq subgroup CI2;
	proc sort;
	by grp seq;
run;


*组间均值差异及其置信区间;
data plot_diff;
	set plotdata;
	if avisitn=99.1 and seq=3;
	proc sort;
	by GRP;
run;
proc transpose data=plot_diff out=diff(rename=(COL1=diff) where=(not missing(diff)));
	by GRP;
	var c1 c3 c5;
run;

data column_4_diff;
	length grp seq 8 subgroup $200;
	set diff;
	ESTIMATE = input(diff,??best.);
	if GRP=1 and _name_="C1" then do;seq=1;subgroup="TSAT<=20%";end;
	if GRP=1 and _name_="C3" then do;seq=2;subgroup="TSAT>20%";end;
	if GRP=2 and _name_="C1" then do;seq=1;subgroup="3期";end;
	if GRP=2 and _name_="C3" then do;seq=2;subgroup="4期";end;
	if GRP=2 and _name_="C5" then do;seq=3;subgroup="5期";end;
	if GRP=3 and _name_="C1" then do;seq=1;subgroup="ACR<=ULN";end;
	if GRP=3 and _name_="C3" then do;seq=2;subgroup="ACR>ULN";end;
	if GRP=4 and _name_="C1" then do;seq=1;subgroup="合并糖尿病 ";end;
	if GRP=4 and _name_="C3" then do;seq=2;subgroup="未合并糖尿病";end;
	if GRP=5 and _name_="C1" then do;seq=1;subgroup="合并心血管疾病";end;
	if GRP=5 and _name_="C3" then do;seq=2;subgroup="未合并心血管疾病";end;
	if GRP=6 and _name_="C1" then do;seq=1;subgroup="CRP/HsCRP<=ULN";end;
	if GRP=6 and _name_="C3" then do;seq=2;subgroup="CRP/HsCRP>ULN";end;
	if GRP=7 and _name_="C1" then do;seq=1;subgroup="IL-6<=ULN";end;
	if GRP=7 and _name_="C3" then do;seq=2;subgroup="IL-6>ULN";end;
	keep grp seq subgroup diff ESTIMATE;
	proc sort;
	by grp seq;
run;


data plot_diffCI;
	set plotdata;
	if avisitn=99.1 and seq=4;
	proc sort;
	by GRP;
run;
proc transpose data=plot_diffCI out=diffCI(rename=(COL1=diffCI) where=(not missing(diffCI)));
	by GRP;
	var c1 c3 c5;
run;


data column_4_diffCI;
	length grp seq 8 subgroup $200;
	set diffCI;
	if GRP=1 and _name_="C1" then do;seq=1;subgroup="TSAT<=20%";end;
	if GRP=1 and _name_="C3" then do;seq=2;subgroup="TSAT>20%";end;
	if GRP=2 and _name_="C1" then do;seq=1;subgroup="3期";end;
	if GRP=2 and _name_="C3" then do;seq=2;subgroup="4期";end;
	if GRP=2 and _name_="C5" then do;seq=3;subgroup="5期";end;
	if GRP=3 and _name_="C1" then do;seq=1;subgroup="ACR<=ULN";end;
	if GRP=3 and _name_="C3" then do;seq=2;subgroup="ACR>ULN";end;
	if GRP=4 and _name_="C1" then do;seq=1;subgroup="合并糖尿病 ";end;
	if GRP=4 and _name_="C3" then do;seq=2;subgroup="未合并糖尿病";end;
	if GRP=5 and _name_="C1" then do;seq=1;subgroup="合并心血管疾病";end;
	if GRP=5 and _name_="C3" then do;seq=2;subgroup="未合并心血管疾病";end;
	if GRP=6 and _name_="C1" then do;seq=1;subgroup="CRP/HsCRP<=ULN";end;
	if GRP=6 and _name_="C3" then do;seq=2;subgroup="CRP/HsCRP>ULN";end;
	if GRP=7 and _name_="C1" then do;seq=1;subgroup="IL-6<=ULN";end;
	if GRP=7 and _name_="C3" then do;seq=2;subgroup="IL-6>ULN";end;
	LOWER = input(scan(diffCI,1,","),??best.);
	UPPER = input(scan(diffCI,2,","),??best.);
	keep grp seq subgroup diffCI LOWER UPPER;
	proc sort;
	by grp seq;
run;


*估计的可信度P值;
data plot_pvalue;
	set plotdata;
	if avisitn=99.1 and seq=5;
	proc sort;
	by GRP;
run;
proc transpose data=plot_pvalue out=pvalue(rename=(COL1=pvalue) where=(not missing(pvalue)));
	by GRP;
	var c1 c3 c5;
run;


data column_5_pvalue;
	length grp seq 8 subgroup $200;
	set pvalue;
	if GRP=1 and _name_="C1" then do;seq=1;subgroup="TSAT<=20%";end;
	if GRP=1 and _name_="C3" then do;seq=2;subgroup="TSAT>20%";end;
	if GRP=2 and _name_="C1" then do;seq=1;subgroup="3期";end;
	if GRP=2 and _name_="C3" then do;seq=2;subgroup="4期";end;
	if GRP=2 and _name_="C5" then do;seq=3;subgroup="5期";end;
	if GRP=3 and _name_="C1" then do;seq=1;subgroup="ACR<=ULN";end;
	if GRP=3 and _name_="C3" then do;seq=2;subgroup="ACR>ULN";end;
	if GRP=4 and _name_="C1" then do;seq=1;subgroup="合并糖尿病 ";end;
	if GRP=4 and _name_="C3" then do;seq=2;subgroup="未合并糖尿病";end;
	if GRP=5 and _name_="C1" then do;seq=1;subgroup="合并心血管疾病";end;
	if GRP=5 and _name_="C3" then do;seq=2;subgroup="未合并心血管疾病";end;
	if GRP=6 and _name_="C1" then do;seq=1;subgroup="CRP/HsCRP<=ULN";end;
	if GRP=6 and _name_="C3" then do;seq=2;subgroup="CRP/HsCRP>ULN";end;
	if GRP=7 and _name_="C1" then do;seq=1;subgroup="IL-6<=ULN";end;
	if GRP=7 and _name_="C3" then do;seq=2;subgroup="IL-6>ULN";end;
	keep grp seq subgroup pvalue;
	proc sort;
	by grp seq;
run;


data all_columns;
	merge column_:;
	by grp seq;
run; 


proc format;
	value subgrp
	1="转铁蛋白饱和度"
	2="CKD分期"
	3="尿白蛋白/肌酐比率"
	4="糖尿病"
	5="心血管疾病"
	6="C反应蛋白/超敏C反应蛋白"
	7="白细胞介素-6"
	;
quit;

data dummy;
	do grp=1 to 7;
		seq=0;
		SUBGROUP=put(grp, subgrp.); 
		output;
	end;
run;


data SubgroupData;
	length indent 8;
	set all_columns dummy;
	if seq=0 then do;
		indent=0;
	end;
	else do; 
		indent=1;
		C2=cat(strip(point1),"(",strip(CI1),")");
		C3=cat(strip(point2),"(",strip(CI2),")");
		C4=cat(strip(diff),"(",strip(diffCI),")");
	end;
	proc sort;
	by grp seq;
run;


data SubgroupData;
	set SubgroupData;
	row=_N_;
	array charvar _char_;
	do over charvar;
		charvar=tranwrd(charvar, '<=', '(*ESC*){Unicode ''2264''x}');
		charvar=tranwrd(charvar, '>=', '(*ESC*){Unicode ''2265''x}'); 
	end;
run;


data figdat.&outname.;
	set SubgroupData;
	informat _all_;
	format _all_;
	attrib _all_ label='';
	keep grp seq subgroup C2 C3 C4 DIFF LOWER UPPER PVALUE;
	proc sort;
	by grp seq;
run;


%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
/*	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));*/
%end;


/*--Used for Subgroup labels in column 1--*/
data anno(drop=indent);
set SubgroupData(keep=row subgroup indent rename=(row=y1));
retain Function 'Text ' ID 'id1' X1Space 'DataPercent' Y1Space 'DataValue   ' x1 x2 2 TextSize 6 Width 100 Anchor 'Left ';
if indent;
label = tranwrd(subgroup, '>=', '(*ESC*){Unicode ''2265''x}');
run;


/*--Used for text under x axis of HR scatter plot in column 7--*/
data anno2;
retain Function 'Arrow' ID 'id2' X1Space X2Space 'DataValue' FIllTransparency 0 Y1Space Y2Space 'GraphPercent' Scale 1e-40
LineThickness 1 y1 y2 8 Width 100 FillStyleElement 'GraphWalls' LineColor 'Black';

*arrow;
*x1=起点 x2=终点;
x1 = -0.5; x2 = -22; output;
x1 = 0.5;  x2 = 20; output;

function = 'Text'; y1 = 5; y2 = 5;
x1 = 0;
anchor = 'Right'; label = "&trt2.更好"; Textsize=7;output;
x1 = 0;
Anchor = 'Left '; label = "&trt1.更好"; Textsize=7; output;
run;


data anno;
	set anno anno2;
run;


data forest2(drop=flag);
	set SubgroupData nobs=nobs;
	Head = not indent;
	retain flag 0;
	if head then flag = mod(flag + 1, 2);
	if flag then ref=row;
	if indent then subgroup = ' ';
run;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=11.0cm;
ods listing gpath="&outdir.\figures" image_dpi=400; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


/*--Define template for Forest Plot--*/
/*--Template uses a Layout Lattice of 8 columns--*/
proc template;
	define statgraph ForestPlot;
	dynamic /*_show_bands*/ _color _thk;
	begingraph;

	discreteattrmap name='text';
		value '1' / textattrs=(weight=bold); 
		value other;
		enddiscreteattrmap;
	discreteattrvar attrvar=type var=head attrmap='text';

	layout lattice /columns=6 columnweights=(0.2 0.13 0.12 0.12 0.25 0.04);

		/*--Column headers--*/
		sidebar / align=top;
			layout lattice /

				rows=2 columns=5 columnweights=(0.19 0.13 0.12 0.32 0.08);

				entry " ";
				entry textattrs=(size=6) halign=left " &trt1";
				entry textattrs=(size=6) halign=left " &trt2";
				entry " ";
				entry " ";

				entry textattrs=(size=8) halign=left "亚组";
				entry textattrs=(size=6) halign=left "最小二乘均值(95% CI)";
				entry textattrs=(size=6) halign=left "最小二乘均值(95% CI)";
				entry textattrs=(size=6) halign=left "组间差值 (95% CI)";
				entry halign=right textattrs=(size=6) "P 值*" ;

			endlayout;
		endsidebar;

		/*--First Subgroup column, shows only the Y2 axis--*/
		layout overlay / walldisplay=none xaxisopts=(display=none) yaxisopts=(reverse=true display=none tickvalueattrs=(weight=bold));
			annotate / id='id1';
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=subgroup /display=(values) textgroup=type valueattrs=(size=6pt);
		endlayout;

		/*--Second column showing point estimation and CI estimation --*/
		layout overlay / xaxisopts=(display=none) yaxisopts=(reverse=true display=none) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=C2 /display=(values) valuejustify = center valueattrs=(size=6pt);
		endlayout;

		/*--Third column showing point estimation and CI estimation --*/
		layout overlay / xaxisopts=(display=none)
			yaxisopts=(reverse=true display=none) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=C3 /display=(values) valuejustify = center valueattrs=(size=6pt);
		endlayout;

		/*--Forth column showing group difference and confidence intervals--*/
		layout overlay / x2axisopts=(display=none)
			yaxisopts=(reverse=true display=none) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=C4 / display=(values) valueattrs=(size=6pt);
		endlayout;

		/*--Fifth column showing diff with 95% error bars--*/
		layout overlay / xaxisopts=(	
				label=' ' 
				labelattrs=(size=6) 
				/*logopts=(tickvaluepriority=true tickvaluelist=(-10 -5 0 5))*/ 
				/*linearopts=(viewmin=-10 viewmax=10 tickvaluesequence=(start=-10 end=10 increment=1 ) ))*/
				type=linear
				linearopts=(viewmin=-20 viewmax=20 tickvaluesequence=(start=-20 end=20 increment=5))
				tickvalueattrs=(size=7pt family="Arial") 
			)
			yaxisopts=(reverse=true display=none) walldisplay=none;
			annotate / id='id2';
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			scatterplot y=row x=ESTIMATE / xerrorlower=LOWER xerrorupper=UPPER
			/*sizeresponse=SquareSize*/ sizemin=4 sizemax=12 markerattrs=(symbol=trianglefilled);
			referenceline x=-5 / lineattrs=(color=cxFF7F0E pattern=shortdash thickness=1);
			referenceline x=0  / lineattrs=(color=black pattern=solid thickness=1);
			referenceline x=5  / lineattrs=(color=cxFF7F0E pattern=shortdash thickness=1);
		endlayout;

		/*--Sixth column showing P-Values--*/
		layout overlay / x2axisopts=(display=none) yaxisopts=(reverse=true display=none) walldisplay=none;
			referenceline y=ref / lineattrs=(thickness=_thk color=_color);
			axistable y=row value=pvalue / display=(values) valuejustify = right valueattrs=(size=6pt) showmissing=false; 
			/*false removes . for missing pvalues*/
		endlayout;

	endlayout; *layout lattice /columns=8 columnweights=(0.21 0.06 .07 0.06 .07 0.12 0.33 0.09);

	entryfootnote halign=left textattrs=(size=8) '* 基于（低起始剂量组-标准起始剂量组）≤-5g/L计算P值';
	endgraph; *begingraph;

	end;
run;

proc sgrender data=Forest2 template=ForestPlot sganno=anno;
	dynamic _color='white' _thk=10 ; 
run;

ods rtf close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
