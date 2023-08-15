/*==========================================================================================*
Sponsor Name        : 福建海西新药创制有限公司
Study   ID          : HXP019-CTPI-01
Project Name        : 一项评价口服 C019199 片单次和多次给药在中国局部晚期或转移性实体瘤患者中的安全性、 耐受性、 药代动力学特征和抗肿瘤活性的多中心、 开放、 剂量递增的 I 期临床研究
Program Name        : F-1-1-1.sas
Program Path        : E:\Project\HXP019-CTPI-01\csr\dev\pg\figures
Program Language    : SAS v9.4
_____________________________________________________________________________________________
 
Purpose             : to create output F-01-01-01.rtf
 
Macro Calls         : %Mstrtrtf2, %preview 
 
Input File          : ADSL,ADPC
Output File         : E:\Project\HXP019-CTPI-01\csr\dev\output\figures\F-01-01-01.rtf
 
_____________________________________________________________________________________________
Version History     : 
Version     Date           Programmer                Description
-------     ----------     ----------                -----------
1.0         2022-06-09     weineng.zhou              Creation
 
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
%let pgmname = f-1-1-1.sas;
%let outname = f010101;


data adpc;
	set ads.adpc;
	where pkcsfl='Y' and periodc="0" and paramcd="C019199";
	linear=CONCPK;
	Semi=CONCPK;
	proc sort;
	by trt01an trt01a atptn atpt;
run;


ods html close;
ods output summary=linear_Semi;
proc means data=adpc n mean stddev ;
	by trt01an trt01a atptn atpt;
	var linear Semi;
run;

ods output summary=minmax;
proc means data=adpc n min max;
	var linear Semi;
run;
data _null_;
	set minmax;
	call symputx("LINEAR_MIN",LINEAR_MIN);
	call symputx("LINEAR_MAX",LINEAR_MAX);
	call symputx("SEMI_MAX",SEMI_MAX);
	call symputx("SEMI_MAX",SEMI_MAX);
run;


data final;
	set linear_Semi;
	informat _all_;
	format _all_;
	if cmiss(linear_mean,linear_stddev)=0 then do;
		linear_lower=linear_mean-linear_stddev;
		linear_upper=linear_mean+linear_stddev;		
	end;
	if cmiss(Semi_mean,Semi_stddev)=0 then do;
		Semi_lower=Semi_mean-Semi_stddev;
		Semi_upper=Semi_mean+Semi_stddev;
	end;
	array numvar _numeric_;
	do over numvar;
		if prxmatch("/Semi/i",vname(numvar)) then do;
			if numvar<=0 then numvar=.;
		end;
	end;
	keep trt01an trt01a atptn linear_mean linear_lower linear_upper Semi_mean Semi_lower Semi_upper;
run;


data figdat.&outname.;
	set final;
	proc sort;
	by trt01an trt01a atptn;
run;


%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=8in height=4in;
ods listing gpath="&outdir.\figures" image_dpi=300; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


proc template;
	define statgraph PKPlot;
		begingraph / border=false backgroundcolor = white /* datacontrastcolors=( white ) datacolors=( ) */;	

			discreteattrmap name='trt';
				value 'C019199 50 mg QD' / markerattrs=(symbol=trianglefilled color=cx0000FF size=6)   lineattrs=(color=cx0000FF pattern=solid);
				value 'C019199 100 mg QD' / markerattrs=(symbol=squarefilled color=cxFF0000 size=6)    lineattrs=(color=cxFF0000 pattern=MediumDash) ;
				value 'C019199 200 mg QD' / markerattrs=(symbol=circlefilled color=cx008200 size=6)    lineattrs=(color=cx008200 pattern=MediumDashShortDash);
				value 'C019199 300 mg QD' / markerattrs=(symbol=starfilled color=cxFF7F0E size=6)      lineattrs=(color=cxFF7F0E pattern=LongDash);
				value 'C019199 450 mg QD' / markerattrs=(symbol=diamondfilled color=cx00C2C0 size=6)   lineattrs=(color=cx00C2C0 pattern=LongDashShortDash);
				value 'C019199 600 mg QD' / markerattrs=(symbol=homedownfilled color=cx00bc57 size=6)  lineattrs=(color=cx00bc57 pattern=Dash);
			enddiscreteattrmap;
			discreteattrvar attrvar=trt_map var=trt01a attrmap='trt';

			legendItem type=text name="group" / text="Treatment" ;
			legendItem type=MARKERLINE  name="item1" / markerattrs=(symbol=trianglefilled color=cx0000FF size=6) lineattrs=(color=cx0000FF pattern=solid) label="50 mg QD" ;
			legendItem type=MARKERLINE  name="item2" / markerattrs=(symbol=squarefilled color=cxFF0000 size=6)   lineattrs=(color=cxFF0000 pattern=MediumDash) label="100 mg QD" ;
			legendItem type=MARKERLINE  name="item3" / markerattrs=(symbol=circlefilled color=cx008200 size=6)   lineattrs=(color=cx008200 pattern=MediumDashShortDash) label="200 mg QD" ;
			legendItem type=MARKERLINE  name="item4" / markerattrs=(symbol=starfilled color=cxFF7F0E size=6)     lineattrs=(color=cxFF7F0E pattern=LongDash) label="300 mg QD" ;
			legendItem type=MARKERLINE  name="item5" / markerattrs=(symbol=diamondfilled color=cx00C2C0 size=6)  lineattrs=(color=cx00C2C0 pattern=LongDashShortDash) label="450 mg QD" ;
			legendItem type=MARKERLINE  name="item6" / markerattrs=(symbol=homedownfilled color=cx00bc57 size=6) lineattrs=(color=cx00bc57 pattern=Dash) label="600 mg QD" ;

			layout lattice / columns=2 rows=1 columngutter=1cm rowgutter=1cm border=false;

			  cell;
				  cellheader;
           	   	    entry "Linear Scale" / border=false;
          		  endcellheader;

				    layout overlay/cycleattrs=true /* walldisplay = none */
						xaxisopts=(
							griddisplay=off label="Time(h)"
							labelattrs=(family="Times New Roman" size=12pt weight=bold)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							linearopts=(viewmin=0 viewmax=96 tickvaluesequence=(start=0 end=96 increment=12) ) 
						)
						yaxisopts=(
							griddisplay=off label="Concentration(ng/mL)" 
							labelattrs=(family="Times New Roman" size=12pt weight=bold)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							linearopts=(viewmin=0 viewmax=2500 tickvaluesequence=(start=0 end=2500 increment=100 ) ) 
						);

						seriesplot  x=atptn y=linear_mean / name="line" group=trt_map ;
						scatterplot x=atptn y=linear_mean / name="dot" group=trt_map yerrorlower=linear_lower yerrorupper=linear_upper;

				    endlayout;
			   endcell;


			   cell;
				  cellheader;
           	     	 entry "Semi-Logarithmic Scale" / border=false;
          		  endcellheader;		  	
	
					layout overlay/cycleattrs=true /* walldisplay = none */
						xaxisopts=(
							griddisplay=off label="Time(h)"
							labelattrs=(family="Times New Roman" size=12pt weight=bold )
							tickvalueattrs=(size=8pt family="Times New Roman")
/*							type=linear*/
							linearopts=(viewmin=0 viewmax=96 tickvaluesequence=(start=0 end=96 increment=12))  
						)
						yaxisopts=(
							griddisplay=off 
							display=(ticks tickvalues label line)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							label="Concentration(ng/mL)" 
							labelattrs=(family="Times New Roman" size=12pt weight=bold)							
							type=log
							logopts=(
								base=10
								tickvaluepriority=true 
								tickintervalstyle=logexpand
								tickvaluelist = ( 1 10 100 1000 10000)
							) 
						);

						seriesplot  x=atptn y=semi_mean / name="line" group=trt_map ;
						scatterplot x=atptn y=semi_mean / name="dot" group=trt_map yerrorlower=semi_lower yerrorupper=semi_upper;

					endlayout;
				 endcell;

				 sidebar / align=bottom;
						discretelegend "item1" "item2" "item3" "item4" "item5" "item6" / valueattrs=(family="Times New Roman" size=8pt)
						title='Treatment' location=outside opaque=true halign=center valign=center border=true pad=(left=0px right=0px);
			     endsidebar;

			endlayout; *layout lattice / columns=2 rows=1 columngutter=1cm rowgutter=1cm border=false;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final template=PKPlot;
run;

ods rtf close;
ods listing;
ods results on;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
