function [img, s]=rad_mat(scanner,runno,input,options)
% [img, s]=RAD_MAT(scanner,runno,input,options)
% Reconstruct All Devices in MATlab
% rad_mat, a quasi generic reconstruction/reformating scanner to archive
% pipeline.
% It relies on a dumpheader perl script which knows most of the differences
% between different types of input data. That script could be co-opted by
% adding a headfile override option(this isnt implemented yet).
%
% scanner  - short name of scanner to get data input from
% runno    - run number for output
% input    - string or cell array of the data name on scanner
%          - for agilent 20120101_01/ser01.fid
%          - for aspect  '004534', by convention asepect runnumbers are
%          aspect id+6000
%          - for bruker   {'patientid','scanid'}
%                (datanum is not supported yet?)
% option   - for a list and explaination use 'help'.
%
% img      - output volume in the output_order
% s        - status 1 for success, and 0 for failures.
%            (following matlab boolean, true/false)

% Primary goals,
% A scanner independent(generic) scanner to civm raw image pipeline with
% archive ready outputs.
% Use as much memory as possible without over flowing, by breaking the
% problem into chunks.
% Include taking scanner reconstucted images into the same work flow to
% avoid having separate handler code for them.
%
% the steps of the pipeline,
% load scanner and engine dependencies.
% copy data using puller_simple.pl
% interpret and save an initial scanner header using dumpHeader.pl
% load the scanner header,
% determine expected memory load and disk space required
% for each chunk
% load(partial or full)
% if scanner recon inverse fft?
% regrid(partial or full)
% filter(partial or full)
% fft (partial or full)
% resort/rotate
% save.
%
% Currrently a very beta project.
% supports Aspect data, bruker data, or agilent data location convention.
%
% TODO's
% testing
% param file support
% testing
% agilent support
% testing
% arbitrary headfile variables through options cellarray
% testing
% load arbitrary headfile for overriding
% testing
% fix up regridding to bea  meaninful step other than reshape very
% testing
% specifically for GRE aspect and RARE Bruker scans
% testing
% add scanner image reformat support, could add inverse fft to load step,
% testing
% did i mention testing?
if verLessThan('matlab', '8.1.0.47')
    error('Requires Matlab version 8.1.0.47 (2013a) or newer');
end
%% arg check or help
if ( nargin<3)
    if nargin==0
        help rad_mat; %('','','',{'help'});
    else
        rad_mat('','','','help');
    end
    
end

%% data setup
img=0;
data_buffer=large_array;
data_buffer.addprop('data');
data_buffer.addprop('scanner_constants');
data_buffer.addprop('engine_constants');
data_buffer.addprop('headfile');     % ouput headfile to dump or partial output for multi sets.
data_buffer.addprop('input_headfile'); % scanner input headfile
data_buffer.headfile=struct;

%% put some in put into the headfile
data_buffer.headfile.B_recon_type='rad_mat'; % warning, can only be 16 chars long.
data_buffer.headfile.U_runno=runno;
data_buffer.headfile.comment={'# Rad_Mat Matlab recon'};
data_buffer.headfile.comment{end+1}=['# Reconstruction time ' datestr(now,'yyyy-mm-dd HH:MM:SS')];
% version=  ''; % get version from v file name on disk

%% option and function argument handling
if ~iscell(input)
    input={input};
end

%switch for setting options might be better served ina little struct?
if exist('options','var')
    if ~iscell(options)
        options={options};
    end
else
    options={};
end
% define the possible options, so we can error for unrecognized options.
% 3 classes of options,
% standard, ready for use,
% beta,     just written tested very little
% planned,  an inkling that they're desried, possibly started etc.
standard_options={
    '',                       'Core options which have real support.'
    'help',                   ' Display the help'
    'overwrite',              ' over write anything in the way, especially re run puller and overwrite whats there'
    'existing_data',          ' use data from system(as if puller had already run)'
    'skip_mem_checks',        ' do not test if we have enough memory'
    'testmode',               ' skip qui and just put dummy info in gui fields, will not be archiveable'
    'write_output',           ' disable all output saving, good for running inside matlab and continuing in another function'
    'skip_write_civm_raw',    ' do now save civm raw files.'
    'skip_write_headfile',    ' do not write civm headfile output'
    'write_unscaled',         ' save unscaled nifti''s in the work directory '
    'display_kspace',         ' display the kspace data prior to reconstruction, will showcase errors in regrid and load functions'
    'display_output',         ' display reconstructed output after the resort and transform operations'
    '',                       ''
    };
beta_options={
    '',                       'Secondary, new, experimental options'
    'planned_ok',             ' specaial option which must be early in list of options, controlls whether planned optinos are an error'
    'unrecognized_ok',        ' special option which must be early in list of options, controls whether arbitrary options are an error, this is so that alternate child functions could be pass ed the opt_struct variable and would work from there.'
    'debug_mode',             ' way to set our verbosity. use debug_mode=##'
    'study',                  ' set the bruker study to pull from, useful if puller fails to find the correct data'
    'U_dimension_order',      ' input_dimension_order will override whatever the perl script comes up with.'
    'vol_type_override',      ' if the processing script fails to guess the proper acquisition type(2D|3D) it can be specified.'
    'ignore_kspace_oversize', ' when we do our sanity checks on input data ignore kspace file being bigger than expected, this currently must be on for aspect data'
    'output_order',           ' specify the order of your output dimensions. Default is xyzcpt. use output_oder=xyzcpt.'
    'channel_alias',          ' list of values for aliasing channels to letters, could be anything using this'
    'combine_method',         ' specify the method used for combining multi-channel data. supported modes are square_and_sum, or mean, use  combine_method=text'
    'skip_combine_channels',  ' do not combine the channel images'
    'write_complex',          ' should the complex output be written to th work directory. Will be written is rp(or near rp file) format.'
    'do_aspect_freq_correct', ' skip the aspect frequency correction.'
    'skip_load'               ' do not load data, implies skip regrid, skip filter, skip recon and skip resort'
    'skip_regrid',            ' do not regrid'
    'skip_filter',            ' do not filter data sets.'
    'skip_recon',             ' for re-writing headfiles only, implies skip filter, and existing_data'
    'skip_resort',            ' for 3D acquisitions we resort after fft, this alows that to be skiped'
    'force_ij_prompt',        ' force ij prompt on, it is normally ignored with skip_recon'
    'remove_slice',           ' removes a slice of the acquisition at the end, this is a hack for some acquisition types'
    'open_volume_limit',      ' maximum number of volumes imagej will open at a time'
    'warning_pause',          ' lenght of pause after warnings (default 3)'
    '',                       ''
    };
planned_options={
    '',                       'Options we may want in the future, they might have been started. They could even be finished and very unpolished. '
    'write_phase',            ' write a phase output to the work directory'
    'fp32_magnitude',         ' write fp32 civm raws instead of the normal ones'
    'write_kimage',           ' write the regridded and filtered kspace data to the work directory.'
    'write_kimage_unfiltered',' write the regridded unfiltered   kspace data to the work direcotry.'
    'ignore_errors',          ' will try to continue regarless of any error'
    'asymmetry_mirror',        ' with echo asymmetry tries to copy 85% of echo trail to leading echo side.'
    '',                       ''
    };
standard_options_string =[' ' strjoin(standard_options(2:end,1)',' ') ' ' ];
beta_options_string     =[' ' strjoin(beta_options(2:end,1)',    ' ') ' ' ];
planned_options_string  =[' ' strjoin(planned_options(2:end,1)', ' ') ' ' ];
all_options=[standard_options; beta_options; planned_options;];
% make all options = false, set some defaults right after this.
for o_num=1:length(all_options(:,1))
    if ~isfield('opt_struct',all_options{o_num,1}) && ~isempty(all_options{o_num,1})
        opt_struct.(all_options{o_num,1})=false;
    end
end
%%% set default options
opt_struct.debug_mode=10;
opt_struct.open_volume_limit=36;
opt_struct.channel_alias='abcdefghijklmnopqrstuvwxyz';
opt_struct.warning_pause=3;
opt_struct.ignore_errors=false;
% [... % just a lookup of letters to assign to channel data, we'll reserve _m numbers for acquisition params other than channels, eg. time, te, tr alpha, gradients
%     'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' ...
%     'n' 'o' 'p' 'q' 'r' 's' 't' 'u' 'v' 'w' 'x' 'y' 'z' ];
opt_struct.puller_option_string='';
opt_struct.write_output=true;     % normally we want to save output
%opt_struct.combine_channels=true; % normally we want to combine channels
% opt_struct.display_kspace=false;
% opt_struct.display_output=false;
%
opt_struct.output_order='xyzcpt'; % order of dimensions on output. p is parameters, c is channels.
possible_dimensions=opt_struct.output_order;
opt_struct.combine_method='mean';
% opt_struct.combine_method='square_and_sum';
%%% handle options cellarray.
% look at all before erroring by placing into cellarray err_strings or
% warn_strings.
warn_string='';
err_string='';
if length(runno)>16
    warn_string=sprintf('%s\nRunnumber too long for db\n This scan will not be archiveable.',warn_string);
end
for o_num=1:length(options)
    option=options{o_num};
    %%% see what kind of option and add to error and warning message if not
    %%% standard/allowed.
    value=true;
    specific_text='';
    if regexpi(option,'=')
        parts=strsplit(option,'=');
        if length(parts)==2
            value=parts{2};
            option=parts{1};
        else
            err_string=sprintf('%s ''='' sign in option string %s, however does not split cleanly into two parts',err_string,option);
        end
    end
    if regexpi(standard_options_string,[' ' option ' '])
        w=false;
        e=false;
    elseif ~isempty(regexpi(beta_options_string,[' ' option ' ']))
        w=true;
        e=false;
        specific_text='is a beta option, CHECK YOUR OUTPUTS CAREFULLY! and use at own risk.';
    elseif regexpi(planned_options_string,[' ' option ' '])
        w=false;
        e=true;
        specific_text='is at best partially implemented.';
        if opt_struct.planned_ok  % allows planned options to pass through.
            w=true;
            e=false;
            specific_text=sprintf( '%s you enabled it with planned_ok',specific_text);
        end
        specific_text=sprintf('%s if you''re sure you want to use it add the planned_ok option also.',specific_text );
    else
        w=false;
        e=true;
        specific_text='not recognized.';
        if opt_struct.unrecognized_ok  % allows unrecognized options to pass through.
            w=true;
            e=false;
            specific_text=sprintf('%s Maybe it is used in some secondary code which did not update the allowed options here.\n continuing.',specific_text);
        end
    end
    if w
        warn_string=sprintf('%s\n ''%s'' option %s',warn_string,option,specific_text);
    end
    if e
        err_string=sprintf('%s\n ''%s'' option %s',err_string,option,specific_text);
    end
    %%% since we're a struct its easy to add options that dont exist etc,
    %%% we'll just error because they were recongnized as unexpected above.
    if ~isnan(str2double(value))
        value=str2double(value);
    end
    opt_struct.(option)=value;
end
if ~isempty(warn_string)
    warning('\n%s\n',warn_string);
    pause(opt_struct.warning_pause);
end
if ~isempty(err_string) && ~opt_struct.ignore_errors
    useage_string=help('rad_mat');
    error('\n%s%s\n',useage_string,err_string);
end
if opt_struct.help
    help rad_mat;
    for o_num=1:length(all_options(:,1))
        fprintf('%24s - %s\n',all_options{o_num,1},all_options{o_num,2});
    end
    error('help display stop.');
end
if length(opt_struct.output_order)<length(possible_dimensions)
    for char=1:length(possible_dimensions)
        test=strfind(opt_struct.output_order,possible_dimensions(char));
        if isempty(test)
            warning('mission dimension %s, appending to end of list',possible_dimensions(char));
            opt_struct.output_order=sprintf('%s%s',opt_struct.output_order,possible_dimensions(char));
        end
    end
end
if length(opt_struct.U_dimension_order)<length(possible_dimensions)
    for char=1:length(possible_dimensions)
        test=strfind(opt_struct.U_dimension_order,possible_dimensions(char));
        if isempty(test)
            warning('mission dimension %s, appending to end of list',possible_dimensions(char));
            opt_struct.U_dimension_order=sprintf('%s%s',opt_struct.U_dimension_order,possible_dimensions(char));
        end
    end
end
if opt_struct.overwrite
    opt_struct.puller_option_string=[' -o ' opt_struct.puller_option_string];
end
if opt_struct.existing_data||opt_struct.skip_recon
    opt_struct.puller_option_string=[' -e ' opt_struct.puller_option_string];
end
clear possible_dimensions warn_string err_string;

%% dependency loading
data_buffer.scanner_constants=load_scanner_dependency(scanner);
data_buffer.engine_constants=load_engine_dependency();
data_buffer.headfile.matlab_functioncall=['rad_mat('''  scanner ''', ''' data_buffer.headfile.U_runno ''', {''' strjoin(input,''', ''') '''} ' ', {''' strjoin(options,''', ''') '''})'];
data_buffer.headfile.comment{end+1}='# \/ Matlab function call \/';
data_buffer.headfile.comment{end+1}=['# ' data_buffer.headfile.matlab_functioncall];
data_buffer.headfile.comment{end+1}='# /\ Matlab function call /\';
data_buffer.headfile.comment{end+1}=['# Reconstruction engine:' data_buffer.engine_constants.engine ];
data_buffer.headfile.comment{end+1}='# see reconstruciton_ variables for engind_dependencies';
data_buffer.headfile.comment{end+1}='# see scanner_ variables for engind_dependencies';

%%% stuff special dependency variables into headfile
data_buffer.headfile.S_tesla=data_buffer.scanner_constants.scanner_tesla_image_code;

clear o_num options option all_options standard_options standard_options_string beta_options beta_options_string planned_options planned_options_string specific_text value err_strings warn_strings e w parts;

%% data pull and build header from input

if strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')
    if ~regexpi(input{end},'fid')
        % if ! endswith fid, add fid
        dirext='.fid';
    else
        dirext='';
    end
else
    dirext='';
end
if numel(input)==1
    input= strsplit(input{1},'/');
end
if numel(input)==2 && strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    input{1}=[input{1} '*'];
    if opt_struct.study~=0
        opt_struct.puller_option_string=sprintf('%s -s %s',opt_struct.puller_option_string,opt_struct.study);
    end
end %else
puller_data=[strjoin(input, '/'), dirext];
datapath=[data_buffer.scanner_constants.scanner_data_directory '/' puller_data ];
data_buffer.input_headfile.origin_path=datapath;
% display(['data path should be omega@' scanner ':' datapath ' based on given inputs']);
% display(['base runno is ' runno ' based on given inputs']);

%pull the data to local machine
work_dir_name= [data_buffer.headfile.U_runno '.work'];
work_dir_path=[data_buffer.engine_constants.engine_work_directory '/' work_dir_name];
cmd=['puller_simple ' opt_struct.puller_option_string ' ' scanner ' ''' puller_data ''' ' work_dir_path];
data_buffer.headfile.comment{end+1}=['# \/ pull cmd ' '\/'];
data_buffer.headfile.comment{end+1}=['# ' cmd ];
data_buffer.headfile.comment{end+1}=['# /\ pull cmd ' '/\'];
if ~opt_struct.existing_data&&~opt_struct.skip_recon
    s =system(cmd);
    if s ~= 0|| opt_struct.ignore_errors
        error('puller failed:%s',cmd);
    end
end

% load data header given scanner and directory name
data_buffer.input_headfile=load_scanner_header(scanner, work_dir_path );
data_tag=data_buffer.input_headfile.S_scanner_tag;
if opt_struct.U_dimension_order ~=0
    data_buffer.input_headfile.([data_tag 'dimension_order'])=opt_struct.U_dimension_order;
end
data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.input_headfile,'combine');
data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.scanner_constants,false);
data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.engine_constants,false);
data_buffer.headfile=combine_struct(data_buffer.headfile,opt_struct,'rad_mat_option_');
if isfield(data_buffer.input_headfile,'aspect_remove_slice')
    if data_buffer.input_headfile.aspect_remove_slice
        opt_struct.remove_slice=1;
    else
        opt_struct.remove_slice=0;
    end
end
clear datapath dirext input puller_data s;
%% determing input acquisition type
% some of this might belong in the load data function we're going to need
vol_type=data_buffer.input_headfile.([data_tag 'vol_type']);
if opt_struct.vol_type_override~=0
    vol_type=opt_struct.vol_type_override;
end
% vol_type can be 2D or 3D
scan_type=data_buffer.input_headfile.([data_tag 'vol_type_detail']);
% vol_type_detail says the type of volume we're dealing with,
% this is set in the header parser perl modules the type can be
% single
% DTI
% MOV
% slab
% multi-vol
% multi-vol-interleave %%%% NOT IMPLMENTED YET IN HEADER PARSER
%                            > THIS WILL BE FOR MULTI-CHANNEL DATA
% multi-echo
% multi-echos are normally interleaved, so we cut our chunk size in necho pieces
% mutli-echo-non_interleave %%%% NOT IMPLEMENTED YET IN HEADER PARSER
%                               > MAY NEVER HAPPEN.

in_bitdepth=data_buffer.input_headfile.([data_tag 'kspace_bit_depth']);
in_bytetype=data_buffer.input_headfile.([data_tag 'kspace_data_type']);
if strcmp(in_bytetype,'Real')
    in_bytetype='float';
elseif strcmp(in_bytetype,'Signed');
    in_bytetype='int';
elseif strcmp(in_bytetype,'UnSigned');
    in_bytetype='uint';
end

if isfield(data_buffer.input_headfile,[ data_tag 'kspace_endian'])
    in_endian=data_buffer.input_headfile.([ data_tag 'kspace_endian']);
    if strcmp(in_endian,'little')
        in_endian='l';
    elseif strcmp(in_endian,'big');
        in_endian='b';
    end
end
if ~exist('in_endian','var')
    warning('Input kspace endian unknown, header parser defficient!');
    in_endian='';
end

% if in_bitdepth==32 || in_bitdepth==64
in_precision=[in_bytetype num2str(in_bitdepth)];
% end
% if regexp(scan_type,'echo')
%     volumes=data_buffer.input_headfile.([data_tag 'echos']);
%     if regexp(scan_type,'non_interleave')
%         interleave=false;
%     else
%         interleave=true;
%     end
% else
%     volumes=data_buffer.input_headfile.([data_tag 'volumes']);
%     if regexp(scan_type,'interleave')
%         interleave=true;
%     else
%         interleave=false;
%     end
% end
volumes=data_buffer.input_headfile.([data_tag 'volumes']);
if regexp(scan_type,'channel')
    warning('multi-channel support still poor.');
end
%% calculate required disk space
bytes_per_pix_output=(2+8+4+4);
% calculate space required on disk to save the output.
% 2 bytes for each voxel in civm image, 8 bytes per voxel of complex output
% if saved, 4 bytes for save 32-bit mag, 4 bytes for save 32-bit phase
voxel_count=volumes*...
    data_buffer.input_headfile.dim_X*...
    data_buffer.input_headfile.dim_Y*...
    data_buffer.input_headfile.dim_Z;
required_free_space=voxel_count*bytes_per_pix_output;

%% disk usage checking
fprintf('Required disk space is %0.2fMB\n',required_free_space/1024/1024);
%%% get free space

[~,local_space_bytes] = unix(['df ',data_buffer.engine_constants.engine_work_directory,' | tail -1 | awk ''{print $4}'' ']);
local_space_bytes=512*str2double(local_space_bytes); %this converts to bytes because default blocksize=512 byte
%  required_free_space=npoints*ntraces*nblocks*10; %estimate we need at least 10 bytes per image point because we save an unscaled 32 bit and a 16 bit and compelx
fprintf('Available disk space is %0.2fMB\n',local_space_bytes/1024/1024)
if required_free_space<local_space_bytes|| opt_struct.ignore_errors
    fprintf('      .... Proceding with plenty of disk space\n');
else
    error('not enough free local disk space to reconstruct data, delete some files and try again');
end

clear local_space_bytes status required_free_space bytes_per_pix_output;


%% RAM usage checking and load_data parameter determination
display('Determining RAM requirements and chunk size');
data_prefix=data_buffer.input_headfile.(['U_' 'prefix']);
meminfo=imaqmem; %check available memory
copies_in_memory=3; % number of copies of each point required to do work.
%    (as we improve we should update this number)
% in theory,
% 1 copy to load,
% 1 copy for filter,
% 1 copy for output files
bytes_per_vox=8;    % number of bytes each voxel requires in memory.
% 4 for single precision, 8 for double, generally
% matlab requires single or double, and we cant
% calculate in short

binary_header_size   =data_buffer.input_headfile.binary_header_size; %distance to first data point in bytes
load_skip            =data_buffer.input_headfile.block_header_size;  %distance between blocks of rays in file
ray_blocks           =data_buffer.input_headfile.ray_blocks;         %number of blocks of rays total, sometimes nvolumes, sometimes nslices, somtimes nechoes, ntrs nalphas
rays_per_block       =data_buffer.input_headfile.rays_per_block;     %number or rays per in a block of input data,
ray_length           =data_buffer.input_headfile.ray_length;         %number of samples on a ray, or trajectory (this is doubled due to complex data being taken as real and imaginary discrete samples.)
% ne                   =data_buffer.input_headfile.ne;                 % number of echos.
channels             =data_buffer.input_headfile.([data_tag 'channels']); % number of channels.

ray_padding      =0;
% block_factors=factor(ray_blocks);

%%% calculate padding for bruker
if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    if strcmp(data_buffer.input_headfile.([data_prefix 'GS_info_dig_filling']),'Yes')|| ~ignore_errors  %PVM_EncZfRead=1 for fill, or 0 for no fill, generally we fill( THIS IS NOT WELL TESTED)
        %bruker data is usually padded out to a power of 2 or multiple of
        %3*2^6 940 is
        % there may be aminimum padding of som enumber?
        % have now seen with a 400x2channel acq padding of 96
        [F,~]=log2(channels*ray_length/(2^6*6));
        %[F,~]=log2(channels*ray_length/(2^5)); % when seeing 96, perhaps
        %this is the clue, padding is a multiple of 2^5th
        if mod(channels*ray_length,(2^6*6))>0&& F ~= 0.5
            ray_length2 = 2^ceil(log2(channels*ray_length));
            ray_length3 = ceil(((channels*(ray_length)))/(2^6*6))*2^6*6;
            %             [F,~]=log2(ray_length3);
            %             if ray_length3<ray_length2&&F==0.5
            %                 ray_length2=ray_length3;
            %             end
            ray_length2=min(ray_length2,ray_length3);
        else
            ray_length2=channels*ray_length;
        end
        ray_padding  =   ray_length2-channels*ray_length;
        ray_length   =   ray_length2;
        input_points = 2*ray_length*rays_per_block/channels*ray_blocks;
        % because ray_length is number of complex points have to doubled this.
        min_load_size=   ray_length*rays_per_block/channels*(in_bitdepth/8);
        % minimum amount of bytes of data we can load at a time,
        %         if mod(ray_length,(2^6*6))>0
        %             ray_length2 = 2^ceil(log2(ray_length));
        %             ray_length3 = ceil(ray_length/(2^6*6))*2^6*6;
        %             if ray_length3<ray_length2
        %                 ray_length2=ray_length3;
        %             end
        %         else
        %             ray_length2=ray_length;
        %         end
        %         ray_padding  =ray_length2-ray_length; % might want this to be divided by 2 depending on when we correct for this and throw it out.
        % %         acquired_ray_length=ray_length2;
        %         ray_length   =ray_length2;
        %         input_points = ray_length*rays_per_block*ray_blocks; % because ray_length is doubled, this is doubled too.
        %         min_load_size=ray_length*rays_per_block*(in_bitdepth/8);             % amount of data to load at a time, (should be single 2dft's worth of data)
    else
        error(['Found no pad option with bruker scan for the first time,' ...
            'Tell james let this continue in test mode']);
    end
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
    %TENC = 4
    %INTRLV = INTRLV
    %DISTANZA = 4
    %     if  strcmp(data_buffer.input_headfile.([data_prefix 'INTRLV']),'INTRLV')
    %
    %     end
    if strcmp(data_buffer.input_headfile.S_PSDname,'SE_')
        warning('Aspect SE_ detected!, setting ray_padding value=navigator_length! Does not use navigator data!');
        ray_length=ray_length+50;
        ray_padding=50;
        input_points = 2*ray_length*rays_per_block/channels*ray_blocks;
        % because ray_length is number of complex points have to doubled this.
        min_load_size= ray_length*rays_per_block/channels*(in_bitdepth/8);
        % minimum amount of bytes of data we can load at a time,
    end
else
    % not bruker, no ray padding...
    input_points = 2*ray_length*rays_per_block*ray_blocks;
    % because ray_length is doubled, this is doubled too.
    min_load_size=ray_length*rays_per_block*(in_bitdepth/8);
    % minimum amount of bytes of data we can load at a time,
end
total_memory_required= (input_points+voxel_count*copies_in_memory)*bytes_per_vox;
system_reserved_memory=2*1024*1024*1024;% reserve 2gb for the system while we work.

% handle ignore memory limit options
if opt_struct.skip_mem_checks==1;
    display('you have chosen to ignore this machine''s memory limits, this machine may crash');
    total_memory_required=1;
end

%%% set number of chunks and chunk size based on memory required and
%%% total memory available. if volume will fit in memory happily will
%%% evaluate to num_chunks=1
min_chunks=ceil(total_memory_required/(meminfo.TotalPhys-system_reserved_memory));
memory_space_required=(total_memory_required/min_chunks);
max_loadable_chunk_size=(input_points*(in_bitdepth/8))/min_chunks;
% worst case number of loads to get all data in memory. At the worst would be n rays, but we should avoid that at all

%%% use block_factors to find largest block size to find in
%%% max_loadable_chunk_size, and set c_dims
c_dims=[ data_buffer.input_headfile.dim_X,...
    data_buffer.input_headfile.dim_Y,...
    data_buffer.input_headfile.dim_Z];
warning('c_dims set poorly just to volume dimensions for now');

%%% first just try a purge to free enough space.
if meminfo.AvailPhys<memory_space_required
    system('purge');
end
%%% now prompt for program close and purge each time
while meminfo.AvailPhys<memory_space_required
    input('you have too many programs open.\n close some programs and then press enter >> ','s');
    system('purge');
end
%%% Load size calculation,
max_loads_per_chunk=max_loadable_chunk_size/min_load_size;
if floor(max_loads_per_chunk)<max_loads_per_chunk && ~opt_struct.ignore_errors
    error('un-even loads per chunk size, %f < %f have to do better job getting loading sizes',floor(max_loads_per_chunk),max_loads_per_chunk);
end
chunk_size=floor(max_loadable_chunk_size/min_load_size)*min_load_size;
% kspace_file_size=binary_header_size+(load_size+load_skip)*ray_blocks*volumes; % total ammount of data in data file.

kspace_header_bytes  =binary_header_size+load_skip*(ray_blocks-1);
if strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')
    kspace_header_bytes  =binary_header_size+load_skip*ray_blocks; %%% TEMPORARY HACK TO FIX ISSUES WITH AGILENT
end
% total bytes used in header into throught out the kspace data
kspace_data          =input_points*(in_bitdepth/8);
% total bytes used in data only(no header/meta info)
kspace_file_size     =kspace_header_bytes+kspace_data; % total ammount of data in data file.
num_chunks           =kspace_data/chunk_size;
if floor(num_chunks)<num_chunks
    warning('Number of chunks did not work out to integer, things may be wrong!');
end
if min_load_size>chunk_size && skip_mem_checks==false&& ~opt_struct.ignore_errors
    error('Oh noes! blocks of data too big to be handled in a single chunk, bailing out');
end
fileInfo = dir(data_buffer.input_headfile.kspace_data_path);
if isempty(fileInfo)
    error('puller did not get data, check pull cmd and scanner');
end
measured_filesize    =fileInfo.bytes;

if kspace_file_size~=measured_filesize
    if (measured_filesize>kspace_file_size && opt_struct.ignore_kspace_oversize) || opt_struct.ignore_errors % measured > expected provisional continue
        warning('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=  %d\nCalculated=%d\n',measured_filesize,kspace_file_size);
    else %if measured_filesize<kspace_file_size    %if measured < exected fail.
        error('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=%d\nCalculated=%d\n',measured_filesize,kspace_file_size);
    end
end
min_load_size=min_load_size/(in_bitdepth/8); % minimum_load_size in data samples.
chunk_size=   chunk_size/(in_bitdepth/8);    % chunk_size in data samples.
if num_chunks>1 && ~opt_struct.ignore_errors
    error('not tested with more than one chunk yet');
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
%     num_chunks=volumes;
%     max_blocks=blocks_per_vol;
%     if max_blocks*npoints*ntraces>memory_space_required
%         error('volume size is too large, consider closing programs and restarting')
%     end
% else %if its just one volume, see if we can do it all at once or need to do chunks
%     max_blocks=floor(memory_space_required/(ntraces*npoints)); %number of blocks we can work on at a time
%     num_chunks=ceil(nblocks/max_blocks);
% end
fprintf('    ... Proceding doing recon with %d chunk(s)\n',num_chunks);

clear ray_length2 ray_length3 fileInfo bytes_per_vox copies_in_memory in_bitdepth in_bytetype min_chunks system_reserved_memory total_memory_required memory_space_required meminfo measured_filesize kspace_file_size kspace_data kspace_header_bytes ;


%% collect gui info (or set testmode)
%check civm runno convention
% add loop while gui has not run successfully,
if ~regexp(data_buffer.headfile.U_runno,'^[A-Z][0-9]{5-6}.*')
    %~strcmp(runno(1),'S') && ~strcmp(runno(1),'N') || length(runno(2:end))~=5 || isnan(str2double(runno(2:end)))
    display('runno does not match CIVM convention, the recon will procede in testmode')
    opt_struct.testmode=1;
end
% if not testmode then create headfile
if  opt_struct.testmode==1
    display('this recon will not be archiveable, rerun same command with skip_recon to rewrite just the headfile using the gui settings.');
    data_buffer.engine_constants.engine_recongui_menu_path;
    [~, gui_dump]=system(['$GUI_APP ' ...
        ' ''' data_buffer.engine_constants.engine_constants_path ...
        ' ' data_buffer.engine_constants.engine_recongui_menu_path ...
        ' ' data_buffer.scanner_constants.scanner_tesla ...
        ' ' 'check' ...
        ' ''']);
    gui_info_lines=strtrim(strsplit(gui_dump,' '));
    gui_dump=strjoin(gui_info_lines,':::test\n');
else
    display('gathering gui info');
    display(' ');
    data_buffer.engine_constants.engine_recongui_menu_path;
    [~, gui_dump]=system(['$GUI_APP ' ...
        ' ''' data_buffer.engine_constants.engine_constants_path ...
        ' ' data_buffer.engine_constants.engine_recongui_menu_path ...
        ' ' data_buffer.scanner_constants.scanner_tesla ...
        ' ''']);
end

gui_info_lines=strtrim(strsplit(gui_dump,'\n'));
for l=1:length(gui_info_lines)
    guiinfo=strsplit(gui_info_lines{l},':::');
    if length(guiinfo)==2
        data_buffer.headfile.(['U_' guiinfo{1}])=guiinfo{2};
        fprintf('adding meta line %s=%s\n', ['U_' guiinfo{1}],data_buffer.headfile.(['U_' guiinfo{1}]));
    else
        fprintf('ignoring line %s\n',gui_info_lines{l});
    end
end
if isempty(gui_info_lines) && ~opt_struct.ignore_errors
    error('GUI did not return values!');
end
clear gui_info gui_dump gui_info_lines l;

%% fancy dimension settings before reconstruction
%%% this data get for dimensions is temporary, should be handled better in
%%% the future.
x=data_buffer.input_headfile.dim_X;
y=data_buffer.input_headfile.dim_Y;
z=data_buffer.input_headfile.dim_Z;
channels=data_buffer.input_headfile.([data_tag 'channels'] );
if isfield (data_buffer.input_headfile,[data_tag 'varying_parameter'])
    varying_parameter=data_buffer.input_headfile.([data_tag 'varying_parameter']);
else
    varying_parameter='';
end
if strcmp(varying_parameter,'echos')
    params=data_buffer.input_headfile.ne;
elseif strcmp(varying_parameter,'alpha')
    params=length(data_buffer.input_headfile.alpha_sequence);
elseif strcmp(varying_parameter,'tr')
    params=length(data_buffer.input_headfile.tr_sequence);
elseif regexpi(varying_parameter,',')
    error('MULTI VARYING PARAMETER ATTEMPTED:%s THIS HAS NOT BEEN DONE BEFORE.',varying_parameter);
else
    fprintf('No varying parameter\n');
    params=1;
end
timepoints=data_buffer.input_headfile.([data_tag 'volumes'])/channels/params;
% dont need rare factor here, its only used in the regrid section
% if  isfield (data_buffer.input_headfile,[data_tag 'rare_factor'])
%     r=data_buffer.input_headfile.([data_tag 'rare_factor']);
% else
%     r=1;
% end

d_struct=struct;
d_struct.x=x;
d_struct.y=y;
d_struct.z=z;
d_struct.c=channels;
d_struct.p=params;
d_struct.t=timepoints;
dim_order=data_buffer.input_headfile.([data_tag 'dimension_order' ]);

%strfind(opt_struct.output_order(1),dim_order)
permute_code=zeros(size(dim_order));
for char=1:length(dim_order)
    permute_code(char)=strfind(opt_struct.output_order,dim_order(char));
end

% this mess gets the input and output dimensions using char arrays as
% dynamic structure element names.
% given the structure s.x, s.y, s.z the dim_order='xzy' and
% outputorder='xyz'
% will set input to in=[x z y];
% and output to out=[x y z];
input_dimensions=[d_struct.(dim_order(1)) d_struct.(dim_order(2))...
    d_struct.(dim_order(3)) d_struct.(dim_order(4))...
    d_struct.(dim_order(5)) d_struct.(dim_order(6))];
output_dimensions=[d_struct.(opt_struct.output_order(1)) d_struct.(opt_struct.output_order(2))...
    d_struct.(opt_struct.output_order(3)) d_struct.(opt_struct.output_order(4))...
    d_struct.(opt_struct.output_order(5)) d_struct.(opt_struct.output_order(6))];
%% do work.
% for each chunk, load chunk, regrid, filter, fft, (save)
% save not implemented yet, requires a chunk stitch funtion as well.
% for now assuming we didnt chunk and saves after the fact.
%
for chunk_num=1:num_chunks
    if ~opt_struct.skip_load
        %%% LOAD
        chunks_to_load=[1];
        %load data with skips function, does not reshape, leave that to regridd
        %program.
        
        load_from_data_file(data_buffer, data_buffer.input_headfile.kspace_data_path, ....
            binary_header_size, min_load_size, load_skip, in_precision, chunk_size, ...
            num_chunks,chunks_to_load(chunk_num),...
            in_endian);
        
        if ray_padding>0  %remove extra elements in padded ray,
            % lenght of full ray is spatial_dim1*nchannels+pad
            %         reps=ray_length;
            % account for number of channels and echos here as well .
            if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
                % padd beginning code
                logm=zeros((ray_length-ray_padding)/channels,1);
                logm(ray_length-ray_padding+1:ray_length)=1;
                %             logm=logical(repmat( logm, length(data_buffer.data)/(ray_length),1) );
                %             data_buffer.data(logm)=[];
            elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
                % pad ending code
                logm=ones((ray_padding),1);
                logm(ray_length-ray_padding+1:ray_length)=0;
            else
            end
            logm=logical(repmat( logm, length(data_buffer.data)/(ray_length),1) );
            data_buffer.data(logm)=[];
            warning('padding correction applied, hopefully correctly.');
            % could put sanity check that we are now the number of data points
            % expected given datasamples, so that would be
            % (ray_legth-ray_padding)*rays_per_blocks*blocks_per_chunk
            % NOTE: blocks_per_chunk is same as blocks_per_volume with small data,
            if numel(data_buffer.data) ~= (ray_length-ray_padding)/channels*rays_per_block*ray_blocks && ~opt_struct.ignore_errors
                error('Ray_padding reversal went awrry. Data length should be %d, but is %d',(ray_length-ray_padding)/channels*rays_per_block*ray_blocks,numel(data_buffer.data));
            else
                fprintf('Data padding retains corrent number of elements, continuing...\n');
            end
        end
        
        %%% pre regrid data save.
        %     if opt_struct.display_kspace==true
        %         input_kspace=reshape(data_buffer.data,input_dimensions);
        %     end
        %% REGRID  just simple reshape for cartesian
        if ~opt_struct.skip_regrid
            rad_regid(data_buffer,c_dims);
        else
            data_buffer.data=reshape(data_buffer.data,input_dimensions);
        end
        if opt_struct.do_aspect_freq_correct && strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
            fprintf('Performing aspect frequency correction\n');
            aspect_freq_correct(data_buffer,opt_struct);
            %         data_buffer.data=permute(data_buffer.data,[ 1 3 2 ]);
        elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
            %fprintf('Performing aspect frequency correction');
            %         data_buffer.data=permute(data_buffer.data,[ 1 3 2 ]);
        end
        if opt_struct.remove_slice
            fprintf('Slice removal occured, updateing zdim %f to %f,',z,z-1);
            z=z-1;
            data_buffer.headfile.dim_Z=z;
            data_buffer.input_headfile.dim_Z=z;
        end
        if isfield(data_buffer.headfile,'echo_asymmetry')
            if data_buffer.headfile.echo_asymmetry>0
                if z>1
                    warning('asymmetry not tested with multi-slice');
                end
                % move data down the x, then add some x back...
                % ex for 128x128 image.
                % ak(33:128,:)=ak(1:128-32,:);
                % ak(1:32,:)=ak(128:-1:128-31,:);
                asym_offset=x*data_buffer.headfile.echo_asymmetry/2;
                % perhaps a full mirror option would be good?
                se_inputtrash=4;
                data_buffer.data(asym_offset+1+se_inputtrash:x,:)=data_buffer.data(1:x-asym_offset-se_inputtrash,:);
                if opt_struct.asymmetry_mirror
                    se_inputtrash=ceil(asym_offset*0.85)-se_inputtrash; %adding just a little more cut off with the asymmetry copy.
                end
                data_buffer.data(1:asym_offset+1+se_inputtrash,:)=data_buffer.data(x:-1:x-asym_offset-se_inputtrash,:);
                warning('asymmetry support very experimental! CHECK YOUR OUTPUTS!');
                pause(8);
                
                
                %do asym stuff...
            end
        else
            disp('No asymmetry handling');
        end
        %% display kspace
        if opt_struct.display_kspace==true
            %         kslice=zeros(size(data_buffer.data,1),size(data_buffer.data,2)*2);
            %         kslice=zeros(x,y);
            s.x=':';
            s.y=':';
            for tn=1:timepoints
                s.t=tn;
                for zn=1:z
                    s.z=zn;
                    for cn=1:channels
                        s.c=cn;
                        for pn=1:params
                            s.p=pn;
                            fprintf('z:%d c:%d p:%d\n',zn,cn,pn);
                            if opt_struct.skip_regrid
                                kslice=data_buffer.data(s.(dim_order(1)),s.(dim_order(2)),...
                                    s.(dim_order(3)),s.(dim_order(4)),...
                                    s.(dim_order(5)),s.(dim_order(6)));
                            else
                                kslice=data_buffer.data(...
                                    s.(opt_struct.output_order(1)),...
                                    s.(opt_struct.output_order(2)),...
                                    s.(opt_struct.output_order(3)),...
                                    s.(opt_struct.output_order(4)),...
                                    s.(opt_struct.output_order(5)),...
                                    s.(opt_struct.output_order(6)));
                            end
                            %kslice(1:size(data_buffer.data,1),size(data_buffer.data,2)+1:size(data_buffer.data,2)*2)=input_kspace(:,cn,pn,zn,:,tn);
                            imagesc(log(abs(squeeze(kslice))));
                            %                             fprintf('.');
                            pause(4/z/channels/params);
                            %                         pause(1);
                            %                         imagesc(log(abs(squeeze(input_kspace(:,cn,pn,zn,:,tn)))));
                            %                             fprintf('.');
                            %                         pause(4/z/channels/params);
                            %                         pause(1);
                        end
                        fprintf('\n');
                    end
                end
            end
        end
        %% preserve original kspace
        if opt_struct.write_kimage_unfiltered
            data_buffer.addprop('data_pristine');
            data_buffer.data_pristine=data_buffer.data;
        end
        %% filter kspaces data
        if ~opt_struct.skip_filter
            fprintf('Performing fermi filter on volume with size %s\n',num2str(output_dimensions));
            if strcmp(vol_type,'2D')
                data_buffer.data=reshape(data_buffer.data,[ output_dimensions(1:2) prod(output_dimensions(3:end))] );
                data_buffer.data=fermi_filter_isodim2(data_buffer.data,'','',true);
                data_buffer.data=reshape(data_buffer.data,output_dimensions );
            elseif strcmp(vol_type,'3D')
                %             fermi_filter_isodim2_memfix_obj(data_buffer);
                data_buffer.data=fermi_filter_isodim2(data_buffer.data,'','',false);
            else
                warning('DID NOT PERFORM FILTER');
            end
            %
        else
            fprintf('skipping fermi filter\n');
        end
        %% fft
        if ~opt_struct.skip_recon
            fprintf('Performing FFT\n');
            if strcmp(vol_type,'2D')
                if ~exist('img','var') || numel(img)==1;
                    img=zeros(output_dimensions);
                end
                %         xyzcpt
                s.z=':';
                s.x=':';
                s.y=':';
                for cn=1:channels
                    s.c=cn;
                    if opt_struct.debug_mode>=10
                        fprintf('channel %d working...\n',cn);
                    end
                    for tn=1:timepoints
                        s.t=tn;
                        for pn=1:params
                            s.p=pn;
                            if opt_struct.debug_mode>=20
                                fprintf('p%d ',pn);
                            end
                            %                     kvol=data_buffer.data(...
                            %                         s.(opt_struct.output_order(1)),...
                            %                         s.(opt_struct.output_order(2)),...
                            %                         s.(opt_struct.output_order(3)),...
                            %                         s.(opt_struct.output_order(4)),...
                            %                         s.(opt_struct.output_order(5)),...
                            %                         s.(opt_struct.output_order(6)));
                            %   data_buffer.data(:,:,:,cn,pn,tn)=fermi_filter_isodim2(data_buffer.data(:,:,:,cn,pn,tn),'','',true);
                            img(...
                                s.(opt_struct.output_order(1)),...
                                s.(opt_struct.output_order(2)),...
                                s.(opt_struct.output_order(3)),...
                                s.(opt_struct.output_order(4)),...
                                s.(opt_struct.output_order(5)),...
                                s.(opt_struct.output_order(6)))=fftshift(ifft2(fftshift(data_buffer.data(...
                                s.(opt_struct.output_order(1)),...
                                s.(opt_struct.output_order(2)),...
                                s.(opt_struct.output_order(3)),...
                                s.(opt_struct.output_order(4)),...
                                s.(opt_struct.output_order(5)),...
                                s.(opt_struct.output_order(6))))));
                            if opt_struct.debug_mode>=20
                                fprintf('\n');
                            end
                        end
                    end
                end
            else
                img=fftshift(ifftn(data_buffer.data));
            end
            
            %% resort images flip etc
            if strcmp(vol_type,'3D') && ~opt_struct.skip_resort
                %%% decide how and if a resort should be done.
                if strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
                    
                    warning('90degree rotation and resort all aspect images occurs now')
                    pause(opt_struct.warning_pause);
                    %             fprintf('permuting...');
                    %             img=permute(img,[ 1 3 2 ]);
                    fprintf('resorting along z...');
                    objlist=[z/2+1:z 1:z/2 ];
                    %img=circshift(img,[ 0 y/2 0 ]);
                    img(:,:,objlist)=img;
                    fprintf('rotating image by 90...');
                    img=imrotate(img,90);
                    %img=transpose(img());
                    fprintf('resort and rotate done!\n');
                else
                    fprintf('Non-aspect data is not rotated or flipped, unsure what settings should be used');
                    %imagejmacro commands for drawing centerline.
                    %in a bruker volume of 160,240,108
                    % makeLine(80, 26, 80, 206);
                    %in civmmatrecon volume from 240,160,108
                    % run("Rotate by 90 degrees right");
                    % run("Flip Horizontally", "stack");
                    % makeLine(89, 21, 89, 215);
                    % gives aproximately 9voxel shift.... so we'd circshift by 9,
                    % then what?
                    
                end
            else
                if strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
                    %             z=size(it,3);
                    % for SE_ scans these values have been true 1 time(s)
                    if z>1 && mod(z,2) == 0
                        objlist=[1:z/2;z/2+1:z];
                        objlist=objlist(:);
                        img=img(:,:,objlist);
                    end
                    %             for i=1:64
                    %                 figure(6);
                    %                 imagesc(log(abs(it(:,:,i))));
                    %                 pause(0.18);
                    %             end
                    %             y=size(it,2);
                    objlist=[y/2+1:y 1:y/2];
                    img=img(:,objlist,:);
                    %             for i=1:64
                    %                 figure(6);
                    %                 imagesc(log(abs(it2(:,:,i))));
                    %                 pause(0.18);
                    %             end
                end
            end
            if opt_struct.display_output==true
                s.x=':';
                s.y=':';
                for zn=1:z
                    s.z=zn;
                    for tn=1:timepoints
                        s.t=tn;
                        for pn=1:params
                            s.p=pn;
                            for cn=1:channels
                                s.c=cn;
                                imagesc(log(abs(squeeze(img(...
                                    s.(opt_struct.output_order(1)),...
                                    s.(opt_struct.output_order(2)),...
                                    s.(opt_struct.output_order(3)),...
                                    s.(opt_struct.output_order(4)),...
                                    s.(opt_struct.output_order(5)),...
                                    s.(opt_struct.output_order(6))...
                                    )))));
                                pause(4/z/channels/params);
                                
                            end
                        end
                        fprintf('%d %d\n',zn,tn);
                    end
                end
            end
            combine_image='DID NOT COMBINE';
            if ~opt_struct.skip_combine_channels && channels>1
                % To respect the output order we use strfind.
                fprintf('combining channel complex data with method %s\n',opt_struct.combine_method);
                dind=strfind(opt_struct.output_order,'c'); % get dimension index for channels
                if regexpi(opt_struct.combine_method,'mean')
                    combine_image=squeeze(mean(abs(img),dind));
                elseif regexpi(opt_struct.combine_method,'square_and_sum')
                    combine_image=squeeze(mean(img.^2,dind));
                else
                    %%% did not combine
                end
            end
            %     error('Code very unfinished, just meta data and setup done now.');
            % foreach interleave ( separate out interleaved acquistions to recon one at a time)
            %     for interleave_num=1:n_interleaves
            %         % we're cartesean for now  so no regrid
            %         % regrid(data_buffer.data,regrid_method);
            %         filter(data_buffer,interleave_num);
            %         fft(data_buffer,interleave_num);
            %         savedata(data_buffer,interleave_num,outloc);
            %     end
        else
            img='RECON_DISABLED';
            if opt_struct.remove_slice
                z=z-1;
                data_buffer.headfile.dim_Z=z;
                data_buffer.input_headfile.dim_Z=z;
            end
        end
    end % end foreachchunk
    
    warning('this saving code is temporary it is not designed for chunnks');
    %% save data
    % this needs a bunch of work, for now it is just assuming the whole pile of
    % data is sitting in memory awaiting saving, does not handle chunks or
    % anything correctly just now.
    
    %  mag=abs(raw_data(i).data);
    ij_prompt='';
    archive_prompts='';
    if opt_struct.skip_combine_channels
        channel_images=channels;
    else
        channel_images=1;
    end
    runnumbers=cell(channel_images*params*timepoints,1);
    rindx=1;
    if (opt_struct.fp32_magnitude==true)
        datatype='fp32';
    else
        datatype='raw';
    end
    data_buffer.headfile.F_imgformat=datatype;
    if opt_struct.write_output
        work_dir_img_path_base=[ work_dir_path '/' data_buffer.headfile.U_runno ] ;
        %%% save n-D combined nii.
        if ~opt_struct.skip_combine_channels && channels>1 && ~opt_struct.skip_recon && opt_struct.write_unscaled
            if ~exist([work_dir_img_path_base '.nii'],'file') || opt_struct.overwrite
                fprintf('Saving image combined with method:%s using %i channels to output work dir.\n',opt_struct.combine_method,channels);
                nii=make_nii(abs(combine_image), [ ...
                    data_buffer.headfile.fovx/data_buffer.headfile.dim_X ...
                    data_buffer.headfile.fovy/data_buffer.headfile.dim_Y ...
                    data_buffer.headfile.fovz/data_buffer.headfile.dim_Z]); % insert fov settings here ffs....
                save_nii(nii,[work_dir_img_path_base '.nii']);
            else
                warning('Combined Image already exists and overwrite disabled');
            end
        end
        
        max_mnumber=timepoints*params;
        m_length=length(num2str(max_mnumber));
        if ~opt_struct.skip_combine_channels
            data_buffer.headfile.([data_tag 'volumes'])=data_buffer.headfile.([data_tag 'volumes'])/channels;
            channels=1;
        end
        
        openmacro_path=sprintf('%s%s',work_dir_img_path_base ,'.ijm');
        if opt_struct.overwrite && exist(openmacro_path,'file')
            delete(openmacro_path);
        else
            warning('macro exists at:%s\n did you mean to enable overwrite?',openmacro_path);
        end
        %     end
        %        for tn=1:timepoints
        %         for cn=1:channels
        %             for pn=1:params
        openmacro_lines=strcat(...
            'channels=',num2str(channels),';\n' , ...
            'channels=1;\n',...
            'frames=', num2str(timepoints),';\n', ...
            'slices=', num2str(z),';\n', ...
            'volumes=', num2str(1),';\n', ...
            'runno="', data_buffer.headfile.U_runno, '"',';\n', ...
            'runno_dir="', data_buffer.engine_constants.engine_work_directory, '/"+runno+""',';\n', ...
            'open_all_output="open";\n',...
            'if(slices==1){ open_all_output=""; }\n',...
            'sub_start=1',';\n', ...
            'sub_stop=sub_start+slices-1;\n', ...
            'for(framenum=1;framenum<=frames;framenum++) {\n', ...
            '    for(channelnum=1;channelnum<=channels;channelnum++) {\n', ...
            '        volumenum=(framenum-1)*channels+channelnum;\n', ...
            '        if (volumes > 1) {\n', ...
            '            num=d2s(volumenum,0);\n', ...
            '            digits=lengthOf(d2s(volumes,0));\n', ...
            '            while(lengthOf(num)<digits && lengthOf(num) < 4 ) {\n', ...
            '               num="0"+num;\n', ...
            '            }\n', ...
            '            multi_suffix="_m"+num;\n', ...
            '        } else {\n', ...
            '          multi_suffix="";\n', ...
            '        }\n',...
            '\n', ...
            '        out_runno=""+runno+multi_suffix;\n', ...
            '        output_dir=""+runno_dir+multi_suffix+"/"+out_runno+"images";\n', ...
            '\n', ...
            '        if ( !File.isDirectory(output_dir) ) {\n', ...
            '            print("  Imagej: making directory"+output_dir);\n', ...
            '            dirparts=split(output_dir,"/");\n', ...
            '            current="";\n', ...
            '            for (part=0;part<dirparts.length;part++) { \n', ...
            '                current=current+"/"+dirparts[part];\n', ...
            '                if (!File.isDirectory(current) ) {\n', ...
            '                    File.makeDirectory(current);\n', ...
            '                }\n', ...
            '            }\n', ...
            '         }\n',...
            '\n', ...
            '        if ( volumes < ', num2str(opt_struct.open_volume_limit), ' ) { \n', ...
            '            run("Raw...", "open="+output_dir+"/"+out_runno+"',...
            data_buffer.scanner_constants.scanner_tesla_image_code,...
            'imx.0001.raw image=[16-bit Unsigned] width=',...
            num2str(x),' height=',num2str(y),...
            ' offset=0 number="+slices+" gap=0 "+open_all_output+"");\n', ...
            '        }  else if ( volumenum == 1 ) {\n', ...
            '            run("Raw...", "open="+output_dir+"/"+out_runno+"',...
            data_buffer.scanner_constants.scanner_tesla_image_code,...
            'imx.0001.raw image=[16-bit Unsigned] width=', num2str(x),...
            ' height=', num2str(y),' offset=0 number="+slices+" gap=0 "+open_all_output+"");\n', ...
            '        } else  if ( volumenum == channels*frames) {\n', ...
            '            run("Raw...", "open="+output_dir+"/"+out_runno+"',...
            data_buffer.scanner_constants.scanner_tesla_image_code,...
            'imx.0001.raw image=[16-bit Unsigned] width=', num2str(x),...
            ' height=', num2str(y),' offset=0 number="+slices+" gap=0 "+open_all_output+"");\n', ...
            '        }\n', ...
            '    }\n', ...
            '}\n', ...
            'run("Tile");\n', ...
            '\n');
        mfid=fopen(openmacro_path,'w');
        fprintf(mfid,openmacro_lines);
        fclose(mfid);
        clear mfid openmacro_lines;
        s.x=':';
        s.y=':';
        s.z=':';
        for tn=1:timepoints
            s.t=tn;
            for cn=1:channels
                s.c=cn;
                for pn=1:params
                    s.p=pn;
                    if ~opt_struct.skip_recon
                        if ~opt_struct.skip_combine_channels  && ~ ischar(combine_image);% && channels>1
                            tmp=squeeze(combine_image(...
                                s.(opt_struct.output_order(1)),...
                                s.(opt_struct.output_order(2)),...
                                s.(opt_struct.output_order(3)),...
                                s.(opt_struct.output_order(4)),...
                                s.(opt_struct.output_order(5)),...
                                s.(opt_struct.output_order(6))...
                                ));
                        else
                            tmp=squeeze(img(...
                                s.(opt_struct.output_order(1)),...
                                s.(opt_struct.output_order(2)),...
                                s.(opt_struct.output_order(3)),...
                                s.(opt_struct.output_order(4)),...
                                s.(opt_struct.output_order(5)),...
                                s.(opt_struct.output_order(6))...
                                ));% pulls out one volume at a time.
                        end
                    else
                        tmp=img;
                    end
                    fprintf('Extracting image channel:%0.0f param:%0.0f timepoint:%0.0f\n',cn,pn,tn);
                    %%%set channel and mnumber codes for the filename
                    if channels>1
                        channel_code=opt_struct.channel_alias(cn);
                    else
                        channel_code='';
                    end
                    m_number=(tn-1)*params+pn;
                    if timepoints> 1 || params >1
                        m_code=sprintf(['_m%0' num2str(m_length) '.0f'], m_number);
                    else
                        m_code='';
                    end
                    space_dir_img_name =[ data_buffer.headfile.U_runno channel_code m_code];
                    space_dir_img_folder=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '/' space_dir_img_name 'images' ];
                    work_dir_img_path=[work_dir_img_path_base channel_code m_code];
                    %%% complex save
                    if opt_struct.write_complex && ~opt_struct.skip_recon
                        fprintf('\twrite_complex (radish_format) save\n');
                        save_complex(tmp,[ work_dir_img_path '.rp.out']);
                    end
                    %%% kimage_
                    if opt_struct.write_kimage && ~opt_struct.skip_filter && ~opt_struct.skip_load
                        fprintf('\tradish_magnitude kimage save\n');
                        nii=make_nii(log(abs(data_buffer.data)));
                        save_nii(nii,[work_dir_img_path '_kspace.nii']);
                    end
                    %%% kimage_unfiltered
                    if opt_struct.write_kimage_unfiltered  && ~opt_struct.skip_load
                        fprintf('\twrite_kimage_unfiltered save\n');
                        nii=make_nii(log(abs(data_buffer.data_pristine)));
                        save_nii(nii,[work_dir_img_path '_kspace_unfiltered.nii']);
                    end
                    %%% nii_save
                    if ( opt_struct.write_unscaled && ~opt_struct.skip_recon ) %|| opt_struct.skip_write_civm_raw
                        fprintf('\twrite_unscaled save\n');
                        nii=make_nii(abs(tmp), [ ...
                            data_buffer.headfile.fovx/data_buffer.headfile.dim_X ...
                            data_buffer.headfile.fovy/data_buffer.headfile.dim_Y ...
                            data_buffer.headfile.fovz/data_buffer.headfile.dim_Z]); % insert fov settings here ffs....
                        save_nii(nii,[work_dir_img_path '.nii']);
                    end
                    %%% civmraw save
                    if ~exist(space_dir_img_folder,'dir') || opt_struct.ignore_errors
                        mkdir(space_dir_img_folder);
                    elseif ~opt_struct.overwrite
                        % the folder existed, however we were not set for
                        % overwrite
                        error('Output directory existed! NOT OVERWRITING SOMEONE ELSES DATA UNLESS YOU TELL ME!, use overwrite option.');
                    end
                    %%% set param value in output
                    % if te
                    if isfield(data_buffer.headfile,'te_sequence')
                        data_buffer.headfile.te=data_buffer.headfile.te_sequence(pn);
                    end
                    % if tr
                    if isfield(data_buffer.headfile,'tr_sequence')
                        data_buffer.headfile.tr=data_buffer.headfile.tr_sequence(pn);
                    end
                    % if alpha
                    if isfield(data_buffer.headfile,'alpha_sequence')
                        data_buffer.heafdile.alpha=data_buffer.headfile.alpha_sequence(pn);
                    end
                    
                    if ~opt_struct.skip_write_headfile
                        fprintf('\tHeadfile save\n');
                        write_headfile([space_dir_img_folder '/' space_dir_img_name '.headfile'],data_buffer.headfile);
                        % insert validate_header perl script check here?
                    end
                    
                    if ~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon
                        fprintf('\tcivm_raw save\n');
                        complex_to_civmraw(tmp,[ data_buffer.headfile.U_runno channel_code], ...
                            data_buffer.scanner_constants.scanner_tesla_image_code, ...
                            space_dir_img_folder,'auto','',1,datatype)
                        % must write convert_info_histo for old school radish purposesx
                        histo_percent=99.95;
                        histo_bins=numel(tmp);
                        img_s=sort(abs(tmp(:)));
                        maxin=max(img_s);
                        s_max_intensity=img_s(round(length(img_s)*histo_percent/100));%throwaway highest % of data... see if that helps.
                        
                        outpath=[space_dir_img_folder '/convert_info_histo'];
                        % display(['Saving vintage threeft to ' outpath '.']);
                        ofid=fopen(outpath,'w+');
                        if ofid==-1
                            error('problem opening convert_info_hist file for writing file');
                        end
                        fprintf(ofid,'%f=scale_max found by agilent_scale_histo in complex file %s\n',s_max_intensity,[work_dir_img_path '.out']);
                        fprintf(ofid,'%i %i : image dimensions.\n',data_buffer.headfile.dim_X,data_buffer.headfile.dim_Y);
                        fprintf(ofid,'%i : image set zdim.\n', data_buffer.headfile.dim_Z);
                        fprintf(ofid,'%i : hito_bins, %f : histo_percent\n',histo_bins,histo_percent);
                        fprintf(ofid,'x : user provided max voxel value? pfovided for max= none (if file used).\n');
                        fprintf(ofid,'%f : max voxel value used to construct histogram\n',maxin);
                        fprintf(ofid,' agilent_scale_histo ma script 2012/11/28\n');
                        fclose(ofid);
                        
                    end
                    %%% convenience prompts
                    
                    if ~opt_struct.skip_recon||opt_struct.force_ij_prompt
                        % display ij call to examine images.
                        [~,txt]=system('echo -n $ijstart');  %-n for no newline i think there is a smarter way to get system variables but this works for now.
                        ij_prompt=sprintf('\n\n%s -macro %s\n\n\n',txt, openmacro_path);
                    end
                    if ~opt_struct.skip_write_civm_raw
                        %write_archive_tag(runno,spacename, slices, projectcode, img_format,civmid)
                        runnumbers(rindx)={[data_buffer.headfile.U_runno channel_code m_code]};
                        rindx=rindx+1;
                        
                    end
                    
                end
            end
        end
    end
    if ~isempty(ij_prompt)&& ~opt_struct.skip_write_civm_raw
        fprintf('test image output from a terminal using following command (it may only open the first and last in lage sequences).\n');
        fprintf(ij_prompt);
    end
    if ~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon
        archive_prompts=sprintf('%s%s',archive_prompts,...
            write_archive_tag(runnumbers,...
            data_buffer.engine_constants.engine_work_directory,...
            z,data_buffer.headfile.U_code,datatype,...
            data_buffer.headfile.U_civmid,false));
        fprintf('initiate archive from a terminal using, (should change person to yourself). \n\n');
        fprintf(archive_prompts);
    end
    
    
    
end
