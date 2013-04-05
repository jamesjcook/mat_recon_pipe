% This function will roll a NIfTI image by shiftsize=[x y z] where x, y amd
% z are positive or negative integer voxel values.  For example, if
% shiftsize = [0 -60] (equivalent to [0 60 0]) then the resulting image
% will be shifted up 60 pixels in y (the new y=0 will be where the old
% y=60 was).  The output will be saved in the same folder as the input nii
% with the title "input_title_rolled.nii".
% Example usage: roll_nii('/Volumes/trinityspace/S56300.nii', [0 -60 0])

function roll_nii(input_nii,shiftsize,outpath)
nii=load_untouch_nii(input_nii);
nii.img=circshift(nii.img, shiftsize);
[folder name ext]=fileparts(input_nii);
if exist('outpath','var')
    output_nii=outpath;
else
    output_nii=[folder '/' name '_rolled' ext];
end
save_untouch_nii(nii,output_nii);