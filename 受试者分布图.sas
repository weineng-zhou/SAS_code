
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
%let pgmname = f-14-1-1-1.sas;
%let outname = F14010101;


*���������;
data BOX;
input boxid xb yb @@;
datalines;
1 41 200 
1 59 200 
1 59 180 
1 41 180

2 60 180 
2 96 180 
2 96 170 
2 60 170

3 60 165 
3 96 165 
3 96 155 
3 60 155

4 60 150
4 96 150 
4 96 140 
4 60 140

5 41 130 
5 59 130 
5 59 110
5 41 110

6 8 100 
6 27 100 
6 27 80 
6 8 80

7 73 100 
7 92 100 
7 92 80 
7 73 80
8 2 70 
8 14 70 
8 14 10 
8 2 10

9 14.5 70 
9 49.5 70 
9 49.5 10
9 14.5 10

10 50.5 70
10 85.5 70 
10 85.5 10
10 50.5 10

11 86 70 
11 98 70
11 98 10
11 86 10
;
run;


*�������ӵ�;
data LINK;
input linkid xl yl @@;
datalines;
1 50 180 
1 50 130

2 50 175 
2 60 175

3 50 160 
3 60 160

4 50 145 
4 60 145

5 41   120 
5 17.5 120
5 17.5 120
5 17.5 100

6 59   120 
6 82.5 120
6 82.5 120
6 82.5 100

7 17.5 80 
7 17.5 75 
7 8 75 
7 8 70

8 17.5 75
8 32 75 
8 32 70

9 82.5 80 
9 82.5 75 
9 68 75 
9 68 70

10 82.5 75 
10 92 75 
10 92 70
;
run;


*������ͼ��Ҫ�ı���;
data ADSL;
	set ads.adsl;
	if RFICFL="Y";
	*if missing(DCSREAS) then DCSREAS="����";
	keep USUBJID TRT01P TRT01PN RFICFL SCRNFL RANDFL TRTSDT SAFFL EOSSTT DCSREAS;
run;


data figdat.&outname.;
	set ADSL;
	informat _all_;
	format _all_;
	attrib _all_ label='';
	proc sort;
	by USUBJID;
run;


*������ͷ�������;
proc sql noprint;
	select distinct(trt01p) into: DRUG_A separated by '' from ADSL where trt01pn=1;
	select distinct(trt01p) into: DRUG_B separated by '' from ADSL where trt01pn=2;
	select count(usubjid) into: N1 from ADSL where RFICFL="Y";
	select count(usubjid) into: N2 from ADSL where SCRNFL^="Y" ;
	select count(usubjid) into: N3 from ADSL where SCRNFL="Y" and RANDFL^="Y";

	select count(usubjid) into: N4 from ADSL where RANDFL="Y" and missing(trtsdt);
	select count(usubjid) into: N5 from ADSL where RANDFL="Y" and not missing(trtsdt);

	select count(usubjid) into: N6 from ADSL where RANDFL="Y" and not missing(trtsdt) and trt01pn=1;
	select count(usubjid) into: N7 from ADSL where RANDFL="Y" and not missing(trtsdt) and trt01pn=2;

	select count(usubjid) into: N8 from ADSL where RANDFL="Y" and not missing(trtsdt) and SAFFL="Y" and trt01pn=1 and EOSSTT in("����о�" );
	select count(usubjid) into: N9 from ADSL where RANDFL="Y" and not missing(trtsdt) and SAFFL="Y" and trt01pn=1 and  EOSSTT="��ǰ��ֹ";
	select count(usubjid) into: N10 from ADSL where RANDFL="Y" and not missing(trtsdt) and SAFFL="Y" and trt01pn=2 and EOSSTT in("����о�" );
	select count(usubjid) into: N11 from ADSL where RANDFL="Y" and not missing(trtsdt) and SAFFL="Y" and trt01pn=2 and EOSSTT="��ǰ��ֹ";
	
quit;
%put ||&DRUG_A||;
%put ||&DRUG_B||;
%put &N1 &N2 &N3 &N4 &N5 &N6 &N7 &N8 &N9 &N10 &N11 ;


*��ǰ��ֹ��ԭ��;
proc freq data=ADSL noprint;
    where RANDFL="Y" & not missing(trtsdt) and EOSSTT="��ǰ��ֹ";
    table TRT01PN*TRT01P*DCSREAS/missing out=DCSREAS;
run;


data DCSREAS;
	set DCSREAS;	
	if index(upcase(DCSREAS),"���о��ڼ����͸��������") then ord=1;
	if index(upcase(DCSREAS),"ʹ���˽���ҩ") then ord=2;
	if index(upcase(DCSREAS),"�о�����Ϊ�����߽����˲����ϲ������Ʊ�׼�ķǽ����Ĳ�������") then do;
		ord=3;
		DCSREAS="�����߽����˲����ϲ������Ʊ�׼�ķǽ����Ĳ�������";
	end;
	if index(upcase(DCSREAS),"�����о�����Ϊ��������Ӱ���������ٴ�״̬�����Ĳ�������") then ord=4;
	if index(upcase(DCSREAS),"�����߲����ӣ���������Ӱ���о��յ��������") then ord=5;
	if index(upcase(DCSREAS),"����������Ҫ����ֹ�о�") then ord=6;
	if index(upcase(DCSREAS),"�������ܵĲ����¼�����ҽѧ���ҩ���Ʒ��޷��ʵ����������������ز����¼���") then do;
		ord=7;
		DCSREAS="�������ܵĲ����¼�";
	end;
	if index(upcase(DCSREAS),"���ز����¼�") then ord=8;
	if index(upcase(DCSREAS),"����") then ord=9;
	if index(upcase(DCSREAS),"��췽Ҫ����ֹ�о�") then ord=10;
	if index(upcase(DCSREAS),"ʧ��") then ord=11;
	if index(upcase(DCSREAS),"����") then ord=12;
	if index(upcase(DCSREAS),"����") then ord=13;
	text=strip(DCSREAS)||" (n="||strip(put(COUNT,best.))||")";
run;


proc sort data=DCSREAS; by trt01pn ord; run;
proc transpose data=DCSREAS out=xDCSREAS;
	by trt01pn trt01p;
	id ord;
	var text;
run;

data xDCSREAS;
    length text $ 200;
    set xDCSREAS;
    text="$- "||catx("$- ", of _1 _2 _5 _6 _8 _11 );
    call symput("reason_"||strip(put(trt01pn,best.)),strip(text));
run;
%put &reason_1;
%put &reason_2;


data CTEXT;
	length ctext $200;
	xt=50; yt=190; ctext="����ɸѡ��������$(N=%cmpres(&N1.))"; output;
	xt=77.5;yt=175; ctext="ɸѡʧ�ܵ�������$(N=%cmpres(&N2.))";output;
	xt=77.5;yt=160; ctext="ɸѡ�ɹ���δ�����������$(N=%cmpres(&N3.))";output;
	xt=77.5;yt=145; ctext="�������δ���Ƶ�������$(N=%cmpres(&N4.))";output;
	xt=50; yt=120; ctext="����������Ƶ�������$(N=%cmpres(&N5.))"; output;
	xt=17.5;yt=90;ctext="&DRUG_A.$(N=%cmpres(&N6.))"; output;
	xt=82.5;yt=90;ctext="&DRUG_B.$(N=%cmpres(&N7.))"; output;
	xt=8; yt=50;ctext="����о�$(N=%cmpres(&N8.))"; output;
	xt=92; yt=50;ctext="����о�$(N=%cmpres(&N10.))"; output;
run;

data LTEXT;
	length ltext $200;
	xt=15; yt=49; ltext="��ǰ��ֹ�о� (N=%cmpres(&N9.))$&reason_1."; output;
	xt=51; yt=46; ltext="��ǰ��ֹ�о� (N=%cmpres(&N11.))$&reason_2."; output;
run;

data FINAL;
	set BOX LINK CTEXT LTEXT;
run;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=18.0cm height=11.0cm noborder;
goptions device=emf;
ods listing gpath="&outdir.\figures" image_dpi=400; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods graphics off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


*��ͼ�����;
%macro plot();
proc sgplot data=final noborder noautolegend;
polygon id=boxid x=xb y=yb;
series x=xl y=yl / group=linkid lineattrs=graphdatadefault arrowheadpos=end arrowheadshape=filled;
text x=xt y=yt text=ctext / splitchar='$' splitpolicy=splitalways textattrs=(size=6 family="����");
text x=xt y=yt text=ltext / splitchar='$' splitpolicy=splitalways textattrs=(size=6 family="����") position=right;
xaxis display=none min=0 max=100 offsetmin=0 offsetmax=0;
yaxis display=none min=0 max=200 offsetmin=0 offsetmax=0;
run;
%mend;
%plot;
ods rtf close;
ods listing;
ods results on;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);

