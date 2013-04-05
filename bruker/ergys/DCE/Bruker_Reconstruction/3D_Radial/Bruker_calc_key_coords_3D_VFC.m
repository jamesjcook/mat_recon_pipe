%This function calculates the kspace coordinates of each interleave (from a
%keyhole acquisition) using a variable cutoff frequency. This function is
%written with the intent that a sliding window reconstruction will be used.
%VFC=variable frequency cutoff


function []=Bruker_calc_key_coords_3D_VFC(Nyquist_cutoff, incrmnt, key_number, key_hole, kspace_coords_full)

nviews=size(kspace_coords_full, 3);
k=kspace_coords_full;
for i=1:floor(key_hole/2)
   
    indx1=key_number-i;
    if indx1<=0
        indx1=key_hole-abs(indx1);
    end
    indx2=key_number+i;
    if indx2>key_hole
        indx2=indx2-key_hole;
    end
    
    cf=1:(Nyquist_cutoff+round((i-1)*incrmnt*Nyquist_cutoff)); %cutoff frequency
    ind1=Bruker_calc_ind_3D_VCF(indx1, key_hole, nviews);
    ind2=Bruker_calc_ind_3D_VCF(indx2, key_hole, nviews);
    
    k(:, cf, ind1)=NaN;
    k(:, cf, ind2)=NaN;
       
end

v=['key' num2str(key_number) '_coords_VFC'];
eval([v '=k;']);
save(v,v, '-v7.3'); clear(v); %Save and clear