% This function reconstructs dynamic images acquired with the cryocoil
% using the keyhole technique. A variable frequency cutoff (VFC) or uniform
% frequency cutoff (UFC) can be used when keyholing. A sliding window (SW)
% reconstruction method is used for either scheme (VFC or UFC). The
% reconstructed volumes are then combined in a hypervolume.

% Ergys Subashi
% November, 2012


function []=cryocoil_4D_recon(Patient_ID, Study, Scan_ID, runno, Traj_runno, Traj_Scan_ID, Filtering_method)


%% INPUTS
% =========examples=========
% runno='B99999test'; %Needs to be a string
% Traj_runno='B99998test'; %Needs to be a string
% Patient_ID='20111007'; %Needs to be a string
% Study='20120504'; %Usually the date (needs to be a string)
% Scan_ID=40; %Scan ID for the dynamic scan
% Filtering_method='VFC'; %Needs to be a string (either VFC or UFC)
% Traj_Scan_ID=39; %Scan ID for the scan measuring the k-space trajectory


tStart=tic;
%=========================================================================


%% Get data from Bruker scanner
local_dir='/androsspace'; cd(local_dir);
dynamic_scan_dir=[local_dir '/' runno '.work']; mkdir(dynamic_scan_dir);
Traj_dir=[local_dir '/' Traj_runno '.work'];
getbruker_command=['/pipe_home/script/bash/getbruker.bash ' dynamic_scan_dir ' ' Patient_ID ' ' Study ' ' num2str(Scan_ID)];
system(getbruker_command)
transferred_dir=[dynamic_scan_dir '/' Patient_ID '_' Study]; cd(transferred_dir);
cd(num2str(Scan_ID)); method_header=readBrukerHeader('method');
mat=method_header.PVM_Matrix; mat=mat(1); mat2=mat/2; 
key_hole=method_header.KeyHole; 
repeat=method_header.PVM_NRepetitions;
cd(dynamic_scan_dir);
movefile([Traj_dir '/' Patient_ID '_' Study '/' num2str(Traj_Scan_ID) '/traj']);
movefile([transferred_dir '/' num2str(Scan_ID) '/fid']);


%% Parse all repeat data
tStart=tic;
[kspace_data_all, ~]=Bruker_open_3D_fid(mat);
Bruker_parse_acquisition_data(kspace_data_all, repeat);
tElapsed=toc(tStart);
display(['Getting and parsing all data took ' num2str(tElapsed/60) ' minutes'])


%% Get the kspace coordinates for full (non-keyholed) acquisition
[kspace_coords_full, nviews]=Bruker_open_3D_traj(mat2);


%% Calculate k-space coordinates of each key in acqusition using a variable frequency cutoff
Nyquist_cutoff=25;
if strcmp(Filtering_method, 'VFC')
    d=floor(key_hole/2)-1;
    incrmnt=(mat2-Nyquist_cutoff)/Nyquist_cutoff/d;
elseif strcmp(Filtering_method, 'UFC')
    incrmnt=0; %Use a uniform frequency cutoff (at Nyquist)
else
    error('Select correct filtering method: either VFC or UFC (make sure it is a string)')
end

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
    eval([dcf_name '=dcf;']);
    save(dcf_name, dcf_name', '-v7.3');
    
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
    Bruker_recon_3Dradial_cryocoil([runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
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
        Bruker_recon_3Dradial_cryocoil([runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        
    elseif indx == ceil(key_hole/2)
        data_full=data_full_current;
        key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
        k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
        dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
        Bruker_recon_3Dradial_cryocoil([runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        
    else
        ind1=(indx-ceil(key_hole/2))*views_per_key;
        data_full=data_full_current;
        data_full(:,:,1:ind1)=data_full_next(:,:,1:ind1);
        key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
        k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
        dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
        Bruker_recon_3Dradial_cryocoil([runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
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
    Bruker_recon_3Dradial_cryocoil([runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
    fclose('all');
    
end
tElapsed=toc(tStart);
display(['Reconstructing ' num2str(key_hole*repeat) ' keys using the sliding window method took ' num2str(tElapsed/60) ' minutes'])
fclose('all');

%% Concatenate volumes
tStart=tic;
concat_vol=zeros(mat,mat,mat*repeat*key_hole);
for j=1:key_hole*repeat
    vol_name= [runno '_m' num2str(j) '.f32'];
    vol=open_raw(vol_name, mat);
    concat_vol(:,:,((j-1)*mat+1):j*mat)=vol;
    fclose('all');
end

fid=fopen([runno '_concat_' num2str(repeat*key_hole) 'volumes.f32' ], 'w');
fwrite(fid, concat_vol, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

v=genvarname([runno '_concat_' num2str(repeat*key_hole) 'volumes']);
eval([v '=concat_vol;']);
save(v, v, '-v7.3');
tElapsed=toc(tStart);
display(['Concatenating ' num2str(key_hole*repeat) ' volumes took ' num2str(tElapsed/60) ' minutes'])

%% 
tElapsed=toc(tStart);
display(['Reconstructing and concatenating all data from dynamic scan took ' num2str(tElapsed/60) ' minutes'])