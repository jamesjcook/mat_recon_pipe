function fid = readBrukerFID(directory, varargin)
filename = fullfile(directory, 'fid');
fileid = fopen(filename, 'r', 'l');
fid = fread(fileid, Inf, 'int32');
fclose(fileid);
fid = fid(1:2:end) + i*fid(2:2:end);