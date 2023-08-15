

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
%let pgmname = f-14-2-3-4.sas;
%let outname = F14020304;


%let Lib    = ads;
%let adam   = adtr;
%let TrtVar = trt01a;
%let AnaSet = %str(PPROTFL="Y");


proc sql noprint;
	select max(&TrtVar.N) into :trtmax
	from &lib..adsl;
quit;
%put &trtmax.;


data adsl;
	set &lib..adsl(in=a where=(&AnaSet.)) end=last;
	if last then call symputx('total', _N_);
	output;
	if &AnaSet. then do;
		&trtVar="Total";
		&trtVar.N=&trtmax.+1;
		output;
	end;
run;

* calculate BigN;
proc freq data=adsl noprint;
	table &trtVar.N*&trtVar / out=BigN(rename=(count=bigN) drop=percent);
run;

data _null_;
	set BigN;
    call symputx('N'||strip(put(_N_, best.)), bigN);
run;
%put &N1 &N2 &N3;


data &adam.;
	merge &lib..adsl(in=a where=(&AnaSet.)) &lib..&adam.(in=b) ;
	by usubjid;
	if a and b;	
run;


data screen_&adam.;
	set &adam.;
	if ANL01FL="Y" and paramcd="SUMDIAM";
	if CYCLE="基线" then do; 
		CYCLEN=0;
		PCHG=0;
	end;
	else if CYCLE="治疗结束/提前退出" then CYCLEN=99;
	else CYCLEN=input(prxchange("s/(\w)(\d+)(\w)(\d+)/$2/",-1,CYCLE),??best.);
	keep USUBJID MHDIAG INVBEST EOSSTT trt01aN trt01a CYCLEN CYCLE PARAMCD PCHG;
	proc sort;
	by usubjid CYCLEN;
run;


data final;
	set screen_&adam.;
	_CYCLEN=lag(CYCLEN);
	if CYCLEN=99 and _CYCLEN=0 then CYCLEN=1;
	if CYCLEN=99 and _CYCLEN^=0 then CYCLEN=_CYCLEN+2;
	drop _CYCLEN;
run;


data figdat.&outname.;
	set final;
	informat _all_;
	format _all_;
	keep USUBJID MHDIAG INVBEST EOSSTT trt01an trt01a CYCLEN CYCLE PARAMCD PCHG;
	proc sort ;
	by usubjid;
run;


proc sql noprint;
	select count(distinct mhdiag) into: catn separated by ''
	from final;
	select distinct mhdiag into: mhdiag_list separated by '|'
	from final;
quit;
%put &mhdiag_list.;
%put &sqlobs;


data random_color;
	do i = 1 to &catn.;
		R = (0 + floor((1 + 255 - 0) * rand("uniform")));
		G = (0 + floor((1 + 255 - 0) * rand("uniform")));
		B = (0 + floor((1 + 255 - 0) * rand("uniform")));
		R1 = put(R,hex.);
		G1 = put(G,hex.);
		B1 = put(B,hex.);
		random_color = cats("cx",substr(R1,7,2), substr(G1,7,2), substr(B1,7,2));
		output;
	end;
run;

proc sql noprint;
	select random_color into: color_list separated by ' '
	from random_color;
quit;
%put &color_list.;

%let symbol_list = trianglefilled squarefilled circlefilled starfilled diamondfilled homedownfilled
				  trianglefilled squarefilled circlefilled starfilled diamondfilled homedownfilled
			      trianglefilled squarefilled circlefilled starfilled diamondfilled homedownfilled;

options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=8in height=4in; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods listing gpath="&outdir.\figures" image_dpi=300;
ods listing close;
ods results off;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 

/*%let color1 = cx0000FF;*/
/*%let color2 = cxFF0000;*/

proc template;
	define statgraph SpiderPlot;
		begingraph / border=false backgroundcolor = white /* datacontrastcolors=( white ) datacolors=( ) */;	
			entrytitle "percent change in tumor size from baseline by cycle";

/*			discreteattrmap name='restype';				*/
/*				value 'SD' / markerattrs=(symbol=trianglefilled color=&color1. size=10) lineattrs=(color=&color1. pattern=solid);*/
/*				value 'PD' / markerattrs=(symbol=squarefilled color=&color2. size=10) lineattrs=(color=&color2. pattern=solid);				*/
/*			enddiscreteattrmap;*/
/*			discreteattrvar attrvar=resn_map var=INVBEST attrmap='restype';*/

			discreteattrmap name='diag';
				%macro valueloop;
					%do i=1 %to &catn;
						%let mhdiag = %scan(&mhdiag_list, &i, %str(|));
						%let symbol = %scan(&symbol_list, &i, %str( ));
						%let color  = %scan(&color_list, &i, %str( ));
							value "&mhdiag." / markerattrs=(symbol=&symbol. color=&color. size=6) lineattrs=(color=&color. pattern=solid);
					%end;
				%mend;
				%valueloop;
			enddiscreteattrmap;
			discreteattrvar attrvar=diag_map var=MHDIAG attrmap='diag';

			*legendItem type=text name="group" / text="Treatment" ;
			
			%macro legendloop;
				%do i=1 %to &catn;					
					%let mhdiag = %scan(&mhdiag_list, &i, %str(|));
					%let symbol = %scan(&symbol_list, &i, %str( ));
					%let color  = %scan(&color_list, &i, %str( ));
						legendItem type=MARKERLINE  name="item&i" / markerattrs=(symbol=&symbol. color=&color. size=6) 
						lineattrs=(color=&color. pattern=solid) label="&mhdiag." ;
				%end;
			%mend;
			%legendloop;
			
			*layout lattice / columns=1 rows=2 Rowweights=(0.8 0.2) columngutter=1cm rowgutter=1cm border=false;

				    layout overlay/cycleattrs=true /* walldisplay = none */
						xaxisopts=(
							griddisplay=off label="Cycle"
							labelattrs=(family="Times New Roman" size=8pt weight=bold)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							linearopts=(viewmin=0 viewmax=11 tickvaluesequence=(start=0 end=11 increment=1)) 
						)
						yaxisopts=(
							griddisplay=off label="percent change in tumor size from baseline by cycle" 
							labelattrs=(family="Times New Roman" size=8pt weight=bold)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							linearopts=(viewmin=-40 viewmax=40 tickvaluesequence=(start=-40 end=40 increment=20 ) ) 
						);

						referenceline y=20 / lineattrs=(color=cxFF0000 thickness=1 pattern=dash) curvelabel="20%";
						referenceline y=-30 / lineattrs=(color=cx00C2C0 thickness=1 pattern=dash) curvelabel="-30%";

						seriesplot  x=CYCLEN y=PCHG / name="line" group=usubjid linecolorgroup=diag_map
						lineattrs=(thickness=1 pattern=solid) groupdisplay=overlay break=true;

						scatterplot x=CYCLEN y=PCHG / name="dot" group=diag_map;

						discretelegend 
						%macro Itemloop;
							%do i=1 %to &catn;
								"item&i." 
							%end;
						%mend;
						%Itemloop
						/ title='疾病诊断' titleattrs=(family="宋体" size=8pt) valueattrs=(family="宋体" size=8pt) 
						location=outside opaque=true valign=center halign=right border=true pad=(left=0px right=0px) across=1;

				    endlayout;

/*					layout gridded /valign=top halign=right border=false;*/
/*						discretelegend "item1" "item2" / valueattrs=(family="Times New Roman" size=8pt) title='Response' */
/*						location=inside opaque=true valign=top halign=right border=true pad=(left=0px right=0px) across=1;*/
/*					endlayout;*/

/*					sidebar / align=bottom;*/
/*						discretelegend "item1" "item2" / valueattrs=(family="Times New Roman" size=8pt) title='Response' */
/*						location=outside opaque=true valign=top halign=right border=true pad=(left=0px right=0px) /*across=0*/;*/
/*				    endsidebar;*/

			endlayout; *layout lattice / columns=2 rows=1 columngutter=1cm rowgutter=1cm border=false;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final template=SpiderPlot;
run;

ods rtf close;
ods listing;


%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
