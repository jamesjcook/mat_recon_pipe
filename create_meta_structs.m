function [d_struct,data_in,data_work,data_out]=create_meta_structs(data_buffer,opt_struct)

%% read dimensions to shorthand struct
d_struct=struct;
d_struct.x=data_buffer.headfile.dim_X;
d_struct.y=data_buffer.headfile.dim_Y;
d_struct.z=data_buffer.headfile.dim_Z;
data_tag=data_buffer.headfile.S_scanner_tag;
d_struct.c=data_buffer.headfile.([data_tag 'channels'] );
if isfield (data_buffer.headfile,[data_tag 'varying_parameter'])
    varying_parameter=data_buffer.headfile.([data_tag 'varying_parameter']);
else
    varying_parameter='';
end
if regexpi(varying_parameter,'.*echo.*')% strcmp(varying_parameter,'echos') || strcmp(varying_parameter,'echoes')
    d_struct.p=data_buffer.headfile.ne;
elseif strcmp(varying_parameter,'alpha')
    d_struct.p=length(data_buffer.headfile.alpha_sequence);
elseif strcmp(varying_parameter,'tr')
    d_struct.p=length(data_buffer.headfile.tr_sequence);
elseif regexpi(varying_parameter,',')
    error('MULTI VARYING PARAMETER ATTEMPTED:%s THIS HAS NOT BEEN DONE BEFORE.',varying_parameter);
else
    fprintf('No varying parameter\n');
    d_struct.p=1;
end
d_struct.t=data_buffer.headfile.([data_tag 'volumes'])/d_struct.c/d_struct.p;
% dont need rare factor here, its only used in the regrid section
% if  isfield (data_buffer.headfile,[data_tag 'rare_factor'])
%     r=data_buffer.headfile.([data_tag 'rare_factor']);
% else
%     r=1;
% end
%% read input acquisition type from our header
data_in.input_order=data_buffer.headfile.([data_tag 'dimension_order' ]);
% some of this might belong in the load data function we're going to need
data_in.vol_type=data_buffer.headfile.([data_tag 'vol_type']);
if opt_struct.vol_type_override~=0
    data_in.vol_type=opt_struct.vol_type_override;
    warning('Using override volume_type %s',opt_struct.vol_type_override);
end
% vol_type can be 2D or 3D or radial.
data_in.scan_type=data_buffer.headfile.([data_tag 'vol_type_detail']);
% vol_type_detail says the type of volume we're dealing with,
% this is set in the header parser perl modules the type can be
% single
% DTI
% MOV
% slab
% multi-vol
% multi-echo are normally interleaved, so we cut our chunk size in necho pieces

% translate scanner terminology to matlab
data_in.disk_bit_depth=data_buffer.headfile.([data_tag 'kspace_bit_depth']);
data_in.disk_data_type=data_buffer.headfile.([data_tag 'kspace_data_type']);
if strcmp(data_in.disk_data_type,'Real')
    data_in.disk_data_type='float';
elseif strcmp(data_in.disk_data_type,'Signed');
    data_in.disk_data_type='int';
elseif strcmp(data_in.disk_data_type,'UnSigned');
    data_in.disk_data_type='uint';
end

if isfield(data_buffer.headfile,[ data_tag 'kspace_endian'])
    data_in.disk_endian=data_buffer.headfile.([ data_tag 'kspace_endian']);
    if strcmp(data_in.disk_endian,'little')
        data_in.disk_endian='l';
    elseif strcmp(data_in.disk_endian,'big');
        data_in.disk_endian='b';
    end
else
    warning('Input kspace endian unknown, header parser defficient!');
    data_in.disk_endian='';
end

% if kspace.bit_depth==32 || kspace.bit_depth==64
data_in.precision_string=[data_in.disk_data_type num2str(data_in.disk_bit_depth)];
% end
% if regexp(data_in.scan_type,'echo')
%     volumes=data_buffer.headfile.([data_tag 'echoes']);
%     if regexp(data_in.scan_type,'non_interleave')
%         interleave=false;
%     else
%         interleave=true;
%     end
% else
%     volumes=data_buffer.headfile.([data_tag 'volumes']);
%     if regexp(data_in.scan_type,'interleave')
%         interleave=true;
%     else
%         interleave=false;
%     end
% end
% volumes=data_buffer.headfile.([data_tag 'volumes']);
% if regexp(data_in.scan_type,'channel')
%     warning('multi-channel support still poor.');
% end
% volumes_in_memory_at_time=2; % part of the peak memory calculations. Hopefully supplanted with better way of calcultating in future

%% set data acquisition parameters to determine how much to work on at a time and how.
% permute_code=zeros(size(data_in.input_order));
% for char=1:length(data_in.input_order)
%     permute_code(char)=strfind(opt_struct.output_order,data_in.input_order(char));
% end

% this mess gets the input and output dimensions using char arrays as
% dynamic structure element names.
% given the structure s.x, s.y, s.z the data_in.input_order='xzy' and
% outputorder='xyz'
% will set input to in=[x z y];
% and output to out=[x y z];
data_in.binary_header_bytes  =data_buffer.headfile.binary_header_size; %distance to first data point in bytes-standard block header.
data_in.ray_block_hdr_bytes  =data_buffer.headfile.block_header_size;  %distance between blocks of rays in file in bytes
data_in.ray_blocks           =data_buffer.headfile.ray_blocks;         %number of blocks of rays total, sometimes nvolumes, sometimes nslices, somtimes nechoes, ntrs nalphas
data_in.rays_per_block       =data_buffer.headfile.rays_per_block;     %number or rays per block of input data,
data_in.ray_length           =data_buffer.headfile.ray_length;         %number of samples on a ray, or trajectory

% if anything except radial
% if( ~regexp(data_in.vol_type,'.*radial.*'))
if strcmp(data_in.vol_type,'radial')
    % if radial
    data_in.input_dimensions=[data_in.ray_length d_struct.(data_in.input_order(2))...
        d_struct.(data_in.input_order(3)) data_in.rays_per_block data_in.ray_blocks];
else
    if exist('dimstruct','class')
        data_in.ds=dimstruct(data_in.input_order,d_struct);
        data_in.input_dimensions=data_in.ds.dim_sizes;
    else
        data_in.input_dimensions=[d_struct.(data_in.input_order(1)) d_struct.(data_in.input_order(2))...
            d_struct.(data_in.input_order(3)) d_struct.(data_in.input_order(4))...
            d_struct.(data_in.input_order(5)) d_struct.(data_in.input_order(6))];
    end
end
data_out.output_order=opt_struct.output_order;
if exist('dimstruct','class')
    data_out.ds=dimstruct(data_out.output_order,d_struct);
    data_out.output_dimensions=data_out.ds.Sub(data_out.output_order);
else
    data_out.output_dimensions=[d_struct.(opt_struct.output_order(1)) d_struct.(opt_struct.output_order(2))...
        d_struct.(opt_struct.output_order(3)) d_struct.(opt_struct.output_order(4))...
        d_struct.(opt_struct.output_order(5)) d_struct.(opt_struct.output_order(6))];
end

%% calculate bytes per voxel for RAM(input,working,output) and disk dependent on settings
% using our different options settings guess how many bytes of ram we need per voxel
% of, input, workspace, and output
data_in.RAM_volume_multiplier=1;
data_in.disk_bytes_per_sample=2*data_in.disk_bit_depth/8; % input samples are always double because complex points are (always?) stored in 2 component vectors.
data_work.RAM_volume_multiplier=1;
data_work.RAM_bytes_per_voxel=0;
data_out.disk_bytes_per_voxel=0;
data_out.RAM_bytes_per_voxel=0;
data_out.RAM_volume_multiplier=1;
data_out.disk_bytes_header_per_out_vol=0;
data_out.disk_bytes_single_header=352; % this way we can do an if nii header switch.
% precision_bytes is multiplied by 2 because complex data takes one number
% for real and imaginary

if ~opt_struct.workspace_doubles&& isempty(regexp(data_in.vol_type,'.*radial.*', 'once'))
    data_work.precision_bytes=2*4;   % we try to keep our workspace to single precision complex.
else
    data_work.precision_bytes=2*8;   % use double precision workspace
end
data_in.RAM_bytes_per_voxel=data_work.precision_bytes;
data_out.precision_bytes=4;
data_work.RAM_bytes_per_voxel=data_work.precision_bytes;

% calculate space required on disk and in memory to save the output.
% 2 bytes for each voxel in civm image, 8 bytes per voxel of complex output
% 4 bytes for save 32-bit mag, 32-bit phase, unscaled nii, kspace image,
% unfiltered kspace image etc.
if ~opt_struct.skip_write_civm_raw
    if ~opt_struct.fp32_magnitude % if not fp32, then we're short int.
        data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+2;
    else
        data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+4;
    end
    data_out.RAM_bytes_per_voxel=data_out.RAM_bytes_per_voxel+data_work.precision_bytes;
end
if opt_struct.write_unscaled
    data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
    data_out.disk_bytes_header_per_out_vol=data_out.disk_bytes_header_per_out_vol+data_out.disk_bytes_single_header;
end
% if opt_struct.write_unscaled
%     data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
% end
if opt_struct.write_unscaled_nD
    data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
end
if opt_struct.write_phase
    data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
    data_out.disk_bytes_header_per_out_vol=data_out.disk_bytes_header_per_out_vol+data_out.disk_bytes_single_header;
end
if opt_struct.write_complex
    data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
end

if opt_struct.write_kimage
    data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
%     data_out.RAM_bytes_per_voxel=data_out.RAM_bytes_per_voxel+data_work.precision_bytes*2;
    data_out.disk_bytes_header_per_out_vol=data_out.disk_bytes_header_per_out_vol+data_out.disk_bytes_single_header;
%     data_work.RAM_bytes_per_voxel=data_work.RAM_bytes_per_voxel+data_work.precision_bytes;
end
if opt_struct.write_kimage_unfiltered
    data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
%     data_out.RAM_bytes_per_voxel=data_out.RAM_bytes_per_voxel+data_work.precision_bytes*2;
%     data_work.RAM_bytes_per_voxel=data_work.RAM_bytes_per_voxel+data_work.precision_bytes;
end
if opt_struct.write_unscaled || opt_struct.write_unscaled_nD || opt_struct.write_phase|| opt_struct.write_complex ||opt_struct.write_kimage_unfiltered||opt_struct.write_kimage_unfiltered
%     output_
%     data_out.RAM_bytes_per_voxel=data_out.RAM_bytes_per_voxel+data_work.precision_bytes;
    data_work.RAM_bytes_per_voxel=data_work.RAM_bytes_per_voxel+data_work.precision_bytes;
end
% data_out.volumes=data_buffer.headfile.([data_tag 'volumes'])/d_struct.c;
data_work.volumes=data_buffer.headfile.([data_tag 'volumes']); % initalize to worst case before we run through possibilities below.
data_out.volumes=data_buffer.headfile.([data_tag 'volumes']);
if opt_struct.skip_combine_channels % while we're using the max n volumes this is unnecessary.
    data_out.volumes=data_buffer.headfile.([data_tag 'volumes']);
end
%% calculate expected disk usage and check free disk space.

data_out.volume_voxels=...
    d_struct.x*...
    d_struct.y*...
    d_struct.z;
data_out.total_voxel_count=...
    data_out.volume_voxels*...
    data_out.volumes;

if regexp(data_in.vol_type,'.*radial.*')
    if ~opt_struct.grid_oversample_factor
        %         opt_struct.grid_oversample_factor=3;
        data_buffer.headfile.radial_grid_oversample_factor=3;
        fprintf('\trad_mat default oversample factor=%0.2f.\n',data_buffer.headfile.radial_grid_oversample_factor);
    else
        data_buffer.headfile.radial_grid_oversample_factor=opt_struct.grid_oversample_factor;
        fprintf('\trad_mat oversample factor=%0.2f.\n',data_buffer.headfile.radial_grid_oversample_factor);
    end
    if ~opt_struct.dcf_iterations
        data_buffer.headfile.radial_dcf_iterations=18; %Number of iterations used for dcf calculation, should be put up higher to top.
        fprintf('\trad_mat default dcf iterations=%d.\n',data_buffer.headfile.radial_dcf_iterations);
    else
        data_buffer.headfile.radial_dcf_iterations=opt_struct.dcf_iterations;
        fprintf('\trad_mat dcf iterations=%d.\n',data_buffer.headfile.radial_dcf_iterations);
    end

    data_work.volume_voxels=data_out.volume_voxels*data_buffer.headfile.radial_grid_oversample_factor^3;
    data_work.total_voxel_count=...
        data_work.volume_voxels...
        *(data_work.volumes+4);
    % we add 4 to the volumes because we need 3x vols for the trajectory
    % points, and then an additional 1x for the dcf volume This is a little
    % imprecise and will probably made totally precise later. The
    % trajectory is double precision 3 part vector (3x64) for each point of
    % kspace sampled. DCF is single precision (or at least can be without
    % noticeable loss in quality).
    if exist('dimstruct','class')
        og_vol=[1 1 1 ]*data_out.output_dimensions(1)*data_buffer.headfile.radial_grid_oversample_factor;
        data_work.ds=dimstruct(data_out.output_order,[og_vol data_out.output_dimensions(4:end)]);
    end
else
    data_work.volume_voxels=data_out.volume_voxels;
    data_work.total_voxel_count=data_out.total_voxel_count;
    if exist('dimstruct','class')
        data_work.ds=dimstruct(data_out.output_order,data_out.output_dimensions);
    end
end
data_out.disk_total_bytes=data_out.total_voxel_count*data_out.disk_bytes_per_voxel;
fprintf('Required disk space is %0.2fMB\n',data_out.disk_total_bytes/1024/1024);

%% calculate memory and chunk sizes
data_in.total_points = data_in.ray_length*data_in.rays_per_block*data_in.ray_blocks;
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

% total data / nvols?(this would only work for cartesian)
data_in.single_vol_RAM=(data_in.ray_length*data_in.rays_per_block*data_in.ray_blocks)/data_out.volumes;

data_work.single_vol_RAM=data_work.volume_voxels*data_work.RAM_bytes_per_voxel*data_work.RAM_volume_multiplier;%add slice sizes as well in all likely hood if we do slice recon we'll still have room to load at least one whole volume.
% data_work.one_slice_RAM=d_struct.x*d_strucyt.y*data_work.RAM_bytes_per_voxel;
data_out.single_vol_RAM =data_out.volume_voxels *data_out.RAM_bytes_per_voxel *data_out.RAM_volume_multiplier;
% data_out.one_slice_RAM = d_struct.x*d_strucyt.y*data_out.RAM_bytes_per_voxel;


data_in=orderfields(data_in);
data_work=orderfields(data_work);
data_out=orderfields(data_out);




