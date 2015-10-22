run([getenv('WORKSTATION_HOME') '/recon/External/ScottHaileRobertson/Duke-CIVM-MRI-Tools/setup.m']);
run([getenv('WORKSTATION_HOME') '/recon/External/ScottHaileRobertson/GE-MRI-Tools/setup.m']);
run([getenv('WORKSTATION_HOME') '/recon/External/ScottHaileRobertson/Non-Cartesian-Reconstruction/setup.m']);


opt_struct.good='true';
% a sliding window recon of 4channel data.
% these are ergys standard acquisitions. Dummy header info had to be found
% to make use of these datasets. 
% their full dimensions are, 64x1980x13x11(by 4 channels)
% ray_length=64
% rays_per_key=1980
% keys_per_acq=13
% nfullwindows=11
% nchannels=4
%%B02124
opt_struct.dataFile = '/Users/james/Desktop/data/B02124/fid';
opt_struct.window_width=13;
opt_struct.trajectoryOnly=0;
% if exist('B02124','var')
    B02124=large_array;
    
% end
i=opt_struct.window_width;
sliding_window_recon(B02124,opt_struct)
if ~isfield(opt_struct,'trajectoryOnly')|| ( isfield(opt_struct,'trajectoryOnly') && opt_struct.trajectoryOnly==0)
    save_nii(make_nii(B02124.data),sprintf('/piperspace/B02124.work/B02124_win%d.nii',i));
end

%%B02126
opt_struct.dataFile ='/Users/james/Desktop/data/B02126/fid';
% if ~exist('B02126','var')
    B02126=large_array;
% end
sliding_window_recon(B02126,opt_struct)
if ~isfield(opt_struct,'trajectoryOnly')|| ( isfield(opt_struct,'trajectoryOnly') && opt_struct.trajectoryOnly==0)
save_nii(make_nii(B02126.data),sprintf('/piperspace/B02126.work/B02126_win%d.nii',i));
end