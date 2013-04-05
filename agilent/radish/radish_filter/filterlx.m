function oraw=filterlx(iraw,width,window)
% -------------------------------------------------------------------------
% kspace_filter(iraw) generates the 3D filtered kspace image. Only filter 
% function is a fermi window. The input complex kspace dataset is
% multiplied by the 3D fermi window.
%
% INPUT: "iraw" is the complex kspace dataset already reshaped  
% OUPUT: "oraw" is the filtered complex kspace data
% -------------------------------------------------------------------------

%% fermi filter

if ~exist('width','var')
    width=0.15;
end

if ~exist('window','var')
    window=0.75;
end

xres=size(iraw,1); yres=size(iraw,2); zres=size(iraw,3);
[y,x,z] = meshgrid(-yres/2:yres/2-1,-xres/2:xres/2-1,-zres/2:zres/2-1);
mres=max([xres,yres,zres]);     % use the max res to set up the fermi window

fermit=mres*width;   % fermi temp: increase for more curvature/smooth edge [default=.03]
fermiu=mres*window;  % fermi level: increase for larger window [default=.3]

kradius=sqrt(x.^2+y.^2+z.^2);               % use the elucidean dist to determine fermi
FW=1./(1+exp((kradius-fermiu)/fermit));     % computing the FERMI window

oraw=iraw.*FW;


