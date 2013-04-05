%% INPUTS
% =========examples=========
tStart=tic;
T1_runno='B00653'; %Needs to be a string
DCE_runno='B00654'; %Needs to be a string
Patient_ID='20111007'; %Needs to be a string
Study='20120608'; %Usually the date (needs to be a string)
T1_ScanRange=15:22; %Scan IDs for the VFA data acquired with QueuedACQ
DCE_Scan_ID=23; %Scan ID for DCE acquisition
Filtering_method='UFC'; %Needs to be a string (UFC or VFC, both use sliding window)
baseline_time=2*60+30; %time (in sec) before injection (at baseline)
D=0.5; %Dose [mmol/kg]
%====Needed for archiving====
civmid='eds'; %Needs to be a string
projectcode='10.eds.02'; %Needs to be a string
specimenid='120530-1:0'; %Needs to be a string


% DCE_T1map(Patient_ID, Study, T1_ScanRange, T1_runno);
% DCE_calc_concentration(Patient_ID, Study, DCE_Scan_ID, DCE_runno, T1_runno, T1_ScanRange, Filtering_method, baseline_time);
% DCE_calc_Ktrans(Patient_ID, Study, DCE_runno, DCE_Scan_ID, D);
[ind1, ind_end]=DCE_send_to_archive(Patient_ID, Study, DCE_Scan_ID, DCE_runno, T1_runno, T1_ScanRange, Filtering_method, civmid, projectcode, specimenid, baseline_time);

pause
system(['archiveme2 ' civmid ' ' T1_runno 'T1']);
system(['archiveme2 ' civmid ' ' T1_runno 'M0']);
system(['archiveme2 ' civmid ' ' DCE_runno '_m' ind1 '-' DCE_runno '_m' ind_end]);  
system(['archiveme2 ' civmid ' ' DCE_runno 'Ktrans']);
system(['archiveme2 ' civmid ' ' DCE_runno 'ke']);
system(['archiveme2 ' civmid ' ' DCE_runno 've']);
system(['archiveme2 ' civmid ' ' DCE_runno 'vp']);

tElapsed=toc(tStart);
display(['The DCE pipeline took ' num2str(tElapsed/60) ' minutes to run'])