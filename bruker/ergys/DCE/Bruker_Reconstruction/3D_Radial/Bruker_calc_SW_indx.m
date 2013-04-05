% This function calculates the indeces for a particular key given a
% key_number (useful shortcut for sliding window recon)

function [rep, key_indx]=Bruker_calc_SW_indx(key_number, key_hole)

rep=ceil(key_number/key_hole);
key_indx=key_number-(rep-1)*key_hole;

if key_indx==0
    key_indx=key_hole;
end