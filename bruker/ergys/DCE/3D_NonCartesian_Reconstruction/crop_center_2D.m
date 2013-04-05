% This function crops the center of the 2D image after it has been been
% reconstructed with oversampling. Works for isotropic image only (for now)

function im=crop_center_2D(im1, im_size)

im1_size=size(im1,1);
d=im1_size-im_size;
d2=floor(d/2);

s=(d2+1);
e=s+im_size-1;
im=im1(s:e,s:e);