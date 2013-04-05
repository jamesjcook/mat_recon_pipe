%This function generates the headfile needed for archiving

function []=gen_archiving_headfile(headfile_name, repeat, key_hole, total_nproj, undersampling_factor, recon_type, runno, civmid, projectcode, specimenid, dimx, dimy, dimz, fovX, fovY, fovZ, im_plane, FA, TE, TR, BW, baseline_time)

%==========INPUTS==========
% headfile_name=(string) name of headfile (wooooooooooooow)
% recon_type=(string)
% runno=(string) run number (ex: 'B00364')
% civmid=(string) ID of person who acquired data (ex: 'eds')
% projectcode=(string) project code (ex: '10.eds.02')
% specimenid=(string) specimen ID (ex: '120321-2:0')
% dim*=recon matrix size
% fov*=FOV in three directions
% im_plane=(string) imaging plane (ex: 'axial')
% FA=flip angle
% TE=echo time (ms)
% TR=repetition time (ms)
% BW=bandwidth (kHz)
% baseline_time=time (in sec) before injection (at baseline)
%==========OUTPUTS==========
% Headfile for archiving

file_name=[headfile_name '.headfile'];
headfile_cell{1,1}=['S_runno' '=' runno recon_type '_m' timepoint];
headfile_cell{2,1}=['U_civmid' '=' civmid];
headfile_cell{3,1}=['U_code' '=' projectcode];
headfile_cell{4,1}=['U_rplane' '=' im_plane];
headfile_cell{5,1}=['U_specid' '=' specimenid];
headfile_cell{6,1}=['alpha' '=' num2str(FA)];
headfile_cell{7,1}=['bw' '=' num2str(BW)];
headfile_cell{8,1}=['dim_X' '=' num2str(dimx)];
headfile_cell{9,1}=['dim_Y' '=' num2str(dimy)];
headfile_cell{10,1}=['dim_Z' '=' num2str(dimz)];
headfile_cell{11,1}=['fovx' '=' num2str(fovX)];
headfile_cell{12,1}=['fovy' '=' num2str(fovY)];
headfile_cell{13,1}=['fovz' '=' num2str(fovZ)];
headfile_cell{14,1}=['te' '=' num2str(TE)];
headfile_cell{15,1}=['tr' '=' num2str(TR)];
headfile_cell{16,1}='B_recon_type=ergys';
headfile_cell{17,1}='B_tesla=bt7';
headfile_cell{18,1}='F_imgformat=raw';
headfile_cell{19,1}='hfpmcnt=1';
headfile_cell{20,1}='U_status=ok';
headfile_cell{21,1}='B_header_type=ergys_recon';
headfile_cell{22,1}=['repeat' '=' num2str(repeat)];
headfile_cell{23,1}=['key_hole' '=' num2str(key_hole)];
headfile_cell{24,1}=['total_nproj' '=' num2str(total_nproj)];
headfile_cell{25,1}=['undersampling_factor' '=' num2str(undersampling_factor)];
headfile_cell{26,1}=['baseline_time' '=' num2str(baseline_time)];

dlmcell(file_name, headfile_cell);