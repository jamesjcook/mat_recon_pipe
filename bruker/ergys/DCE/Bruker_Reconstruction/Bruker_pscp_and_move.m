%This function retrives the data files from the Bruker scanner (nemo) and
%moves them into the appropriate folder in my computer. 

function []=Bruker_pscp_and_move(local_data_dir, runno, host_data_dir, host_scan_dir)

%% INPUT EXAMPLE
% local_data_dir='E:\Scans_20120223\'; %Final directory of data in my computer (local)
% runno='00310'; %Initial run number (needs to be string for now)
% host_data_dir='20111007.cF1';
% host_scan_dir=3; %Not a string

%ex: Bruker_pscp_and_move(local_data_dir, runno, host_data_dir, host_scan_dir)

%%
computer_name='nemo'; 
user='nmrsu';
pswd='topspin ';
host_comp=['@' computer_name '.duhs.duke.edu'];
file_dir=['/opt/PV5.1/data/nmrsu/nmr/' host_data_dir '/' num2str(host_scan_dir)];

target_loc='C:\cygwin\home\ergys\';
pscp='C:\Progra~2\PuTTY\pscp.exe ';
command_options=['-pw ' pswd '-r '];

pscp_command=[pscp command_options user host_comp ':' file_dir ' ' target_loc];
system(pscp_command)

loc_file=[target_loc num2str(host_scan_dir)];
cd(local_data_dir);
dir=[scanner_code runno];
mkdir(dir)
next_target_dir=[local_data_dir scanner_code runno '\From_Scanner'];

movefile(loc_file, next_target_dir);
