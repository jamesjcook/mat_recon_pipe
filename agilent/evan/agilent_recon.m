function agilent_recon(scanner,runno,study,series,option)
%% Agilent Recon Help
%
% USAGE: agilent_recon scanner runno study series {option}
%
% EXAMPLE 1: agilent_recon kamy S63000 S63000_11 ser02
%            do normal reconstruction with no extra options
%
% EXAMPLE 2: agilent_recon kamy S63000 S63000_11 ser02 o
%            do reconstruction and overwrite existing data
%
% OPTIONS:
% o - overwrite work folder for this runno if it already exists
% i - ignore built in memory limit protections - WARNING: this may crash the recon engine
% phase - output phase instead of magnitude images (always float)
% float - output float magnitude images instead of int16
% kimages - output log(abs()) k-space images
%
% SHORTCUTS:
% k may be used in place of kamy
% h may be used in place of heike
% + can be use for either study, series or both to get the newest fid file on the scanner

%% remaining work

%handle phase option for chunk recon
%handle kimages option for all recons
%bypass reference?
%multislice, and multiecho support
%fix write_headfile to regex look for __ in field names and replace with space
%write multi entry tag file instead of individual for muti-dataset recons
%write headfile reader so we can use hostname dependency files that lucy can edit.
%    this should also allow us to deploy on arbitrary hosts without having to change code or code folders 
%DONE -- zeropad m and p numbers
%DONE -- write headfile <-- done
%DONE -- add convenience prompts for open image in imagej and archiveme <- archiveme added, 
%    imagej not needed because nifti volumes are made

% -- features

%DONE -- save roll and scale variables as .mat files in work folder <-- done
%DONE -- add the option to roll data? including slice data <-- done for existing recons except chunk recon
%DONE -- add option to pass data to DTI pipeline, possibly pull b-value? <-- done,
%    tensorpipe command generated for DTI data, and b-value calculated and
%    added to header, currently only works for half sine diffusion gradients

%% Argument check
tic
if nargin==0
    help agilent_recon;
    return
elseif nargin<4
    error('not enough input arguments');
elseif nargin==4
    option='';
elseif nargin~=5
    error('too many input arguments');
end


%% handle + option for study and series

%now handle + option for study then series
if strcmp(study,'+')
    display('translating plus to newest study on scanner')
    [status newest_study]=system(['ssh omega@' scanner ' ls -tr /home/mrraw | tail -n 1']);
    study=newest_study(1:end-1);
end
if strcmp(series,'+')
    display(['translating plus to newest series in study ' study])
    [status newest_series]=system(['ssh omega@' scanner ' ls -tr /home/mrraw/' study ' | grep fid | tail -n 1']);
    series=newest_series(1:end-5); %must remove 5 characters for newline and '.fid'
end


%% handle options

%switch for setting options
switch option
    case 'o'
        overwrite=1;
    case 'phase'
        phase_boolean=1;
        %error('phase option not fully implemented yet')
    case 'float'
        float_boolean=1;
        error('float option not fully implemented yet')
    case 'kimages'
        kimage_boolean=1;
        overwrite=1;
        error('kimages option not fully implemented yet')
    case 'i'
        ignore_memory_boolean=1;
    case ''
        display('no additional options selected');
    otherwise
        error(['option ''' option ''' not recognized']);
end

% list all options in cell array
all_options={
    'overwrite'...
    'phase_boolean'...
    'float_boolean'...
    'kimage_boolean'...
    'ignore_memory_boolean'...
    };

% make all undefinted options = 0
for o=1:length(all_options)
    if ~exist(all_options{o},'var')
        eval([all_options{o} '=0;']);
    end
end


%% read headers collect metadata and set up work directories

%consider adding the metadata GUI here

%first assemble the path to the data
if strcmp(scanner,'kamy') || strcmp(scanner,'k')
    scannercode='t7imx';
    scanner='kamy';
elseif strcmp(scanner,'heike') || strcmp(scanner,'h')
    scannercode='t9imx';
    scanner='heike';
else
    error(['Scanner ' scanner ' is not a recognized scanner']);
end
datapath=['/home/mrraw/' study '/' series '.fid'];
display(['data path should be omega@' scanner ':' datapath ' based on given inputs']);
display(['base runno is ' runno ' based on given inputs']);

%pull the data to local machine
workpath=puller(runno,datapath,scanner,overwrite);
fidpath=[workpath '/' runno '.fid'];
procpar_path=[workpath '/' runno '.procpar'];

%read the procpar
procpar = readprocpar(procpar_path);

%read the fid file header
[npoints,nblocks,ntraces,bitdepth] = load_fid_hdr(fidpath);
display(['fid file has ' num2str(npoints) ' points; ' num2str(ntraces) ' traces; ' num2str(nblocks) ' blocks; and bitdepth ' bitdepth]);

%check free disk space
local_volume=get_local_vol;
[status,local_space_bytes] = unix(['df ',local_volume,' | tail -1 | awk ''{print $4}'' ']);
local_space_bytes=512*str2double(local_space_bytes); %this converts to bytes because default blocksize=512 byte
required_free_space=npoints*ntraces*nblocks*10; %estimate we need at least 10 bytes per image point because we save an unscaled 32 bit and a 16 bit and compelx
if required_free_space>local_space_bytes
    error('not enough free local disk space to reconstruct data, delete some files and try again');
end


%% headfile preparation

%check civm runno convention
if ~strcmp(runno(1),'S') && ~strcmp(runno(1),'N') || length(runno(2:end))~=5 || isnan(str2double(runno(2:end)))
    display('runno does not match CIVM convention, the recon will procede in testmode')
    testmode=1;
end
% if not testmode then create headfile
if exist('testmode','var') && testmode==1
    display('this recon will not be archiveable');
    headfile=0;
else
    display('gathering headfile info');
    display(' ');
    if float_boolean==1 || phase_boolean==1
        img_format='f32';
    else
        img_format='raw';
    end
    headfile=create_agilent_headfile(procpar,img_format,runno);
    display(' ');
end


%% memory checks
%check system memory
display('Checking system memory and purging, this will take a few seconds');
system('purge');
meminfo=imaqmem; %check available memory
while meminfo.TotalPhys/2>meminfo.AvailPhys
    input('Less than half of physical memory is currently available, close some programs and then press enter >> ','s');
end
divisor=3; %this is the expected multiplication in memory, reduce for efficient memory use
max_total_points=meminfo.AvailPhys/(4*divisor); %calculate number of single percision points we can put in memory
% handle ignore memory limit options
if ignore_memory_boolean==1;
    display('you have chosen to ignore this machine''s memory limits, this machine may crash');
    max_total_points=npoints*ntraces*nblocks;
end


voldims=[procpar.np/2 procpar.nv procpar.nv2];
nvols=(npoints/2*ntraces*nblocks)/prod(voldims);
blocks_per_vol=nblocks/nvols;
fov=[procpar.lro procpar.lpe procpar.lpe2].*10; %fov in mm this may not be right for multislice data
res=fov./voldims;

%check to see if we need to do this in chunks or not
if nvols>1 %recon one volume at a time
    numchunks=nvols;
    max_blocks=blocks_per_vol;
    if max_blocks*npoints*ntraces>max_total_points
        error('volume size is too large, consider closing programs and restarting')
    end
else %if its just one volume, see if we can do it all at once or need to do chunks
    max_blocks=floor(max_total_points/(ntraces*npoints)); %number of blocks we can work on at a time
    numchunks=ceil(nblocks/max_blocks);
end
%Now we have all the information we need to decide what type of recon to do


%% decide what type of recon to do

%check for multislice and or multiecho <------ we can also add any other
%type of recon right here
if procpar.nv2==1
    error('multislice not support!');
elseif procpar.echo>1
    error('multiecho not support!');
end


%below we are dealing with 3D cartesian single echo data only

%if possible do the whole thing at once
if numchunks==1; 
    display('reconstructing dataset in one step');
    single_vol_recon(fidpath,workpath,nblocks,ntraces,npoints,bitdepth,numchunks,voldims,scannercode,runno,res,phase_boolean,headfile); %here we use nblocks because maxblocks may be larger than the volume itself

%if its multiple volumes recon by volume
elseif numchunks==nvols 
    display(['data contains ' num2str(numchunks) ' volumes and will undergo scaled group recon']);
    scaled_group_recon(fidpath,workpath,max_blocks,ntraces,npoints,bitdepth,voldims,nvols,scannercode,runno,res,phase_boolean,headfile);

%if data is one large array, then we need to reconstruct as chunks
elseif max_blocks<nblocks 
    display('data is a single large volume and will need to be reconstructed in chunks');
    chunk_recon(fidpath,max_blocks,ntraces,npoints,bitdepth,voldims,scannercode,runno,res,workpath,headfile);
end

%% completion and cleanup


display('Agilent recon completed successfully');
toc
