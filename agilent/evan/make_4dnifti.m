% This function will take a variable number of NIfTI files and create a 4D
% hyperstack with each image volume as a different element in the 4th
% dimension.  If the files are different bit depths, make sure the first
% file specified is the highest bit-depth (i.e. 32 bit) as it will convert
% all subsequent files to this bit-depth.  Combining RGB color and
% grayscale images will not work.  Also note that if each image has
% different levels, then you will have to readjust levels when you switch
% between volumes.

% -Evan Calabrese

function [res]=make_4dnifti(outpath, iso_voxelsize, varargin)

% arbitrary number of nifti filenames follow voxelsize; these get made into one 4D nifti.

filenames=varargin(:);

%function [res]=make_4dnifti(outpath,voxelsize, filename1, filename2, filename3, filename4, filename5, filename6, filename7 )
%filenames={ filename1 filename2 filename3 filename4 filename5 filename6 filename7 };




for i=1:length(filenames)
    display(['loading file ' num2str(i) ' of ' num2str(length(filenames))]);
    nii=load_nii(filenames{i});
    if isnan(iso_voxelsize);
        iso_voxelsize=nii.hdr.dime.pixdim(2);
    end
    im(:,:,:,i)=nii.img;
    clear nii;
end

% forcing isotropic for now 
voxelsizex=iso_voxelsize;
voxelsizey=iso_voxelsize;
voxelsizez=iso_voxelsize;
    
im=make_nii(im, [voxelsizex voxelsizey voxelsizez] , [0 0 0 ]);
save_nii(im,strcat(outpath));

res = 1;  % provide result code for Perl caller to check 
