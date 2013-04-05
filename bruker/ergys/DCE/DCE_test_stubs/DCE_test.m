%% INPUTS
% =========examples=========
T1_runno='B00541'; %Needs to be a string
DCE_runno='B00542'; %Needs to be a string
Patient_ID='20111007'; %Needs to be a string
Study='20120514'; %Usually the date (needs to be a string)
T1_ScanRange=24:31; 
DCE_Scan_ID=32; %Scan IDs for the VFA data acquired with QueuedACQ
Filtering_method='VFC'; %Needs to be a string (UFC or VFC, both use sliding window)
baseline_time=2*60+30; %time (in sec) before injection (at baseline)
D=0.5; %Dose [mmol/kg]
%====Needed for archiving====
civmid='eds'; %Needs to be a string
projectcode='10.eds.02'; %Needs to be a string
specimenid='120514-2:0'; %Needs to be a string


% DCE_T1map(Patient_ID, Study, T1_ScanRange, T1_runno);
% DCE_calc_concentration(Patient_ID, Study, DCE_Scan_ID, DCE_runno, T1_runno, T1_ScanRange, Filtering_method, baseline_time);
% DCE_calc_Ktrans(Patient_ID, Study, DCE_runno, DCE_Scan_ID, D);
DCE_send_to_archive(Patient_ID, Study, DCE_Scan_ID, DCE_runno, T1_runno, T1_ScanRange, Filtering_method, civmid, projectcode, specimenid, baseline_time);