% function data_buffer = load_fid_modular(fidpath,max_blocks,ntraces,npoints,bitdepth,cyclenum,voldims)
%                        load_fid(fidpath,zfactor_npoints/(npoints*ntraces),ntraces,npoints,bitdepth,zchunk,[voldims(1) voldims(2) voldims(3)/zdivisor]);

function data_buffer = load_fid_modular(fidpath,block_array)
% max_blocks,ntraces,npoints,bitdepth,cyclenum,voldims)
% fidpath
% block_array, =[array of block numbers]

try
    fid = fopen(fidpath,'r','ieee-be');
catch ME
    disp(ME)
end

% Read datafileheader
nblocks   = fread(fid,1,'int32');
ntraces   = fread(fid,1,'int32');
npoints   = fread(fid,1,'int32');
ebytes    = fread(fid,1,'int32');
tbytes    = fread(fid,1,'int32');
bbytes    = fread(fid,1,'int32');
vers_id   = fread(fid,1,'int16');
status    = fread(fid,1,'int16');
nbheaders = fread(fid,1,'int32');

% s_data    = bitget(status,1);
% s_spec    = bitget(status,2);
s_32      = bitget(status,3);
s_float   = bitget(status,4);
% s_complex = bitget(status,5);
% s_hyper   = bitget(status,6);

if s_float == 1
    bitdepth ='float32';
elseif s_32 == 1
    bitdepth='int32';
else
    bitdepth='int16';
end

%find out how many bytes per point
if strcmp(bitdepth,'int16');
    bytes_per_point=2;
else
    bytes_per_point=4;
end

% RE = zeros(np/2,ntraces*nblocks,'single'); % need to find out if the agilents will ever put out 64 bit data, if they will this single here will be a problem. 
% IM = zeros(np/2,ntraces*nblocks,'single');
%preallocate complex array
display('preallocating complex array');
data_buffer=zeros((npoints/2)*ntraces,length(block_array),'single');
data_buffer=complex(data_buffer,data_buffer);



display('reading blocks');
inx=1;%index pointer
for bnum = 1:length(block_array)    
    b=block_array(bnum);
    
    %fseek to the right place, skip 60 byte header and 28 byte block header, then data
    byteskip=60+npoints*ntraces*bytes_per_point*(b-1)+28*(b-1);
    fseek(fid,byteskip,'bof');%seek to block
    fseek(fid,28,'cof'); %skip block header
    %28 block header bytes.
%     scale     = fread(fid,1,'int16');
%     bstatus   = fread(fid,1,'int16');
%     index     = fread(fid,1,'int16');
%     mode      = fread(fid,1,'int16');
%     ctcount   = fread(fid,1,'int32');
%     lpval     = fread(fid,1,'float32');
%     rpval     = fread(fid,1,'float32');
%     lvl       = fread(fid,1,'float32');
%     tlt       = fread(fid,1,'float32');
       
    data = fread(fid,npoints*ntraces,[bitdepth '=>single']);
    data_buffer(:,inx)=complex(data(1:2:end),data(2:2:end));
    inx=inx+1;
end  % done reading one block
fclose(fid);

% data_buffer=reshape(data_buffer,voldims); %reshape into 3d array