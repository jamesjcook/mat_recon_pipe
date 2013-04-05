function agilent_split(dir,fname);
%function agilent_split(dir,fname)
% splits fid file into individiual fids per volume
% loads fid file or fname file in dir
% saves results to dir as fname_m0..n (if not specified its fid_m0..n)

%% check input vars
if ~exist('fname','var')
    fname='fid';
else
    [path,parts]=regexp(fname,'^(.*)_m([0-9]+).*$','match','tokens');
    if sum(size(parts)>=1)
        base_name=parts{1}{1};
        volnum=str2num(parts{1}{2})+1; %matlab indexing start at 1 error
    else
        warning('agilent_recon:fname', 'fname specified, but not a _m# image.');
    end
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
    %     images_stop='n'% has to be set close to for loop
end
verbosity=0;

%% load data and scanner settings
procpar=readprocpar(dir,verbosity);
display('Reading fid file');
% [RE,IM,NP,NB,NT,HDR] = load_fid(dir);
[RE,IM,NP,NB] = load_fid(dir);
display(['Finished! Looks like there are ' num2str(NB) ' scan(s) to reconstruct']);

% get the number of navechoes
if isfield(procpar,'navechoes')
    navechoes = procpar.navechoes;
else
    navechoes = 0;
end

% get the dimensions of the scan
dim = [NP procpar.nv length(procpar.pss) NB];

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
if procpar.nv2 > 1
    % since the 3rd dimension is taken as a single slice with multiple
    % phase encodes, we have to get the voxel size and dimensions differently
    voxsize(3) = 10*procpar.lpe2/procpar.nv2;
    dim(3) = procpar.nv2;
end


% would change to be single here single(), but radish likes 64bit complex
% raw_data=single(reshape(complex(RE,IM),dim)); %reshape into complex array
raw_data=reshape(complex(RE,IM),dim); %reshape into complex array

path=dir;
name=procpar.studyid_{1};
im_max=zeros(1,NB);

if image_stop==-1
    image_stop=NB;
end


%% split and save
for i=image_start:image_stop
    %make output name
    if image_start==image_stop || image_stop<image_start
        name_tag='';
    else
        name_tag=['_m' num2str((i-1))];
    end
%     if cmdline==1
        outpath=[path '/' fname name_tag ]; %command line does complex output
%     else
%         outpath=[path '/' name '_scan_' num2str((i-1)) '.nii'];
%     end
    
    %raw_data(:,:,z,i)=fermi_filter_isodim2(raw_data(:,:,z,i));
    display('Saving...');
    save_complex(raw_data(:,:,:,i),outpath);
end