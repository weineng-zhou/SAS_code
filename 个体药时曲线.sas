
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
%let pgmname = F-3-1-1.sas;
%let outname = f030101;


data adpc;
	set ads.adpc;
	where pkcsfl='Y' and periodc="0" and paramcd="C019199";
	linear=CONCGRA;
	Semi=CONCGRA;
	proc sort;
	by trt01an trt01a subjid atptn atpt;
run;

proc freq data=adpc noprint;
	table trt01an*trt01a*subjid / out=freq(keep=trt01an trt01a subjid);
run;
data _null_;
	set freq end=last;
	call symputx("trt01a"||strip(put(_N_,best.)), trt01a);
	call symputx("subjid"||strip(put(_N_,best.)), subjid);
	if last then call symputx("maxiter", _N_);
run;
%put &trt01a1;
%put &subjid1;
%put &maxiter.;



proc freq data=adpc noprint;
	table trt01an*trt01a*subjid / out=freq(keep=trt01an trt01a subjid);
run;
data _null_;
	set freq end=last;
	call symputx("trt01a"||strip(put(_N_,best.)), trt01a);
	call symputx("subjid"||strip(put(_N_,best.)), subjid);
	if last then call symputx("maxiter", _N_);
run;
%put &trt01a1;
%put &subjid1;
%put &maxiter.;


*每个剂量组每个人的最大浓度;
proc means data=adpc noprint;
	by trt01an trt01a subjid;
	var atptn;
	output out=atptn_max min=min max=max;
run;

data _null_;
	set atptn_max;
	call symputx("atptn_max"||strip(put(_N_,best.)), max);
run;


*每个剂量组每个人的最大浓度;
proc means data=adpc noprint;
	by trt01an trt01a subjid;
	var CONCGRA;
	output out=minmax min=min max=max;
run;
data _null_;
	set minmax end=last;
/*	if mod(max,100)<50 then do;*/
/*		call symputx("maxc"||strip(put(_N_,best.)), round(max,100)+100);*/
/*		call symputx("increment"||strip(put(_N_,best.)), int((round(max,100)+100)/10) );*/
/*	end;*/
/*	if mod(max,100)>=50 then do;*/
/*		call symputx("maxc"||strip(put(_N_,best.)), round(max,100));*/
/*		call symputx("increment"||strip(put(_N_,best.)), int(round(max,100)/10) );*/
/*	end;*/
	call symputx("maxc"||strip(put(_N_,best.)), round(max,10)+10);
	call symputx("increment"||strip(put(_N_,best.)), int((round(max,10)+10)/10) );
run;
%put &maxc1.;
%put &maxc2.;
%put &increment1.;



*每个剂量组每个人的最大半对数浓度;
proc means data=adpc noprint;
	by trt01an trt01a subjid;
	var Semi;
	output out=Semi_minmax min=min max=max;
run;
data _null_;
	set Semi_minmax end=last;
	if mod(max,1)<0.5 then call symputx("maxlnc"||strip(put(_N_,best.)), round(max,1)+1);
	if mod(max,1)>=0.5 then call symputx("maxlnc"||strip(put(_N_,best.)), round(max,1));
run;
%put &maxlnc1.;


data final;
	set adpc;
	informat _all_;
	format _all_;
	array numvar _numeric_;
	do over numvar;
		if prxmatch("/Semi/i",vname(numvar)) then do;
			if numvar<=0 then numvar=.;
		end;
	end;
	keep subjid trt01an trt01a periodc atptn linear semi;
	proc sort;
	by trt01an trt01a subjid;
run;

data figdat.&outname.;
	set final;
	proc sort;
	by trt01an trt01a subjid;
run;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=8in height=4in;
ods listing gpath="&outdir.\figures" image_dpi=300;
ods results off;
ods listing close;  /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/

%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


%macro figloop;
%let i=0;
%do %while (&i<&maxiter.);
%let i=%eval(&i+1);

proc template;
	define statgraph PKPlot;
		begingraph / border=false backgroundcolor = white 
/*			datacontrastcolors=( white ) datacolors=( cxFF0000 cx0000FF )*/
			;

			entrytitle "剂量组=&&trt01a&i.  Subject ID=&&subjid&i.";

			discreteattrmap name='periodc_type';
				value '0' / markerattrs=(symbol=trianglefilled color=cxFF0000 size=8) lineattrs=(color=cxFF0000 pattern=solid );
			enddiscreteattrmap;
			discreteattrvar attrvar=periodc_map var=PERIODC attrmap='periodc_type';

			legendItem type=MARKERLINE  name="item1" / markerattrs=(symbol=trianglefilled color=cxFF0000 size=8) lineattrs=(color=cxFF0000 pattern=solid) label="单次给药";

			layout lattice / columns=2 rows=1 columnweights=(0.5 0.5) border=false;

			  cell;
				  cellheader;
           	   	    entry "Linear Scale" / border=false;
          		  endcellheader;

				    layout overlay/cycleattrs=true /* walldisplay = none */
						xaxisopts=(
							griddisplay=off label="Time(h)"
							labelattrs=(family="Times New Roman" size=12pt weight=bold)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							linearopts=(viewmin=0 viewmax=&&atptn_max&i tickvaluesequence=(start=0 end=&&atptn_max&i increment=3)) 
						)
						yaxisopts=(
							griddisplay=off label="Concentration(ng/mL)" 
							labelattrs=(family="Times New Roman" size=12pt weight=bold)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							linearopts=(viewmin=0 viewmax=&&maxc&i tickvaluesequence=(start=0 end=&&maxc&i increment=&&increment&i ) ) 
						);

						seriesplot  x=atptn y=linear / name="line" group=periodc_map ;
						scatterplot x=atptn y=linear / name="dot" group=periodc_map ;

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
							linearopts=(viewmin=0 viewmax=&&atptn_max&i tickvaluesequence=(start=0 end=&&atptn_max&i increment=3))  
						)
						yaxisopts=(
							griddisplay=off label="Concentration(ng/mL)" 
							labelattrs=(family="Times New Roman" size=12pt weight=bold)
							tickvalueattrs=(size=8pt family="Times New Roman") 
							type=log
							logopts=(
								base=10
								tickvaluepriority=true 
								tickintervalstyle=logexpand
								tickvaluelist = ( 1 10 100 1000 )
							)
						);

						seriesplot  x=atptn y=semi / name="line" group=periodc_map ;
						scatterplot x=atptn y=semi / name="dot" group=periodc_map ; 

					endlayout;
				 endcell;

				 sidebar / align=bottom;
						discretelegend "item1" / valueattrs=(family="宋体" size=8pt) title='AVISIT' 
						location=outside opaque=true halign=center valign=center border=true pad=(left=0px right=0px);
			     endsidebar;

			endlayout; *layout lattice / columns=2 rows=1 columngutter=1cm rowgutter=1cm border=false;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final(where=(trt01a="&&trt01a&i" and subjid="&&subjid&i")) template=PKPlot;
run;

%end;

%mend;
%figloop;

ods rtf close;
ods listing;
ods results on;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
