function [recon_strategy, opt_struct]=get_recon_strategy(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo)

%% calculate memory and chunk sizes
data_in.total_bytes_RAM=...
    data_in.RAM_volume_multiplier...
    *data_in.RAM_bytes_per_voxel...
    *data_in.total_points;
data_work.total_bytes_RAM=...
    data_work.RAM_volume_multiplier...
    *data_work.RAM_bytes_per_voxel...
    *data_work.total_voxel_count;
data_out.total_bytes_RAM=...
    data_out.RAM_volume_multiplier...
    *data_out.RAM_bytes_per_voxel...
    *data_out.total_voxel_count;
% maximum_memory_requirement =...
%     data_in.RAM_volume_multiplier   *data_in.disk_bytes_per_sample  *data_in.total_points...
%     +data_work.RAM_volume_multiplier*data_work.RAM_bytes_per_voxel *data_work.total_voxel_count...
%     +data_out.RAM_volume_multiplier *data_out.RAM_bytes_per_voxel  *data_out.total_voxel_count; %...
%     +volumes_in_memory_at_time*data_in.total_points*d_struct.c*data_in.disk_bytes_per_sample+data_work.total_voxel_count*data_out.RAM_bytes_per_voxel;
maximum_RAM_requirement = data_in.total_bytes_RAM+data_out.total_bytes_RAM+data_work.total_bytes_RAM;
% system_reserved_memory=2*1024*1024*1024;% reserve 2gb for the system while we work.
system_reserved_RAM=max(2*1024*1024*1024,meminfo.TotalPhys*0.3); % reserve at least 2gb for the system while we work
useable_RAM=meminfo.TotalPhys-system_reserved_RAM;
fprintf('\tdata_input.sample_points(Complex kspace points):%d output_voxels:%d\n',data_in.total_points,data_out.total_voxel_count);
fprintf('\ttotal_memory_required for all at once:%0.02fM, system memory(- reserve):%0.2fM\n',maximum_RAM_requirement/1024/1024,(useable_RAM)/1024/1024);
% handle ignore memory limit options
if opt_struct.skip_mem_checks;
    display('you have chosen to ignore this machine''s memory limits, this machine may crash');
    maximum_RAM_requirement=1;
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
if useable_RAM>=maximum_RAM_requirement || opt_struct.skip_mem_checks
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
    min_chunks=1;
    recon_strategy.memory_space_required=maximum_RAM_requirement;
    % max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*data_in.ray_blocks*data_in.disk_bytes_per_sample);
    max_loadable_chunk_size=((data_in.line_points*rays_per_block)*data_in.ray_blocks*data_in.disk_bytes_per_sample);
    % the maximum chunk size for an exclusive data per volume reconstruction.
    recon_strategy.c_dims=[ d_struct.x,...
        d_struct.y,...
        d_struct.z];
    recon_strategy.c_dims=data_buffer.input_headfile. ...
        ([ data_buffer.input_headfile.S_scanner_tag 'dimension_order' ]);
    warning('c_dims set poorly just to input dimensions for now');
    chunk_size_bytes=max_loadable_chunk_size;
    recon_strategy.num_chunks           =kspace_data/chunk_size_bytes;
    if floor(recon_strategy.num_chunks)<recon_strategy.num_chunks
        warning('Number of chunks did not work out to integer, things may be wrong!');
    end
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
elseif true
    % set variables
    %%%
    % binary_header_size % set above so we're good
    % recon_strategy.min_load_size      % set according to data_in.min_load_bytes(this is in data values).
    % load_skip          % set above so we're good
    % chunk_size
    % recon_strategy.num_chunks
    % chunks_to_load(chunk_num)
    % recon_strategy.dim_string='xyz';
    recon_strategy.dim_string=opt_struct.output_order;
    data_work.single_vol_RAM=data_work.volume_voxels*data_work.RAM_bytes_per_voxel*data_work.RAM_volume_multiplier;
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
    end
    recon_strategy.c_dims=recon_strategy.dim_string;
    clear rd;
else
    recon_strategy.min_chunks=ceil(maximum_RAM_requirement/useable_RAM);
    recon_strategy.memory_space_required=(maximum_RAM_requirement/min_chunks); % this is our maximum memory requirements
    % max_loadable_chunk_size=(data_input.sample_points*d_struct.c*(kspace.bit_depth/8))/min_chunks;
    max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*data_in.ray_blocks*data_in.disk_bytes_per_sample)...
        /min_chunks;
    % the maximum chunk size for an exclusive data per volume reconstruction.
    
    recon_strategy.c_dims=[ d_struct.x,...
        d_struct.y,...
        d_struct.z];
    warning('recon_strategy.c_dims set poorly just to volume dimensions for now');
    
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
    fprintf('\tmemory_required :%0.02fM, split into %d problems\n',recon_strategy.memory_space_required/1024/1024,recon_strategy.num_chunks);
    pause(3);
end
clear maximum_RAM_requirement useable_RAM ;
