% This function is needed to get the trajectory file from the Bruker
% console.

% Ergys Subashi
% November, 2012



function []=get_traj_file(Patient_ID, Study, Traj_Scan_ID, Traj_runno)


%% INPUTS
% =========examples=========
% Traj_runno='B99999test'; %Needs to be a string
% Patient_ID='20111007'; %Needs to be a string
% Study='20120501'; %Usually the date (needs to be a string)
% Traj_Scan_ID=39; %Scan ID for the scan measuring the k-space trajectory

tStart=tic;
%=========================================================================


%% Get data from Bruker scanner
local_dir='/androsspace'; cd(local_dir);
Traj_dir=[local_dir '/' Traj_runno '.work']; mkdir(Traj_dir);
Traj_Scan_ID_string=num2str(Traj_Scan_ID);
getbruker_command=['/pipe_home/script/bash/getbruker.bash ' Traj_dir ' ' Patient_ID ' ' Study ' ' Traj_Scan_ID_string];
system(getbruker_command)
tElapsed=toc(tStart);
display(['Transferring the trajectory file took ' num2str(tElapsed/60) ' minutes'])