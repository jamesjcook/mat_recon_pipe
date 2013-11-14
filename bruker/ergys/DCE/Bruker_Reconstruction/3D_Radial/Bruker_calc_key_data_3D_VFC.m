%This function calculates the kspace data of each interleave (from a
%keyhole acquisition) using a variable cutoff frequency. This function is
%written with the intent that a sliding window reconstruction will be used.
%VFC=variable frequency cutoff


function [k]=Bruker_calc_key_data_3D_VFC...
    (Nyquist_cutoff, incrmnt, key_number, key_hole, kspace_data_full)
%kspace_data_full is one acq of kspace, it has bee cut out of 3 ergys
%repetition files


nviews=size(kspace_data_full, 3);
mat=size(kspace_data_full, 2);
mat2=mat/2;
k1=kspace_data_full(:,1:mat2,:); %Channel 1 data
k2=kspace_data_full(:,(mat2+1):end,:); %Channel 2 data
k=zeros(size(kspace_data_full));
for i=1:floor(key_hole/2) % this loop runs for half the number of times we have keys in a full sample set.
   
    indx1=key_number-i;
    if indx1<=0
        indx1=key_hole-abs(indx1);
    end
    indx2=key_number+i;
    if indx2>key_hole
        indx2=indx2-key_hole;
    end
%     indx1 and 2 will be for key_number 1, This complicated junk is to get
%     the right indices for the sliding window, the whole agorithim would
%     be better suited to using a fifo buffer of some kind.
%     13,2
%     12,3
%     11,4
%     10,5
%     9,6
%     8,7
    cf=1:(Nyquist_cutoff+round((i-1)*incrmnt*Nyquist_cutoff)); %cutoff frequency
    ind1=Bruker_calc_ind_3D_VCF(indx1, key_hole, nviews);
    ind2=Bruker_calc_ind_3D_VCF(indx2, key_hole, nviews);
    
    k1(:, cf, ind1)=NaN; %Channel 1
    k1(:, cf, ind2)=NaN;    
    
    k2(:, cf, ind1)=NaN; %Channel 2
    k2(:, cf, ind2)=NaN;
    
    k(:,1:mat2,:)=k1(:,1:mat2,:);
    k(:,(mat2+1):end,:)=k2(:,1:mat2,:);
       
end