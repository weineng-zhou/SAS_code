
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
%let pgmname = f-14-2-1-2.sas;
%let outname = F14020102;


proc format;
	invalue RESPN
	"CR"=1
	"PR"=2
	"SD"=3
	"PD"=4
	"NE"=5
	;
	value RESP
	1="CR"
	2="PR"
	3="SD"
	4="PD"
	5="NE"
	;
quit;


%let lib=ads;
%let AnaSet=FASFL;


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
	if &TrtVar.N=2 then delete;
	if &TrtVar.N=3 then &TrtVar.N=2;
run;


proc sql noprint;
    select max(&TrtVar.N)+1 into :trtmax
    from adsl;
quit;
%put &trtmax.;


data adsl;
    set adsl(in=a where=(&AnaSet.="Y")) end=last;
    if last then call symputx('total', _N_);
    output;
    &trtVar="Total";
    &trtVar.N=&trtmax.;
    output;
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


*ADSL;
data adsl;
	set &lib..adsl;
	if &TrtVar.N=2 then delete;
	if &TrtVar.N=3 then &TrtVar.N=2;
run;

data temp;
	set adsl;
run;

proc sql noprint;
	create table tte as 
	select a.*, b.ADY as RESPDURD, b.AVALC as RESP
	from temp(where=(&AnaSet.="Y")) as a left join ads.adrs(where=(paramcd="OVRLRESP" and not missing(ADT))) as b 
	on a.subjid=b.subjid;
quit;


data final;
    set tte;
	DIAGCAT=coalescec(DIAGCASP,DIAGCAT);
	RESPN=input(RESP,RESPN.);
	dose = scan(&TrtVar.,2,' ');
	subject = strip(subjid)||" ("||strip(dose)||")";
	if prxmatch("/继续|进行/",EOTSTT) then ONGDURD=TRTDURD+3;	
    keep subjid subject &TrtVar.N &TrtVar. DIAGCAT EOTSTT TRTDURD RESP RESPN RESPDURD ONGDURD ;
	proc sort;
	by TRTDURD subject ;
run;


data _null_;
    set final end=last;
    if last then do;
        call symputx("bar", _N_);
		if mod(TRTDURD,100)<50 then do;
            call symputx("_viewmax", round(TRTDURD,100)+100);
        end;
        else do;
            call symputx("_viewmax", round(TRTDURD,100)+90);
        end;     
    end;
run;
%put &_viewmax.;


data final;
    set final;
    by TRTDURD subject ;
    if first.subject then do;
		subjectn+1;
		BARN=subjectn;
	end;
	else do;
		call missing(TRTDURD);
	end;
	proc sort;
	by subjectn; 
run;


proc sort data=final out=subject(keep=subject subjectn) nodupkey;
	by subjectn subject ;
run;

data fmt;
	set subject;
	fmtname="subject";
	start=_N_;
	end=_N_;
	label=subject;
	type="N";
	proc format cntlin=fmt fmtlib;
quit;


data anno;
     retain function "text" drawspace "datavalue" textfont "宋体" textsize 7 /*textweight "bold"*/ width 150 widthunit "pixel" anchor "left" discreteoffset 0;
     set final;
	 if not missing(TRTDURD) then x1=TRTDURD+8;
     y1=BARN;
     label=DIAGCAT;
     keep function drawspace textfont textsize /*textweight*/ width widthunit anchor discreteoffset x1 y1 label;
run;


data figdat.&outname.;
    retain subjid subjectn BARN subject &TrtVar.N &TrtVar. DIAGCAT EOTSTT RESP RESPN RESPDURD TRTDURD ;
    set final;
	keep subjid subjectn BARN subject &TrtVar.N &TrtVar. DIAGCAT EOTSTT RESP RESPN RESPDURD TRTDURD ;
    proc sort;
    by subject;
run;


%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=17.0cm height=11.0cm; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/
ods listing gpath="&outdir.\figures" image_dpi=400; 
ods listing close;


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 

%let color1=cx00bc57;
%let color2=cx00b8e5;
%let color3=cxFF7F0E;
%let color4=cxF92672;
%let color5=cxCC3333;

proc template;
    define statgraph SwimmingPlot;
        begingraph / border=false backgroundcolor = white /*datacolors=( &color1. &color2. ) datacontrastcolors=( black ) */;    
            entrytitle "Tumor Response by Stage and Day" / textattrs=(family="Times New Roman" size=10pt weight=normal );

			*Group by;
            discreteattrmap name='resp';
	            value 'CR' / markerattrs=(symbol=squarefilled color=&color1. size=8);
                value 'PR' / markerattrs=(symbol=squarefilled color=&color2. size=8);
                value 'SD' / markerattrs=(symbol=squarefilled color=&color3. size=8);
                value 'PD' / markerattrs=(symbol=squarefilled color=&color4. size=8);
                value 'NE' / markerattrs=(symbol=squarefilled color=&color5. size=8);
            enddiscreteattrmap;
            discreteattrvar attrvar=resp_map var=resp attrmap='resp';

			*Order by;
			legendItem type=MARKER  name="item1" / markerattrs=(symbol=squarefilled color=&color1. size=6) lineattrs=(color=&color1. pattern=solid) label="CR" ;
			legendItem type=MARKER  name="item2" / markerattrs=(symbol=squarefilled color=&color2. size=6) lineattrs=(color=&color2. pattern=solid) label="PR" ;
			legendItem type=MARKER  name="item3" / markerattrs=(symbol=squarefilled color=&color3. size=6) lineattrs=(color=&color3. pattern=solid) label="SD" ;
			legendItem type=MARKER  name="item4" / markerattrs=(symbol=squarefilled color=&color4. size=6) lineattrs=(color=&color4. pattern=solid) label="PD" ;
			legendItem type=MARKER  name="item5" / markerattrs=(symbol=squarefilled color=&color5. size=6) lineattrs=(color=&color4. pattern=solid) label="NE" ;

            layout lattice / columns=1 rows=1  border=false;

                    layout overlay/cycleattrs=true walldisplay = none 

                        xaxisopts=(
                            griddisplay=off offsetmin=0 label="Duration of treatment (Days)"
                            labelattrs=(family="Times New Roman" size=8pt weight=normal )
                            tickvalueattrs=(size=8pt family="Times New Roman") 
                            linearopts=(viewmin=0 viewmax=&_viewmax tickvaluesequence=(start=0 end=&_viewmax increment=30)) 
                        )
                        yaxisopts=(
                            griddisplay=off label="Subjects Received Study Drug"
                            labelattrs=(family="Times New Roman" size=8pt weight=normal )
                            tickvalueattrs=(size=8pt family="Times New Roman") 
                        );

                        barchartparm category=BARN response=TRTDURD / orient=horizontal barwidth=0.2 dataskin=none 
						/*datalabel=DIAGCAT discreteoffset=0 datalabeltype=column datalabelattrs=(color=cx282828 size=8pt) */
						fillattrs=(color=cxF8D4BA) outlineattrs=(color=white) 
						/*segmentlabeltype=auto segmentlabelfitpolicy=thin*/
						;

						annotate;

                        scatterplot x=RESPDURD y=SUBJECTN / name="resp" group=resp_map;
                        scatterplot x=ONGDURD y=SUBJECTN / name="ongo" markerattrs=(symbol=trianglerightfilled color=cx000000 size=8) legendlabel="Treatment Ongoing";

                        discreteLegend "item1" "item2" "item3" "item4" "item5" "ongo" / title='' valueattrs=(family="Times New Roman" size=8pt) 
                        location=inside opaque=true valign=bottom halign=right border=false pad=(left=0px right=0px) across=1;

                    endlayout;

            endlayout; *layout lattice / columns=2 rows=1 columngutter=1cm rowgutter=1cm border=false;
        endgraph; *begingraph / backgroundcolor=white border=false;
    end; *define statgraph avg;
run;


proc sgrender data=final template=SwimmingPlot sganno=anno;
	format barn subjectn subject. respn resp.;
run;
ods rtf close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);
