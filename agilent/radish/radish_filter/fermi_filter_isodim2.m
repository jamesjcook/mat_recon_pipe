function oraw=fermi_filter_isodim2(iraw,w1,w2)
% -------------------------------------------------------------------------
% kspace_filter(iraw) generates the 3D filtered kspace image. Only filter 
% function is a fermi window. The input complex kspace dataset is
% multiplied by the 3D fermi window.
%
% INPUT: "iraw" is the complex kspace dataset already reshaped  
% OUPUT: "oraw" is the filtered complex kspace data
%
% written by LX 11/16/12, inspired by GPC, LU, RD
% -------------------------------------------------------------------------

%% intial parameters

if ~exist('w1','var')
    w1=0.15;    % width [default: 0.15]
end
if ~exist('w2','var')
    w2=0.75;    % window [default: 0.75]
end

%% fermi filter

dx=size(iraw,1); dy=size(iraw,2); dz=size(iraw,3);
[y,x,z] = meshgrid(-dy/2:dy/2-1,-dx/2:dx/2-1,-dz/2:dz/2-1);  % replace meshgrid with bsxfun ?
mres=max([dx,dy,dz]);     % use the max res 
nres=min([dx,dy,dz]);     % use the min res 

fermit=mres.*w1/2;   % fermi temp: increase for more curvature/smooth edge [default=.03]
fermiu=mres.*w2/2;  % fermi level: increase for larger window [default=.3]

%kradius=sqrt(x.^2+y.^2+z.^2);               % use the elucidean dist to determine fermi
kradius=sqrt(x.^2/(dx/mres)^2+y.^2/(dy/mres)^2+z.^2/(dz/mres)^2);               % use the elucidean dist to determine fermi

FW=1./(1+exp((kradius-fermiu)/fermit));     % computing the FERMI window
%FW=1./(1+exp((kradius-mres)/fermit));     % computing the FERMI window
FW=FW/max(FW(:));

oraw=iraw.*FW;

