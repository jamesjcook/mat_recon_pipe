function load_from_data_file(data_buffer,file_path,header_skip,min_load_size,load_skip_bytes,data_precision,chunk_size,total_chunks,chunks_to_load,endian,post_skip_bytes)
% LOAD_FROM_DATA_FILE(data_buffer,file_path,header_skip,load_size,load_skip,data_precision,chunk_size,total_chunks,chunks_to_load,endian)
%
%
% Inputs
% data_buffer     our super struct/object we pass by reference.
%                 hopefully will only access the data element, for size of
%                 data, and to put the data into.
% file_path       path to input file
% header_skip     bytes to skip forward in file counting for first header
% min_load_size   number of contiguous data points. will be 2 * complex points
% load_skip       how many bytes of non-data between each file chunk, we
%                 skip this much before each chunk
% data_precsion   input data precision
% chunk_size      size of native file chunks measured points, will be 2*
%                 complex points
% total_chunks    number of chunks to make up the file. 
% chunks_to_load  number of chunks to load or an array of indicies
% post_skip       number of bytes to skip after each load(fread).
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
complex_struct=false;
contiguous_chunks=true;
load_method='standard';%'experimental'
force_standard=false;
if isfield(data_buffer.headfile,'load_method')
    load_method=data_buffer.headfile.load_method;
    if strcmp(load_method,'standard')
        force_standard=true;
    end
end

if isempty(endian)
    endian='l';
end
if ~exist('post_skip_bytes','var') || isempty(post_skip_bytes) 
    post_skip_bytes=0;
end
load_size=min_load_size;
if load_skip_bytes==0&&post_skip_bytes==0
    load_size=chunk_size;
end
if regexp(data_precision,'(16)')
    precision_bytes=2;
elseif regexp(data_precision,'(32)')
    precision_bytes=4;
else
    precision_bytes=0;
end
loads_per_chunk=chunk_size/(min_load_size+post_skip_bytes/precision_bytes);%+load_skip);
% if ~isinteger(loads_per_chunk)
%%%%%% IS INTEGER CHECKS CLASS TYPE!
%if isequal(fix(loads_per_chunk),loads_per_chunk) % one possibility
if ceil(loads_per_chunk) ~= floor(loads_per_chunk)
    db_inplace('load_from_data_file','ERROR setting load operators: loads_per_chunk non integer but it must be an integer!')
end
post_skip_size=post_skip_bytes/precision_bytes;% should be 2x npoints skiped because complex.
if mod(load_skip_bytes,precision_bytes)==0 && mod(post_skip_bytes,precision_bytes)==0  && ~force_standard
    load_skip_size=load_skip_bytes/precision_bytes;
    % modifieds load_skip to be in data values
%    load_size=load_skip_size+chunk_size;
%     loads_per_chunk=1;
    
%     chunk_with_skip=load_skip_size+(load_size+post_skip_size)*loads_per_chunk;
    % this makes loads size (chunk_size+load_skip)*nchunks
    load_size=(min_load_size+post_skip_size)*loads_per_chunk;
    load_method='experiental2';
else
end

% header_skip=68;
% load_size=128;
% load_skip=8;
% chunks_to_load=[1 3 4 9];
% chunk_size=256;

fileid = fopen(file_path, 'r', endian);
if ~isvector(chunks_to_load)
    chunks_to_load=(chunks_to_load);
end
if length(chunks_to_load)>1
    complex_struct=true;
end
for c=2:length(chunks_to_load)
    if chunks_to_load(c)-1~=chunks_to_load(c-1)
        contiguous_chunks=false;
    end
end

if contiguous_chunks && (chunks_to_load(1)~=1 || numel(chunks_to_load)==1  )
    contiguous_chunks=false;
end
if complex_struct
    if ( ~isprop(data_buffer,'ds'))
        data_buffer.addprop('ds');
    end
    data_buffer.ds=struct;
end
if numel(data_buffer.data)==0 && ~complex_struct
    data_buffer.data=sparse((chunk_size-post_skip_size*loads_per_chunk)/2*numel(chunks_to_load),1);
%     data_buffer.data=sparse((load_size+post_skip_size)/2*numel(chunks_to_load),1);
%     data_buffer.data=complex(zeros(chunk_size/2*numel(chunks_to_load),1),zeros(chunk_size/2*numel(chunks_to_load),1));

%     data_buffer.data=chunk_size-post_skip_size*loads_per_chunk)/2*numel(chunks_to_load),1);
end
buffer_pos=1;
if contiguous_chunks
    fseek(fileid,header_skip,'bof');
end
for c=1:length(chunks_to_load)
    if c==1 && numel(chunks_to_load)
      warning('multi chunk loads probably dont work');
    end
%     skip=header_skip; %+load_skip+(load_size+load_skip)*(chunks_to_load(c)-1)*loads_per_chunk;
    %     fprintf('filepos after headerskip %d',ftell(fileid));
    if ~strcmp(load_method,'experiental2')
        %% n+ loads per chunk.
        fseek(fileid,header_skip,'bof');
        for n=1:loads_per_chunk
            fprintf('.');
            lpos=ftell(fileid);
            if strcmp(load_method,'standard')
                %% "standard" one fid at a time.
                fseek(fileid,load_skip_bytes,'cof');
                [fid_data, points_read]= fread(fileid, min_load_size, [data_precision '=>single'],post_skip_bytes);
                if points_read ~= min_load_size
                    error('Data file contained less data than expected.');
                end
                
                %insert the cut out load_skip data here.
                fid_data = fid_data(1:2:end) + 1i*fid_data(2:2:end); %compelxify.
                data_buffer.data(buffer_pos:buffer_pos+min_load_size/2-1,1)=fid_data;
            elseif strcmp(load_method,'experimental');
                %% experimental
                fseek(fileid,load_skip_bytes,'cof');
                %             example
                %         r=fread(fp,inf,'double',1); % r is 50Mb
                %         fseek(fp,8,'bof');
                %         c=[r fread(fp,inf,'double',1)]; % c is 50Mb
                
                r=fread(fileid,min_load_size/2, [data_precision '=>single']);
                fseek(fileid,lpos+load_skip_bytes,'bof');
                data_buffer.data(buffer_pos:buffer_pos+min_load_size/2-1,1)=complex(r, fread(fileid,min_load_size/2, [data_precision '=>single']));
            end
            buffer_pos=buffer_pos+min_load_size/2;
        end
    else
        %% experimental2
        if(c==1)
            fprintf('Experimental loading, (load_skip+load_size+)*nloads\n');
            fprintf('%%...');
        end
        
        %         if ( contiguous_chunks )
        if contiguous_chunks 
            fseek(fileid,load_skip_bytes,'cof');
        else
            % fseek(fileid,load_skip_bytes+chunk_with_skip*(chunks_to_load(c)-1)*precision_bytes,'cof');% save time by seeking past the first little tid bit.
            skip=header_skip+(load_size*precision_bytes+load_skip_bytes)*(chunks_to_load(c)-1)+load_skip_bytes;
            % seek past file header, and (blockheader + block ) * (block to  load -1) + block header
            st=fseek(fileid,skip,'bof');% a skip from beginning skip
            if st<0
                error('Seek operation failed!%s\n ',ferror(fileid));
            end
            data_buffer.headfile.(['chunkskip_' num2str(chunks_to_load(c))])=skip;
            if (chunks_to_load(c)>=total_chunks) 
                expected_endpoint=skip+load_size*precision_bytes;% no block header as its incoperated into load skip. +load_skip_bytes;
                if expected_endpoint ~= data_buffer.headfile.kspace_file_size
                    warning('filesize %d doesnt match parameters, %d , %d .',data_buffer.headfile.kspace_file_size,expected_endpoint,(ftell(fileid)+load_size*precision_bytes));
                    pause(3);
                end
            end
        end
        
        % fseek per chunk usnt too bad, but we could be better off and not
        % seek for contiguous chunks.
        % fprintf('filepos after otherchunk skip %d',ftell(fileid));
        [fid_data, points_read]= fread(fileid, load_size, [data_precision '=>single']);
%         fprintf('filepos after read our chunk %d',ftell(fileid));
        if  points_read ~= load_size && (load_size-points_read)>floor(post_skip_bytes/precision_bytes)
            error('Did not correctly read file, load_size(%d) ~= points_read(%d) load size is %f times the size of successfully read points',load_size,points_read,(load_size/points_read));
        elseif points_read ~= load_size && (load_size-points_read)<=floor(post_skip_bytes/precision_bytes)
            warning('Did not as much data as requested, chunk_size(%d) ~= points_read(%d)',load_size,points_read);
            fid_data=[fid_data; zeros(load_size-points_read,1)];
        end
%         fid_data=reshape(fid_data,[load_size/(chunk_size+load_skip_size),(chunk_size+load_skip_size)]);
%         fid_data(1:load_skip_size,:)=[];  % this part is correct.
        fid_data=reshape(fid_data,[load_size/loads_per_chunk,loads_per_chunk]); % in theory we've loaded a whole chunk of stuff here.
        fid_data(min_load_size+1:end,:)=[]; %ver unsure about this.
        fid_data=reshape(fid_data,[2 numel(fid_data)/2 ]);
%         fid_data
        if numel(chunks_to_load)==1
            data_buffer.data= fid_data(1,:) + 1i*fid_data(2,:);
        else
            % data_buffer.data(buffer_pos:buffer_pos+chunk_size/2-1,1)=fid_data(1:2:end) + 1i*fid_data(2:2:end);
            % data_buffer.data(buffer_pos:buffer_pos+numel(fid_data)/2-1,1)=fid_data(1:2:end) + 1i*fid_data(2:2:end);
            if complex_struct
                data_buffer.ds.(['c_' num2str(c)])=fid_data(1,:) + 1i*fid_data(2,:);
            else
                data_buffer.data(buffer_pos:buffer_pos+numel(fid_data)/2-1,1)=fid_data(1,:) + 1i*fid_data(2,:);
                buffer_pos=buffer_pos+numel(fid_data)/2;
            end
            if mod(floor(c/numel(chunks_to_load))*100,5)==0
                fprintf('\b\b\b%03d',floor(c/numel(chunks_to_load)*100));
            end
        end
        clear fid_data;
    end
end
fprintf('\n');
fclose(fileid);
if(complex_struct)
    data_buffer.data=struct2array(data_buffer.ds);
    %     data_buffer.rmprop('ds');
    data_buffer.ds=[];
end
% fprintf('\t Load Complete!');