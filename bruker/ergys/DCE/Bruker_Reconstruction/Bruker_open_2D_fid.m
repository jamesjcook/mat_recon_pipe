% This function is used for extracting the data acquired with 2D radial
% scans in the Bruker scanner. It outputs:
% --kdata=matrix: kspace data extracted from source file. 
% --views=total number of views

%Inputs:
% --npts=number of sampling points per view 

%Call syntax: 
%[kdata, views]=open_Bruker_2D_fid(128)
%       or
%[kdata]=open_Bruker_2D_fid(256)


function [kdata, views]=open_Bruker_2D_fid(npts)

filename = 'fid';
fileid = fopen(filename, 'r', 'l');
raw = fread(fileid, Inf, 'int32');
fclose(fileid);


k_real = raw(1:2:end); %real channel k-space array
k_imag = raw(2:2:end); %imaginary channel k-space array
k_complex = complex(k_real,k_imag); % complex k-space data

views=length(k_real)/npts; %total number of views
display(['The total number of (kspace data) views is ' num2str(views)])

kdata=reshape(k_complex, npts, views);


