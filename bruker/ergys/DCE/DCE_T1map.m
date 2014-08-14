% This function is used in the calculation of the T1, M0, and E1 maps with
% the variable flip angle (VFA) technique. It is assumed that the Bruker
% script QueuedACQ is used in the acquisition of the data. 1) Data are
% transferred from the Bruker scanner; 2) Images are reconstructed (no
% keyhole) 3) T1, M0, E1 are calculated from the reconstructed images.
exit();
% Ergys Subashi
% June, 2012


function []=DCE_T1map(Patient_ID, Study, T1_ScanRange, T1_runno, RF_coil)


%% INPUTS
% =========examples=========
% T1_runno='B99999test'; %Needs to be a string
% Patient_ID='20111007'; %Needs to be a string
% Study='20120501'; %Usually the date (needs to be a string)
% T1_ScanRange=33:40; %Scan IDs for the VFA data acquired with QueuedACQ
% RF_coil='4-element-array' or 'cryocoil' (string)

tStart=tic;
%=========================================================================


%% Get data from Bruker scanner
local_dir='/nospace'; cd(local_dir);
T1map_dir=[local_dir '/' T1_runno '.work']; mkdir(T1map_dir);
T1_ScanRange_string=[num2str(T1_ScanRange(1)) '-' num2str(T1_ScanRange(end))];
getbruker_command=['/pipe_home/script/bash/getbruker.bash ' T1map_dir ' ' Patient_ID ' ' Study ' ' T1_ScanRange_string];
system(getbruker_command)
transferred_dir=[T1map_dir '/' Patient_ID '_' Study];
cd(transferred_dir);
cd(num2str(T1_ScanRange(1)));
method_header=readBrukerHeader('method');
mat=method_header.PVM_Matrix;
mat=mat(1);
mat2=mat/2;
TR=method_header.PVM_RepetitionTime;


%% Get trajectory data and calculate dcf
t1=tic;
[kspace_coords, nviews]=Bruker_open_3D_traj(mat2);

iter=18; %Number of iterations used for dcf calculation
dcf=sdc3_MAT(kspace_coords, iter, mat, 0, 2.1, ones(mat2, nviews));

t1_end=toc(t1);
display(['Calculating the density compensation factors took ' num2str(t1_end/60) ' minutes'])


%% Recon
FAvalues=zeros(1,length(T1_ScanRange));
varFAstack=zeros(mat^3,length(T1_ScanRange));
for i=T1_ScanRange
    cd([transferred_dir '/' num2str(i)]);
    acqp_header=readBrukerHeader('acqp');
    scan_FA=acqp_header.ACQ_flip_angle;
    im_indx=i-T1_ScanRange(1)+1;
    FAvalues(im_indx)=scan_FA;
    
    % Get kspace data and reconstruct
    [kspace_data, ~]=Bruker_open_3D_fid(2*mat); % this should be nchannels*mat2 not 2*mat.
    
    im_name=[T1_runno '_m' num2str(im_indx)];
    cd(T1map_dir);
    if strcmp(RF_coil, '4-element-array')
        %the function below, "Bruker_recon_3Dradial_4element_array_coil"
        %does not seem to send back images that are scaled properly. For
        %example, the image intensity at a 10deg FA is not larger than the
        %image intensity at a 2deg FA (actually, the function return the
        %same image amplitude, so it seems that there is a scaling
        %problem?).
        im=Bruker_recon_3Dradial_4element_array_coil(im_name, kspace_data, kspace_coords, dcf, mat);
        varFAstack(:, im_indx)=im(:);
        %ADDED BY JOHN BELOW
        varFAstack(:, im_indx)=varFAstack(:, im_indx)/sin(FAvalues(im_indx)/180*pi);
    elseif strcmp(RF_coil, 'cryocoil')
        im=Bruker_recon_3Dradial_cryocoil(im_name, kspace_data, kspace_coords, dcf, mat);
        varFAstack(:, im_indx)=im(:);
        %ADDED BY JOHN BELOW
        varFAstack(:, im_indx)=varFAstack(:, im_indx)/sin(FAvalues(im_indx)/180*pi);
    else
        disp('Select correct RF coil: either "4-element-array" or "cryocoil"');
    end
end


%% Calculate T1map, M0map, and E1map. it also saves the different images used to calculate the T1 map.
[T1map, Mo_map, E1]=calcT1map_3D(TR, FAvalues, varFAstack, mat);

image_name=[T1_runno '_FAFirst.fp32'];
fid=fopen(image_name, 'w');
fwrite(fid, varFAstack(:, 1), 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

image_name=[T1_runno '_FASecond.fp32'];
fid=fopen(image_name, 'w');
fwrite(fid, varFAstack(:, 2), 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

image_name=[T1_runno 'T1.fp32'];
fid=fopen(image_name, 'w');
fwrite(fid, T1map, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

image_name=[T1_runno 'M0.fp32'];
fid=fopen(image_name, 'w');
fwrite(fid, Mo_map, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

image_name=[T1_runno 'E1.fp32'];
fid=fopen(image_name, 'w');
fwrite(fid, E1, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

save('varFAstack', 'varFAstack');
save('FAvalues', 'FAvalues');

varFA_TR=TR;
save('varFA_TR', 'varFA_TR');

tElapsed=toc(tStart);
display(['Reconstructing VFA images and calculating T1, M0, and E1 volumes took ' num2str(tElapsed/60) ' minutes'])
