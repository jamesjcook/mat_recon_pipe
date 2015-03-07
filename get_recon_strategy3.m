function [recon_strategy, opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo)
% recon strategy settings
% possible recon strategys
% for a series of acquistions load the whole or load most reasonable small
% part.(1 volume,1slice,1ray)
% filter always operates per volume or slice so its operation is
% unaffected.
% fft all in parllel, or fft whole most reasonable chunk or, fft slice then
% fft across 3rd dimension later if need be.



% terminolgy conventions
% points=samples of data, complex points 
% size=  data_size reads, in loading operations we read by bit depth, this
% ammount.
% bytes  bytes, data_size reads bitdepth(generally), size translated to
% size on disk more or less. 




% maximum_memory_requirement =...
%     data_in.RAM_volume_multiplier   *data_in.disk_bytes_per_sample  *data_in.total_points...
%     +data_work.RAM_volume_multiplier*data_work.RAM_bytes_per_voxel *data_work.total_voxel_count...
%     +data_out.RAM_volume_multiplier *data_out.RAM_bytes_per_voxel  *data_out.total_voxel_count; %...
%     +volumes_in_memory_at_time*data_in.total_points*d_struct.c*data_in.disk_bytes_per_sample+data_work.total_voxel_count*data_out.RAM_bytes_per_voxel;
recon_strategy.maximum_RAM_requirement = data_in.total_bytes_RAM+data_out.total_bytes_RAM+data_work.total_bytes_RAM;
% system_reserved_memory=2*1024*1024*1024;% reserve 2gb for the system while we work.
system_reserved_RAM=max(2*1024*1024*1024,meminfo.TotalPhys*0.3); % reserve at least 2gb for the system while we work
useable_RAM=meminfo.TotalPhys-system_reserved_RAM;
fprintf('\tdata_input.sample_points(Complex kspace points):%d output_voxels:%d\n',data_in.total_points,data_out.total_voxel_count);
fprintf('\ttotal_memory_required for all at once:%0.02fM, system memory(- reserve):%0.2fM\n',recon_strategy.maximum_RAM_requirement/1024/1024,(useable_RAM)/1024/1024);
% handle ignore memory limit options
if opt_struct.skip_mem_checks;
    display('you have chosen to ignore this machine''s memory limits, this machine may crash');
    recon_strategy.maximum_RAM_requirement=1;
end


%% set the recon strategy dependent on memory requirements
%%% Load size calculation,
% here we try to figure out our best way to fit ourselves in memory.
% Possibilities
% -input and output fit in memory, we recon in memory and write to disk all at
% once.
% -input data fits with room for 1-n multi-channel recons
% -input data fits with room for 1 single-channel recon
% -input fits but not enough room for a single volume, 
% 
%%% use block_factors to find largest block size to find in
%%% max_loadable_chunk_size, and set recon_strategy.c_dims 
%%% set number of processing chunks and the chunk size based on memory required and
%%% total memory available.
%%% min_chunks is the minimum number we will need to procede. 
%%% if all the data will fit in memory this evaluates to min_chunks=1
%%% when min_chunks is 1 Max_loadable_ should evaluate to complete data size
%%%
recon_strategy.load_whole=true;
recon_strategy.channels_at_once=true;
recon_strategy.dim_string=opt_struct.output_order;
recon_strategy.work_by_chunk=false;
recon_strategy.num_chunks=1;
recon_strategy.post_scaling=false;
recon_strategy.recon_operations=1;
recon_strategy.op_dims='';
if useable_RAM>=recon_strategy.maximum_RAM_requirement || opt_struct.skip_mem_checks
    %% load whole process whole
    % for our best case where verything fits in memory set recon variables.
    % set variables 
    %%%
    % binary_header_size
    % recon_strategy.min_load_size
    % load_skip
    % chunk_size
    % recon_strategy.num_chunks
    % chunks_to_load(chunk_num)]
%     if true
    recon_strategy.min_chunks=1;
    recon_strategy.memory_space_required=recon_strategy.maximum_RAM_requirement;
    % max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*data_in.ray_blocks*data_in.disk_bytes_per_sample);
    max_loadable_chunk_size=((data_in.line_points*data_in.rays_per_block)*data_in.ray_blocks*data_in.disk_bytes_per_sample);
    % the maximum chunk size for an exclusive data per volume reconstruction.
%     recon_strategy.c_dims=[ d_struct.x,...
%         d_struct.y,...
%         d_struct.z];
    recon_strategy.c_dims=data_buffer.input_headfile. ...
        ([ data_buffer.input_headfile.S_scanner_tag 'dimension_order' ]);
    warning('c_dims set poorly just to input dimensions for now');
    chunk_size_bytes=max_loadable_chunk_size;
    recon_strategy.num_chunks           =kspace_data/chunk_size_bytes;
    if floor(recon_strategy.num_chunks)<recon_strategy.num_chunks
        warning('Number of chunks did not work out to integer, things may be wrong!');
    end
%     data_in.min_load_bytes= 2*data_in.line_points*data_in.rays_per_block*(data_in.disk_bit_depth/8);
    recon_strategy.min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
    recon_strategy.chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);       % chunk_size in data samples.
    if recon_strategy.num_chunks>1 && ~opt_struct.ignore_errors
        error('not tested with more than one chunk yet');
    end
%     else
%         min_chunks=ceil(maximum_RAM_requirement/useable_RAM);
%         recon_strategy.memory_space_required=(maximum_RAM_requirement/min_chunks); % this is our maximum memory requirements
%         % max_loadable_chunk_size=(data_input.sample_points*d_struct.c*(kspace.bit_depth/8))/min_chunks;
%         max_loadable_chunk_size=((data_in.line_points*rays_per_block)*data_in.ray_blocks*data_in.disk_bytes_per_sample)...
%             /min_chunks;
%         % the maximum chunk size for an exclusive data per volume reconstruction.
%         
%         c_dims=[ d_struct.x,...
%             d_struct.y,...
%             d_struct.z];
%         warning('c_dims set poorly just to volume dimensions for now');
%         
%         max_loads_per_chunk=max_loadable_chunk_size/data_in.min_load_bytes;
%         if floor(max_loads_per_chunk)<max_loads_per_chunk && ~opt_struct.ignore_errors
%             error('un-even loads per chunk size, %f < %f have to do better job getting loading sizes',floor(max_loads_per_chunk),max_loads_per_chunk);
%         end
%         chunk_size_bytes=floor(max_loadable_chunk_size/data_in.min_load_bytes)*data_in.min_load_bytes;
%         
%         recon_strategy.num_chunks           =kspace_data/chunk_size_bytes;
%         if floor(recon_strategy.num_chunks)<recon_strategy.num_chunks
%             warning('Number of chunks did not work out to integer, things may be wrong!');
%         end
%         if data_in.min_load_bytes>chunk_size_bytes && ~opt_struct.skip_mem_checks && ~opt_struct.ignore_errors
%             error('Oh noes! blocks of data too big to be handled in a single chunk, bailing out');
%         end
%         
%         recon_strategy.min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
%         recon_strategy.chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);    % chunk_size in data samples.
%     end
elseif isfield(data_in,'ds')
    %% complex recon strategy required.
    % check that one 3d vol of xyz will fit?
    % precalc all recon strategies? in tree?
    %%% possible recon strategies(summary). 
    % load_whole, process_whole  (num_chunks=1)
    % load_whole. process_single_vol (num_chunks=n_vols)
    % load_whole, process_n_vol (num_chunks=n_vols/someidms)
    % load_onevol,process_onevol (num_chunks=n_vols)
    % load_onevol,process_volpart (n_parts?) (num_chunks=n_vols*chunks_per_vol)
    % load_volpart,process_volpart, (n_parts?) (num_chunks=n_vols*chunks_per_vol)
    
    recon_strategy.memory_space_required=data_in.ds.Sub('x')...
        *data_in.RAM_bytes_per_voxel;
    % recon_strategy.load_whole=true;
    % recon_strategy.channels_at_once=true;
    % recon_strategy.dim_string=opt_struct.output_order;
    % recon_strategy.work_by_chunk=false;
    % recon_strategy.num_chunks=1;
    recon_strategy.dim_string=data_in.input_order;
    recon_strategy.c_dims='';%=zeros(0,0);
    
    % recon_strategy.min_load_size      % set according to data_in.min_load_bytes(this is in data values).
    % load_skip          
    % chunk_size
    % recon_strategy.num_chunks
    % chunks_to_load(chunk_num)
    % recon_strategy.dim_string='xyz';
    
%     load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
%         data_in.binary_header_size, recon_strategy.min_load_size, recon_strategy.load_skip, data_in.precision_string, recon_strategy.chunk_size, ...
%         load_chunks,chunks_to_load(chunk_num),...
%         data_in.disk_endian);
            
    % we're not load_whole,process_whole becuase that is what our outer if
    % statment checks.
    % how much memory to load whole,procsss_vol
    rs.last=recon_strategy;
    string_ver=true;
    while recon_strategy.memory_space_required < useable_RAM && ...
            numel(recon_strategy.c_dims) < numel(data_out.output_dimensions)
        rs.last=recon_strategy;
        if string_ver
            recon_strategy.c_dims(end+1)=data_out.output_order(numel(recon_strategy.c_dims)+1);
            recon_strategy.memory_space_required=prod(data_in.ds.Sub(recon_strategy.c_dims))...
                *data_in.RAM_bytes_per_voxel...
                +prod(data_work.ds.Sub(recon_strategy.c_dims))...
                *data_work.RAM_bytes_per_voxel...
                +prod(data_out.ds.Sub(recon_strategy.c_dims))...
                *data_out.RAM_bytes_per_voxel;
        elseif num_ver
            recon_strategy.c_dims(end+1)=data_out.output_dimensions(numel(recon_strategy.c_dims)+1);
            recon_strategy.memory_space_required=prod(data_in.ds.Sub(data_in.ds.showorder(recon_strategy.c_dims)))...
                *data_in.RAM_bytes_per_voxel...
                +prod(data_work.ds.Sub(data_work.ds.showorder(recon_strategy.c_dims)))...
                *data_work.RAM_bytes_per_voxel...
                +prod(data_out.ds.Sub(data_out.ds.showorder(recon_strategy.c_dims)))...
                *data_out.RAM_bytes_per_voxel;
        end
    end
    if recon_strategy.memory_space_required > useable_RAM 
        recon_strategy=rs.last;
    end
    if numel(recon_strategy.c_dims)<numel(data_out.output_order)
        recon_strategy.op_dims=data_out.output_order(numel(recon_strategy.c_dims)+1:end);
    end
    %     recon_strategy.dim_string=data_out.ds.showorder(recon_strategy.c_dims);
    recon_strategy.recon_operations=prod(data_out.ds.dim_sizes)/prod(data_out.ds.Sub(recon_strategy.c_dims));
    %%%
    
    % data_in.min_load_bytes= 2*data_in.line_points*data_in.rays_per_block*(data_in.disk_bit_depth/8);
    recon_strategy.chunk_size=2*data_in.line_points*data_in.rays_per_block;  % chunk_size in # of values (eg, 2*complex_points).
    recon_strategy.min_load_size=recon_strategy.chunk_size; % minimum_load_size in data samples. this is the biggest piece of data we can load between header bytes.
    
    chunk_size_bytes=recon_strategy.chunk_size*(data_in.disk_bit_depth/8);
    recon_strategy.num_chunks=data_in.kspace_data/chunk_size_bytes;

    %chunks_per_vol
    %sub_chunks_per_chunk.
    
    %%% calc var skip btween dim_string and c_dims.
    %%% indicate subchunk skips.... if we got them.
    %%% what is the chunk dimension? previously we always just assumed it.
    recon_strategy.work_by_chunk=false;
    recon_strategy.work_by_sub_chunk=false;
    %%% blocks = chunks, so how big is the block dimension, that should
    %%% matchup with the possible read data dimensions.
    
    %%%% if 2D we will operate in slice mode.... (code that later).
    if strcmp(data_in.vol_type,'2D')
        error('did not do 2D recon strategy. code');
    %%%% if 3D
    elseif strcmp(data_in.vol_type,'3D')
        if ( recon_strategy.num_chunks ~= prod(data_out.output_dimensions)/prod(data_out.ds.Sub('xyz'))) 
            warning('native fft blocks dont line up with chunks!');
        end
        unique_test_string=data_in.ds.showorder([data_in.ray_blocks data_in.ray_blocks data_in.ray_blocks]);
        unique_test_string=unique_test_string([true diff(unique_test_string)~=0]);%collapses any extra f's to a singluar f'.
        if strcmp(unique_test_string(end-1),'z')&&strcmp(unique_test_string(end),'f')
            recon_strategy.work_by_sub_chunk=true;
            recon_strategy.load_whole=false;
            %%% this is guessing our GUESSING our ray_block dimension.
            %%% if this this we're working over z, we have to skip over the
            %%% product of anything between x, y and z dimensions of our
            %%% output, this significantly complicates the skip load
            %%% options.  This begs the question would we be better off
            %%% with a pre-fid reformat in this context.
            
            %ray_length is always x. so we can assume that dimension is
            %fine.
            % we have to traverse until we get to a non-one dimension other
            % than y or z. then calculate our subskip.
            skip_dims=[];
            for dn=1:length(recon_strategy.dim_string)
                dl=recon_strategy.dim_string(dn);
                if ~isempty(regexp(dl,'[^xyz]', 'once')) && data_in.ds.Sub(dl)>1
                    skip_dims(numel(skip_dims)+1)=dl;
                elseif ~isempty(regexp(dl,'[yz]', 'once')) && numel(skip_dims)>=1
                    dn=length(recon_strategy.dim_string); % EARLY EXIT OF LOOP.
                end
            end
            skip_dims=char(skip_dims);% fix it not being a char...
            skip_dims=['x' skip_dims];
            skip_dims=data_in.ds.Sub(skip_dims);
            sub_chunk_load_skip_dim=skip_dims;
            sub_chunk_load_skip_dim(end)=sub_chunk_load_skip_dim(end)-1;
            sub_chunk_skip_points=prod(sub_chunk_load_skip_dim);
            recon_strategy.sub_chunk_size=2*(prod(skip_dims)-prod(sub_chunk_load_skip_dim));
            recon_strategy.sub_chunk_skip_bytes=2*sub_chunk_skip_points*(data_in.disk_bit_depth/8);
            recon_strategy.post_skip=recon_strategy.sub_chunk_skip_bytes;
            recon_strategy.min_load_size=recon_strategy.sub_chunk_size;%*(data_in.disk_bit_depth/8);
%             recon_strategy.chunk_size=recon_strategy.min_load_size*recon_strategy.num_chunks;
            
            recon_strategy.load_skip=data_in.ray_block_hdr_bytes;
            %%% do i need to double the size of load,and skip because
            %%% complex?
            %%%% have sub_chunk_skip_points, but we load each chunk in
            %%%% file. Have to pass this off to ourrecon_strat.
            % native_chunk_dimensions?
        elseif ~strcmp(unique_test_string(end-1),'x')&&~strcmp(unique_test_string(end-1),'y')&&~strcmp(unique_test_string(end-1),'z')&&strcmp(unique_test_string(end),'f')
            %%% so long as the chunk dimension is not x y or z, loading and
            %%% load skipping should be okay.
            error('DID NOT FIX NORMAL CHUNKING YET');
            % num_chunks=ray_blocks and life is relatively easy.
        else
            error('UNHANDLED CHUNK CONDIDTION :(%s)',unique_test_string(end-1));
        end
    end
    
    
elseif true
    % set variables
    %%
    % binary_header_size % set above so we're good
    % recon_strategy.min_load_size      % set according to data_in.min_load_bytes(this is in data values).
    % load_skip          
    % chunk_size
    % recon_strategy.num_chunks
    % chunks_to_load(chunk_num)
    % recon_strategy.dim_string='xyz';
    recon_strategy.dim_string=opt_struct.output_order;
    data_work.single_vol_RAM=data_work.volume_voxels*data_work.RAM_bytes_per_voxel*data_work.RAM_volume_multiplier;%add slice sizes as well in all likely hood if we do slice recon we'll still have room to load at least one whole volume.
    data_out.single_vol_RAM =data_out.volume_voxels *data_out.RAM_bytes_per_voxel *data_out.RAM_volume_multiplier;
    %%% NEED TO DETERMINE CHUNK STRATEGY!
    %%% Can we load all input data at once?
    %%% Do Volumes share data(keyhole)?
    % should work backwards from largest dimensions to see how many dimensions
    % of data we can fit in memory, theoretically time will never fit, however
    % it'd be great to get channels, and nice to get any parameter dimension to fit.
    % starting with the last outputgg1 dimension see if  for each dimension see if any will fit with the data loaded.
    recon_strategy.dim_mask=ones(1,size(data_out.output_dimensions,2));
    rd=numel(recon_strategy.dim_string);
    while rd>3 && ( useable_RAM < data_in.total_bytes_RAM...
            +data_work.single_vol_RAM*prod(data_out.output_dimensions(4:rd))...
            +data_out.single_vol_RAM*prod(data_out.output_dimensions(4:rd)) ) || ...
            (data_out.output_dimensions(rd)==1)
        % strfind lookup here to equate input to output dimensions?
        % recon_strategy.dim_mask(strfind(input_order,opt_struct.output_order(rd)))=0;
        recon_strategy.dim_mask(rd)=0;
        rd=rd-1;
    end
    recon_strategy.dim_string(recon_strategy.dim_mask==0)=[];
    if length(recon_strategy.dim_string)<3
        warning('recon strategy cannot be load whole!')
        recon_strategy.dim_string='xyz';
    end
    % if we've removed all except for the first three dimensions do one more
    % check to see if we can fit all input in memory at once with a single
    % recon volume.
    if length(recon_strategy.dim_string)==3
        if d_struct.c>1 % if there are channels this is false no matter what here.
            %&& useable_RAM < data_work.single_vol_RAM*d_struct.c+data_in.total_bytes_RAM
            recon_strategy.channels_at_once=false;
        end
        if ( useable_RAM>=data_in.total_bytes_RAM ...
                + data_work.single_vol_RAM ...
                + data_out.single_vol_RAM )
            recon_strategy.load_whole=true;
        else
            recon_strategy.load_whole=false;
        end
        if ~strcmp(data_buffer.headfile. ...
                ([data_buffer.input_headfile.S_scanner_tag 'vol_type']),'radial')
            recon_strategy.load_whole=false;
        end
    end
    % load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
    %     binary_header_size, recon_strategy.min_load_size, load_skip, data_in.precision_string, recon_strategy.chunk_size, ...
    %     recon_strategy.num_chunks,chunks_to_load(chunk_num),...
    %     data_in.disk_endian);
    % binary_header_size % set above so we're good
    % recon_strategy.min_load_size      % set according to data_in.min_load_bytes(this is in data values).
    % load_skip          % set above so we're good
    % chunk_size
    % recon_strategy.num_chunks
    % chunks_to_load(chunk_num)
%     working_space=volumes_in_memory_at_time*data_work.total_voxel_count*data_out.RAM_bytes_per_voxel;
%     extra_RAM_bytes_required=0;
%     if regexp(vol_type,'.*radial.*')
%         sample_space_length=ray_length*rays_per_block*data_buffer.headfile.data_in.ray_blocks_per_volume;
%         extra_RAM_bytes_required=sample_space_length*3*data_out.RAM_bytes_per_voxel+sample_space_length*data_out.RAM_bytes_per_voxel;
%     end
%     vols_or_vols_plus_channels=floor((meminfo.TotalPhys-system_reserved_RAM-data_in.total_bytes_RAM-extra_RAM_bytes_required)/working_space);
    if recon_strategy.load_whole  %%% this block will only be active for radial right now.
        recon_strategy.memory_space_required=data_in.total_bytes_RAM ...
            + data_work.single_vol_RAM * prod(data_out.output_dimensions(4:rd)) ...
            + data_out.single_vol_RAM  * prod(data_out.output_dimensions(4:rd));
        
        opt_struct.parallel_jobs=min(12,floor((useable_RAM-data_in.total_bytes_RAM)...
            / data_work.single_vol_RAM*prod(data_out.output_dimensions(4:rd)) ...
            + data_out.single_vol_RAM*prod(data_out.output_dimensions(4:rd))));
        % cannot have more than 12 parallel jobs in matlab.
        % max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*data_in.ray_blocks*data_in.disk_bytes_per_sample);
        max_loadable_chunk_size=((data_in.line_points*rays_per_block) ...
            * data_in.ray_blocks*data_in.RAM_bytes_per_voxel);
        recon_strategy.min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
        
        %this chunk_size only works here because we know that we cut at
        %least one dimensions because we can only get here when we havnt
        %got enough memory for all at once. 
        if numel(recon_strategy.dim_string)<numel(data_out.output_dimensions)
            chunk_size_bytes=max_loadable_chunk_size/data_out.output_dimensions(numel(recon_strategy.dim_string)+1);
        else
            chunk_size_bytes=max_loadable_chunk_size/data_out.output_dimensions(end);
        end
        recon_strategy.num_chunks      =kspace_data/chunk_size_bytes;
        recon_strategy.chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);       % chunk_size in # of values (eg, 2*complex_points.
    else
        warning('multi chunk not well tested, assumes we can load and recon individual data_in.ray_blocks');
        recon_strategy.memory_space_required=data_in.total_bytes_RAM/data_in.ray_blocks ...
            + data_work.single_vol_RAM*prod(data_out.output_dimensions(4:rd)) ...
            + data_out.single_vol_RAM *prod(data_out.output_dimensions(4:rd));
        
        opt_struct.parallel_jobs=min(12, floor( ...
        (useable_RAM-data_in.total_bytes_RAM)/data_work.single_vol_RAM ...
        * prod(data_out.output_dimensions(rd:end)) ...
        + data_out.single_vol_RAM * prod(data_out.output_dimensions(rd:end))));
        % cannot have more than 12 parallel jobs in matlab.
        % max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*data_in.ray_blocks*data_in.disk_bytes_per_sample);
        recon_strategy.min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
        
        chunk_size_bytes=data_in.min_load_bytes;
        recon_strategy.num_chunks=data_in.kspace_data/chunk_size_bytes;
        recon_strategy.chunk_size=chunk_size_bytes/(data_in.disk_bit_depth/8);       % chunk_size in # of values (eg, 2*complex_points the 2x points was factored into min_load_bytes).
    end
    if recon_strategy.num_chunks>1
        recon_strategy.work_by_chunk=true;
        opt_struct.write_complex=true;
        opt_struct.independent_scaling=true;
        recon_strategy.load_whole=false;
        recon_strategy.post_scaling=true;
    end
    recon_strategy.c_dims=recon_strategy.dim_string;
    clear rd;
else
 %%
 recon_strategy.min_chunks=ceil(maximum_RAM_requirement/useable_RAM);
    recon_strategy.memory_space_required=(maximum_RAM_requirement/min_chunks); % this is our maximum memory requirements
    % max_loadable_chunk_size=(data_input.sample_points*d_struct.c*(kspace.bit_depth/8))/min_chunks;
    max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*data_in.ray_blocks*data_in.disk_bytes_per_sample)...
        /min_chunks;
    % the maximum chunk size for an exclusive data per volume reconstruction.
    
%     recon_strategy.c_dims=[ d_struct.x,...
%         d_struct.y,...
%         d_struct.z];
%     warning('recon_strategy.c_dims set poorly just to volume dimensions for now');
    
    max_loads_per_chunk=max_loadable_chunk_size/data_in.min_load_bytes;
    if floor(max_loads_per_chunk)<max_loads_per_chunk && ~opt_struct.ignore_errors
        error('un-even loads per chunk size, %f < %f have to do better job getting loading sizes',floor(max_loads_per_chunk),max_loads_per_chunk);
    end
    chunk_size_bytes=floor(max_loadable_chunk_size/data_in.min_load_bytes)*data_in.min_load_bytes;
    
    recon_strategy.num_chunks           =kspace_data/chunk_size_bytes;
    if floor(recon_strategy.num_chunks)<recon_strategy.num_chunks
        warning('Number of chunks did not work out to integer, things may be wrong!');
    end
    if data_in.min_load_bytes>chunk_size_bytes && ~opt_struct.skip_mem_checks && ~opt_struct.ignore_errors
        error('Oh noes! blocks of data too big to be handled in a single chunk, bailing out');
    end
    
    recon_strategy.min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
    recon_strategy.chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);    % chunk_size in data samples.
    if recon_strategy.num_chunks>1 && ~opt_struct.ignore_errors
        error('not tested with more than one chunk yet');
    end
end

% need to get n samples from data set here. We're going to just assume
% cartesian samples all time for now.
% voldims=[procpar.np/2 procpar.nv procpar.nv2];
% nvols=(npoints/2*ntraces*nblocks)/prod(voldims);
% blocks_per_vol=nblocks/nvols;
% % fov=[procpar.lro procpar.lpe procpar.lpe2].*10; %fov in mm this may not be right for multislice data
% % res=fov./voldims;

% %check to see if we need to do this in chunks or not
% if volumes>1 %recon one volume at a time
%     recon_strategy.num_chunks=volumes;
%     max_blocks=blocks_per_vol;
%     if max_blocks*npoints*ntraces>recon_strategy.memory_space_required
%         error('volume size is too large, consider closing programs and restarting')
%     end
% else %if its just one volume, see if we can do it all at once or need to do chunks
%     max_blocks=floor(recon_strategy.memory_space_required/(ntraces*npoints)); %number of blocks we can work on at a time
%     recon_strategy.num_chunks=ceil(nblocks/max_blocks);
% end
if recon_strategy.num_chunks>1
    fprintf('\tmemory_required :%0.02fM, split into %d problems\n',recon_strategy.memory_space_required/1024/1024,recon_strategy.recon_operations);
    pause(3);
end
clear maximum_RAM_requirement useable_RAM ;
