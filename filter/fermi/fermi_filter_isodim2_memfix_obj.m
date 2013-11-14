function fermi_filter_isodim2_memfix_obj(large_array,w1,w2)
% -------------------------------------------------------------------------
% function fermi_filter_isodim2_memfix_obj(large_array,w1,w2)
% kspace_filter(iraw) generates the 3D filtered kspace image. Only filter 
% function is a fermi window. The input complex kspace dataset is
% multiplied by the 3D fermi window.
%
% INPUT: "large_array" data handle object with property "data"
%                      data is the the array to be filtered
%                      data is the reshaped complex kspace dataset
% OUTPUT: is written directly to the object reference over the input.
%
% 2013/02/12 updated by James using code evan wrote to use less
% memory.(evan did the real work there) Also updated to use a reference
% object to avoid copies in memory.
% written by LX 11/16/12, inspired by GPC, LU, RD
% -------------------------------------------------------------------------

meminfo=imaqmem;% get size of system memory
max_array_elements=meminfo.AvailPhys/8/4; % each element takes 8 bytes, 
% and we'll need 4 sets in memory so set warning level to 1/8th of 1/4.

disp('Filtering');
%% intial parameters
if ~exist('w1','var')
    w1='';
end
if ~exist('w2','var')
    w2='';
end
if strcmp(w1,'')
    w1=0.15;    % width [default: 0.15]
end
if strcmp(w2,'')
    w2=0.75;    % window [default: 0.75]
end
if ~isnumeric(w1)
    w1=str2double(w1);
    fprintf('\tcustom w entered=%2f\n',w1);% width [default: 0.15]
end
if ~isnumeric(w2)
    w2=str2double(w2);
    fprintf('\tcustom r entered=%2f\n',w2); % window [default: 0.75]
end

%% fermi filter
dx=size(large_array.data,1); dy=size(large_array.data,2); dz=size(large_array.data,3);

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
if numel(large_array.data)>=max_array_elements
    display('Starting fermi filtering, this can take a long time(5-30 minutes) on larger arrays, especially when falling out of memory.');
end
FW=1./(1+exp((sqrt(bsxfun(@plus,xvec,bsxfun(@plus,yvec,zvec)))-fermiu)/fermit));     % computing the FERMI window
if numel(large_array.data)>=max_array_elements
    display('main filtering done.');
end
FW=FW/max(FW(:));
% 
large_array.data=large_array.data.*FW;

clear FW
if numel(large_array.data)==max_array_elements
    display('fitering finished');
end