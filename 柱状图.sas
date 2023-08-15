/*==========================================================================================*
Sponsor Name        : 珐博进（中国） 医药技术开发有限公司（珐博进中国）
Study   ID          : FGCL-4592-858
Project Name        : 一项评估罗沙司他低起始剂量给药方案治疗慢性肾脏病非透析贫血患者的有效性和安全性的随机、 对照、 开放标签、 多中心研究
Program Name        : f-14-2-1-7.sas
Program Path        : E:\Project\FGCL-4592-858\csr\dev\pg\figures
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output T-14-02-01-07.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : ADLB
Output File         : E:\Project\FGCL-4592-858\csr\dev\output\figures\T-14-02-01-07.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-11-18     weineng.zhou              Creation
 
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
%let pgmname = f-14-2-1-7.sas;
%let outname = F14020107;


%let lib=ads;
%let AnaSet=FASFL;
%let adam=adlb;


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
/*	value trtp*/
/*	1="Lower Dose"*/
/*	2="Standard Dose"*/
/*	3="Total"*/
/*	;*/
	/*	value avisit*/
/*	-2="SCREENING"*/
/*	-1="BASELINE, Day 1"*/
/*	0="BASELINE"*/
/*	2="Week 2"*/
/*	4="Week 4"*/
/*	6="Week 6"*/
/*	8="Week 8"*/
/*	12="Week 12"*/
/*	16="Week 16"*/
/*	20="Week 20,Follow-up"*/
/*	;*/
	value trtp
	1="低起始剂量组"
	2="标准起始剂量组"
	3="合计"
	;
	value avisit
	0="基线"
	2="第2周"
	4="第4周"
	6="第6周"
	8="第8周"
	12="第12周"
	16="第16周"
	18="12-16周"
	20="第20周(随访)"
	;
quit;



proc sql noprint;
	select max(&trtvar.N)+1 into :trtmax separated by ''
	from &lib..adsl;
quit;
%put &trtmax.;

data adsl;
	set &lib..adsl(in=a where=(&AnaSet.="Y")) end=last;
	if last then call symputx('total', _N_);
	output;
	&trtvar.="Total";
	&trtvar.N=&trtmax.;
	output;
run;

* calculate BigN;
proc freq data=adsl noprint;
	table &trtvar.N*&trtvar. / out=BigN(rename=(count=bigN) drop=percent);
run;
data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), BigN);
run;
%put &N1 &N2 &N3 ;


data dummy;
	do &trtvar.N=1 to 2;
		&trtvar.=put(&trtvar.N, trtp.);
		do avisitn=2,4,6,8,12,16,20;
			do efffl="N","Y";
				count=0;
				output;
			end;
		end;
	end;
	proc sort;
	by &trtvar.N &trtvar. avisitn efffl;
run;


*基于二项分布假设的逻辑回归;
data adlb;
	set ads.adlb(where=(&AnaSet.="Y" & ANL01FL="Y" & paramcd in("HGB") ));
	if avisitn in (2 4 6 8 12 16);
	if 100<=aval<=120 then efffl='Y'; else efffl="N";
	output;
	*&trtvar.n=3;
	*&trtvar.="Total";
	*output;
	keep usubjid &trtVar.N &trtVar. paramn param avisitn avisit efffl;
	proc sort;
	by usubjid paramn param avisitn ;
run;


data adeff;
	set ads.adeff(where=(&AnaSet.="Y" & paramcd in ("HB100120") ));
	if not missing(avalc);
	efffl=avalc;
	paramn=29;
	param="血红蛋白(g/L)";	
	avisitn=18;
	avisit="第12-16周";
	output;
	*&trtVar.N=&trtmax.; 
	*&trtVar.='Total';
	*output;
	keep usubjid &trtVar.N &trtVar. paramn param avisitn avisit efffl;
	proc sort; 
	by paramn param avisitn;
run;


data Y_bin;
	length param avisit $200;
	set adlb adeff;
	proc sort; 
	by paramn param avisitn;
run;

*组内各访视内的有效率;
proc freq data=Y_bin noprint;
	table &trtVar.N*&trtVar.*paramn*param*avisitn*avisit*efffl / out=freq_bin(drop=percent);
run;


data EFFFL_Y;
	set freq_bin(rename=(count=EFFFL_Y));
	where EFFFL="Y";
	proc sort;
	by &trtvar.N;
run;


proc freq data=freq_bin;
	by &trtvar.n &trtvar. avisitn;
	table EFFFL / binomial(level='Y' cl=all) alpha=0.05;
	weight count / zeros;
	ods output binomialcls=rate_CI(where=(prxmatch("/Pearson/",type)));
run;


data rate_CI;
	merge rate_CI EFFFL_Y;
	by &trtvar.N &trtvar. AVISITN;
	if missing(EFFFL_Y) then EFFFL_Y=0;
	n_pct=strip(put(EFFFL_Y,best.))||" ("||strip(put(100*PROPORTION, pct.))||")";
	if cmiss(LOWERCL,UPPERCL)=0 then CI=strip(put(LOWERCL*100,8.1))||", "||strip(put(UPPERCL*100,8.1));
run;


data final;
	set rate_CI;
	n=EFFFL_Y;
	linear_mean=100*PROPORTION;
	if cmiss(linear_mean,LOWERCL)=0 then do;
		linear_lower=LOWERCL*100;
		linear_upper=UPPERCL*100;		
	end;
	linear_mean=round(linear_mean,0.01);
	linear_lower=round(linear_lower,0.01);
	linear_upper=round(linear_upper,0.01);
	keep &trtvar.N &trtvar. avisitn n linear_mean linear_lower linear_upper;
run;


*横坐标刻度;
proc sql noprint;
	select min(avisitn) into :visitmin separated by '' from final;
	select max(avisitn) into :visitmax separated by '' from final;
quit;
%put &visitmin;
%put &visitmax;


proc sql noprint;
	select min(linear_lower) into :LINEAR_MIN separated by ''
	from final;
	select max(linear_upper) into :LINEAR_MAX separated by ''
	from final;
quit;
%put &LINEAR_MIN.;


*右上角显示文本;
*基于二项分布假设的逻辑回归;
%let adam=adeff;
data &adam.;
	set ads.&adam.(where=(&AnaSet.="Y" & paramcd in ("HB100120") ));
	if not missing(avalc);
	output;
	*&trtvar.N=&trtmax.; 
	*&trtvar.='Total';
	*output;
	keep usubjid &trtvar.N &trtvar. paramn paramcd param avalc;
	proc sort; 
	by paramn param;
run;


*协变量;
data temp;
	set &adam.;
run;
proc sql noprint;
	create table &adam. as 
	select a.*, b.HGBBL, input(b.GFR,best.) as eGFR
	from temp a left join ads.adsl b on a.usubjid=b.usubjid
	order by paramn
;
quit;


*统计模型;
*ods trace on;
proc sort data=&adam.; by paramn param; run;
ods output OddsRatios=OddsRatios OddsRatiosWald=OddsRatiosWald ParameterEstimates=ParameterEstimates;
proc logistic data=&adam.;
	by paramn param;
	class &trtvar.N;
	model avalc(event='Y')=&trtvar.N HGBBL eGFR ;
	oddsratio &trtvar.N ;
run;
*ods trace off;

data _null_;
	set OddsRatiosWald;
	if EFFECT="TRT01PN 1 vs 2";
	call symputx('OddsRatio',strip(put(ODDSRATIOEST,8.3))||" ("||strip(put(LOWERCL,8.3))||", "||strip(put(UPPERCL,8.3))||")");
run;
%put &OddsRatio.;


data figdat.&outname.;
	length &trtvar. $200;
	set final;
	informat _all_;
	format _all_;
	attrib _all_ label='';
	proc sort;
	by &trtvar.N avisitn;
run;


/*%if %sysfunc(exist(vfigdat.&outname.)) %then %do;*/
/*	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));*/
/*%end;*/


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=6in height=4in;
ods listing gpath="&outdir.\figures" image_dpi=300; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


%let color1=cx00b8e5;
%let color2=cxF92672;


proc template;
	define statgraph Barplot;
		begingraph / border=false backgroundcolor = white datacontrastcolors=( &color1. &color2. ) datacolors=(&color1. &color2. ) ;	

			discreteattrmap name='grp';
				value '1' / markerattrs=(symbol=squarefilled color=&color1. size=4) lineattrs=(color=&color1. pattern=solid);
				value '2' / markerattrs=(symbol=squarefilled color=&color2. size=4) lineattrs=(color=&color2. pattern=dash);
				*value '3' / markerattrs=(symbol=squarefilled color=&color3. size=8) lineattrs=(color=&color3. pattern=solid);
			enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar._map var=&trtvar.N attrmap='grp';

			discreteattrmap name = "smalln" / ignorecase = true;
                value "1"  / textattrs=(color = &color1. size=8);
                value "2"  / textattrs=(color = &color2. size=8);
            enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar._legend var=&trtvar.N attrmap='smalln';			
			
			*legendItem type=MARKERLINE  name="item1" / markerattrs=(symbol=trianglefilled color=&color1. size=8) lineattrs=(color=&color1. pattern=solid) label="Lower Dose (N=&N1.)" ;
			*legendItem type=MARKERLINE  name="item2" / markerattrs=(symbol=circlefilled color=&color2. size=8) lineattrs=(color=&color2. pattern=dash) label="Standard Dose (N=&N2.)" ;
			*legendItem type=MARKERLINE  name="item3" / markerattrs=(symbol=squarefilled color=&color3. size=8) lineattrs=(color=&color2. pattern=solid) label="Total" ;
			legendItem type=MARKER  name="item1" / markerattrs=(symbol=squarefilled color=&color1. size=8) lineattrs=(color=&color1. pattern=solid) label="&trt1. (N=&N1.)" ;
			legendItem type=MARKER  name="item2" / markerattrs=(symbol=squarefilled color=&color2. size=8) lineattrs=(color=&color2. pattern=dash) label="&trt2. (N=&N2.)" ;
			
			layout lattice / columns=1 rows=2 Rowweights=(1.0 0) columngutter=2cm rowgutter=0.5cm border=false;

			cell;
				  cellheader;
           	   	    entry " " / border=false;
          		  endcellheader;

				    layout overlay/cycleattrs=true walldisplay = none /*(fill outline)*/
						xaxisopts=(
							griddisplay=off 
							label="访视"
							labelattrs=(family="宋体" size=8pt weight=bold)							
							tickvalueattrs=(size=8pt family="宋体") 
/*							type=discrete*/
							discreteopts=(tickvaluefitpolicy=splitalways tickvaluesplitchar="*")
							linearopts=(
								viewmin=2 viewmax=20 tickvaluelist=( 2 4 6 8 12 16 20  )						
							) 
						)
						yaxisopts=(
							griddisplay=off 
							offsetmax=0.2
							label="比例 (95% CI)" 
							labelattrs=(family="宋体" size=8pt weight=bold )		
							labelfitpolicy=split	
							tickvalueattrs=(size=8pt family="宋体") 
/*							linearopts=(viewmin=&LINEAR_MIN viewmax=&LINEAR_MAX tickvaluesequence=(start=&LINEAR_MIN end=&LINEAR_MAX increment=10 ) )*/
							linearopts=(viewmin=0 viewmax=80 tickvaluesequence=(start=0 end=80 increment=10 ) ) 
						);

/*						drawtext textattrs=(family="Arial" size=8pt weight=bold) "Mean (+/- SE) Change from Baseline in Hemoglobin (Hb)" */
/*						/ x=-10 y=-25 anchor=left width=200 xspace=wallpercent yspace=datavalue rotate=90;*/
						
						barchartparm category=avisitn response=linear_mean / name="BAR" group=&trtvar.N 
						errorlower=linear_lower errorupper=linear_upper errorbarcapshape=serif						
						groupdisplay=cluster orient=vertical barwidth=0.9 dataskin=none datalabel=linear_mean 
						outlineattrs=(color=black) segmentlabeltype=none
						;

						*seriesplot  x=avisitn y=linear_mean / name="line" group=&trtvar._map ;
						*scatterplot x=avisitn y=linear_mean / name="dot" group=&trtvar._map yerrorlower=linear_lower yerrorupper=linear_upper
/*						datalabel=linear_mean datalabelattrs=(color=black)*/
						;

/*						drawtext textattrs=(size=8pt) "Number of Subjects" /anchor=bottomleft width=22 widthunit=percent*/
/*						xspace=wallpercent yspace=wallpercent x=5 y=15 justify=center;*/

/*						innermargin/align=bottom pad=0.8;*/
/*							axistable x=avisitn value=n / name='smalln' class=&trtvar. colorgroup=&trtvar._legend valueattrs=(size=8pt );*/
/*						endinnermargin;*/

						layout gridded /valign=0.95 halign=right border=false;  
							entry halign=right "12-16周 比值比: &OddsRatio."   /  textattrs=(family="宋体" size=8pt );
							*entry halign=right "p value:                  &pvalue."   / textattrs=(family="Arial" size=8pt);
				        endlayout;

/*						discreteLegend "item1" "item2" / valueattrs=(family="Arial" size=8pt) */
/*						title='Treatment' titleattrs=(family="Arial" size=8pt )*/
/*						location=outside opaque=true halign=center valign=bottom border=true*/
/*						pad=(left=0px right=0px) across=2;*/

				    endlayout;
				endcell;

/*				cell;*/
/*				    cellheader;*/
/*	           	   	  entry "" / border=false;*/
/*	          	    endcellheader;*/
/*				    layout overlay / walldisplay=NONE xaxisopts=(display=none */
/*				        linearopts=(viewmin=2 viewmax=20 tickvaluelist=( 2 4 6 8 12 16 20 ) )) border=false ;*/
/*				        entry halign=left "Proportion (%)" / location=outside valign=top textattrs=(size=8pt ) ; */
/*				        axistable x=avisitn value=linear_mean / display=(label) valueattrs=(size=8pt) class=&trtvar. colorgroup=&trtvar._map;*/
/*				    endlayout;*/
/*				endcell;*/

				sidebar / align=bottom;
					discretelegend  "item1" "item2" / valueattrs=(family="宋体" size=10pt ) 
					title="治疗组"  titleattrs=(family="宋体" size=8pt ) 
					location=outside opaque=true valign=bottom halign=center border=false across=2; *across用来显示legend,pad=(left=20px right=20px);
			    endsidebar;

			endlayout; *layout lattice / columns=1 rows=2 Rowweights=(0.80 0.2) columngutter=2cm rowgutter=0.5cm border=false;;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final template=Barplot;
	format avisitn avisit. ; *&trtvar.N  trtp.;
run;

ods rtf close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
