
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
%let pgmname = f-14-2-1-1.sas;
%let outname = F14020101;


%let lib=ads;
%let AnaSet=FASFL;
%let adam=adtr;


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


data adsl;
	set &lib..adsl;
	if &TrtVar.N in (1 3);
	if &TrtVar.N=3 then &TrtVar.N=2;
run;


data &adam.;
	merge adsl(in=a where=(&AnaSet.="Y")) &lib..&adam.(in=b) ;
	by usubjid;
	if a;
	if paramcd="SUMPPD" and not missing(PCHG);
	DIAGCAT=coalescec(DIAGCASP,DIAGCAT);
	keep usubjid subjid &TrtVar.N &TrtVar. DIAGCAT EOTSTT INVBOR PCHG;
	proc sort;
	by subjid PCHG;
run;


data best;
	set &adam.;
	by subjid pchg;
	if first.subjid;
run;


data final;
	set best;
	dose = scan(trt01p,2,' ');
	subject = strip(subjid)||" ("||strip(dose)||")";
	if pchg>=0 then do;
		textloc=-5;
	end;
	else do;
		textloc=5;
	end;
	if EOTSTT="ºÃ–¯Ω¯––" then do;
		if pchg>=0 then do;
			marker=pchg+3;
		end;
		else if not missing(pchg) then do;
			marker=pchg-3;
		end;
	end;
	proc sort;
	by descending PCHG;
run;


data figdat.&outname.;
	set final;
	informat _all_;
	format _all_;	
	keep subjid subject &TrtVar.N &TrtVar. DIAGCAT TEXTLOC EOTSTT INVBOR PCHG;
	proc sort;
	by descending PCHG;
run;


%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=15.9cm height=11.0cm;
ods listing gpath="&root.output\figures" image_dpi=400; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods results off;
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


proc template;
	define statgraph waterfall;
		begingraph /  border=false backgroundcolor = white 
/*			datacolors=(cxFF0000 cx0000FF cx00C2C0 ) datacontrastcolors=( white )*/
			;
			entrytitle "Best percent change in tumor size from baseline";
			symbolchar name=rightarrow char='2192'x;

			discreteattrmap name='restype';
                value 'CR' /      markerattrs=(symbol=squarefilled color=cx003399 size=8);
                value 'PR' /      markerattrs=(symbol=squarefilled color=cxFFFF00 size=8);
                value 'SD' /      markerattrs=(symbol=squarefilled color=cx9966CC size=8);
                value 'PD' /      markerattrs=(symbol=squarefilled color=cxCC3333 size=8);
                value 'NE' /      markerattrs=(symbol=squarefilled color=cx999999 size=8);
            enddiscreteattrmap;
            discreteattrvar attrvar=resp_map var=INVBOR attrmap='restype';

			layout overlay/ cycleattrs=true walldisplay = none 
				xaxisopts=(
					griddisplay=off label="Subject"
					labelattrs=(family="Times New Roman" size=8pt weight=bold)
					tickvalueattrs=(size=8pt family="Times New Roman") 
				)
				yaxisopts=(
					griddisplay=off label="Best percent change in tumor size from baseline" 
					labelattrs=(family="Times New Roman" size=8pt weight=bold)
					tickvalueattrs=(size=8pt family="Times New Roman") 
					linearopts=(viewmin=-100 viewmax=40 tickvaluesequence=(start=-100 end=40 increment=20 ) ) 
				);
				referenceline y=20 / lineattrs=(color=cxFF0000 thickness=1 pattern=dash) curvelabel="20%";
				referenceline y=-30 / lineattrs=(color=cx00C2C0 thickness=1 pattern=dash) curvelabel="-30%";

				barchartparm category=subject response=pchg/ name="BAR" group=DIAGCAT barwidth=0.5 
				datalabel=DIAGCAT datalabeltype=COLUMN datalabelattrs=(color=cx000000 size=8pt) 
                datalabelfitpolicy=NONE
				;
				scatterplot x=subject y=marker / markerattrs=(symbol=rightarrow color=black size=30 weight=bold);
				textplot x=subject y=textloc text=INVBOR / rotate=0 position=center textattrs=(size=8) contributeoffsets=(ymin);

				discreteLegend "BAR"/ titleattrs=(size=10pt) valueattrs=(size=8pt) title="º≤≤°’Ô∂œ" 
				location=outside opaque=true valign=center halign=right border=false  borderattrs=(color=black) across=1 ;

				drawtext textattrs=(size=15pt color=black weight=bold) {unicode "2192"x} / anchor=bottomright width=9 widthunit=percent xspace=wallpercent yspace=wallpercent x=67 y=1.6 justify=center;
				drawtext textattrs=(size=8pt) "Ongoing" / anchor=bottomright width=12 widthunit=percent xspace=wallpercent yspace=wallpercent x=80 y=3.0 justify=center;
			endlayout;
		endgraph;
	end;
run;

proc sgrender data=final template=waterfall;
run;

ods rtf close;
ods listing;
ods results on;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
