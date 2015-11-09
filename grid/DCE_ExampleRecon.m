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

opt_struct.trajectoryOnly=0;
% if exist('B02124','var')
    B02124=large_array;
    
% end
win_val=[13,7,3,1];
for n=1:length(win_val)
    B02124=large_array;
    opt_struct.window_width=win_val(n);
    opt_struct.sharpness=0.21;
    sliding_window_recon(B02124,opt_struct)
    if ~isfield(opt_struct,'trajectoryOnly')|| ( isfield(opt_struct,'trajectoryOnly') && opt_struct.trajectoryOnly==0)
        save_nii(make_nii(B02124.data),sprintf('/piperspace/B02124.work/B02124_win%d_shrp%g.nii',opt_struct.window_width,opt_struct.sharpness));
    end
end

win_val=[7,3,1];
sharp_vals=[0.25,0.3,0.35];
for n=1:length(win_val)
    B02124=large_array;
    opt_struct.window_width=win_val(n);
    opt_struct.sharpness=sharp_vals(n);
    sliding_window_recon(B02124,opt_struct)
    if ~isfield(opt_struct,'trajectoryOnly')|| ( isfield(opt_struct,'trajectoryOnly') && opt_struct.trajectoryOnly==0)
        save_nii(make_nii(B02124.data),sprintf('/piperspace/B02124.work/B02124_win%d_shrp%g.nii',opt_struct.window_width,opt_struct.sharpness));
    end
end

sharp_vals=[0.2,0.3,0.4,0.5,0.6,0.7];
for n=1:length(sharp_vals)
    B02124=large_array;
    opt_struct.window_width=3;
    opt_struct.sharpness=sharp_vals(n);
    sliding_window_recon(B02124,opt_struct)
    if ~isfield(opt_struct,'trajectoryOnly')|| ( isfield(opt_struct,'trajectoryOnly') && opt_struct.trajectoryOnly==0)
        save_nii(make_nii(B02124.data),sprintf('/piperspace/B02124.work/B02124_win%d_shrp%g.nii',opt_struct.window_width,opt_struct.sharpness));
    end
end

if exist('continue','var')
%%B02126
opt_struct.dataFile ='/Users/james/Desktop/data/B02126/fid';
% if ~exist('B02126','var')
    B02126=large_array;
% end
sliding_window_recon(B02126,opt_struct)
if ~isfield(opt_struct,'trajectoryOnly')|| ( isfield(opt_struct,'trajectoryOnly') && opt_struct.trajectoryOnly==0)
save_nii(make_nii(B02126.data),sprintf('/piperspace/B02126.work/B02126_win%d.nii',i));
end
end