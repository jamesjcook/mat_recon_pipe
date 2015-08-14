function [recon_strategy, opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo)
%%% possible recon strategies(summary).
% load_whole, process_whole 
%    load_whole=true,
%    work_by_chunk=false;
%    work_by_sub_chunk=false;
%    num_chunks=1,
%    recon_operations=1,
%    prod(w_dims)=prod(output_dimensions),
% load_whole. process_single_vol 
%    load_whole=true,
%    work_by_chunk=true;
%    work_by_sub_chunk=false;
%    num_chunks=n_file_chunks
%    recon_operations=n-_vols;
%    prod(w_dims)=prod(output_dimensions)/prod(op_dims),
% load_whole, process_n_vol (num_recons=n_vols/somedims)
% NOT CURRENTLY SUPPORTED DUE TO THE EXTRA COMPLICATIONS OF PARTIAL DIMENSIONAL WORK.
%    load_whole=true;
%    work_by_chunk=false;
%    work_by_sub_chunk=false;
%    num_chunks=n_file_chunks,
%    recon_operations=n_vols/simultanous_vols,
%    prod(w_dims)=prod(output_dimensions)/simultaneous_vols,
% load_onevol,process_onevol (num_chunks=n_vols) 
%    load_whole=false,
%    work_by_chunk=true;
%    work_by_sub_chunk=false;
%    num_chunks=n_file_chunks,
%    recon_operations=n_vols,
%    prod(w_dims)=prod(output_dimensions),
% load_onevol,process_volpart (n_parts?) (num_chunks=n_vols*chunks_per_vol)
%    load_whole=false,
%    work_by_chunk=false
%    work_by_sub_chunk=true
%    num_chunks=n_file_chunks,
%    recon_operations=n_vols*parts_per_vol,
%    prod(w_dims)=prod(output_dimensions)/,
% load_volpart,process_volpart, (n_parts?) (num_chunks=n_vols*chunks_per_vol)
%    load_whole=true,
%    work_by_chunk=false;
%    work_by_sub_chunk=false;
%    num_chunks=1,
%    recon_operations=1,
%    prod(w_dims)=prod(output_dimensions),

%% complex recon strategy identification
% check that one 3d vol of xyz will fit?
% precalc all recon strategies? in tree?
% the work by chunk or subchunk fields refer to how much of the data is
% loaded at a time. Either a full data block in file, or a partial one.

% recon strategy settings
% possible recon strategys
% for a series of acquistions load the whole or load most reasonable small
% part.(1 volume,1slice,1ray)
% filter always operates per volume or slice so its operation is
% unaffected.
% fft all in parallel, or fft whole most reasonable chunk or, fft slice then
% fft across 3rd dimension later if need be.

% terminolgy conventions
% points=samples of data, complex points
% size=  data_size reads, in loading operations we read by bit depth, this
% ammount.
% bytes  bytes, data_size reads bitdepth(generally), size translated to
% size on disk more or less.

%% get memory info
recon_strategy.maximum_RAM_requirement = data_in.total_bytes_RAM+data_out.total_bytes_RAM+data_work.total_bytes_RAM;
% system_reserved_memory=2*1024*1024*1024;% reserve 2gb for the system while we work.

if meminfo.AvailPhys> meminfo.TotalPhys*.05 % if mem is relatively clear
    memparam='TotalPhys';
else
    warning('Lots of memory occupied, trying to squeek by anyway');
    memparam='AvailPhys'; % if mem is not clear.
end
system_reserved_RAM=max(2*1024*1024*1024,meminfo.TotalPhys*0.3); % reserve at least 2gb for the system while we work

useable_RAM=meminfo.(memparam)-system_reserved_RAM;
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
recon_strategy.load_whole=true;% do we load all input data
recon_strategy.channels_at_once=true;% can we recon all the cahnnels
recon_strategy.dim_string=opt_struct.output_order; % what order will we work in 
recon_strategy.work_by_chunk=false;% will we operate on a whole chunk of the file at once
recon_strategy.work_by_sub_chunk=false; % do we have to operate on partial chunks, work by chunk, and work by sub-chunk are exclusive.
recon_strategy.num_chunks=1;% how many chunks ar there in the file, sub_chunk size is set later.
recon_strategy.post_scaling=false; % unused 
recon_strategy.recon_operations=1; % how many times through the main fft loop code.
recon_strategy.op_dims=''; % the non-working dimensions

recon_strategy.chunk_size=2*data_in.line_points*data_in.rays_per_block;  % chunk_size in # of values (eg, 2*complex_points).
recon_strategy.min_load_size=recon_strategy.chunk_size; % minimum_load_size in data samples. this is the biggest piece of data we can load between header bytes.

recon_strategy.load_skip=data_in.ray_block_hdr_bytes;
recon_strategy.post_skip=0;  % part of subchunk code 
chunk_size_bytes=recon_strategy.chunk_size*(data_in.disk_bit_depth/8);
recon_strategy.num_chunks=data_in.kspace_data/chunk_size_bytes; clear chunk_size_bytes;


%%% set starting point to exactly one ray worth of input in memory.
recon_strategy.memory_space_required=data_in.ds.Sub('x')...
    *data_in.RAM_bytes_per_voxel;
recon_strategy.dim_string=data_in.input_order;
recon_strategy.w_dims='';

% one dimension at a time starting at the beginning. add that dimension to
% our ram requirement calculation. Stop when we're over the useable ram.
% each time a dimension is added keep track. Set aside the last
% calculation each iteration of the loop.
% after the loop exits, if we went too far, restore the last calculated value.
rs.last=recon_strategy;
td=1;% index var for the output dimensions
while recon_strategy.memory_space_required < useable_RAM ...
        && td <= numel(data_out.output_dimensions)
    if data_out.output_dimensions(td)>1 % skip dimensions of size 1
        rs.last=recon_strategy;
        recon_strategy.w_dims(end+1)=data_out.output_order(td);
        recon_strategy.memory_space_required=prod(data_in.ds.Sub(recon_strategy.w_dims))...
            *data_in.RAM_bytes_per_voxel...
            +prod(data_work.ds.Sub(recon_strategy.w_dims))...
            *data_work.RAM_bytes_per_voxel...
            +prod(data_out.ds.Sub(recon_strategy.w_dims))...
            *data_out.RAM_bytes_per_voxel;
    end
    td=td+1;
end
if recon_strategy.memory_space_required > useable_RAM
    % we are not load_whole, process_whole.
    recon_strategy=rs.last; clear rs td;
end
%%%% get mapping of input order ot output order becuase we find our ram in output order.
to=[]; % indices of our working dims in the input_order.
for d=1:length(recon_strategy.w_dims)
    ti=strfind(data_in.input_order,recon_strategy.w_dims(d));
    to=[to ti];
end
recon_strategy.w_dims=data_in.input_order(sort(to));
if numel(recon_strategy.w_dims)<numel(data_out.output_order)
    %         recon_strategy.op_dims=data_out.output_order(numel(recon_strategy.w_dims)+1:end);
    recon_strategy.op_dims=data_out.ds.Rem(recon_strategy.w_dims);
end
%     recon_strategy.dim_string=data_out.ds.showorder(recon_strategy.w_dims);
recon_strategy.recon_operations=prod(data_out.ds.dim_sizes)/prod(data_out.ds.Sub(recon_strategy.w_dims));

%%%% code above works well, and as intended. it calculates how much data we 
%%%% can load symetrically. Incorporating both input, working and output
%%%% memory requiremnts equally. Now lets see if we can get more input data
%%%% into memory.
% w_dims will be our working dimensions that we can fit
% op_dims will be any dims which cannot fit in memory.
% recon_operations will be the number of times the main processing loop has to run
% memory_space_required is an operational minimum. We havnt checked yet if
% we can load the whole volume.
if ( recon_strategy.memory_space_required < recon_strategy.maximum_RAM_requirement)
    if ( useable_RAM < ...
            (recon_strategy.memory_space_required + data_in.total_bytes_RAM - data_in.single_vol_RAM ) )
        recon_strategy.load_whole=false;
    else
        recon_strategy.memory_space_required=recon_strategy.memory_space_required + data_in.total_bytes_RAM - data_in.single_vol_RAM ;
    end
end
%%%
%chunks_per_vol
%sub_chunks_per_chunk.

%%% calc var skip btween dim_string and w_dims.
%%% indicate subchunk skips... if we got them.
%%% what is the chunk dimension? previously we always just assumed it.
recon_strategy.work_by_chunk=false;
recon_strategy.work_by_sub_chunk=false;
%%% blocks = chunks, so how big is the block dimension, that should
%%% matchup with the possible read data dimensions.

%%%% if 2D we will operate in slice mode.... (code that later).
if strcmp(data_in.vol_type,'2D')...
        && recon_strategy.maximum_RAM_requirement > useable_RAM
    warning('did not do 2D recon strategy. code');
    %%%% if 3D
elseif ~isempty(regexp(data_in.vol_type,'(3D|4D)', 'once'))
    if ( recon_strategy.num_chunks ~= prod(data_out.output_dimensions)/prod(data_out.ds.Sub('xyz')))
        warning('native fft blocks dont line up with chunks!');
    end
    unique_test_string=data_in.ds.showorder([data_in.ray_blocks data_in.ray_blocks data_in.ray_blocks]);
    unique_test_string=unique_test_string([true diff(unique_test_string)~=0]);%collapses any extra f's to a singluar f'.
    
    %%% if the chunk dimension is z we have to work by sub_chunks, this has
    %%% come up once.
    if (   (numel(unique_test_string)>=2 && strcmp(unique_test_string(end-1),'z')&&strcmp(unique_test_string(end),'f') )...
            || (numel(unique_test_string)>=1 &&strcmp(unique_test_string(end),'f') )   )...
            && recon_strategy.maximum_RAM_requirement > useable_RAM
        recon_strategy.work_by_sub_chunk=true;
        %%% this is guessing our ray_block dimension.
        %%% if our block dimension is z, we have to skip over the
        %%% product of anything between the x, y and z dimensions of our
        %%% output, this significantly complicates the skip load
        %%% options.  This begs the question would we be better off
        %%% with a pre-fid reformat in this context.
        %%% This comes up with muti-echo/multi-channel data.
        
        %ray_length is always x. so we can assume that dimension is
        %fine.
        % we have to traverse until we get to a non-one dimension other
        % than y or z. then calculate our subskip.
        skip_dims=[];
        for dn=1:length(recon_strategy.dim_string) % check over our dimensions in input order.
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
        %%% do i need to double the size of load,and skip because
        %%% complex?
        %%%% have sub_chunk_skip_points, but we load each chunk in
        %%%% file. Have to pass this off to ourrecon_strat.
        % native_chunk_dimensions?
    elseif (   numel(unique_test_string)>=2 &&  ~strcmp(unique_test_string(end-1),'x')...
            && ~strcmp(unique_test_string(end-1),'y')...
            && ~strcmp(unique_test_string(end-1),'z') ...
            && strcmp(unique_test_string(end),'f')   )... 
            || (   numel(unique_test_string)>=1 && strcmp(unique_test_string(end),'f')   )
        
        %%% so long as the chunk dimension is not x y or z, loading and
        %%% load skipping should be okay.
        warning('NORMAL CHUNK ORDERING NOT VERIFIED');
        %%% num_chunks=ray_blocks and life is relatively easy.
        % recon_strategy.work_by_chunk=true; % this was disabled, i
        % think its a bug.
        pause(3);
    else
        
        warning('UNHANDLED CHUNK CONDIDTION :(%s)',unique_test_string(end-1));
    end
end

if recon_strategy.work_by_chunk || recon_strategy.work_by_sub_chunk
    recon_strategy.load_whole=false;
end

if ~recon_strategy.load_whole 
    if ~recon_strategy.work_by_sub_chunk
        recon_strategy.work_by_chunk=true;
        recon_strategy.recon_operations=recon_strategy.num_chunks;
    end
end



if recon_strategy.recon_operations>1
    fprintf('\tmemory_required :%0.02fM, split into %d problems\n',recon_strategy.memory_space_required/1024/1024,recon_strategy.recon_operations);
    pause(3);
end
clear maximum_RAM_requirement useable_RAM ;
