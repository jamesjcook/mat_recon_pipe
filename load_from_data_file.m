function load_from_data_file(data_buffer,file_path,header_skip,load_size,load_skip,data_precision,chunk_size,total_chunks,chunks_to_load,endian)
% LOAD_FROM_DATA_FILE(data_buffer,file_path,header_skip,load_size,load_skip,data_precision,chunk_size,total_chunks,chunks_to_load,endian)
%
%
% Inputs
% data_buffer     our super struct/object we pass by reference.
%                 hopefully will only access the data element, for size of
%                 data, and to put the data into.
% file_path       path to input file
% header_skip     bytes to skip forward in file counting for first header
% load_size       how much data we can load at a time
% load_skip       how many bytes of non-data between loads, we skip this much before every load
% data_precsion   input data precision
% chunk_size      size of a data chunk we expect to fit in memory should be
%                 equal to size(data_buffer.data)*bytes_per_pix+header info
% total_chunks    number of chunks to make up the file. 
% chunks_to_load  number of chunks to load or an array of indicies
% 
% function to load data has to be very smart to load to same kind of array
% for any instrument
% would be nice if we could specify funny things to it, so that it wouldnt
% have to dig into data_buffer headers for anything.
% it will be called by the smart loading function.....
%
% ... what options owuld that require. 
% an initial skip,  amount of data to load at a time, skip size, pieces to
% load, or how much data should we load before we've loaded enough.
% 
%
% Loads data for reconstruction in chunks, 
% some scanners have a header on data files, we'll jump that with 
% header_skip
% Some scanners have extra bytes in data we'll skip over those by
% specifiying a load_size and a load_skip for between.
% 


% bruker data is easy as it is just continuous acquisition 
% filename = fullfile(directory, 'fid');
% fileid = fopen(filename, 'r', 'l');
% fid = fread(fileid, Inf, 'int32');
% fclose(fileid);
% fid = fid(1:2:end) + i*fid(2:2:end);

% chunk_dims=size(data_buffer.data);

% filename = fullfile(directory, 'fid');

if isempty(endian)
    endian='l';
end
if load_skip==0
    load_size=chunk_size;
end
loads_per_chunk=chunk_size/load_size;%+load_skip);
% header_skip=68;
% load_size=128;
% load_skip=8;
% chunks_to_load=[1 3 4 9];
% chunk_size=256;

fileid = fopen(file_path, 'r', endian);
if ~isvector(chunks_to_load)
    chunks_to_load=(chunks_to_load);
end
if numel(data_buffer.data)==0
    data_buffer.data=complex(zeros(chunk_size/2*numel(chunks_to_load),1),zeros(chunk_size/2*numel(chunks_to_load),1));
end
buffer_pos=1;
for c=1:length(chunks_to_load)
    if c>1 
      warning('multi chunk loads probably dont work');
    end
    skip=header_skip; %+load_skip+(load_size+load_skip)*(chunks_to_load(c)-1)*loads_per_chunk;
    fseek(fileid,skip,'bof');
    for n=1:loads_per_chunk
        fprintf('.');
        fseek(fileid,load_skip,'cof');
%         if n==1  % skip chunk load_size header only if not first piece
%             fseek(fileid,skip,'bof');
%         else
% %             fseek(fileid,skip+(load_size*n)+1,'bof');
%         end
        [fid_data points_read]= fread(fileid, load_size, data_precision);
        if points_read ~= load_size 
            error('Data file contained less data than expected.');
        end
        fid_data = fid_data(1:2:end) + 1i*fid_data(2:2:end);
        data_buffer.data(buffer_pos:buffer_pos+load_size/2-1,1)=fid_data;

%         figure(1);imagesc(log(abs(reshape(fid_data,[256 128]))));
%         figure(2);imagesc(log(abs(reshape(data_buffer.data(1+(n-1)*256*128:256*128*n),[256,128]))));
%         pause(0.01);
        buffer_pos=buffer_pos+load_size/2;

    end
end
fclose(fileid);

