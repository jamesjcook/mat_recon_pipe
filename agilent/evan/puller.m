function workpath=puller(runno,datapath,scanner,overwrite)

%check arguments
if nargin<3
    error('not enough input arguments');
elseif nargin==3
    overwrite=0;
elseif nargin~=4
    error('too many input arguments arguments');
end


%find local disk and workpath
local_volume=get_local_vol;
workpath=[local_volume '/' runno '.work'];

%create work directory and handle overwrite option
if exist(workpath,'dir') && overwrite==1
    display('data already exists in workpath and you have specified to overwrite existing data');
    system(['rm -r ' workpath]);
    mkdir(workpath);
elseif ~exist(workpath,'dir')
    mkdir(workpath);
end


%first create pull commands
fid_pull_cmd=['scp omega@' scanner ':' datapath '/fid ' workpath '/' runno '.fid'];
procpar_pull_cmd=['scp omega@' scanner ':' datapath '/procpar ' workpath '/' runno '.procpar'];

%pull the fid file and the procpar to the work directory if they dont exist
%if they do exist check filesize
if ~exist([workpath '/' runno '.fid'],'file')
    display('fid file has not been pulled from scanner yet, checking available local disk space...')
    fid_size_check_cmd=['ssh omega@' scanner ' stat -c %s ' datapath '/fid'];
    [status fid_file_size]=system(fid_size_check_cmd);
    [status,local_space_bytes] = unix(['df ',local_volume,' | tail -1 | awk ''{print $4}'' ']);
    local_space_bytes=512*str2double(local_space_bytes); %this converts to bytes because default blocksize=512 byte
    if fid_file_size>local_space_bytes
        error('not enough free space on local disk to pull fid file, delete some files and try again');
    else
        system(fid_pull_cmd);
    end
else
    display('fid file already present in workpath, checking filesize');
    %check filesize on scanner
    fid_size_check_cmd=['ssh omega@' scanner ' stat -c %s ' datapath '/fid'];
    [status fid_file_size]=system(fid_size_check_cmd);
    %check local file size
    fileInfo = dir([workpath '/' runno '.fid']);
    if str2double(fid_file_size)==fileInfo.bytes
        display('fid file size on scanner matches local fid file size');
    else
        display('bypass')%error('fid file size on scanner DOES NOT MATCH local fid file size, use ''o'' option to overwrite BE CAREFUL');
    end
end


if ~exist([workpath '/' runno '.procpar'],'file')
    system(procpar_pull_cmd);
else
    display('procpar file already present in workpath, checking filesize');
    %check filesize on scanner
    procpar_size_check_cmd=['ssh omega@' scanner ' stat -c %s ' datapath '/procpar'];
    [status procpar_file_size]=system(procpar_size_check_cmd);
    %check local file size
    fileInfo = dir([workpath '/' runno '.procpar']);
    if str2double(procpar_file_size)==fileInfo.bytes
        display('procpar file size on scanner matches local procpar file size');
    else
        display('bypass')%error('procpar file size on scanner DOES NOT MATCH local procpar file size, use ''o'' option to overwrite BE CAREFUL');
    end
end


