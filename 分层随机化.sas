
*�ֲ����������;


dm "log;clear;";
proc datasets lib=work kill nolist memtype=data;run;
quit;

%macro currentroot;
%global currentroot currentpath;
%let currentroot= %sysfunc(getoption(sysin));
%if "&currentroot" eq "" %then %do;
%let currentroot= %sysget(SAS_EXECFILEPATH);
%let currentpath=%sysfunc(prxchange(s/(.*)\\.*/\1/, -1, &currentroot));
%end;
%mend;
%currentroot;
%put &currentroot;
%let root=%substr(%str(&currentroot),1,%index(%str(&currentroot), %str(\pg\))); %put &root;
%include "&root.pg\other\setup.sas";

/*��������ֲ�����*/
data ds2;
	set raw.ds2(where=(^missing(dsid)));
	proc sort;by DSSTA1_U DSID;
run;

/*�õ�ÿ�������*/
proc sql noprint;
	select count(distinct usubjid)  into: totn1 trimmed from ds2 where DSSTA1_U="1";
	select count(distinct usubjid)  into: totn2 trimmed from ds2 where DSSTA1_U="2";
quit;

%put &totn1. &totn2.;

/*������vs��ο�� 3:1,block������4*/
%let hierBlk_blk_NO=%sysfunc(ceil(&totn1./4));*ÿ���е�������Ŀ;
%let hierBlk_blk_LEN=4;	        *���鳤��;
%let hierBlk_seed=20221113;	    *������ӣ�ͨ��ȡֵΪ��ǰ���ڵ�;

%let hierBlk_blk_NO1=%sysfunc(ceil(&totn2./4));*ÿ���е�������Ŀ;
%let hierBlk_seed1=88888888;	    *������ӣ�ͨ��ȡֵΪ��ǰ���ڵ�;

%put &hierBlk_blk_NO. hierBlk_blk_NO1;

/*�����1 ��ȫ���*/
proc plan seed=&hierBlk_seed.;
    factors block= &hierBlk_blk_NO.
            length= &hierBlk_blk_LEN. / noprint;
    output out=hierBlk_export00;
quit;

/*�����2 ��ȫ���*/
proc plan seed=&hierBlk_seed1.;
    factors block= &hierBlk_blk_NO1.
            length= &hierBlk_blk_LEN. / noprint;
    output out=hierBlk_export01;
quit;

data dummydata;
	set hierBlk_export00(obs= &totn1.) hierBlk_export01(obs= &totn2.);
run;
 
proc format;
	value arm
	0="������"
	1="������"
	;
quit;

data final(rename=(dsid=randid));
	merge ds2 dummydata;
	if length<=3 then group=0;
	else if length=4 then group=1;
	arm = put(group, arm.);
	keep DSID arm;
run;

proc export data=final outfile="&root.data\random\dummy.xlsx"
	dbms=excel replace;
run;

