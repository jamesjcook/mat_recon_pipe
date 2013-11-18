function fermi_filter_isodim2_memfix_obj(large_array,w1,w2,bool_2D_mode)
% -------------------------------------------------------------------------
% function fermi_filter_isodim2_memfix_obj(large_array,w1,w2,2D_switch)
% kspace_filter(iraw) generates the 3D filtered kspace image. Only filter 
% function is a fermi window. The input complex kspace dataset is
% multiplied by the 3D fermi window.
% evan has done additional work in his large dataset recon that
% could/should be added here to filter per element z to further reduce
% memory overhead.
%
% INPUT: "large_array" data handle object with property "data"
%                      data is the the array to be filtered
%                      data is the reshaped complex kspace dataset
%                      this is an n-dimensional array, it will be filtered
%                      either 2D or 3D at a time. 
%        "ray_width" fermi weight 1
%        "window_width' fermi 
%        2D_switch     true/false use 2D filtering or 3D.
% OUTPUT: is written directly to the object reference over the input.
%
% 2013/02/12 updated by James using code evan wrote to use less
% memory.(evan did the real work there) Also updated to use a reference
% object to avoid copies in memory.
% 
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
if ~exist('bool_2D_mode','var') 
    bool_2D_mode=false;
end
%% fermi filter
dx=size(large_array.data,1);
dy=size(large_array.data,2);
dz=size(large_array.data,3);
if bool_2D_mode
    dz=1;
end
mres=max([dx,dy,dz]);     % use the max res
nres=min([dx,dy,dz]);     % use the min res (is this supposed to  be mres istead of nres?)
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
    display('Filter calc done.');
end
FW=FW/max(FW(:));

% 
dims=size(large_array.data);
if numel(dims)==3
    large_array.data=large_array.data.*FW;
else
    %%%
    % code copy from the n-d 2d code
    if ~bool_2D_mode
        if numel(size(large_array.data))>3
            large_array.data=reshape(large_array.data,[dims(1:3) prod(dims(4:end))]);
        end
        %     oraw=zeros(size(iraw));
%         temp=large_array.data(:,:,:,1);
% these per volume loops appear to cause a memory double.
fprintf('Filtering %d volumes...\n',size(large_array.data,4));
tic;
        for v=1:size(large_array.data,4)
%             temp=large_array.data(:,:,:,v);
%             temp=temp.*FW;
%             temp=large_array.data(:,:,:,v).*FW;
%             large_array.data(:,:,:,v)=temp;
            large_array.data(:,:,:,v)=large_array.data(:,:,:,v).*FW;
        end
        fprintf('Apply filter time was %f seconds.\n',toc);
        %     oraw=reshape(oraw,dims);
    else
        for image=1:size(large_array.data,3)
            large_array.data(:,:,image)=large_array.data(:,:,image).*FW;
        end
    end
end
clear FW
if numel(large_array.data)>=max_array_elements
    display('Fitering finished');
end