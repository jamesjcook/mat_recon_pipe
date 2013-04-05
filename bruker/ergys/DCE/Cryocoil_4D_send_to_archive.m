% This function prepares the dynamic data (acquired with the cryocoil)
% for archival and sends them to the archive machines.

% Ergys Subashi
% November, 2012


function [im_indx1, im_indx_end]=Cryocoil_4D_send_to_archive(Patient_ID, Study, DCE_Scan_ID, DCE_runno, T1_runno, Filtering_method, civmid, projectcode, specimenid, baseline_time, RF_coil)
% ===========INPUT================
% ==========(examples)============
% T1_runno='B00534'; %Needs to be a string
% DCE_runno='B00535'; %Needs to be a string
% Patient_ID='20111007'; %Needs to be a string
% Study='20120510'; %Usually the date (needs to be a string)
% DCE_Scan_ID=17; %Scan IDs for the VFA data acquired with QueuedACQ
% Filtering_method='VFC'; %Needs to be a string
% baseline_time=2*60+30; %time (in sec) before injection (at baseline)
% D=0.5; %Dose [mmol/kg]
% RF_coil='cryocoil' (string)
% ===========OUTPUTS================
% im_indx1=first image index for dynamic dataset
% im_indx_end=last image index for dynamic dataset

tStart=tic;
%=========================================================================

%% Reconstruction directories
local_dir='/androsspace';  cd(local_dir);
DCE_dir=[local_dir '/' DCE_runno '.work'];
T1map_dir=[local_dir '/' T1_runno '.work'];
T1map_transferred_dir=[T1map_dir '/' Patient_ID '_' Study];
DCE_transferred_dir=[DCE_dir '/' Patient_ID '_' Study];


%% Archive dynamic data
method_header=readBrukerHeader([DCE_transferred_dir '/' num2str(DCE_Scan_ID) '/method']);
acqp_header=readBrukerHeader([DCE_transferred_dir '/' num2str(DCE_Scan_ID) '/acqp']);
mat=method_header.PVM_Matrix; mat=mat(1);
method_header.FAvalues=acqp_header.ACQ_flip_angle;
method_header.baseline_time=baseline_time;
method_header.RFcoil=RF_coil;
key_hole=method_header.KeyHole;
repeat=method_header.PVM_NRepetitions;
hdrs=catstruct(method_header, acqp_header);

cd(DCE_dir);
hypervol_name=[DCE_runno '_concat_' num2str(repeat*key_hole) 'volumes'];
load(hypervol_name); hypervolume=eval(hypervol_name); clear(hypervol_name);
global_scalar=max(hypervolume(:));

for i=1:repeat*key_hole
    cd(local_dir);
    m_indx=gen_archiving_slice_indx(i, repeat*key_hole);
  
    if i==1;
        im_indx1=m_indx;
    elseif i==repeat*key_hole
        im_indx_end=m_indx;
    end
    archive_dir=[DCE_runno '_m' m_indx]; mkdir(archive_dir); cd(archive_dir);
    archive_im_dir=[archive_dir 'images']; mkdir(archive_im_dir); cd(archive_im_dir);
    headfile_name=[DCE_runno '_m' m_indx '.headfile'];
    fid=fopen(headfile_name, 'w');

    fprintf(fid, '%s\n', ['S_runno' '=' DCE_runno '_m' m_indx]);
    fprintf(fid, '%s\n', ['U_civmid' '=' civmid]);
    fprintf(fid, '%s\n', ['U_code' '=' projectcode]);
    fprintf(fid, '%s\n', ['U_specid' '=' specimenid]);
    fprintf(fid, '%s\n', ['scaling_factor' '=' num2str(global_scalar)]);
    fprintf(fid, '%s\n', ['Recon_filtering_method' '=' Filtering_method]);
    fclose(fid);
    vol=hypervolume(:,:,((i-1)*mat+1):i*mat);
    vol=(vol/global_scalar)*(2^15-1); %Scaling and converting to 16-bit (lab convention)
    
    write_civm_slices([DCE_runno '_m' m_indx], vol, mat, 'civmraw', 0);
    write_struc2headfile(hdrs, headfile_name, 'raw', 'z_Bruker_');
    write_tagfile_DCE([DCE_runno '_m' m_indx], mat, projectcode, civmid, Filtering_method, 'raw');
    fclose('all');
end