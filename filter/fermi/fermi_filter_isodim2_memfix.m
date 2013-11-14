function raw_data=fermi_filter_isodim2_memfix(raw_data,w1,w2)
% -------------------------------------------------------------------------
% kspace_filter(iraw) generates the 3D filtered kspace image. Only filter 
% function is a fermi window. The input complex kspace dataset is
% multiplied by the 3D fermi window.
%
% INPUT: "iraw" is the complex kspace dataset already reshaped  
% OUPUT: "oraw" is the filtered complex kspace data
%
% updated by James using code evan wrote to use less memory.(evan did the
% real work there)
% written by LX 11/16/12, inspired by GPC, LU, RD
% -------------------------------------------------------------------------

meminfo=imaqmem;% get size of system memory
max_array_elements=meminfo.AvailPhys/8/4; % each element takes 8 bytes, 
% and we'll need 4 sets in memory so set warning level to 1/8th of 1/4.

%% intial parameters
if ~exist('w1','var')
    w1=0.15; % width [default: 0.15]
end
if ~exist('w2','var')
    w2=0.75;  % window [default: 0.75]
end

%% fermi filter
dx=size(raw_data,1); dy=size(raw_data,2); dz=size(raw_data,3);

mres=max([dx,dy,dz]);     % use the max res
%
fermit=single(mres.*w1/2);   % fermi temp: increase for more curvature/smooth edge [default=.03]
fermiu=single(mres.*w2/2);  % fermi level: increase for larger window [default=.3]
%
xvec=reshape(single(-dx/2:dx/2-1),[],1,1);
xvec=xvec.^2/(dx/mres).^2;
yvec=reshape(single(-dy/2:dy/2-1),1,[],1);
yvec=yvec.^2/(dy/mres).^2;
zvec=reshape(single(-dz/2:dz/2-1),1,1,[]);
zvec=zvec.^2/(dz/mres).^2;

% 
if numel(raw_data)>=max_array_elements
    display('Starting fermi filtering, this can take a long time(5-30 minutes) on larger arrays, especially when falling out of memory.');
end
FW=1./(1+exp((sqrt(bsxfun(@plus,xvec,bsxfun(@plus,yvec,zvec)))-fermiu)/fermit));     % computing the FERMI window
if numel(raw_data)>=max_array_elements
    display('main filtering done.');
end
FW=FW/max(FW(:));
% 
raw_data=raw_data.*FW;

clear FW
if numel(raw_data)>=max_array_elements
    display('fitering finished');
end