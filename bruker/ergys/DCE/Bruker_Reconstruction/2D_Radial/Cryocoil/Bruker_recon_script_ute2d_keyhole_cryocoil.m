% This script reconstructs the data acquired with "ute2d_keyhole.ppg" in
% the Bruker scanner.


clc
%% INPUTS
for i=13:29
local_data_dir='E:\Scans_20120229\'; %Final directory of data in my computer (local)
runno='00278'; %Initial run number (needs to be string for now)
host_data_dir='20120922.cL1';
host_scan_dir=i; %Not a string
mat=64; %Reconstruction matrix size
keyhole=2; %Number of keys
repeat=10; %Number of times acquisition is repeated


%% Get data from scanner
Bruker_pscp_and_move(local_data_dir, runno, host_data_dir, host_scan_dir);
cd(['B' runno '\From_Scanner']);

end
%% Get trajectory data and calculate dcf
% mat2=mat/2;
% [kspace_coords, nviews]=Bruker_open_2D_traj(mat2);
% key_views=nviews/keyhole;
% Nyquist_cutoff=30;
% for i=1:keyhole
%     k=kspace_coords;
%     k(:,1:Nyquist_cutoff,((i-1)*key_views+1):i*key_views)=NaN;
%     k=Bruker_reshape_kspace_coords(k);
%     
%     dcf=calcdcflut(k, mat); %Calculate dcf
%     
%     
%     dcf_name=['key_' num2str(i) '_dcf'];
%     key_name=['key_' num2str(i) '_coords'];
%     
%     assignin('base', key_name, k); %Generate variable name and assign coordinates
%     save(key_name, key_name, '-v7.3'); clear(key_name);
%     assignin('base', dcf_name, dcf);
%     save(dcf_name, dcf_name, '-v7.3'); clear(dcf_name);
% end


%% Get kspace data


%% Reconstruct
