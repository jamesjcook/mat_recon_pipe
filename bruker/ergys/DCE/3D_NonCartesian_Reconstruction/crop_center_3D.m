% This function crops the center of the 3D image after it has been been
% reconstructed with oversampling. Works for isotropic image only (for now)

function im=crop_center_3D(im1, im_size)

if false
    ogf=3;
    im_size=128;
    im1=rand(im_size*ogf,im_size*ogf,im_size*ogf);
end

im1_size=size(im1,1);
d=im1_size-im_size;
d2=floor(d/2);

start_idx=(d2+1);
end_idx=start_idx+im_size-1;
im=im1(start_idx:end_idx,start_idx:end_idx,start_idx:end_idx);
