% This function is used for extracting the k-space trajectory of the 3D
% radial scans in the Bruker scanner. It outputs:
% --traj=matrix: kspace coords extracted from the source file. The coords
%   are arranged in a 3D matrix of size (3)x(npts)x(views), where
%   traj(1,:,:) refer to the x-coordinates, traj(2,:,:) refer to the
%   y-coordinates, and traj(3,:,:) refer to the z-coordinates.
% --views=total number of views

%Inputs:
% --npts=number of sampling points per view 

%Call syntax: 
%[traj, views]=open_Bruker_3Dtraj(256)
%       or
%[traj]=open_Bruker_3Dtraj(256)


function [traj, views]=open_Bruker_3Dtraj(npts)

filename = 'traj';
fileid = fopen(filename, 'r', 'l');
k_coords = fread(fileid, Inf, 'double');
fclose(fileid);

views=length(k_coords)/(3*npts); %total number of views
sprintf('The total number of (kspace coords) views is %d', views)

x_coords = k_coords(1:3:end); %x-coords
x_coords = reshape(x_coords, npts, views);
y_coords = k_coords(2:3:end); %y-coords
y_coords = reshape(y_coords, npts, views);
z_coords = k_coords(3:3:end); %z-coords
z_coords = reshape(z_coords, npts, views);

traj=zeros(3, npts, views);
traj(1,:,1:views)=x_coords(:,1:views);
traj(2,:,1:views)=y_coords(:,1:views);
traj(3,:,1:views)=z_coords(:,1:views);