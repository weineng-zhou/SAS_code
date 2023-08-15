/*==========================================================================================*
Sponsor Name        : 杭州翰思生物医药有限公司
Study   ID          : HX009-II-02
Project Name        : 重组人源化抗 CD47/PD-1 双功能抗体 HX009 注射液治疗中国复发/难治性淋巴瘤患者的多中心、 开放、 单臂的Ⅰ /Ⅱ 期临床研究
Program Name        : f-14-3-4-1-1.sas
Program Path        : E:\Project\HX009-II-02\csr\dev\pg\figures
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output F-14-03-04-01-01.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : 
Output File         : E:\Project\HX009-II-02\csr\dev\output\figures\F-14-03-04-01-01.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-09-30     weineng.zhou              Creation
 
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
%let pgmname = f-14-3-4-1-1.sas;
%let outname = F1403040101;


proc format;
	value avisit
	0="基线"
	1="C1*D1"	
	2="C1*D2"	
	3="C1*D4"	
	4="C1*D8"	
	5="C2*D1"
	6="C2D14*/C3D1"	
	7="C3*D1"
	8="C4*D1"
	9="C5*D1"
	10="C6*D1"
	11="C7*D1"
	12="C8*D1"
	13="C9*D1"
	14="C10*D1"
	15="C11*D1"
	16="C12*D1"
	17="C13*D1"
	18="C14*D1"
	19="C15*D1"
	20="C16*D1"
	21="C17*D1"
	22="C18*D1"
	23="C19*D1"
	24="C20*D1"
	25="C21*D1"
	26="C22*D1"
	27="C23*D1"
	28="C24*D1"
	997="治疗结束*访视"
	;
quit;


%let lib=ads;
%let AnaSet=SAFFL;
%let adam=adlb;

%let trt1=7.5mg/kg;
%let trt2=10mg/kg;
%let trt3=15mg/kg;
%let trt4=合计;

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


data adlb;
	set ads.adlb(where=(&AnaSet.="Y" and paramcd="PLAT" and 0<avisitn<999 ));
	linear=chg;
	output;
	&trtvar.N=&trtmax.;
	&trtvar.="合计";
	output;
	proc sort;
	by &trtvar.N &trtvar. avisitn avisit;
run;


ods output summary=linear;
proc means data=adlb n mean stddev ;
	by &trtvar.N &trtvar. avisitn avisit;
	var linear;
run;

ods output summary=minmax;
proc means data=adlb n min max;
	var linear;
run;
data _null_;
	set minmax;
	call symputx("LINEAR_MIN",LINEAR_MIN);
	call symputx("LINEAR_MAX",LINEAR_MAX);
run;


data final;
	set linear;
	informat _all_;
	format _all_;
	if cmiss(linear_mean,linear_stddev)=0 then do;
		linear_lower=linear_mean-linear_stddev;
		linear_upper=linear_mean+linear_stddev;		
	end;
	keep &trtvar.N &trtvar. avisitn avisit linear_mean linear_lower linear_upper;
run;


data figdat.&outname.;
	set final;
	proc sort;
	by &trtvar.N &trtvar. avisitn;
run;


%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=11.0cm; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods listing gpath="&outdir.\figures" image_dpi=300; 
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


%let color1=cx00bc57;
%let color2=cxF92672;
%let color3=cx00b8e5;
%let color4=cxFF7F0E;


proc template;
	define statgraph PKPlot;
		begingraph / border=false backgroundcolor = white /* datacontrastcolors=( black ) datacolors=( ) */;	

			discreteattrmap name='trt';
				value '1' / markerattrs=(symbol=trianglefilled color=&color1. size=6) lineattrs=(color=&color1. pattern=solid);
				value '2'  / markerattrs=(symbol=squarefilled  color=&color2. size=6) lineattrs=(color=&color2. pattern=solid);
				value '3'  / markerattrs=(symbol=circlefilled color=&color3. size=6) lineattrs=(color=&color3. pattern=solid);
				value '4'               / markerattrs=(symbol=squarefilled color=&color4. size=6) lineattrs=(color=&color4. pattern=solid);
			enddiscreteattrmap;
			discreteattrvar attrvar=trt_map var=&trtvar.N attrmap='trt';
			
			legendItem type=MARKERLINE  name="item1" / markerattrs=(symbol=trianglefilled color=&color1. size=6) lineattrs=(color=&color1. pattern=solid) label="&trt1" ;
			legendItem type=MARKERLINE  name="item2" / markerattrs=(symbol=squarefilled color=&color2. size=6) lineattrs=(color=&color2. pattern=solid) label="&trt2" ;
			legendItem type=MARKERLINE  name="item3" / markerattrs=(symbol=circlefilled color=&color3. size=6) lineattrs=(color=&color3. pattern=solid) label="&trt3" ;
			legendItem type=MARKERLINE  name="item4" / markerattrs=(symbol=squarefilled color=&color4. size=6) lineattrs=(color=&color4. pattern=solid) label="&trt4" ;
			
			layout lattice / columns=1 rows=1 columngutter=1cm rowgutter=1cm border=false;

				    layout overlay/cycleattrs=true walldisplay = none 
						xaxisopts=(
							griddisplay=off label="访视"							
							labelattrs=(family="宋体" size=8pt weight=bold)
							type=discrete
							tickvalueattrs=(size=4pt family="宋体") 
							discreteopts=(tickvaluefitpolicy=splitalways tickvaluesplitchar="*")
							linearopts=(viewmin=0 viewmax=30 tickvaluesequence=(start=0 end=30 increment=1) ) 
						)
						yaxisopts=(
							griddisplay=off label="血小板较基线变化均值±标准差" 
							labelattrs=(family="宋体" size=8pt weight=bold)
							tickvalueattrs=(size=8pt family="宋体") 
							linearopts=(viewmin=-120 viewmax=130 tickvaluesequence=(start=-120 end=130 increment=20 ) ) 
						);

						seriesplot  x=avisitn y=linear_mean / name="line" group=trt_map ;
						scatterplot x=avisitn y=linear_mean / name="dot" group=trt_map yerrorlower=linear_lower yerrorupper=linear_upper;

						layout gridded /halign=0.8 valign=0.95 border=false;
				            discretelegend "item1" "item2" "item3" "item4" / valueattrs=(family="宋体" size=8pt ) 
							title='治疗组' titleattrs=(family="宋体" size=8pt )
							location=inside opaque=true border=false pad=(left=1px right=20px) across=1;
				        endlayout;

				    endlayout;

			endlayout; *layout lattice / columns=2 rows=1 columngutter=1cm rowgutter=1cm border=false;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final template=PKPlot;
	format avisitn avisit.;
run;

ods rtf close;
ods listing;


%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
