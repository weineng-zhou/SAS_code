

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
%let adam=adtte;


%let trt1=Responder;
%let trt2=Non-responder;


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
	value trtp
	1="Responder"
	2="Non-responder"
	;
quit;


*点估计与区间估计;
%macro point_CI(dsin=,dsout=,var_list=, fmt=);

%if &dsout= %then %do;
	%let dsout=&dsin.;
%end;

proc format;
    value point_ci
	.="NE"
	low-<0.001 ='<0.001'
	999.999< -high='>999.999'
	;
quit;

data &dsout.;
	set &dsin.;
	array point_CI &var_list.;
    array charvar $20 point lower upper;
    do i = 1 to dim(point_CI);
        if 0.001<= point_CI[i] <= 999.999 then charvar[i] = strip(put(point_CI[i], &fmt.));
        else charvar[i] = strip(put(point_CI[i], point_ci.));
    end;
	C = cat(strip(point), " (", strip(lower), ", ", strip(upper), ")");
run;
%mend;


data adsl;
	set &lib..adsl;
run;


proc sql noprint;
	select max(&trtvar.N)+1 into :trtmax separated by ''
	from adsl;
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


data &adam.;
	set &lib..&adam.(where=(&AnaSet.="Y" and paramcd="PFS"));
	output;
	*&trtVar="Total";
	*&trtVar.N=&trtmax.;
	*output;
run;


*事件数;
proc sql;
	create table event0 as
	select &trtvar.n, count(distinct usubjid) as count
	from &adam. where cnsr=0 
	group by &trtvar.n, cnsr;
quit;

data dummy_cnsr;
	do &trtvar.n=1,2;
		count=0;
		output;
	end;
run;

data event ;
	merge dummy_cnsr(in=a) event0 BigN;
	by &trtvar.n;
	if a;
	percent=count/BigN*100;
run;


data _null_;
	set event;
	call symputx('event'||strip(put(_N_,best.)), put(count,best.));
	call symputx('percent'||strip(put(_N_,best.)), put(percent,10.1));
run;
%put &event1. &event2.; 
%put &percent1. &percent2.;



%let x_order = 0 24 48 72 96 120 144 168 192;

ods graphics on;
ods output Survivalplot=Survivalplot Quartiles=Quartiles HomTests=HomTests;
proc lifetest data=&adam. method=KM plots=survival(atrisk=&x_order.);
	time aval*cnsr(1);
	strata &trtVar.N;
run;


*中位数;
data median;
	set Quartiles;
	if percent=50; 
	proc sort;
	by &trtVar.N;
run;

proc format;
    value median
	.="NE"
	low-<0.001 ='<0.001'
	999.999<-high='>999.999'
	;
quit;


data _null_;
	set median;
	if 0.001<= ESTIMATE <= 999.999 then call symputx('median'||strip(put(_N_,best.)), strip(put(ESTIMATE,8.2)));
	else call symputx('median'||strip(put(_N_,best.)), strip(put(ESTIMATE,median.)));
run;
%put &median1; 
%put &median2; 



%point_CI(dsin=median,dsout=median,var_list=ESTIMATE LOWERLIMIT UPPERLIMIT,fmt=8.0);


data _null_;
	set median;
	call symputx('medianCI'||strip(put(&trtvar.N,best.)), C);
run;
%put &medianCI1;
%put &medianCI2;


data _null_;
     set HomTests;
     if Test eq 'Wilcoxon' then call symput('wilcoxon_p', put(ProbChiSq,pvalue6.4));
     else if Test in('-2Log(LR)' '-2Log(LR)*') then call symput('_2log_LR_p', put(ProbChiSq,pvalue6.4));
	 else call symput('log_rank_p', put(ProbChiSq,pvalue6.4));
run;


*HAZARD RITIO;
*协变量;
/*data temp;*/
/*	set &adam.;*/
/*run;*/
/*proc sql noprint;*/
/*	create table &adam. as */
/*	select a.*, b.HGBBL, input(b.GFR,best.) as eGFR*/
/*	from temp a left join ads.adsl b on a.usubjid=b.usubjid*/
/*	order by usubjid*/
/*;*/
/*quit;*/


ods output ParameterEstimates = ParameterEstimates;
proc phreg data=&adam. covsandwich;
    *by SEX;
	class &trtvar.n(param=REF REF='2');
    model aval*cnsr(1) = &trtvar.n /RL ties=exact alpha=0.05;
    *strata &strataVarList.;
run;


%point_CI(dsin=ParameterEstimates,dsout=ParameterEstimates,var_list=HAZARDRATIO HRLOWERCL HRUPPERCL,fmt=8.2);

data _null_;
	set ParameterEstimates;
	call symputx('HR'||strip(put(_N_,best.)), C);
run;
%put &HR1;


data _null_;
	set ParameterEstimates;
	if PARAMETER="&trtvar.N";
	pvalue=put(PROBCHISQ,pvalue6.4);
	call symputx('pvalue', pvalue);
run;
%put &pvalue.;

data final;
	set Survivalplot ;
	&trtVar.N=STRATUMNUM;
	&trtVar.=put(&trtVar.N, trtp.);
	median1="&median1";
	median2="&median2";
	pct=0.5;
	log_rank_p="&log_rank_p";
	HR="&HR1.";
	pvalue="&pvalue.";
	keep &trtVar.N &trtVar. time survival censored tatrisk atrisk median1 median2 pct log_rank_p HR pvalue ;
run;


data figdat.&outname.;
	set final;
	informat _all_;
	format _all_;
	attrib _all_ label='';
run;


%if %sysfunc(exist(vfigdat.&outname.)) %then %do;
	%compare_tfl(devlib=figdat,vallib=vfigdat,ds=&outname., var_list=%str(*));
%end;


options papersize=letter orientation=landscape nodate nonumber center missing=" " nobyline;
options formchar="|----|+|---+=|-/\<>*"; 
ods escapechar="@";
ods graphics on/reset=all outputfmt=jpg width=16.0cm height=11.0cm; 
ods listing gpath="&root.output\figures\" image_dpi=300;
ods results off;
ods listing close; /*BMP,PNG,GIF,JPG,JPEG,PDF,TIFF,PS,SVG*/


%Mstrtrtf2(pgmname=%str(&pgmname.), pgmid=1, style=figures_8_pt); 


%let color1=cx0000ff;
%let color2=cxff0000;


proc template;
	define statgraph KMPlot;
		begingraph / border = false backgroundcolor = white	
		datacolors=(&color1. &color2.) datacontrastcolors=(&color1. &color2.)
		;
			entrytitle "";

			discreteattrmap name='grp';
				value '1'  / markerattrs=(symbol=trianglefilled color=&color1. size=4) lineattrs=(color=&color1. pattern=solid) ;
				value '2'  / markerattrs=(symbol=circlefilled   color=&color2. size=4) lineattrs=(color=&color2. pattern=solid) ;
			enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar.N_map var=&trtvar.N attrmap='grp';

			discreteattrmap name='cnsr';
				value '1'  / markerattrs=(symbol=plus color=&color1. size=8) lineattrs=(color=&color1. pattern=solid) ;
				value '2'  / markerattrs=(symbol=plus color=&color2. size=8) lineattrs=(color=&color2. pattern=solid) ;
			enddiscreteattrmap;
			discreteattrvar attrvar=&trtvar.N_cnsr var=&trtvar.N attrmap='cnsr';

			legendItem type=MARKERLINE  name="item1" / markerattrs=(color=&color1.  symbol=trianglefilled) lineattrs=(color=&color1. pattern=solid) label="&trt1.";
			legendItem type=MARKERLINE  name="item2" / markerattrs=(color=&color2.  symbol=circlefilled)   lineattrs=(color=&color2. pattern=solid) label="&trt2.";

			layout lattice / columns=1 rows=2 Rowweights=(0.8 0.2) columngutter=2cm rowgutter=1cm border=false;

			  cell;
				  cellheader;
           	   	    entry " " / border=false;
          		  endcellheader;

				    layout overlay/cycleattrs=true walldisplay = none 

						xaxisopts=(
							griddisplay=off offsetmin=0 label="Time (Month)"
							labelattrs=(family="Arial" size=8pt weight=bold)
							tickvalueattrs=(size=8pt family="Arial") 
							linearopts=(
								viewmin=0 viewmax=192 tickvaluelist=(&x_order.) 
							) 
						)
						yaxisopts=(
							griddisplay=off offsetmin=0 label="Probability Estimated" 
							labelattrs=(family="Arial" size=8pt weight=bold)
							tickvalueattrs=(size=8pt family="Arial") 
							linearopts=(viewmin=0 viewmax=1 tickvaluesequence=(start=0 end=1 increment=0.1 ) ) 
						);

						referenceline y=0.5 / lineattrs=(pattern=dot thickness=1 color=cxFF0000 ) 
						curvelabel="Median Time" /* curvelabellocation=outside */ curvelabelposition=auto curvelabelsplitchar="of";
						
						stepplot x=time y=SURVIVAL / name="step" group=&trtvar.N_map;
						*scatterplot x=tabtime y=B_SURV / name="dot1" group=&trtvar.N_map yerrorlower=B_LCI_SURV yerrorupper=B_UCI_SURV;
						scatterplot x=time y=CENSORED / name="dot2" group=&trtvar.N_cnsr ;

						*needleplot x=median1 y=pct / dataskin=none baselineintercept=0 lineattrs=(pattern=dot thickness=1 color=&color1. );
						*needleplot x=median2 y=pct / dataskin=none baselineintercept=0 lineattrs=(pattern=dot thickness=1 color=&color2. );	
		
						*drawtext textattrs=(family="Arial" size=8 weight=bold color=&color1.) ;
						*drawtext textattrs=(family="Arial" size=8 weight=bold color=&color2.) ;

						*drawtext textattrs=(family="Arial" size=8 weight=bold color=red) "&median1" / anchor=bottom width=10 x=40 y=10;
						*drawtext textattrs=(family="Arial" size=8 weight=bold color=red) "&median2" / anchor=bottom width=10 x=40 y=10;
						*事件、中位数、中位时间、处于风险中的受试者数、风险比;
						layout gridded /valign=0.1 halign=0.1 border=false;  
							entry halign=right '             Event            Median (95%CI)' / textattrs=(family="Arial" size=8pt );
							entry halign=right "&trt1  &event1. (&percent1."'%)        ' "&MEDIANCI1." / textattrs=(family="Arial" size=8pt COLOR=&COLOR1.);
							entry halign=right "&trt2  &event2. (&percent2."'%)        ' "&MEDIANCI2." / textattrs=(family="Arial" size=8pt COLOR=&COLOR2.);

							%if %index(&log_rank_p.,<) %then %do;
								entry halign=right "Logrank Test, p&log_rank_p" / textattrs=(family="Arial" size=8pt );
							%end;
							%else %do;
								entry halign=right "Logrank Test, p=&log_rank_p" / textattrs=(family="Arial" size=8pt );
							%end;

							entry halign=right 'Hazard Ratio (95%CI): '  "&HR1." / textattrs=(family="Arial" size=8pt );

							%if %index(&pvalue.,<) %then %do;
								entry halign=right "P value, p&pvalue." / textattrs=(family="Arial" size=8pt );
							%end;
							%else %do;
								entry halign=right "P value, p=&pvalue." / textattrs=(family="Arial" size=8pt );
							%end;

				        endlayout;

						layout gridded /valign=0.1 halign=right border=false;  
							entry halign=right "+ Censor" / textattrs=(family="Arial" size=8pt ); 
				        endlayout; 

				   endlayout;
			    endcell;

		    cell;
			   cellheader;
           	   	  entry "" / border=false;
          	   endcellheader;
			    layout overlay / walldisplay=NONE xaxisopts=(display=none 
			        linearopts=(viewmin=0 viewmax=192 tickvaluelist=(&x_order))) border=false ;
			        entry halign=left "Subjects at risk" / location=outside valign=top textattrs=(family="Arial" size=10pt ); 
			        axistable x=TATRISK value=ATRISK / class=&trtvar. colorgroup=&trtvar.N_map display=(label) valueattrs=(size=9pt);
			    endlayout;
			endcell;

/*			sidebar / align=right;*/
/*				discretelegend "item1" "item2" / valueattrs=(family="Arial" size=8pt) title='Region' */
/*				location=outside opaque=true halign=center valign=center border=false pad=(left=0px right=0px) across=2;*/
/*		    endsidebar;*/

		    endlayout; *layout lattice / columns=2 rows=1 columngutter=1cm rowgutter=1cm border=false;
		endgraph; *begingraph / backgroundcolor=white border=false;
	end; *define statgraph avg;
run;

proc sgrender data=final template=KMPlot;
run;

ods rtf close;
ods listing;

%preview(pgmname=%str(&pgmname.), pgmid=1, part=2);


