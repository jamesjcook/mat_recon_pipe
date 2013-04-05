% This script uses the keyhole method (without sliding window) to
% reconstruct the data acquired with "ute3d_keyhole.ppg" in the Bruker
% scanner.


clc
%% INPUTS
% for i=13:29
local_data_dir='E:\Scans_20120316\'; %Final directory of data in my computer (local)
runno='00364'; %Initial run number (needs to be string for now)
host_data_dir='20111007.d11';
host_scan_dir=42; %Not a string
mat=128; %Reconstruction matrix size
keyhole=13; %Number of keys
repeat=20; %Number of times acquisition is repeated


%% Get data from scanner
% Bruker_pscp_and_move(local_data_dir, runno, host_data_dir, host_scan_dir);
% cd(['B' runno '\From_Scanner']);

% end
%% Get trajectory data and calculate dcf
mat2=mat/2;
[kspace_coords, nviews]=Bruker_open_3D_traj(mat2);
key_views=nviews/keyhole;
Nyquist_cutoff=26; %Look at script Find_Nyquist_cutoff.m
for i=1:keyhole
    acq_rays_ind=((i-1)*key_views+1):i*key_views;
    n_views=1:nviews;
    n_views(acq_rays_ind)=0;
    ind_not_acq=find(n_views); %Indeces for the rays the center of which was not acquired
    
    k=kspace_coords;
    k(:,1:Nyquist_cutoff,ind_not_acq)=NaN;

    iter=18; %Number of iterations used for dcf calculation
    dcf=sdc3_MAT(k, iter, mat, 0, 2.1, ones(mat2, nviews));


    dcf_name=['key' num2str(i) '_dcf'];
    key_name=['key' num2str(i) '_coords'];

    assignin('base', key_name, k); %Generate variable name and assign coordinates
    save(key_name, key_name, '-v7.3'); clear(key_name);
    assignin('base', dcf_name, dcf);
    save(dcf_name, dcf_name, '-v7.3'); clear(dcf_name);
end


%% Get kspace data and reconstruct
[kspace_data_all, tot_views]=Bruker_open_3D_fid(mat);
Bruker_parse_acquisition_data(kspace_data_all, repeat);

for j=1:repeat
    data_name=['acq' num2str(j) '_data'];
    load(data_name); eval(['d=' data_name ';']); clear(data_name);
    
    for i=1:keyhole
        acq_rays_ind=((i-1)*key_views+1):i*key_views;
        n_views=1:nviews;
        n_views(acq_rays_ind)=0;
        ind_not_acq=find(n_views); %Indeces for the rays the center of which was not acquired
        
        di=d;
        di(:,1:Nyquist_cutoff,ind_not_acq)=NaN; %Channel 1
        di(:,(mat2+1):(mat2+Nyquist_cutoff),ind_not_acq)=NaN; %Channel 2
        key_name=['acq' num2str(j) '_key' num2str(i) '_data'];
        assignin('base', key_name, di); %Generate variable name and assign coordinates
        save(key_name, key_name, '-v7.3'); clear(key_name);
        
        k=['key' num2str(i) '_coords'];load(k);kv=eval(k); clear(k);
        dat=['acq' num2str(j) '_key' num2str(i) '_data']; load(dat);dv=eval(dat); clear(dat);
        dcf=['key' num2str(i) '_dcf'];load(dcf);dcfv=eval(dcf); clear(dcf);
        Bruker_recon_3Dradial_cryocoil(runno, dv, kv, dcfv, mat, j, i)
    end
    
end