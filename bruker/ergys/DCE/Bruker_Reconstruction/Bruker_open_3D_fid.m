% This function is used for extracting the data acquired with 3D radial
% scans in the Bruker scanner. It outputs:
% --kdata=matrix: kspace data extracted from source file. 
% --views=total number of views

%Inputs:
% --npts=number of sampling points per view 

%Call syntax: 
%[kdata, views]=open_Bruker_3D_fid(128)
%       or
%[kdata]=open_Bruker_3D_fid(256)


function [kdata, views]=open_Bruker_3D_fid(npts)
% this doesnt handle data which isnt a power of 2, that should be
% addressed, 
% also could be witten better. 
filename = 'fid';
fileid = fopen(filename, 'r', 'l');
raw = fread(fileid, Inf, 'int32');
fclose(fileid);


k_real = raw(1:2:end); %real channel k-space array
k_imag = raw(2:2:end); %imaginary channel k-space array
k_complex = complex(k_real,k_imag); % complex k-space data

views=length(k_real)/npts; %total number of views
sprintf('The total number of (kspace data) views is %d', views)

%reshape linear complex array
data=reshape(k_complex,npts,views);

kdata=zeros(2, npts, views);
real_data=real(data);
imag_data=imag(data);

kdata(1,:,1:views)=real_data(:,1:views);
kdata(2,:,1:views)=imag_data(:,1:views);


