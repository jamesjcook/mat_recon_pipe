% This function calculates the indices of the views the center of which was
% acquired fully with keyhole imaging. To be used mostly for the variable
% cutoff frequency (VCF) recon.

function ind=Bruker_calc_ind_3D_VCF(key_number, keyhole, nviews)

key_views=nviews/keyhole;
ind=((key_number-1)*key_views+1):key_number*key_views;
