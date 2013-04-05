% This script reconstructs the data acquired with "ute3d_keyhole.ppg" in
% the Bruker scanner. The data are reconstructed as undersampled (without
% keyholing). Only the views from a given acqusition are included in the
% reconstruction of the image, without combining the information from the
% periphery of k-space from the other acquisitions. Script works for data
% acquired with the four-element array coils.
% Note: Directory need "fid" and "traj" file only.

clc
%% INPUTS
runno='00663'; %Initial run number (needs to be string for now)
mat=128; %Reconstruction matrix size
keyhole=13; %Number of keys
repeat=20; %Number of times acquisition is repeated


%% Get trajectory data and calculate dcf
mat2=mat/2;
[kspace_coords, nviews]=Bruker_open_3D_traj(mat2);
key_views=nviews/keyhole;
for i=1:keyhole
    acq_rays_ind=((i-1)*key_views+1):i*key_views;
    n_views=1:nviews;
    n_views(acq_rays_ind)=0;
    ind_not_acq=find(n_views); %Indeces for the rays the center of which was not acquired
    
    k=kspace_coords;
    k(:,:,ind_not_acq)=[];

    iter=18; %Number of iterations used for dcf calculation
    dcf=sdc3_MAT(k, iter, mat, 0, 2.1, ones(mat2, key_views));


    dcf_name=['key' num2str(i) '_dcf'];
    key_name=['key' num2str(i) '_coords'];

    assignin('base', key_name, k); %Generate variable name and assign coordinates
    save(key_name, key_name, '-v7.3'); clear(key_name);
    assignin('base', dcf_name, dcf);
    save(dcf_name, dcf_name, '-v7.3'); clear(dcf_name);
end


%% Get kspace data and reconstruct
[kspace_data_all, tot_views]=Bruker_open_3D_fid(2*mat);
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
        di(:,:,ind_not_acq)=[]; 
        
        k=['key' num2str(i) '_coords'];load(k);kv=eval(k); clear(k);
        dcf=['key' num2str(i) '_dcf'];load(dcf);dcfv=eval(dcf); clear(dcf);
        Bruker_recon_3Dradial_4element_array_coil1(runno, di, kv, dcfv, mat, j, i)
    end
    fclose('all');
    
end