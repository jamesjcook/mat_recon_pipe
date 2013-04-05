%This script reconstructs the data using the variable frequency cutoff method and
%sliding window. It can be adapted (by setting incrmnt=0) for doing a
%sliding window recon using a uniform frequency cutoff.

clc
%% Describe data
runno='00317'; %Initial run number (needs to be string for now)
mat=128;
mat2=mat/2;
key_hole=13;
repeat=20;


%% Get and parse all data 
tStart=tic;
[kspace_data_all, tot_views]=Bruker_open_3D_fid(mat);
Bruker_parse_acquisition_data(kspace_data_all, repeat);
tElapsed=toc(tStart);
display(['Getting and parsing all data took ' num2str(tElapsed/60) ' minutes'])


%% Get the kspace coordinates for full (non-keyholed) acquisition
[kspace_coords_full, nviews]=Bruker_open_3D_traj(mat2);


%% Calculate k-space coordinates of each key in acqusition using a variable frequency cutoff
Nyquist_cutoff=26;
% d=floor(key_hole/2)-1;
% incrmnt=(mat2-Nyquist_cutoff)/Nyquist_cutoff/d;
incrmnt=0; %Use a uniform frequency cutoff (at Nyquist)
for i=1:key_hole
Bruker_calc_key_coords_3D_VFC(Nyquist_cutoff, incrmnt, i, key_hole, kspace_coords_full);
end


%% Calculate the dcf for the coordinates of each key
tStart=tic;
for i=1:key_hole
    
    k=['key' num2str(i) '_coords_VFC'];load(k);kv=eval(k); clear(k);
    iter=18; %Number of iterations used for dcf calculation
    dcf=sdc3_MAT(kv, iter, mat, 0, 2.1, ones(mat2, nviews));
    dcf_name=['key' num2str(i) '_dcf_VFC'];
    assignin('base', dcf_name, dcf);
    save(dcf_name, dcf_name, '-v7.3'); clear(dcf_name);
    
end
tElapsed=toc(tStart);
display(['Calculating the dcf for all keys took ' num2str(tElapsed/60) ' minutes'])


%% Reconstruct the first acqusition (for which no sliding window is required)
tStart=tic;
for im_number=1:key_hole %These keys do not need to be reconned using a sliding window assuming injection was after first full acquisition (acquisition of "key_hole" keys)
    
    [rep_indx,indx]=Bruker_calc_SW_indx(im_number, key_hole); %Index for current acqusition and key
    dat=['acq' num2str(rep_indx) '_data']; load(dat);data_full=eval(dat);clear(dat);
    key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
    k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
    dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
    Bruker_recon_3Dradial_cryocoil(runno, key_data, key_kspace_coords, key_dcf, mat, rep_indx, indx);
    fclose('all');

end


%% Reconstruct using sliding window
views_per_key=nviews/key_hole;
data_full=zeros(size(data_full));
for im_number=(key_hole+1):(key_hole*(repeat-1))
    
    [rep_indx,indx]=Bruker_calc_SW_indx(im_number, key_hole);
    dat=['acq' num2str(rep_indx-1) '_data']; load(dat);data_full_previous=eval(dat);clear(dat);
    dat=['acq' num2str(rep_indx) '_data']; load(dat);data_full_current=eval(dat);clear(dat);
    dat=['acq' num2str(rep_indx+1) '_data']; load(dat);data_full_next=eval(dat);clear(dat);
    
    if indx < ceil(key_hole/2)
        ind1=(ceil(key_hole/2)-indx)*views_per_key;
        data_full=data_full_current;
        data_full(:,:,(nviews-ind1+1):end)=data_full_previous(:,:,(nviews-ind1+1):end);
        key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
        k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
        dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
        Bruker_recon_3Dradial_cryocoil(runno, key_data, key_kspace_coords, key_dcf, mat, rep_indx, indx);
        
    elseif indx == ceil(key_hole/2)
        data_full=data_full_current;
        key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
        k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
        dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
        Bruker_recon_3Dradial_cryocoil(runno, key_data, key_kspace_coords, key_dcf, mat, rep_indx, indx);
        
    else
        ind1=(indx-ceil(key_hole/2))*views_per_key;
        data_full=data_full_current;
        data_full(:,:,1:ind1)=data_full_next(:,:,1:ind1);
        key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
        k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
        dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
        Bruker_recon_3Dradial_cryocoil(runno, key_data, key_kspace_coords, key_dcf, mat, rep_indx, indx);
    end
    fclose('all');
    
end


%% Reconstruct the keys at the end of the acquisition (sliding window not needed)
for im_number=(key_hole*(repeat-1)+1):key_hole*repeat
    
    [rep_indx,indx]=Bruker_calc_SW_indx(im_number, key_hole);
    dat=['acq' num2str(rep_indx) '_data']; load(dat);data_full=eval(dat);clear(dat);
    key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
    k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
    dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
    Bruker_recon_3Dradial_cryocoil(runno, key_data, key_kspace_coords, key_dcf, mat, rep_indx, indx);
    fclose('all');
    
end
tElapsed=toc(tStart);
display(['Reconstructing ' num2str(key_hole*repeat) ' keys using the sliding window method took ' num2str(tElapsed/60) ' minutes'])