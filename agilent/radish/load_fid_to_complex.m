function [COM,NP,NB,NT,HDR] = load_fid(name)
%----------------------------------------
%function load_fid
%Reads a Vnmr fid file
%----------------------------------------
%Usage [COM,np,nb,HDR] = load_fid(name)
%
%Input:
%name   = name of FID directory without the .fid extension
%
%Output:
%COM = Complex combined data, blocks are ordered columnwise.
%np  = number of points (rows in RE/IM); optional
%nb  = number of blocks (columns); optional
%nt  = number of traces; optional
%HDR = data header + last block header; optional
%
%Examples:
%[COM] = load_fid('Test_data');
%[COM np nb] = load_fid('Test_data');
%
%----------------------------------------
% Maj Hedehus, Varian, Inc., Sep 2001.
% changes MSB March 2008
% updated for better memory usage with MR loading and recon, 2013.
%----------------------------------------

% format input name
% fullname = sprintf('%s.fid%cfid',name,'/'); %something funky with the backslash going on...
try
    fid = fopen([name '/fid' ],'r','ieee-be');
catch ME
    disp(ME)
end

% Read datafileheader
nblocks   = fread(fid,1,'int32');
ntraces   = fread(fid,1,'int32');
np        = fread(fid,1,'int32');
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

% reset output structures

% RE = zeros(np/2,ntraces*nblocks,'single'); % need to find out if the agilents will ever put out 64 bit data, if they will this single here will be a problem. 
% IM = zeros(np/2,ntraces*nblocks,'single');
COM = zeros(np/2,ntraces*nblocks,'single');
COM = complex(COM,COM);

inx = 1;
data_buffer=zeros(2,np/2,ntraces,'single');
for b = 1:nblocks % blocks are usually slices or volumes of data to be read
    sprintf('read block %d\n',b);
    % Read a block header
    scale     = fread(fid,1,'int16');
    bstatus   = fread(fid,1,'int16');
    index     = fread(fid,1,'int16');
    mode      = fread(fid,1,'int16');
    ctcount   = fread(fid,1,'int32');
    lpval     = fread(fid,1,'float32');
    rpval     = fread(fid,1,'float32');
    lvl       = fread(fid,1,'float32');
    tlt       = fread(fid,1,'float32');
    %%% convenient break point, can be used to break every 64 blocks of data to test out of memory issues
    if nblocks>256
        if mod(b,256) ==0
            disp(b);
            %end
        elseif mod(b,128) ==0
            disp(b);
            %end
        elseif mod(b,64) ==0
            disp(b);
        end
    end
    if s_float == 1
        data_buffer = fread(fid,np*ntraces,'float32=>single');
    elseif s_32 == 1
        data_buffer = fread(fid,np*ntraces,'int32=>single');
    else
        data_buffer = fread(fid,np*ntraces,'int16=>single');
    end
    data_buffer=reshape(data_buffer,[2 np/2 ntraces]);
%     RE(:,inx:inx+ntraces-1) = squeeze(data_buffer(1,:,:));
%     IM(:,inx:inx+ntraces-1) = squeeze(data_buffer(2,:,:));
    COM(:,inx:inx+ntraces-1)=complex(squeeze(data_buffer(1,:,:)),squeeze(data_buffer(2,:,:)));
    %We have to read data every time in order to increment file pointer
    inx = inx + ntraces;
    %inx code is a hold out from the initial version of this function.
end  % done reading one block
if nargout > 1
    NP = np/2;
end
if nargout > 2
    NB = nblocks;
end
if nargout > 3
    NT = ntraces;
end
if nargout > 4
    HDR = [nblocks, ntraces, np, ebytes, tbytes, bbytes, vers_id, status, nbheaders];
    HDR = [HDR, scale, bstatus, index, mode, ctcount, lpval, rpval, lvl, tlt];
end
fclose(fid);
