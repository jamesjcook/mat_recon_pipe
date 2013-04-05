% This function reconstructs the DCE images using keyhole. A variable
% frequency cutoff (VFC) or uniform frequency cutoff (UFC) can be used when
% keyholing. A sliding window (SW) reconstruction method is used for either
% scheme (VFC or UFC). The combined hypervolume is then passed to the code
% calculating the concentration (mM) of contrast agent on a pixel by pixel
% basis.

% Ergys Subashi
% June, 2012


function []=DCE_calc_concentration(Patient_ID, Study, DCE_Scan_ID, DCE_runno, T1_runno, T1_ScanRange, Filtering_method, baseline_time, RF_coil)


%% INPUTS
% =========examples=========
% DCE_runno='B99999test'; %Needs to be a string
% T1_runno='B99998test'; %Needs to be a string
% Patient_ID='20111007'; %Needs to be a string
% Study='20120504'; %Usually the date (needs to be a string)
% DCE_Scan_ID=40; %Scan IDs for the DCE acquisition
% Filtering_method='VFC'; %Needs to be a string (either VFC or UFC)
% T1_ScanRange=33:40; %Scan IDs for the VFA data acquired with QueuedACQ
% RF_coil='4-element-array' or 'cryocoil' (string)


tStart=tic;
%=========================================================================


%% Get data from Bruker scanner
local_dir='/androsspace'; cd(local_dir);
DCE_dir=[local_dir '/' DCE_runno '.work']; mkdir(DCE_dir);
T1map_dir=[local_dir '/' T1_runno '.work'];
getbruker_command=['/pipe_home/script/bash/getbruker.bash ' DCE_dir ' ' Patient_ID ' ' Study ' ' num2str(DCE_Scan_ID)];
system(getbruker_command)
transferred_dir=[DCE_dir '/' Patient_ID '_' Study]; cd(transferred_dir);
cd(num2str(DCE_Scan_ID)); method_header=readBrukerHeader('method');
mat=method_header.PVM_Matrix; mat=mat(1); mat2=mat/2; TR_dyn=method_header.PVM_RepetitionTime;
key_hole=method_header.KeyHole; n_projs=method_header.NPro;
repeat=method_header.PVM_NRepetitions;
temp_rez=n_projs*TR_dyn/(key_hole*1000); %Temporal resolution in seconds
acqp_header=readBrukerHeader('acqp');
FA_dyn=acqp_header.ACQ_flip_angle;
cd(DCE_dir);
% movefile([T1map_dir '/' Patient_ID '_' Study '/' num2str(T1_ScanRange(2)) '/traj']);
movefile([transferred_dir '/' num2str(DCE_Scan_ID) '/fid']);


%% Parse all repeat data
tStart=tic;
[kspace_data_all, ~]=Bruker_open_3D_fid(2*mat);
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
    if strcmp(RF_coil, '4-element-array')
        Bruker_recon_3Dradial_4element_array_coil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
    elseif strcmp(RF_coil, 'cryocoil')
        Bruker_recon_3Dradial_cryocoil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
    else
        disp('Select correct RF coil: either "4-element-array" or "cryocoil"');
    end
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
        if strcmp(RF_coil, '4-element-array')
            Bruker_recon_3Dradial_4element_array_coil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        elseif strcmp(RF_coil, 'cryocoil')
            Bruker_recon_3Dradial_cryocoil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        else
            disp('Select correct RF coil: either "4-element-array" or "cryocoil"');
        end
        
    elseif indx == ceil(key_hole/2)
        data_full=data_full_current;
        key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
        k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
        dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
        if strcmp(RF_coil, '4-element-array')
            Bruker_recon_3Dradial_4element_array_coil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        elseif strcmp(RF_coil, 'cryocoil')
            Bruker_recon_3Dradial_cryocoil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        else
            disp('Select correct RF coil: either "4-element-array" or "cryocoil"');
        end
        
    else
        ind1=(indx-ceil(key_hole/2))*views_per_key;
        data_full=data_full_current;
        data_full(:,:,1:ind1)=data_full_next(:,:,1:ind1);
        key_data=Bruker_calc_key_data_3D_VFC(Nyquist_cutoff, incrmnt, indx, key_hole, data_full); %Get data for particular key
        k=['key' num2str(indx) '_coords_VFC'];load(k);key_kspace_coords=eval(k); %Get kspace coordinates for particular key
        dcf=['key' num2str(indx) '_dcf_VFC'];load(dcf);key_dcf=eval(dcf);clear(dcf); %Get dcf for particular key
        if strcmp(RF_coil, '4-element-array')
            Bruker_recon_3Dradial_4element_array_coil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        elseif strcmp(RF_coil, 'cryocoil')
            Bruker_recon_3Dradial_cryocoil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
        else
            disp('Select correct RF coil: either "4-element-array" or "cryocoil"');
        end
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
    if strcmp(RF_coil, '4-element-array')
        Bruker_recon_3Dradial_4element_array_coil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
    elseif strcmp(RF_coil, 'cryocoil')
        Bruker_recon_3Dradial_cryocoil([DCE_runno '_m' num2str(im_number)], key_data, key_kspace_coords, key_dcf, mat);
    else
        disp('Select correct RF coil: either "4-element-array" or "cryocoil"');
    end
    fclose('all');
    
end
tElapsed=toc(tStart);
display(['Reconstructing ' num2str(key_hole*repeat) ' keys using the sliding window method took ' num2str(tElapsed/60) ' minutes'])
fclose('all');

%% Concatenate volumes
tStart=tic;
concat_vol=zeros(mat,mat,mat*repeat*key_hole);
for j=1:key_hole*repeat
    vol_name= [DCE_runno '_m' num2str(j) '.f32'];
    vol=open_raw(vol_name, mat);
    concat_vol(:,:,((j-1)*mat+1):j*mat)=vol;
    fclose('all');
end

fid=fopen([DCE_runno '_concat_' num2str(repeat*key_hole) 'volumes.f32' ], 'w');
fwrite(fid, concat_vol, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

v=genvarname([DCE_runno '_concat_' num2str(repeat*key_hole) 'volumes']);
eval([v '=concat_vol;']);
save(v, v, '-v7.3');
tElapsed=toc(tStart);
display(['Concatenating ' num2str(key_hole*repeat) ' volumes took ' num2str(tElapsed/60) ' minutes'])


%% Calculate contrast concentration
load(['/Volumes/androsspace/' T1_runno '.work/FAvalues'])
load(['/Volumes/androsspace/' T1_runno '.work/varFAstack'])
load(['/Volumes/androsspace/' T1_runno '.work/varFA_TR'])
prepare_volumes_and_calc_conc_3D(DCE_runno, repeat, key_hole, temp_rez, baseline_time, varFA_TR, FAvalues, varFAstack, mat, TR_dyn, FA_dyn);

tElapsed=toc(tStart);
display(['Calculating the contrast agent concentration took ' num2str(tElapsed/60) ' minutes'])