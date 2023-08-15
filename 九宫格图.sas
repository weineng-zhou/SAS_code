
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
%let pgmname = f-14-2-1-14.sas;
%let outname = F14020114;


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
	&trtvar="Total";
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


data &adam.;
	set ads.&adam.(where=(&AnaSet.="Y" & ANL01FL="Y" & paramcd in ("HGB") ));
	if avisitn in (0 2 4 6 8 12 16); 
	if avisitn=0 then ady=1;
	output;
	*&trtvar.N=&trtvarmax.; 
	*&trtvar.='合计';
	*output;
	keep usubjid &trtvar.N &trtvar. paramn paramcd param avisitn avisit ady aval base ;
	proc sort; 
	by usubjid paramn param;
run;


*协变量;
data temp;
	set &adam.;
run;
proc sql noprint;
	create table &adam. as 
	select a.*, b.RANDID
	from temp a left join ads.adsl b on a.usubjid=b.usubjid
	order by usubjid, paramn,avisitn
;
quit;


proc freq data=&adam. noprint;
	where not missing(RANDID);
	tables &trtvar.N*RANDID / out=RANDID;
run;
proc sort data=RANDID;
	by &trtvar.N RANDID ;
run;

data RANDID;
	retain seq;
	set RANDID;
	by &trtvar.N RANDID;
	if first.&trtvar.N then seq=1;
	else seq=seq+1;
	if seq<=9;
run;
data randid;
	set randid;
	randnum=_N_;
run;


*每个组挑选9个randid;
proc sql noprint;
	select RANDID into :randid_list separated by '", "'
	from RANDID
	;
quit;
%put "&randid_list.";


data final;
	set &adam.;
	if randid in("&randid_list.");
run;


data temp;
    set final;
run;

proc sql noprint;
    create table final as 
    select a.*, b.randnum
    from temp a left join RANDID b 
    on a.randid=b.randid
    order by usubjid
;
quit;


proc sort data=final out=avisit0_16; 
	where avisitn in (0 2 4 6 8 12 16);
	by usubjid paramn param;
run;


*基线至第16周个体的各个时间点切点的导函数之和;
ods output ParameterEstimates= ParameterEstimates_3;
proc glmselect data=final;
	where avisitn in (0 2 4 6 8 12 16);
	by usubjid paramn param;	
	effect y=poly(ady / degree=3);
	model aval = y / selection=none;
	output out=PolyOut pred=Fit;
quit;

proc transpose data=ParameterEstimates_3 out=Estimate_beta(drop=_name_ _label_) prefix=beta; 
	where EFFECT^="Intercept";
	by usubjid paramn param; 
	var ESTIMATE; 
run;


data avisit0_16;
	merge avisit0_16 Estimate_beta;
	by usubjid paramn param;
	slope=3*beta3*ady**2 + 2*beta2*ady + beta1;
	proc sort;
	by usubjid avisitn;
run;


data final;
	set avisit0_16;
	array HGB[18];
	do i=1 to dim(HGB);
		if i=randnum then HGB[i]=aval;
		if ady=1 then 
	end;

	array _slope[18];
	do i=1 to dim(_slope);
		if i=randnum then _slope[i]=slope;
	end;

	array __slope[18];
	do i=1 to dim(__slope);
		if ady=1 then do;
			__slope[i]=_slope[i];
			_slope[i]=.;
		end;
	end;
	if randnum<=9 then grid=1; else grid=2;
	proc sort;
	by &trtvar.N randid paramn param avisitn;
run;


proc sql noprint;
	select min(aval) into :linear_x_min separated by '' from final;
	select max(aval) into :linear_x_max separated by '' from final;
	select min(slope) into :linear_y_min separated by '' from final;
	select max(slope) into :linear_y_max separated by '' from final;
quit;
%put &linear_x_min.;
%put &linear_x_max.;


data figdat.&outname.;
	set final;
	informat _all_;
	format _all_;
	attrib _all_ label='';
	proc sort;
	by usubjid ;
run;


%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
/*	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));*/
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=6in height=4in;
ods listing gpath="&outdir.\figures" image_dpi=300; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


%let color1=cx00b8e5;
%let color2=cxF92672;


%macro figloop_trtgrp;

%do k=1 %to 2;

proc template;
	define statgraph LoessPlot;
		begingraph / border=false backgroundcolor = white datacontrastcolors=( &color1. &color2. ) datacolors=(&color1. &color2. ) ;	


			discreteattrmap name='dot';
				value '1' / markerattrs=(symbol=trianglefilled color=&color1. size=4) lineattrs=(color=&color1. pattern=solid);
				value '2' / markerattrs=(symbol=circlefilled   color=&color2. size=4) lineattrs=(color=&color2. pattern=solid);
			enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar._map var=&trtvar.n attrmap='dot';

			discreteattrmap name='start';
				value '1' / markerattrs=(symbol=starfilled color=&color1. size=6) lineattrs=(color=&color1. pattern=solid);
				value '2' / markerattrs=(symbol=starfilled color=&color2. size=6) lineattrs=(color=&color2. pattern=solid);
			enddiscreteattrmap;
			discreteattrvar attrvar=start_map var=&trtvar.n attrmap='start';		
			
			legendItem type=MARKERLINE  name="item1" / markerattrs=(symbol=trianglefilled color=&color1. size=4) lineattrs=(color=&color1. pattern=solid) label="&trt1." ;
			legendItem type=MARKERLINE  name="item2" / markerattrs=(symbol=circlefilled color=&color2. size=4) lineattrs=(color=&color2. pattern=solid) label="&trt2." ;
			
			layout lattice / columns=3 rows=3 columngutter=2cm rowgutter=0.5cm border=false;

			%macro NINE_GRID1;
			%do i=1 %to 9;

			cell;
				  cellheader;
           	   	    entry "受试者&i" / border=false textattrs=(family="宋体" size=8pt ) ;
          		  endcellheader;

				    layout overlay/cycleattrs=true walldisplay = (fill outline)
						xaxisopts=(
							griddisplay=off 
							label="血红蛋白"
							labelattrs=(family="宋体" size=8pt weight=bold)							
							tickvalueattrs=(size=8pt family="宋体") 
							discreteopts=(tickvaluefitpolicy=splitalways tickvaluesplitchar="*")
							linearopts=(
								viewmin=&linear_x_min viewmax=&linear_x_max tickvaluesequence=(start=&linear_x_min end=&linear_x_max increment=5)
							) 
						)
						yaxisopts=(
							griddisplay=off							
							label="斜率" 
							labelattrs=(family="宋体 " size=8pt weight=bold )		
							labelfitpolicy=split	
							tickvalueattrs=(size=6pt family="宋体") 
							linearopts=(
								viewmin=&linear_y_min viewmax=&linear_y_max tickvaluesequence=(start=-1 end=2 increment=0.5)
							) 
						);

						scatterplot x=HGB&i y=_slope&i / name="dot" group=&trtvar._map;
						scatterplot x=HGB&i y=__slope&i / name="start" group=start_map;
	
				    endlayout;
			endcell;
			%end;
			%mend;
			

			%macro NINE_GRID2;
			%do i=10 %to 18;

			cell;
				  cellheader;
           	   	    entry "受试者&i" / border=false textattrs=(family="宋体" size=8pt ) ;
          		  endcellheader;

				    layout overlay/cycleattrs=true walldisplay = (fill outline)
						xaxisopts=(
							griddisplay=off 
							label="血红蛋白"
							labelattrs=(family="宋体" size=8pt weight=bold)					
							tickvalueattrs=(size=8pt family="宋体") 
							discreteopts=(tickvaluefitpolicy=splitalways tickvaluesplitchar="*")
							linearopts=(
								viewmin=&linear_x_min viewmax=&linear_x_max tickvaluesequence=(start=&linear_x_min end=&linear_x_max increment=5)
							)
						)
						yaxisopts=(
							griddisplay=off							
							label="斜率" 
							labelattrs=(family="宋体" size=8pt weight=bold )		
							labelfitpolicy=split	
							tickvalueattrs=(size=6pt family="宋体") 
							linearopts=(
								viewmin=&linear_y_min viewmax=&linear_y_max tickvaluesequence=(start=-1 end=2 increment=0.5)
							) 
						);

						scatterplot x=HGB&i y=_slope&i / name="dot" group=&trtvar._map;
						scatterplot x=HGB&i y=__slope&i / name="start" group=start_map;
	
				    endlayout;
			endcell;
			%end;
			%mend;

			%if &k=1 %then %do;
				%NINE_GRID1;
			%end;

			%else %if &k=2 %then %do;
				%NINE_GRID2;
			%end;


			sidebar / align=bottom;
				discretelegend  "item1" "item2" / valueattrs=(family="宋体" size=8pt ) 
				title="治疗组"  titleattrs=(family="宋体" size=8pt ) 
				location=outside opaque=true valign=bottom halign=center border=false across=2; *across用来显示legend,pad=(left=20px right=20px);
		    endsidebar;

			endlayout; *layout lattice / columns=1 rows=2 Rowweights=(0.80 0.2) columngutter=2cm rowgutter=0.5cm border=false;;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final(where=(grid=&k)) template=LoessPlot;
	*format avisitn avisit.;
run;

%end;
%mend;
%figloop_trtgrp;


ods rtf close;
ods listing; 


%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
