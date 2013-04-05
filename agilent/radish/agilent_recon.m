function agilent_recon(dir,fname,cmdline)
% function agilent_recon(dir,fname,cmdline)
% Loads an agilent procpar and fid file at dir, optionally using fname
% instead of 'fid' and peforms a recon of file. Saves data back to that
% directory, 
% If no cmdline not specified or any value except 1, saves seriesname.nii. 
% If cmdline==1 saves, little endian 32-bit floats of
%                 fname.out.mag,  magnitude image
%                 fname.out       complex image, interleaved, like radish,
%                 can be loaded with load_complex(path,[dims])
% if cmdline==2 saves like cmdline==1, however it assumes you've called
%                this with a plain multi fid file, instead of one named with its sequence
%                position. 
% should conver tthis function to stub which loads the fid file, then calls
% agi_recon_core to do work. agi_recon core should be small recon function
% which does just fft and returns fft'd array. this will better support
% being called for single or multi volumes. 


%% handle input
if ~exist('dir','var')
    dir=uigetdir('/Volumes/naxosspace/','Select fid directory');
end
if ~exist('fname','var')
    fname='fid';
    [path,parts]=regexp(dir,'^(.*)/(.*)_m([0-9]+).*$','match','tokens');
    if sum(size(parts)>=1)
        base_name=parts{1}{2};
    else 
        base_name='base_name_undefined';
    end
else
    [path,parts]=regexp(fname,'^(.*)_m([0-9]+).*$','match','tokens');
    if sum(size(parts)>=1)
        base_name=parts{1}{1};
        volnum=str2num(parts{1}{2})+1; %matlab indexing start at 1 error
        base_name=fname;
    else
        warning('agilent_recon:fname', 'fname specified, but not a _m# image.');
        [path,parts]=regexp(fname,'^(.*).rp$','match','tokens');
        base_name=parts{1}{1};
        base_name=fname;
    end
end
if ~exist('cmdline','var')
    cmdline=0;
% else
%     verbosity=0;

end
%%% do secondary input checking.
if ~exist([dir '/fid'],'file')
    system(['ln ' ' -fs ' dir '/' fname ' ' dir '/fid']);
end
if exist('volnum','var')
    image_start=volnum;
    image_stop=volnum;
else
    image_start=1;
    image_stop=-1;
    volnum=1;%need to set this for max check at end.
    %     images_stop='n'% has to be set close to for loop
end
if cmdline==1 % if we called this through perl dont roll, dont do tensor recon.
    rolling=0;
    tensor_recon=0;
    verbosity=0;
else
    rolling=1;
    tensor_recon=1;
    verbosity=1;
end

%% settings for script
overwrite=1; % should we overwrite existing reconstructions
% highest_intensity_percentage=99.95;
bitdepth=16;
img_max=(2^(bitdepth)-1); % because start at 0 not 1

%% load data and scanner settings
procpar=readprocpar(dir,verbosity);
%%%set up data object to hold each scan's worth of data to be passsed into
%%%loadfid, so we dong hve to copy data to separate the volumes.
display('Reading fid file, this can take a long time. '); 
warning('If this uses all available memory you should stop the process and look for ways to reduce memory usage');

[RE, IM, NP,NB,NT,HDR] = load_fid(dir);
meminfo=imaqmem;
if meminfo.MemoryLoad>80
    warning('MEMORYLOAD > 80% CONSIDER CANCELING. PAUSING 10 SECONDS SO YOU CAN SEE THIS MESSAGE');
    pause(10);
end
%RE  real data
%IM  imaginary data
%NP  
%NB  nblocks, might mean some kind of acquisition blocks, 
% number of volumes for dti, number of slices for single 3d
%NT  ntraces, either lines or slices of data, might be points for 2d
%HDR 
display(['Finished! Looks like there are ' num2str(procpar.volumes) ' scan(s) to reconstruct']);

% get the number of navechoes
if isfield(procpar,'navechoes')
    navechoes = procpar.navechoes;
else
    navechoes = 0;
end

% get the dimensions of the scan
% procapr.pss is always a single 0 so far. need to validate this part.

% dim = [NP procpar.nv length(procpar.pss) NB]; 
dim = [NP procpar.nv length(procpar.pss) procpar.volumes]; %NB seems to be used already in load_fid, so volumes looks more appropriate., note NB was not the right thing to do when not a dti volume.
% pss is not the right variable, it seems to always be 1 value, a 0
% (zero).


% check to see if this is a sense reconstruction and what the sense acceleration factor is
% senseFactor = []; % not c no need to pre-declare.
% if isfield(procpar,'petable') && ~isempty(procpar.petable{1}) && (length(procpar.petable{1}>1))
if isfield(procpar,'petable') && ~isempty(procpar.petable{1}) && (procpar.petable{1}>1)
    % petable name that ends in r means a sense protocol
    if isequal(procpar.petable{1}(end),'r')
        % check for the sense factor, (hopefully this number won't be greater than 9!!)
        senseFactor = str2num(procpar.petable{1}(end-1));
        % fix dimensions
        dim(1) = dim(1)*senseFactor;
        dim(2) = dim(2)*senseFactor;
        % print message
        sprintf('(fid2xform) Found a sense factor of %i. Dims are now [%i %i]',senseFactor,dim(1),dim(2)-navechoes)
    end
end

% remove navigator echoes from k-space
dim(2) = dim(2) - navechoes;

% get voxel sizes and put in diagonal to multiply against rotmat
% so that we get the proper spacing
voxsize = [10*procpar.lro/dim(1) 10*procpar.lpe/dim(2) procpar.thk];

% check for 3d acquisition
% this causes trouble in spin echo sequence, it 
if procpar.nv2 > 1
    % since the 3rd dimension is taken as a single slice with multiple
    % phase encodes, we have to get the voxel size and dimensions differently
    voxsize(3) = 10*procpar.lpe2/procpar.nv2;
    dim(3) = procpar.nv2;
end

%%% create nvolume array of dynamic data objects
raw_data(procpar.volumes)=large_array;
% raw_data=zeros(dim,'single');
%%%% would change to be single here single(), but radish likes 64bit complex
%%%% raw_data=single(reshape(complex(RE,IM),dim)); %reshape into complex array
if  procpar.ne > 1 % if multi-echo data, reshape it.
    if procpar.ne ~= procpar.volumes
        error('Multi-echo but not equal volumes unsure how to continue');
    end
    warning('THIS CODE MODIFIED FOR MEMORY EFFIENCY BLINDLY, UNSURE IF GOOD CODE');
    RE=reshape(RE,[dim(1) dim(4) dim(2) dim(3) ]);
    IM=reshape(IM,[dim(1) dim(4) dim(2) dim(3) ]);
    RE=permute(RE,[1 3 4 2]);
    IM=permute(IM,[1 3 4 2]);
%     
%     COM=reshape(COM,[dim(1) dim(4) dim(2) dim(3)]);
%     COM=permute(COM,[1 3 4 2]);
    % for the array of dataobjects this code makes sense, otherwise its bad
    for i=1:procpar.volumes
        raw_data(i).addprop('data');
%         raw_data(i).data=COM(:,:,:,i); %reshape into complex array
        raw_data(i).data=complex(RE(:,:,:,i),IM(:,:,:,i)); %reshape into complex array
    end
else
    %%% since reshapes are free operations in place, lets do that so we can
    %%% assign piece by piece to the raw_data object array.
    RE=reshape(RE,dim);
    IM=reshape(IM,dim);
%     COM=reshape(COM,dim);
    % for the array of dataobjects this code makes sense, otherwise its bad
    for i=1:procpar.volumes
        raw_data(i).addprop('data');
        raw_data(i).data=complex(RE(:,:,:,i),IM(:,:,:,i)); %reshape into complex array
%         raw_data(i).data=COM(:,:,:,i); %reshape into complex array
    end
end
% clear COM; 
clear RE IM;
% large data will not make it through theprocess unless we clear these as soon as possible.
%%% split raw_data.data into an array of objects.(double memory again, then clear it.)


path=dir;
% name=procpar.studyid_{1};
% im_max.mag=zeros(1,NB);
% im_max.imag=zeros(1,NB);
% im_max.real=zeros(1,NB);

im_max.mag=zeros(1,procpar.volumes);
im_max.imag=zeros(1,procpar.volumes);
im_max.real=zeros(1,procpar.volumes);

if image_stop==-1
%     image_stop=NB;
    image_stop=procpar.volumes;
end
if procpar.volumes==1
    image_start=procpar.volumes;
    image_stop=procpar.volumes;
end


meminfo=imaqmem;% get size of system memory
max_array_elements=meminfo.AvailPhys/8/4; % each element takes 8 bytes, 
% and we'll need 4 sets in memory so set warning level to 1/8th of 1/4.
%% recon each image
for i=image_start:image_stop
%     display(['Reconstructing scan ' num2str(i) ' of ' num2str(NB)]);
    display(['Reconstructing scan ' num2str(i) ' of ' num2str(procpar.volumes)]);
    %make output name
    if image_start==image_stop || image_stop<image_start
        name_tag='';
    else
        name_tag=['_m' num2str((i-1))];
    end
    if cmdline>=1
        outpath=[path '/' base_name name_tag '.out']; %command line does complex output
    else
        outpath=[path '/' base_name '_scan_' num2str((i-1)) '.nii'];
    end
    %if not done before
    % need this to look in alternate places too, eg, cmdline2, saves all to
    % same directory.
    if ~exist(outpath,'file') || overwrite    
    % MUST FIGURE OUT HOW TO PASS BY REFERENCE TO AVOID COPYING MEMORY.
        if procpar.acqdim==2 %recon 2D data
            display('2D Sequence reconstructing slice at a time');
            for z=1:dim(3) % perhaps parfor this?
                %fermi filter
%                 raw_data(:,:,z,i)=fermi_filter_isodim2_memfix(raw_data(:,:,:,i));
                raw_data(i).data(:,:,z)=fermi_filter_isodim2(raw_data(i).data(:,:,z));
            end
            %ifft
%             img=fftshift(ifft2(raw_data.data(:,:,:,i)));
            raw_data(i).data=fftshift(ifft2(raw_data(i).data));
        elseif procpar.acqdim==3 %recon 3D data
            %fermi filter inlined for better memory useage.
            fermi_filter_isodim2_memfix_obj(raw_data(i)); %
            %ifft
            raw_data(i).data=ifftn(raw_data(i).data);
            raw_data(i).data=fftshift(raw_data(i).data);
        else
            error('Acquisition dimensions not 2 or 3!');
        end
        mag=abs(raw_data(i).data);

        im_max.mag(i)=max(mag(:));
        %save output
        display(['Saving output to ' outpath '.']);
        if cmdline==0
            nii=make_nii(cast((mag./(im_max/img_max)),'uint16'),voxsize,[0 0 0],512);
            save_nii(nii,outpath);
        else
            im_max.imag(i)=max(imag(raw_data(i).data(:)));
            im_max.real(i)=max(real(raw_data(i).data(:)));
            %%% save mag(nitude)
            save_volume(mag,[outpath '.mag']);
            clear mag;
            if numel(raw_data(i).data)<max_array_elements
                %%% save complex data
                save_complex(raw_data(i).data,outpath);
                %%% save pha(se)
                pha=atan(imag(raw_data(i).data)./real(raw_data(i).data));
                save_volume(pha,[outpath '.pha']);
                clear pha;
            else
                warning('ARRAY SIZE TOO BIG TO SAVE PHASE AND COMPLEX OUTPUTS.');
            end
        end
    else
        display('Found outpath not overwriting.');
    end
    outpaths{i}=outpath;
end

%% radish maxmagfile dump
if cmdline==1 % this satisfies part of radish old junk
    outpath=[path '/' base_name '.out.maxmag'];
    display(['Saving output maxmag to ' outpath '.']);
%     data_max=max(im_max);
    ofid=fopen(outpath,'w+');
    if ofid==-1
        error('problem opening outmax file');
    end
    %12.529548=max magnitude found in 3d ft image volume
    fprintf(ofid,'%f=max magnitude found in 3d ft image volume\n',max(im_max.mag));
    %8.559792=max ichan found in 3d ft image volume
    fprintf(ofid,'%f=max ichan found in 3d ft image volume\n',max(im_max.imag));
    %11.998026=max qchan found in 3d ft image volume
    fprintf(ofid,'%f=max qchan found in 3d ft image volume\n',max(im_max.real));
    fclose(ofid);
    
    outpath=[path '/threeft_info_vintage.txt'];
    display(['Saving vintage threeft to ' outpath '.']);
    ofid=fopen(outpath,'w+');
    if ofid==-1
        error('problem opening outmax file');
    end
    fprintf(ofid,'110131 3d ft recon threeft program vintage\n');
    fclose(ofid);
 
end

%% do rolling if needed
% should have this run check if there are more than 1 volumes.
% (gary might not want that will have to decide if that will be
% default behavior or switched on).
if rolling==1
    resp=input('Would you like to roll your data in the y dimension? >> ','s');
    %%% OPEN IMAGE HERE TO CHECK ROLL AMOUNT.
    if strcmp(resp,'y')
        roll=input('What roll? >> ','s');
        for i=1:length(outpaths)
%             display(['Rolling scan ' num2str(i) ' of ' num2str(NB)]);
            display(['Rolling scan ' num2str(i) ' of ' num2str(procpar.volumes)]);
            outpaths{i}=roll_nii2(outpaths{i},[0 str2double(roll)]);
        end
    end
end

%% nii4d
% do nii4d if cmdline ~= 1


%% do tensor recon
if tensor_recon==1
 
%     if NB>=7
    if procpar.volumes>=7
        resp=input('This looks like a diffusion tensor run, would you like to do tensor recon? >> ','s');
        if strcmp(resp,'y')
            display('Making 4D NIfTI')
            nii4d=[path '/' name '_4D.nii'];
            out_prefix=[path '/' name '_'];
            
            %create gradient matrix file
            gm=[path '/gradient_matrix.txt'];
            fid=fopen(gm,'w','n','ISO-8859-13');
            fprintf(fid,'%d %d %d \n',cat(1,procpar.dro,procpar.dpe,procpar.dsl));
            fclose(fid);
            
            make_4dnifti(nii4d,voxsize(1),outpaths{:});
            display('Performing tensor recon');
            tensor_recon(nii4d,out_prefix,max(procpar.bvalue),gm);
        end
    end
end
end %function end


%%
function [scale, divisor]=get_adj_param(vol,img_max,highest_intensity_percentage)
    vol_s=sort(vol(:));
    adjusted_max=vol_s(round(length(vol_s)*highest_intensity_percentage/100));%throwaway highest % of data... see if that helps.
    divisor=adjusted_max/img_max; %use for ./ value
    scale=img_max/adjusted_max;   %use for .* value
end

%%
function save_complex(vol,path)
% function save_complex(vol,path), 
% saves an interleaved complex file 

% memusage is vol+2xvol for the complex file, might be 3xvol, for a working
% space.
    precision='single';
    dims=size(vol);
    comp=zeros([2,dims]);
    comp(1:2:end)=imag(vol);
    comp(2:2:end)=real(vol);
    fid=fopen(path,'w','l'); 
    if fid == -1
        error('could not open output path');
    end
    fwrite(fid,comp,precision,'l');
    fclose(fid);
    clear comp;
end

%%
function save_volume(vol,outpath,precision)
    if ~exist('precision','var')
        precision='single';
    end
    ofid=fopen(outpath,'w+','l');
    if ofid == -1
        error('Could not open output file');
    end
    fwrite(ofid,vol,precision,0,'l');
    fclose(ofid);
end
