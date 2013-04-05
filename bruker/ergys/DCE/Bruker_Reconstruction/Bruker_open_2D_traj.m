% This function is used for extracting the k-space trajectory of the 2D
% radial scans in the Bruker scanner. It outputs:
% --traj=matrix: kspace coords extracted from the source file. The coords
%   are arranged in a 3D matrix of size (2)x(npts)x(views), where
%   traj(1,:,1) refer to the x-coordinates and traj(2,:,1) refer to the
%   y-coordinates
% --views=total number of views

%Inputs:
% --npts=number of sampling points per view 

%Call syntax: 
%[traj, views]=open_pfile(128)
%       or
%[traj]=open_pfile(256)


function [traj, views]=open_Bruker_2Dtraj(npts)

filename = 'traj';
fileid = fopen(filename, 'r', 'l');
raw = fread(fileid, Inf, 'double');
fclose(fileid);


k_real = raw(1:2:end); %real channel k-space array
k_imag = raw(2:2:end); %imaginary channel k-space array
traj = complex(k_real,k_imag); % complex k-space data

views=length(k_real)/npts; %total number of views
sprintf('The total number of (kspace coords) views is %d', views)

%reshape linear complex array
data=reshape(k_complex,npts,views);

traj=zeros(2, npts, views);
real_data=real(data);
imag_data=imag(data);

traj(1,:,1:views)=real_data(:,1:views);
traj(2,:,1:views)=imag_data(:,1:views);


