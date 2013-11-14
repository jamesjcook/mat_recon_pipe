function [img, success_status]=rad_mat(scanner,runno,input_data,options)
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
%            Can use * to guess any portion of the string except for
%            director boundaries.
%          - for agilent 20120101_01/ser01.fid
%            with wild card 20120101*/ser01.fid
%          - for aspect  '004534', by convention asepect runnumbers are
%          aspect id+6000
%          - for bruker   {'patientid','scanid'} or 'patientid/scanid'
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
% scaling fix/verify
% testing
% param file support
% testing
% agilent support
% testing
% arbitrary headfile variables through options cellarray
% testing
% load arbitrary headfile for overriding
% testing
% fix up regridding to be a  meaninful step other than reshape very
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
success_status=false;
data_buffer=large_array;
data_buffer.addprop('data');
data_buffer.addprop('scanner_constants');
data_buffer.addprop('engine_constants');
data_buffer.addprop('headfile');     % ouput headfile to dump or partial output for multi sets.
data_buffer.addprop('input_headfile'); % scanner input headfile
data_buffer.headfile=struct;

%% put some input into the headfile
data_buffer.headfile.B_recon_type='rad_mat'; % warning, can only be 16 chars long.
data_buffer.headfile.U_runno=runno;
data_buffer.headfile.comment={'# Rad_Mat Matlab recon'};
data_buffer.headfile.comment{end+1}=['# Reconstruction start time ' datestr(now,'yyyy-mm-dd HH:MM:SS')];
% version=  ''; % get version from v file name on disk

%% option and function argument handling
if ~iscell(input_data)
    input_data={input_data};
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
    'existing_data',          ' use data from system(as if puller had already run), puller will not run at all.'
    'skip_mem_checks',        ' do not test if we have enough memory'
    'filter_width',           ' width for fermi filter'
    'filter_window',          ' window for fermi filter'
    'testmode',               ' skip GUI and just put dummy info in GUI fields, will not be archiveable'
    'skip_write',             ' do not save anything to disk. good for running inside matlab and continuing in another function'
    'skip_write_civm_raw',    ' do not save civm raw files.'
    'skip_write_headfile',    ' do not write civm headfile output'
    'write_unscaled',         ' save unscaled nifti''s in the work directory '
    'write_unscaled_nD',      ' save unscaled multi-dimensional nifti in the work directory '
    'display_kspace',         ' display re-gridded kspace data prior to reconstruction, will showcase errors in regrid and load functions'
    'display_output',         ' display reconstructed image after the resort and transform operations'
    '',                       ''
    };
beta_options={
    '',                       'Secondary, new, experimental options'
    'planned_ok',             ' special option which must be early in list of options, controls whether planned options are an error'
    'unrecognized_ok',        ' special option which must be early in list of options, controls whether arbitrary options are an error, this is so that alternate child functions could be passed the opt_struct variable and would work from there. This is also the key to inserting values into the headfile to override what our perlscript generates. '
    'debug_mode',             ' verbosity. use debug_mode=##'
    'study',                  ' set the bruker study to pull from, useful if puller fails to find the correct data'
    'U_dimension_order',      ' input_dimension_order will override whatever the perl script comes up with.'
    'vol_type_override',      ' if the processing script fails to guess the proper acquisition type(2D|3D) it can be specified.'
    'kspace_shift',           ' x:y:z shift of kspace, use kspace_shift=##:##:##' 
    'ignore_kspace_oversize', ' when we do our sanity checks on input data ignore kspace file being bigger than expected, this currently must be on for aspect data'
    'output_order',           ' specify the order of your output dimensions. Default is xyzcpt. use output_oder=xyzcpt.'
    'channel_alias',          ' list of values for aliasing channels to letters, could be anything using this'
    'combine_method',         ' specify the method used for combining multi-channel data. supported modes are square_and_sum, or mean, use  combine_method=text'
    'skip_combine_channels',  ' do not combine the channel images'
    'write_complex',          ' should the complex output be written to th work directory. Will be written as rp(or near rp file) format.'
    'do_aspect_freq_correct', ' perform aspect frequency correction.'
    'skip_load'               ' do not load data, implies skip regrid, skip filter, skip recon and skip resort'
    'skip_regrid',            ' do not regrid'
    'skip_filter',            ' do not filter data sets.'
    'skip_recon',             ' for re-writing headfiles only, implies skip filter, and existing_data'
    'skip_resort',            ' for 3D acquisitions we resort after fft, this alows that to be skiped'
    'force_ij_prompt',        ' force ij prompt on, it is normally ignored with skip_recon'
    'remove_slice',           ' removes a slice of the acquisition at the end, this is a hack for some acquisition types'
    'dcf_by_key',             ' calculate dcf by the key in acq'
    'open_volume_limit',      ' override the maximum number of volumes imagej will open at a time,default is 36. use open_volume_limit=##'
    'warning_pause',          ' length of pause after warnings (default 3). Errors outside matlab from the perl parsers are not effected. use warning_pause=##'
    '',                       ''
    };
planned_options={
    '',                       'Options we may want in the future, they might have been started. They could even be finished and very unpolished. '
    'write_phase',            ' write a phase output to the work directory'
    'fp32_magnitude',         ' write fp32 civm raws instead of the normal ones'
    'write_kimage',           ' write the regridded and filtered kspace data to the work directory.'
    'write_kimage_unfiltered',' write the regridded unfiltered   kspace data to the work direcotry.'
    'ignore_errors',          ' will try to continue regarless of any error'
    'asymmetry_mirror',       ' with echo asymmetry tries to copy 85% of echo trail to leading echo side.'
    'independent_scaling',    ' scale output images independently'
%     'allow_headfile_override' ' Allow arbitrary options to be passed which will overwrite headfile values once the headfile is created/loaded'
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
% [... % just a lookup of letters to assign to channel data, we'll reserve _m numbers for acquisition params other than channels, eg. time, te, tr alpha, gradients
%     'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' ...
%     'n' 'o' 'p' 'q' 'r' 's' 't' 'u' 'v' 'w' 'x' 'y' 'z' ];
opt_struct.warning_pause=3;
opt_struct.ignore_errors=false;
opt_struct.kspace_shift='0:0:0';
opt_struct.histo_percent=99.95;
opt_struct.puller_option_string='';
opt_struct.unrecognized_fields={};% place to put all the names of unrecognized options we recieved. They're assumed to all be headfile values. 
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
            opt_struct.unrecognized_fields{end+1}=option;
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
        fprintf('%24s - %60s\n',all_options{o_num,1},all_options{o_num,2});
    end
    error('help display stop.');
end
if opt_struct.skip_recon
    opt_struct.skip_write_civm_raw=true;
    opt_struct.write_complex=false;
    opt_struct.fp32magnitude=false;
    opt_struct.write_phase=false;
    if opt_struct.skip_write_civm_raw && ~opt_struct.write_complex && ~opt_struct.write_kimage && ~opt_struct.write_kimage_unfiltered
        opt_struct.skip_load=true;
    end
end

if isnumeric(opt_struct.kspace_shift)
    opt_struct.kspace_shift=num2str(opt_struct.kspace_shift);
end
if regexp(opt_struct.kspace_shift,'[-]?[0-9]+(:[-]?[0-9]+){0,2}')
    temp=strsplit(opt_struct.kspace_shift,':');
    opt_struct=rmfield(opt_struct,'kspace_shift');
    opt_struct.kspace_shift=zeros(1,3);
    for ks=1:length(temp)
        opt_struct.kspace_shift(ks)=str2double(temp{ks});
    end
else
    kspace_shift_string='kspace_shift params incorrect. Must be comma separated list of integers, with at most 3 elements.';
    if ~opt_struct.ignore_errors
        error(kspace_shift_string);
    else
        warning(kspace_shift_string);
    end
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
            warning('missing dimension %s, appending to end of list',possible_dimensions(char));
            opt_struct.U_dimension_order=sprintf('%s%s',opt_struct.U_dimension_order,possible_dimensions(char));
        end
    end
end
if opt_struct.overwrite
    opt_struct.puller_option_string=[' -o ' opt_struct.puller_option_string];
end
if opt_struct.existing_data %||opt_struct.skip_recon
    opt_struct.puller_option_string=[' -e ' opt_struct.puller_option_string];
end
clear possible_dimensions warn_string err_string char ks e o_num parts all_options beta_options beta_options_string planned_options planned_options_string standard_options standard_options_string temp test value w

tic
%% dependency loading
data_buffer.scanner_constants=load_scanner_dependency(scanner);
data_buffer.engine_constants=load_engine_dependency();
data_buffer.headfile.matlab_functioncall=['rad_mat('''  scanner ''', ''' data_buffer.headfile.U_runno ''', {''' strjoin(input_data,''', ''') '''} ' ', {''' strjoin(options,''', ''') '''})'];
data_buffer.headfile.comment{end+1}='# \/ Matlab function call \/';
fprintf('Recon started with matlab command\n\t%s\n',data_buffer.headfile.matlab_functioncall);
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
    if ~regexpi(input_data{end},'fid')
        % if ! endswith fid, add fid
        dirext='.fid';
    else
        dirext='';
    end
else
    dirext='';
end
if numel(input_data)==1
    input_data= strsplit(input_data{1},'/');
end
if numel(input_data)==2 && strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    input_data{1}=[input_data{1} '*'];
    if opt_struct.study~=0
        if isnumeric(opt_struct.study)
            opt_struct.study=num2str(opt_struct.study);
        end
        opt_struct.puller_option_string=sprintf('%s -s %s',opt_struct.puller_option_string,opt_struct.study);
    end
end %else
puller_data=[strjoin(input_data, '/'), dirext];
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
if ~opt_struct.existing_data  %&&~opt_struct.skip_recon
    s =system(cmd);
    if s ~= 0 && ~opt_struct.ignore_errors
        error('puller failed:%s',cmd);
    end
end
clear cmd s;
%% load data header and combine with other setting files
data_buffer.input_headfile=load_scanner_header(scanner, work_dir_path );

data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.input_headfile,'combine');
data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.scanner_constants,false);
data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.engine_constants,false);
data_buffer.headfile=combine_struct(data_buffer.headfile,opt_struct,'rad_mat_option_');

if isfield(data_buffer.input_headfile,'S_scanner_tag')
    data_tag=data_buffer.input_headfile.S_scanner_tag;
    bad_hf_path = [work_dir_path '/failed' runno '.headfile'];
    if exist(bad_hf_path,'file')
        % this will only happen rarely. but whatever. 
        delete(bad_hf_path);
    end
else
    bad_hf_path = [work_dir_path '/failed' runno '.headfile'];
    write_headfile(bad_hf_path,data_buffer.headfile);
    error('Failed to process scanner header using dump command ( %s )\nWrote partial hf to %s\nGIVE THE OUTPUT OF THIS TO JAMES TO HELP FIX THE PROBLEM. ',data_buffer.input_headfile.comment{end-1}(2:end),bad_hf_path);
end

if opt_struct.U_dimension_order ~=0
    data_buffer.input_headfile.([data_tag 'dimension_order'])=opt_struct.U_dimension_order;
end

if isfield(data_buffer.input_headfile,'aspect_remove_slice')
    if data_buffer.input_headfile.aspect_remove_slice
        opt_struct.remove_slice=1;
    else
        opt_struct.remove_slice=0;
    end
end
clear datapath dirext input input_data puller_data;
%% determing input acquisition type
% some of this might belong in the load data function we're going to need
vol_type=data_buffer.input_headfile.([data_tag 'vol_type']);
if opt_struct.vol_type_override~=0
    vol_type=opt_struct.vol_type_override;
    warning('Using override volume_type %s',opt_struct.vol_type_override);
end
% vol_type can be 2D or 3D or radial.
scan_type=data_buffer.input_headfile.([data_tag 'vol_type_detail']);
% vol_type_detail says the type of volume we're dealing with,
% this is set in the header parser perl modules the type can be
% single
% DTI
% MOV
% slab
% multi-vol
% multi-echo are normally interleaved, so we cut our chunk size in necho pieces


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
% volumes=data_buffer.input_headfile.([data_tag 'volumes']);
if regexp(scan_type,'channel')
    warning('multi-channel support still poor.');
end
%% calculate required disk and memory space
bytes_per_voxel_disk=0;%
% write_phase,write_phase,write_kimage,write_kimage_unfiltered
bytes_per_output_voxel_RAM=0;
volumes_in_memory_at_time=2;
bytes_per_input_sample_RAM=2*in_bitdepth/8;
workspace_precision_bytes=4;
output_precision_bytes=4;
% we multiply by 2 because each complex point uses two* input_bitdepth
if ~opt_struct.skip_write_civm_raw
    bytes_per_voxel_disk=bytes_per_voxel_disk+2;
    if opt_struct.fp32_magnitude
        bytes_per_voxel_disk=bytes_per_voxel_disk+2;
    end
    bytes_per_output_voxel_RAM=bytes_per_output_voxel_RAM+workspace_precision_bytes;
end
if opt_struct.write_unscaled
    bytes_per_voxel_disk=bytes_per_voxel_disk+output_precision_bytes;
end
if opt_struct.write_unscaled
    bytes_per_voxel_disk=bytes_per_voxel_disk+output_precision_bytes;
end
if opt_struct.write_unscaled_nD
    bytes_per_voxel_disk=bytes_per_voxel_disk+output_precision_bytes;
end
if opt_struct.write_phase
    bytes_per_voxel_disk=bytes_per_voxel_disk+output_precision_bytes;
end
if opt_struct.write_complex
    bytes_per_voxel_disk=bytes_per_voxel_disk+output_precision_bytes;
end
if opt_struct.write_kimage
    bytes_per_voxel_disk=bytes_per_voxel_disk+output_precision_bytes;
    bytes_per_output_voxel_RAM=bytes_per_output_voxel_RAM+workspace_precision_bytes*2;
end
if opt_struct.write_kimage_unfiltered
    bytes_per_voxel_disk=bytes_per_voxel_disk+output_precision_bytes;
    bytes_per_output_voxel_RAM=bytes_per_output_voxel_RAM+workspace_precision_bytes*2;
end
if opt_struct.write_unscaled || opt_struct.write_unscaled_nD || opt_struct.write_phase|| opt_struct.write_complex 
    bytes_per_output_voxel_RAM=bytes_per_output_voxel_RAM+workspace_precision_bytes;
end
% calculate space required on disk to save the output.
% 2 bytes for each voxel in civm image, 8 bytes per voxel of complex output
% if saved, 4 bytes for save 32-bit mag, 4 bytes for save 32-bit phase
voxel_count=...
    data_buffer.input_headfile.dim_X*...
    data_buffer.input_headfile.dim_Y*...
    data_buffer.input_headfile.dim_Z*...
    data_buffer.input_headfile.([data_tag 'volumes']);
if ~opt_struct.skip_combine_channels
    required_free_space=voxel_count/data_buffer.input_headfile.([data_tag 'channels'])*bytes_per_voxel_disk;
else 
    required_free_space=voxel_count*bytes_per_voxel_disk;
end
clear output_precision_bytes workspace_precision_bytes;

%% disk usage checking
fprintf('Required disk space is %0.2fMB\n',required_free_space/1024/1024);
% get free space
[~,local_space_bytes] = unix(['df ',data_buffer.engine_constants.engine_work_directory,' | tail -1 | awk ''{print $4}'' ']);
local_space_bytes=512*str2double(local_space_bytes); %this converts to bytes because default blocksize=512 byte
fprintf('Available disk space is %0.2fMB\n',local_space_bytes/1024/1024);
if required_free_space<local_space_bytes|| opt_struct.ignore_errors
    fprintf('      .... Proceding with plenty of disk space\n');
elseif required_free_space<2*local_space_bytes
    warning('Local disk space is low, may run out');
    pause(opt_struct.warning_pause);
else
    error('not enough free local disk space to reconstruct data, delete some files and try again');
end

clear local_space_bytes status required_free_space bytes_per_pix_output;


%% RAM usage checking and load_data parameter determination
display('Determining RAM requirements and chunk size');
data_prefix=data_buffer.input_headfile.(['U_' 'prefix']);
meminfo=imaqmem; %check available memory

binary_header_size   =data_buffer.input_headfile.binary_header_size; %distance to first data point in bytes
load_skip            =data_buffer.input_headfile.block_header_size;  %distance between blocks of rays in file
ray_blocks           =data_buffer.input_headfile.ray_blocks;         %number of blocks of rays total, sometimes nvolumes, sometimes nslices, somtimes nechoes, ntrs nalphas
rays_per_block       =data_buffer.input_headfile.rays_per_block;     %number or rays per in a block of input data,
ray_length           =data_buffer.input_headfile.ray_length;         %number of samples on a ray, or trajectory (this is doubled due to complex data being taken as real and imaginary discrete samples.)
% ne                   =data_buffer.input_headfile.ne;                 % number of echos.
channels             =data_buffer.input_headfile.([data_tag 'channels']); % number of channels.

acq_line_padding      =0;
% block_factors=factor(ray_blocks);

%%% calculate padding for bruker
if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    if strcmp(data_buffer.input_headfile.([data_prefix 'GS_info_dig_filling']),'Yes')|| ~opt_struct.ignore_errors  %PVM_EncZfRead=1 for fill, or 0 for no fill, generally we fill( THIS IS NOT WELL TESTED)
        %bruker data is usually padded out to a power of 2 or multiple of
        %3*2^6 940 is
        % there may be a minimum padding of some number?
        % have now seen with a 400x2channel acq padding of 96
        mul=2^6*2;
        [F,~]=log2(channels*ray_length/(mul));
        %[F,~]=log2(channels*ray_length/(2^5)); % when seeing 96, perhaps
        %this is the clue, padding is a multiple of 2^5th
        if mod(channels*ray_length,(mul))>0&& F ~= 0.5
            acq_line_lenght2 = 2^ceil(log2(channels*ray_length));
            acq_line_lenght3 = ceil(((channels*(ray_length)))/(mul))*mul;
            %             [F,~]=log2(ray_length3);
            %             if ray_length3<ray_length2&&F==0.5
            %                 ray_length2=ray_length3;
            %             end
            acq_line_lenght2=min(acq_line_lenght2,acq_line_lenght3);
        else
            acq_line_lenght2=channels*ray_length;
        end
        acq_line_padding  =   acq_line_lenght2-channels*ray_length;
        acq_line_lenght   =   acq_line_lenght2;
        input_points = ray_length*rays_per_block*ray_blocks;
        % the number of points in kspace that were sampled.
        % because ray_length now includes channels we must divide it out
        % for our number of input points.
        min_load_size= acq_line_lenght*rays_per_block*(in_bitdepth/8);
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
        
        input_points = ray_length*rays_per_block/channels*ray_blocks;
        % because ray_length is number of complex points have to doubled this.
        min_load_size=   acq_line_lenght*rays_per_block/channels*(in_bitdepth/8);
        acq_line_lenght=channels*ray_length;
    end
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
    display('Aspect scan, data size uncertain');
    %TENC = 4
    %INTRLV = INTRLV
    %DISTANZA = 4
    %     if  strcmp(data_buffer.input_headfile.([data_prefix 'INTRLV']),'INTRLV')
    %
    %     end
    if strcmp(data_buffer.input_headfile.S_PSDname,'SE_')||strcmp(data_buffer.input_headfile.S_PSDname,'ME_SE_')
        warning('Aspect SE_ detected!, setting ray_padding value=navigator_length! Does not use navigator data!');
        acq_line_lenght=ray_length+50;
        acq_line_padding=50;
    end
    input_points = ray_length*rays_per_block/channels*ray_blocks;
    % because ray_length is number of complex points have to doubled this.
    min_load_size= acq_line_lenght*rays_per_block/channels*(in_bitdepth/8);
    % minimum amount of bytes of data we can load at a time,
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')
    display('Agilent scan, data size uncertain');
    % agilent multi-channels handleing.... so far they acquire in xyc ...
    % order. 
    input_points = ray_length*rays_per_block*channels*ray_blocks;
    % because ray_length is doubled, this is doubled too.
    min_load_size= acq_line_lenght*rays_per_block*(in_bitdepth/8);
    % minimum amount of bytes of data we can load at a time,
else
    % not bruker, no ray padding...
    input_points = ray_length*rays_per_block*ray_blocks;
    % because ray_length is doubled, this is doubled too.
    min_load_size= acq_line_lenght*rays_per_block*(in_bitdepth/8);
    % minimum amount of bytes of data we can load at a time,
end
total_memory_required= volumes_in_memory_at_time*input_points*channels*bytes_per_input_sample_RAM+voxel_count*bytes_per_output_voxel_RAM;
system_reserved_memory=2*1024*1024*1024;% reserve 2gb for the system while we work.
fprintf(' input_points(kspace samples):%d output_voxels:%d\n',input_points,voxel_count);
fprintf(' total_memory_required for all at once:%0.02fM, system memory(- reserve):%dM\n',total_memory_required/1024/1024,(meminfo.TotalPhys-system_reserved_memory)/1024/1024);
% handle ignore memory limit options
if opt_struct.skip_mem_checks==1;
    display('you have chosen to ignore this machine''s memory limits, this machine may crash');
    total_memory_required=1;
end

%%% set number of processing chunks and the chunk size based on memory required and
%%% total memory available.%%% min_chunks is the minimum number we will need to procede. 
%%% if all the data will fit in memory happily this evaluates to min_chunks=1
%%% Max_loadable_ uses min_chunks. It should evaluate to complete data size
%%% when min_chunks is 1.
min_chunks=ceil(total_memory_required/(meminfo.TotalPhys-system_reserved_memory));
memory_space_required=(total_memory_required/min_chunks);
% max_loadable_chunk_size=(input_points*channels*(in_bitdepth/8))/min_chunks;
max_loadable_chunk_size=(input_points*channels*bytes_per_input_sample_RAM)/min_chunks;
% best case number maximum chunk size.

if min_chunks>1
    error('need to separate into chunks but never actually finished chunk code');
end
   

%%% use block_factors to find largest block size to find in
%%% max_loadable_chunk_size, and set c_dims
c_dims=[ data_buffer.input_headfile.dim_X,...
    data_buffer.input_headfile.dim_Y,...
    data_buffer.input_headfile.dim_Z];
warning('c_dims set poorly just to volume dimensions for now');

%%% first just try a purge to free enough space.
if meminfo.AvailPhys<memory_space_required
    system('purge');
    meminfo=imaqmem;
end
%%% now prompt for program close and purge each time
while meminfo.AvailPhys<memory_space_required
    fprintf('%d/%d you have too many programs open.\n ',meminfo.AvailPhys,memory_space_required);
    reply=input('close some programs and then press enter >> (press c to ignore mem limit, NOT RECOMMENDED)','s');
    system('purge');
    meminfo=imaqmem; 
    if strcmp(reply,'c')
        meminfo.AvailPhys=memory_space_required;
    end
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
    kspace_header_bytes  =binary_header_size+load_skip*ray_blocks*channels; 
    %%% TEMPORARY HACK TO FIX ISSUES WITH AGILENT
end
% total bytes used in header into throught out the kspace data
kspace_data          =min_load_size*max_loads_per_chunk;
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
        warning('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=\t%d\nCalculated=\t%d\n',measured_filesize,kspace_file_size);
    else %if measured_filesize<kspace_file_size    %if measured < exected fail.
        error('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=\t%d\nCalculated=\t%d\n',measured_filesize,kspace_file_size);
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

clear ray_length2 ray_length3 fileInfo bytes_per_vox copies_in_memory in_bitdepth in_bytetype min_chunks system_reserved_memory total_memory_required memory_space_required meminfo measured_filesize kspace_file_size kspace_data kspace_header_bytes F mul ;


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
x_dimension=data_buffer.input_headfile.dim_X;
y_dimension=data_buffer.input_headfile.dim_Y;
z_dimension=data_buffer.input_headfile.dim_Z;
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
d_struct.x=x_dimension;
d_struct.y=y_dimension;
d_struct.z=z_dimension;
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

% if anything except radial
if( ~regexp(data_buffer.headfile.([data_tag 'vol_type']),'radial'))
    input_dimensions=[d_struct.(dim_order(1)) d_struct.(dim_order(2))...
    d_struct.(dim_order(3)) d_struct.(dim_order(4))...
    d_struct.(dim_order(5)) d_struct.(dim_order(6))];
else
    % if radial
    input_dimensions=[ray_length d_struct.(dim_order(2))...
        d_struct.(dim_order(3)) rays_per_block ray_blocks];
end

output_dimensions=[d_struct.(opt_struct.output_order(1)) d_struct.(opt_struct.output_order(2))...
    d_struct.(opt_struct.output_order(3)) d_struct.(opt_struct.output_order(4))...
    d_struct.(opt_struct.output_order(5)) d_struct.(opt_struct.output_order(6))];
%% do work.
% for each chunk, load chunk, regrid, filter, fft, (save)
% save not implemented yet, requires a chunk stitch funtion as well.
% for now assuming we didnt chunk and saves after the fact.
%        
%%% if radial, and we should load a trajectory, load that here?
% if regexpi(data_buffer.headfile.S_PSDname, strjoin(data_buffer.headfile.bruker_radial_methods,'|')
% load_bruker_traj
% end
chunks_to_load=[1];
for chunk_num=1:num_chunks
    %% reconstruction
    if ~opt_struct.skip_load
        %% Load data file
        fprintf('Loading data\n');
        %load data with skips function, does not reshape, leave that to regridd
        %program.
        time_l=tic;
        load_from_data_file(data_buffer, data_buffer.input_headfile.kspace_data_path, ....
            binary_header_size, min_load_size, load_skip, in_precision, chunk_size, ...
            num_chunks,chunks_to_load(chunk_num),...
            in_endian);
        
        if acq_line_padding>0  %remove extra elements in padded ray,
            % lenght of full ray is spatial_dim1*nchannels+pad
            %         reps=ray_length;
            % account for number of channels and echos here as well .
            if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
                % padd beginning code
                logm=zeros(ray_length,1);
                logm(acq_line_lenght-acq_line_padding+1:acq_line_lenght)=1;
                %             logm=logical(repmat( logm, length(data_buffer.data)/(ray_length),1) );
                %             data_buffer.data(logm)=[];
            elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
                % pad ending code
                logm=ones((acq_line_padding),1);
                logm(acq_line_lenght-acq_line_padding+1:acq_line_lenght)=0;
            else
            end
            logm=logical(repmat( logm, length(data_buffer.data)/(acq_line_lenght),1) );
            data_buffer.data(logm)=[];
            warning('padding correction applied, hopefully correctly.');
            % could put sanity check that we are now the number of data points
            % expected given datasamples, so that would be
            % (ray_legth-ray_padding)*rays_per_blocks*blocks_per_chunk
            % NOTE: blocks_per_chunk is same as blocks_per_volume with small data,
            expected_data_length=(acq_line_lenght-acq_line_padding)/d_struct.c...
                *rays_per_block*ray_blocks;
            
                                
            if numel(data_buffer.data) ~= expected_data_length && ~opt_struct.ignore_errors;
                error('Ray_padding reversal went awrry. Data length should be %d, but is %d',...
                    (acq_line_lenght-acq_line_padding)/d_struct.c*rays_per_block*ray_blocks,numel(data_buffer.data));
            else
                fprintf('Data padding retains corrent number of elements, continuing...\n');
            end
        end
        fprintf('Data loading took %f seconds\n',toc(time_l)); 
        clear l_time;
        %% load trajectory and do dcf calculation
        if( regexp(data_buffer.headfile.([data_tag 'vol_type']),'radial'))
            %% Load trajectory and shape it up.
            %%% temporary add all paths thing.
            fprintf('Loading trajectory\n');
            time_lt=tic;
            addpath(genpath('/Volumes/workstation_home/Software/recon/DCE/3D_NonCartesian_Reconstruction'))
            data_buffer.addprop('traj');
            data_buffer.addprop('dcf');
            base_path=fileparts(data_buffer.input_headfile.kspace_data_path);
            traj_file_path=[base_path '/traj'];
            fileid = fopen(traj_file_path, 'r', in_endian);
            % data_buffer.traj = fread(fileid, Inf, ['double' '=>single']);
            data_buffer.traj = fread(fileid, Inf,'double');
            fclose(fileid);
%             data_buffer.headfile.rays_acquired_in_total=length(data_buffer.traj)/(3*npts); %total number of views
            fprintf('The total number of trajectory co-ordinates loaded is %d\n', numel(data_buffer.traj)/3);
            data_buffer.traj=reshape(data_buffer.traj,...
                [3,  data_buffer.headfile.ray_length,...
                data_buffer.headfile.rays_acquired_in_total]);
            fprintf('Trajectory loading took %f seconds.\n',toc(time_lt));

            opt_struct.iter=18; %Number of iterations used for dcf calculation
            % data_buffer.dcf=sdc3_MAT(data_buffer.traj, opt_struct.iter, x, 0, 2.1, ones(ray_length, data_buffer.headfile.rays_acquired_in_total));
            dcf_file_path=[base_path '/dcf.mat' ];
            if opt_struct.dcf_by_key
                data_buffer.traj=reshape(data_buffer.traj,[3,...
                    ray_length,...
                    data_buffer.headfile.rays_per_block,...
                    data_buffer.headfile.ray_blocks]);
                dcf_file_path=[base_path '/dcf_by_key.mat'];
            end
            data_buffer.dcf=zeros(ray_length,...
                data_buffer.headfile.rays_per_block,...
                data_buffer.headfile.ray_blocks);
%             t_struct=struct;
%             dcf_struct=struct;
%             for k_num=1:data_buffer.header.ray_blocks_per_volume
%                 t_struct.(['key_' k_num])=squeeze(data_buffer.traj(:,:,k_num,:));
%                 dcf_struct.(['key_' k_num])=zeros(data_buffer.headfile.rays_acquired_in_total,rays_length);
%             end
            traj=data_buffer.traj;
            dcf=data_buffer.dcf;
            iter=opt_struct.iter;
            %% Calculate/load dcf
            if exist(dcf_file_path,'file')
                fprintf('loading dcf to save effort :p\n');
                tic;
                load(dcf_file_path);
                fprintf('DCF loaded in %f seconds\n',toc);
                save_dcf=false;
            elseif ~opt_struct.dcf_by_key
                tic;
                dcf=sdc3_MAT(traj, iter, d_struct.x, 0, 2.1);
                fprintf('DCF completed in %f seconds. \n',toc);
                save_dcf=true;
            else
                if matlabpool('size')==0
                    try
                        matlabpool local 12
                    catch err
                        err_m=[err.message ];
                        for e=1:length(err.stack)
                            err_m=sprintf('%s\n \t%s:%i',err_m,err.stack(e).name,err.stack(e).line);
                        end
                        warning('Matlab pool failed to open with message, %s',err_m);
                    end
                end
                clear e err err_m;
                dcf_times=zeros(1,data_buffer.headfile.ray_blocks);
                parfor k_num=1:data_buffer.headfile.ray_blocks
                    tic;
                    dcf(:,:,k_num)=sdc3_MAT(squeeze(traj(:,:,:,k_num)), iter, d_struct.x, 0, 2.1);
                    %                     dcf(:,:,k_num)=reshape(temp,[ray_length,...
                    %                         data_buffer.headfile.rays_per_block...
                    %                         ]); % data_buffer.headfile.ray_blocks/data_buffer.headfile.ray_blocks_per_volume could also be total_rays/rays_per_block
                    dcf_times(k_num)=toc;
                    fprintf('DCF for key %d completed in %f seconds. \n',k_num,dcf_times(k_num));
                    %fprintf('Percent Complete %0.2f',dcf_times(k_num),100*numel(dcf_times(dcf_times~=0))/numel(dcf_times)
                    % this print is not parfor compatible because we're
                    % checking the indexes of dcf_times. too bad it'd be a
                    % great way to check who's done.
                end
                %%% save dcf just because
                fprintf('dcf took %f seconds, un-parallel code would have taken %f seconds.\n',mean(dcf_times),sum(dcf_times));
                save_dcf=true;
            end
            if save_dcf
                tic;
                save(dcf_file_path,'dcf','-v7.3');
                fprintf('DCF saved in %f seconds\n',toc);
            end
            data_buffer.traj=reshape(data_buffer.traj,[3,ray_length,rays_per_block*data_buffer.headfile.ray_blocks_per_volume]);
            data_buffer.dcf=reshape(dcf,[ray_length,rays_per_block*data_buffer.headfile.ray_blocks_per_volume]);
            clear save_dcf temp k_num dcf traj;
%             data_buffer.dcf=sdc3_MAT(t_struct.(['key_' k_num), opt_struct.iter, x, 0, 2.1);
%             data_buffer.dcf=reshape(data_buffer.dcf,[data_buffer.headfile.ray_acquired_in_total,ray_length]);
        end
        %% prep keyhole trajectory
        if ( regexp(scan_type,'keyhole'))
            % set up a binary array to mask points for the variable cutoff
            % this would be ray_length*keys*rays_per_key array
            % data_buffer.addprop('vcf_mask');
            % data_buffer.vcf_mask=calcmask;
            % frequency. Just ignoring right now
            if( ~regexp(data_buffer.headfile.([data_tag 'vol_type']),'radial'))
                error('Non-radial keyhole not supported yet');
            end
%             data_buffer.trajectory=reshape(data_buffer.trajectory,[3 ,data_buffer.headfile.ray_blocks_per_volume,data_buffer.headfile.ray_length]);
                        
        end
        %%% pre regrid data save.
        %     if opt_struct.display_kspace==true
        %         input_kspace=reshape(data_buffer.data,input_dimensions);
        %     end
        %% reformat/regrid kspace to cartesian
        % perhaps my 'regrid' should be re-named to 'reformat' as that is
        % more accurate especially for cartesian. 
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
        %% cleanup post reformat/regrid.
        if opt_struct.remove_slice
            fprintf('Slice removal occured, updateing zdim %f to %f,',d_struct.z,d_struct.z-1);
            d_struct.z=d_struct.z-1;
            data_buffer.headfile.dim_Z=d_struct.z;
            data_buffer.input_headfile.dim_Z=d_struct.z;
        end
        if isfield(data_buffer.headfile,'echo_asymmetry')
            if data_buffer.headfile.echo_asymmetry>0
                if d_struct.z>1
                    warning('asymmetry not tested with multi-slice');
                end
                % move data down the x, then add some x back...
                % ex for 128x128 image.
                % ak(33:128,:)=ak(1:128-32,:);
                % ak(1:32,:)=ak(128:-1:128-31,:);
                asym_offset=d_struct.x*data_buffer.headfile.echo_asymmetry/2;
                % perhaps a full mirror option would be good?
                se_inputtrash=4;
                data_buffer.data(asym_offset+1+se_inputtrash:d_struct.x,:)=data_buffer.data(1:d_struct.x-asym_offset-se_inputtrash,:);
                if opt_struct.asymmetry_mirror
                    se_inputtrash=ceil(asym_offset*0.85)-se_inputtrash; %adding just a little more cut off with the asymmetry copy.
                end
                data_buffer.data(1:asym_offset+1+se_inputtrash,:)=data_buffer.data(d_struct.x:-1:d_struct.x-asym_offset-se_inputtrash,:);
                warning('asymmetry support very experimental! CHECK YOUR OUTPUTS!');
                pause(8);
                
                
                %do asym stuff...
            end
        else
            disp('No asymmetry handling');
        end
        %% kspace shifting
        %opt_struct.kspace_shift
        if min(opt_struct.kspace_shift) <0 || max(opt_struct.kspace_shift) > 0
            warning('Kspace shifting choosen. Very uncertain of consequences. Custom output order not supported! Radial not supported.');
            data_buffer.data=circshift(data_buffer.data,opt_struct.kspace_shift);
            ks=opt_struct.kspace_shift;
            xb=1;xe=d_struct.x;yb=1;ye=d_struct.y;zb=1;ze=d_struct.z;
            if ks(1)<=0
                xe=d_struct.x-abs(ks(1));
            else
                xb=ks(1);
            end
            if ks(2)<=0
                ye=d_struct.y-abs(ks(2));
            else
                yb=ks(2);
            end
            if ks(3)<=0
                ze=d_struct.z-abs(ks(3));
%                 zinc=1;
                zr=ze:d_struct.z;
            else
                zb=ks(3);
%                 zinc=-1;
                zr=zb-ks(3)+1:d_struct.z-ze+ks(3);
            end
            mask2D=logical(sparse(d_struct.x,d_struct.y));
            mask2D(xb:xe,yb:ye)=1;
            mask2D=full(mask2D);
%             mask3D= false(d_struct.x,d_struct.y,d_struct.z,'uint8');
            mask3D=repmat(mask2D,[1 1  d_struct.z]);
            
            mask3D(:,:,zr)=0;
            maskAD=repmat(mask3D,[1 1 1 d_struct.c d_struct.p d_struct.t]);
            data_buffer.data=data_buffer.data.*maskAD;
%             data_buffer.data(:,:,ze:end,:,:,:)=0;
            clear xb xe yb ye zb ze mask;
        end 
        %% display kspace
        if opt_struct.display_kspace==true
            %         kslice=zeros(size(data_buffer.data,1),size(data_buffer.data,2)*2);
            %         kslice=zeros(x,y);
            s.x=':';
            s.y=':';
            figure(1);colormap gray;
            for tn=1:d_struct.t
                s.t=tn;
                for zn=1:d_struct.z
                    s.z=zn;
                    for cn=1:d_struct.c
                        s.c=cn;
                        for pn=1:d_struct.p
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
                            imagesc(log(abs(squeeze(kslice)))), axis image;
                            %                             fprintf('.');
                            pause(4/d_struct.z/d_struct.c/d_struct.p);
                            %                         pause(1);
                            %                         imagesc(log(abs(squeeze(input_kspace(:,cn,pn,zn,:,tn)))));
                            %                             fprintf('.');
                            %                         pause(4/z/d_struct.c/params);
                            %                         pause(1);
                        end
                        fprintf('\n');
                    end
                end
            end
        end
        %% preserve original kspace
        if opt_struct.write_kimage_unfiltered
            data_buffer.addprop('kspace_unfiltered');
            data_buffer.kspace_unfiltered=data_buffer.data;
        end
        %% filter kspace data
        if ~opt_struct.skip_filter
            fprintf('Performing fermi filter on volume with size %s\n',num2str(output_dimensions));
            if ischar(opt_struct.filter_width)
                opt_struct.filter_width=str2double(opt_struct.filter_width);
            elseif ~opt_struct.filter_width
                opt_struct.filter_width='';
            end
            if ischar(opt_struct.filter_window)
                opt_struct.filter_window=str2double(opt_struct.filter_window);
            elseif ~opt_struct.filter_window
                opt_struct.filter_window='';
            end
%             opt_struct.filter_width=0.15; defaults coded into the filter.
%             opt_struct.filter_window=0.75;

            if strcmp(vol_type,'2D') 
                % this requires regridding to place volume in same dimensions as the output dimensions 
                % it also requires the first two dimensions of the output to be to be xy.
                % these asumptions may not always be true. 
                data_buffer.data=reshape(data_buffer.data,[ output_dimensions(1:2) prod(output_dimensions(3:end))] );
                data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
                    opt_struct.filter_width,opt_struct.filter_window,true);
                data_buffer.data=reshape(data_buffer.data,output_dimensions );
            %elseif strcmp(vol_type,'3D')
            elseif regexpi(vol_type,'3D|4D|radial');
                %             fermi_filter_isodim2_memfix_obj(data_buffer);
%                 fermi_filter_isodim2_memfix_obj(data_buffer,...
%                     opt_struct.filter_width,opt_struct.filter_window);

                data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
                    opt_struct.filter_width,opt_struct.filter_window,false);
%             elseif strcmp(vol_type,'4D')
%                 data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
%                     opt_struct.filter_width,opt_struct.filter_window,false);
            else
                warning('%svol_type not specified, DID NOT PERFORM FILTER. \n can use vol_type_override=[2D|3D] to overcome headfile parse defficiency.',data_tag);
                pause(opt_struct.warning_pause);

            end
            %
        else
            fprintf('skipping fermi filter\n');
        end
        if opt_struct.write_kimage
            data_buffer.addprop('kspace');
            data_buffer.kspace=data_buffer.data;
        end
        %% fft, resort, cut bad data, and display
        if ~opt_struct.skip_recon
            %% fft
            fprintf('Performing FFT\n');
            if strcmp(vol_type,'2D')
                if ~exist('img','var') || numel(img)==1;
                    img=zeros(output_dimensions);
                end
                %         xyzcpt
                s.z=':';
                s.x=':';
                s.y=':';
                for cn=1:d_struct.c
                    s.c=cn;
                    if opt_struct.debug_mode>=10
                        fprintf('channel %d working...\n',cn);
                    end
                    for tn=1:d_struct.t
                        s.t=tn;
                        for pn=1:d_struct.p
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
                data_buffer.data=img;
                clear img;
            else
                %method 1 fails for more than 3D
                %                 odims=size(data_buffer.data);
                %                 data_buffer.data=reshape(data_buffer.data,[odims(1:3) prod(odims(4:end))]);
                %                 data_buffer.data=fftshift(ifftn(data_buffer.data));
                % method 2 very slow and memory inefficient.
                %                 Y = data_buffer.data;
                %                 for p = 1:3%length(size(data_buffer.data))
                %                     Y = fftshift(ifft(Y,[],p));
                %                 end
                %                 data_buffer.data=Y;
                % method 3 was incorrect shifting
                %                 data_buffer.data=fftshift(ifft(...
                %                     fftshift(ifft(...
                %                     fftshift(ifft(...
                %                     fftshift(data_buffer.data),[],1)),[],2)),[],3));
                % method 4 looks right however, does not produce same
                % result as evan code. Seems to be issue with my fft
                % shifts.
                
%                 data_buffer.data=...
%                     fftshift(ifft(...
%                     fftshift(ifft(...
%                     fftshift(ifft(...
%                     data_buffer.data,[],1)),[],2)),[],3));
%                 
                % method 5 very slow, seems ok for memory use.
                %                 for six=1:size(data_buffer.data,6)
                %                     for five=1:size(data_buffer.data,5)
                %                         for four=1:size(data_buffer.data,4)
                %                             data_buffer.data(:,:,:,four,five,six)=fftshift(ifftn(data_buffer.data(:,:,:,four,five,six)));
                %                         end
                %                         fprintf('.');
                %                     end
                %                 end
                %                 fprintf('\n');
                % method 6 is same as 4, working on getting the right
                % fftshift But givs very wrong result
                data_buffer.data=fftshift(fftshift(fftshift(ifft(ifft(ifft(data_buffer.data,[],1),[],2),[],3),1),2),3);
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
                    objlist=[d_struct.z/2+1:d_struct.z 1:d_struct.z/2 ];
                    %img=circshift(img,[ 0 y/2 0 ]);
                    data_buffer.data(:,:,objlist)=data_buffer.data;
                    fprintf('rotating image by 90...');
                    data_buffer.data=imrotate(data_buffer.data,90);
                    %img=transpose(img());
                    fprintf('resort and rotate done!\n');
                else
                    fprintf('Non-aspect data is not rotated or flipped, unsure what settings should be used\n');
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
                    if d_struct.z>1 && mod(d_struct.z,2) == 0
                        objlist=[1:d_struct.z/2;d_struct.z/2+1:d_struct.z];
                        objlist=objlist(:);
                        data_buffer.data=data_buffer.data(:,:,objlist);
                    end
                    %             for i=1:64
                    %                 figure(6);
                    %                 imagesc(log(abs(it(:,:,i))));
                    %                 pause(0.18);
                    %             end
                    %             y=size(it,2);
                    objlist=[d_struct.y/2+1:d_struct.y 1:d_struct.y/2];
                    data_buffer.data=data_buffer.data(:,objlist,:);
                    %             for i=1:64
                    %                 figure(6);
                    %                 imagesc(log(abs(it2(:,:,i))));
                    %                 pause(0.18);
                    %             end
                end
            end
            %% display result images
            if opt_struct.display_output==true
                s.x=':';
                s.y=':';
                for zn=1:d_struct.z
                    s.z=zn;
                    for tn=1:d_struct.t
                        s.t=tn;
                        for pn=1:d_struct.p
                            s.p=pn;
                            for cn=1:d_struct.c
                                s.c=cn;
                                imagesc(log(abs(squeeze(data_buffer.data(...
                                    s.(opt_struct.output_order(1)),...
                                    s.(opt_struct.output_order(2)),...
                                    s.(opt_struct.output_order(3)),...
                                    s.(opt_struct.output_order(4)),...
                                    s.(opt_struct.output_order(5)),...
                                    s.(opt_struct.output_order(6))...
                                    ))))), axis image;
                                pause(4/d_struct.z/d_struct.c/d_struct.p);
                                
                            end
                        end
                        fprintf('%d %d\n',zn,tn);
                    end
                end
            end
%             combine_image='DID NOT COMBINE';
            if ~opt_struct.skip_combine_channels && d_struct.c>1
                % To respect the output order we use strfind.
                fprintf('combining channel complex data with method %s\n',opt_struct.combine_method);
                dind=strfind(opt_struct.output_order,'c'); % get dimension index for channels
                %%% Removed the squeeze from our combine operation, better
                %%% to maintain the dimensions of the data object.
                if regexpi(opt_struct.combine_method,'mean')
%                     data_buffer.data=squeeze(mean(abs(data_buffer.data),dind));
                    data_buffer.data=mean(abs(data_buffer.data),dind);
                elseif regexpi(opt_struct.combine_method,'square_and_sum')
%                     data_buffer.data=squeeze(mean(data_buffer.data.^2,dind));
                    data_buffer.data=mean(data_buffer.data.^2,dind);
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
            if opt_struct.remove_slice
                d_struct.z=d_struct.z-1;
                data_buffer.headfile.dim_Z=d_struct.z;
                data_buffer.input_headfile.dim_Z=d_struct.z;
            end
        end
    end % end foreachchunk
    %% stich chunks together
    % this is not implimented yet.
    warning('this saving code is temporary it is not designed for chunks');
    %% save data
    % this needs a bunch of work, for now it is just assuming the whole pile of
    % data is sitting in memory awaiting saving, does not handle chunks or
    % anything correctly just now.
    
    %  mag=abs(raw_data(i).data);
    ij_prompt='';
    archive_prompts='';
    if opt_struct.skip_combine_channels
        channel_images=d_struct.c;
    else
        channel_images=1;
    end
    runnumbers=cell(channel_images*d_struct.p*d_struct.t,1);
    rindx=1;
    if (opt_struct.fp32_magnitude==true)
        datatype='fp32';
    else
        datatype='raw';
    end
    data_buffer.headfile.F_imgformat=datatype;
    if ~opt_struct.skip_write
        work_dir_img_path_base=[ work_dir_path '/' data_buffer.headfile.U_runno ] ;
        %%% save n-D combined nii.
        if ~opt_struct.skip_combine_channels && d_struct.c>1 && ~opt_struct.skip_recon && opt_struct.write_unscaled
            if ~exist([work_dir_img_path_base '.nii'],'file') || opt_struct.overwrite
                fprintf('Saving image combined with method:%s using %i channels to output work dir.\n',opt_struct.combine_method,d_struct.c);
                nii=make_nii(abs(data_buffer.data), [ ...
                    data_buffer.headfile.fovx/data_buffer.headfile.dim_X ...
                    data_buffer.headfile.fovy/data_buffer.headfile.dim_Y ...
                    data_buffer.headfile.fovz/data_buffer.headfile.dim_Z]); % insert fov settings here ffs....
                save_nii(nii,[work_dir_img_path_base '.nii']);
            else
                warning('Combined Image already exists and overwrite disabled');
            end
        end
        
        max_mnumber=d_struct.t*d_struct.p;
        m_length=length(num2str(max_mnumber));
        if ~opt_struct.skip_combine_channels
            data_buffer.headfile.([data_tag 'volumes'])=data_buffer.headfile.([data_tag 'volumes'])/d_struct.c;
            d_struct.c=1;
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
            'channels=',num2str(d_struct.c),';\n' , ...
            'channels=1;\n',...
            'frames=', num2str(d_struct.t),';\n', ...
            'slices=', num2str(d_struct.z),';\n', ...
            'volumes=', num2str(data_buffer.headfile.([data_tag 'volumes'])),';\n', ...
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
            '            num=d2s(volumenum-1,0);\n', ...
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
            '        if ( volumes < ', num2str(opt_struct.open_volume_limit), ' ) { \n', ...
            '            run("Raw...", "open="+output_dir+"/"+out_runno+"',...
            data_buffer.scanner_constants.scanner_tesla_image_code,...
            'imx.0001.raw image=[16-bit Unsigned] width=',...
            num2str(d_struct.x),' height=',num2str(d_struct.y),...
            ' offset=0 number="+slices+" gap=0 "+open_all_output+"");\n', ...
            '        }  else if ( volumenum == 1 ) {\n', ...
            '            run("Raw...", "open="+output_dir+"/"+out_runno+"',...
            data_buffer.scanner_constants.scanner_tesla_image_code,...
            'imx.0001.raw image=[16-bit Unsigned] width=', num2str(d_struct.x),...
            ' height=', num2str(d_struct.y),' offset=0 number="+slices+" gap=0 "+open_all_output+"");\n', ...
            '        } else  if ( volumenum == channels*frames) {\n', ...
            '            run("Raw...", "open="+output_dir+"/"+out_runno+"',...
            data_buffer.scanner_constants.scanner_tesla_image_code,...
            'imx.0001.raw image=[16-bit Unsigned] width=', num2str(d_struct.x),...
            ' height=', num2str(d_struct.y),' offset=0 number="+slices+" gap=0 "+open_all_output+"");\n', ...
            '        }\n', ...
            '    }\n', ...
            '}\n', ...
            'run("Tile");\n', ...
            '\n');
%             '        if ( !File.isDirectory(output_dir) ) {\n', ...
%             '            print("  Imagej: making directory"+output_dir);\n', ...
%             '            dirparts=split(output_dir,"/");\n', ...
%             '            current="";\n', ...
%             '            for (part=0;part<dirparts.length;part++) { \n', ...
%             '                current=current+"/"+dirparts[part];\n', ...
%             '                if (!File.isDirectory(current) ) {\n', ...
%             '                    File.makeDirectory(current);\n', ...
%             '                }\n', ...
%             '            }\n', ...
%             '         }\n',...
%             '\n', ...        
        mfid=fopen(openmacro_path,'w');
        fprintf(mfid,openmacro_lines);
        fclose(mfid);
        clear mfid openmacro_lines;
        s.x=':';
        s.y=':';
        s.z=':';
        data_buffer.headfile.group_max_atpct='auto';
        data_buffer.headfile.group_max_intensity=0;
        if ~opt_struct.independent_scaling ||  ( opt_struct.write_unscaled_nD && ~opt_struct.skip_recon ) 
        data_buffer.headfile.group_max_atpct=0;
            for tn=1:d_struct.t
                s.t=tn;
                for cn=1:d_struct.c
                    s.c=cn;
                    for pn=1:d_struct.p
                        s.p=pn;
                        tmp=abs(squeeze(data_buffer.data(...
                            s.(opt_struct.output_order(1)),...
                            s.(opt_struct.output_order(2)),...
                            s.(opt_struct.output_order(3)),...
                            s.(opt_struct.output_order(4)),...
                            s.(opt_struct.output_order(5)),...
                            s.(opt_struct.output_order(6))...
                            )));
                        tmp=sort(tmp(:));
                        m_tmp=max(tmp);
                        p_tmp=prctile(tmp,opt_struct.histo_percent);
                        if tmp>data_buffer.headfile.group_max_intensity
                            data_buffer.headfile.group_max_intensity=m_tmp;
                        end
                        if data_buffer.headfile.group_max_atpct<p_tmp
                            data_buffer.headfile.group_max_atpct=p_tmp;
                        end
                    end
                end
            end
            if ( opt_struct.write_unscaled_nD && ~opt_struct.skip_recon ) %|| opt_struct.skip_write_civm_raw
                fprintf('Writing debug outputs to %s\n',work_dir_path);
                fprintf('\twrite_unscaled_nD save\n');
                nii=make_nii(abs(squeeze(data_buffer.data)), [ ...
                    data_buffer.headfile.fovx/data_buffer.headfile.dim_X ...
                    data_buffer.headfile.fovy/data_buffer.headfile.dim_Y ...
                    data_buffer.headfile.fovz/data_buffer.headfile.dim_Z]); % insert fov settings here ffs....
                %                         data_buffer.data(...
                %                                 s.(opt_struct.output_order(1)),...
                %                                 s.(opt_struct.output_order(2)),...
                %                                 s.(opt_struct.output_order(3)),...
                %                                 s.(opt_struct.output_order(4)),...
                %                                 s.(opt_struct.output_order(5)),...
                %                                 s.(opt_struct.output_order(6))...
                %                                 )
                fprintf('\t\t save_nii\n');
                save_nii(nii,[work_dir_img_path_base '_ND.nii']);
                write_headfile([work_dir_img_path_base '_ND.headfile'],data_buffer.headfile);
                                        
            end
        end
        for tn=1:d_struct.t
            s.t=tn;
            for cn=1:d_struct.c
                s.c=cn;
                for pn=1:d_struct.p
                    s.p=pn;
                    if ~opt_struct.skip_recon && ( opt_struct.write_complex || opt_struct.write_unscaled || ~opt_struct.skip_write_civm_raw)
                        fprintf('Extracting image channel:%0.0f param:%0.0f timepoint:%0.0f\n',cn,pn,tn);
                        %                         if ~opt_struct.skip_combine_channels  && ~ischar(combine_image);% && d_struct.c>1
                        %                             tmp=squeeze(data_buffer.data(...
                        %                                 s.(opt_struct.output_order(1)),...
                        %                                 s.(opt_struct.output_order(2)),...
                        %                                 s.(opt_struct.output_order(3)),...
                        %                                 s.(opt_struct.output_order(4)),...
                        %                                 s.(opt_struct.output_order(5)),...
                        %                                 s.(opt_struct.output_order(6))...
                        %                                 ));
                        %                         else
                        tmp=squeeze(data_buffer.data(...
                            s.(opt_struct.output_order(1)),...
                            s.(opt_struct.output_order(2)),...
                            s.(opt_struct.output_order(3)),...
                            s.(opt_struct.output_order(4)),...
                            s.(opt_struct.output_order(5)),...
                            s.(opt_struct.output_order(6))...
                            ));% pulls out one volume at a time.
                        %                         end
                    else
                        tmp='RECON_DISABLED';
                    end
                    %%%set channel and mnumber codes for the filename
                    if d_struct.c>1
                        channel_code=opt_struct.channel_alias(cn);
                    else
                        channel_code='';
                    end
                    m_number=(tn-1)*d_struct.p+pn-1;
                    if d_struct.t> 1 || d_struct.p >1
                        m_code=sprintf(['_m%0' num2str(m_length) '.0f'], m_number);
                    else
                        m_code='';
                    end
                    space_dir_img_name =[ data_buffer.headfile.U_runno channel_code m_code];
                    space_dir_img_folder=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '/' space_dir_img_name 'images' ];
                    work_dir_img_path=[work_dir_img_path_base channel_code m_code];
                    
                    if (~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon )||...
                            ~opt_struct.skip_write_headfile
                        % if recon done, and we're writing civmrawoutput or
                        % we're writing headfile outs.
                        fprintf('Writing standard outputs to %s,\n',space_dir_img_folder);
                    end
                    if ( opt_struct.write_unscaled ||...
                            opt_struct.write_complex )&& ~opt_struct.skip_recon ||...
                            opt_struct.write_kimage ||...
                            opt_struct.write_kimage_unfiltered 
                        fprintf('Writing debug outputs to %s\n',work_dir_path);
                    end
                    %%% complex save
                    if opt_struct.write_complex && ~opt_struct.skip_recon
                        fprintf('\twrite_complex (radish_format) save\n');
                        save_complex(tmp,[ work_dir_img_path '.rp.out']);
%                         data_buffer.data(...
%                                 s.(opt_struct.output_order(1)),...
%                                 s.(opt_struct.output_order(2)),...
%                                 s.(opt_struct.output_order(3)),...
%                                 s.(opt_struct.output_order(4)),...
%                                 s.(opt_struct.output_order(5)),...
%                                 s.(opt_struct.output_order(6))...
%                                 )
                    end
                    %%% kimage_
                    if opt_struct.write_kimage && ~opt_struct.skip_filter && ~opt_struct.skip_load
                        fprintf('\twrite_kimage make_nii\n');
                        nii=make_nii(log(abs(data_buffer.kspace(...
                                s.(opt_struct.output_order(1)),...
                                s.(opt_struct.output_order(2)),...
                                s.(opt_struct.output_order(3)),...
                                s.(opt_struct.output_order(4)),...
                                s.(opt_struct.output_order(5)),...
                                s.(opt_struct.output_order(6))...
                                ))));
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path '_kspace.nii']);
                    end
                    %%% kimage_unfiltered
                    if opt_struct.write_kimage_unfiltered  && ~opt_struct.skip_load
                        fprintf('\twrite_kimage_unfiltered make_nii\n');
                        nii=make_nii(log(abs(data_buffer.kspace_unfiltered(...
                                s.(opt_struct.output_order(1)),...
                                s.(opt_struct.output_order(2)),...
                                s.(opt_struct.output_order(3)),...
                                s.(opt_struct.output_order(4)),...
                                s.(opt_struct.output_order(5)),...
                                s.(opt_struct.output_order(6))...
                                ))));
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path '_kspace_unfiltered.nii']);
                    end
                    %%% unscaled_nii_save
                    if ( opt_struct.write_unscaled && ~opt_struct.skip_recon ) %|| opt_struct.skip_write_civm_raw
                        fprintf('\twrite_unscaled save\n');
                        nii=make_nii(abs(tmp), [ ...
                            data_buffer.headfile.fovx/data_buffer.headfile.dim_X ...
                            data_buffer.headfile.fovy/data_buffer.headfile.dim_Y ...
                            data_buffer.headfile.fovz/data_buffer.headfile.dim_Z]); % insert fov settings here ffs....
%                         data_buffer.data(...
%                                 s.(opt_struct.output_order(1)),...
%                                 s.(opt_struct.output_order(2)),...
%                                 s.(opt_struct.output_order(3)),...
%                                 s.(opt_struct.output_order(4)),...
%                                 s.(opt_struct.output_order(5)),...
%                                 s.(opt_struct.output_order(6))...
%                                 )
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path '.nii']);
                    end
                    %%% civmraw save
                    if ~exist(space_dir_img_folder,'dir') || opt_struct.ignore_errors
                        if ~opt_struct.skip_write_civm_raw && ~opt_struct.skip_write_headfile 
                            mkdir(space_dir_img_folder);
                        end
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
                        fprintf('\twrite_headfile save \n');
                        write_headfile([space_dir_img_folder '/' space_dir_img_name '.headfile'],data_buffer.headfile);
                        % insert validate_header perl script check here?
                    end
                    if ~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon
                        fprintf('\tcivm_raw save\n');
                        histo_bins=numel(tmp);
                        if opt_struct.independent_scaling
                            img_s=sort(abs(tmp(:)));
                            data_buffer.headfile.group_max_intensity=max(img_s);
                            data_buffer.headfile.group_max_atpct=img_s(round(numel(img_s)*opt_struct.histo_percent/100));%throwaway highest % of data... see if that helps.
                            fprintf('\tMax for scale = %f\n',data_buffer.headfile.group_max_atpct);
%                         else
%                              data_buffer.headfile.group_max_atpct= data_buffer.headfile.group_max_atpct;
                        end
%                         data_buffer.data(...
%                                 s.(opt_struct.output_order(1)),...
%                                 s.(opt_struct.output_order(2)),...
%                                 s.(opt_struct.output_order(3)),...
%                                 s.(opt_struct.output_order(4)),...
%                                 s.(opt_struct.output_order(5)),...
%                                 s.(opt_struct.output_order(6))...
%                                 )
%                         tmp=data_buffer.data(...
%                                 s.(opt_struct.output_order(1)),...
%                                 s.(opt_struct.output_order(2)),...
%                                 s.(opt_struct.output_order(3)),...
%                                 s.(opt_struct.output_order(4)),...
%                                 s.(opt_struct.output_order(5)),...
%                                 s.(opt_struct.output_order(6))...
%                                 );
                        % must write convert_info_histo for old school radish purposes
%                       opt_struct.histo_percent=99.95;

                        outpath=[space_dir_img_folder '/convert_info_histo'];
                        % display(['Saving vintage threeft to ' outpath '.']);
                        ofid=fopen(outpath,'w+');
                        if ofid==-1 
                            error('problem opening convert_info_hist file for writing file');
                        end
                        fprintf(ofid,'%f=scale_max found by rad_mat in complex file %s\n', data_buffer.headfile.group_max_atpct,[work_dir_img_path '.out']);
                        fprintf(ofid,'%i %i : image dimensions.\n',data_buffer.headfile.dim_X,data_buffer.headfile.dim_Y);
                        fprintf(ofid,'%i : image set zdim.\n', data_buffer.headfile.dim_Z);
                        fprintf(ofid,'%i : histo_bins, %f : histo_percent\n',histo_bins,opt_struct.histo_percent);
                        fprintf(ofid,'x : user provided max voxel value? provided for max= none (if file used).\n');
                        fprintf(ofid,'%f : max voxel value used to construct histogram\n',data_buffer.headfile.group_max_intensity);
                        fprintf(ofid,' rad_mat convert_info_histo dump 2013/11/05\n');
                        fclose(ofid);
                        complex_to_civmraw(tmp,[ data_buffer.headfile.U_runno channel_code m_code], ...
                            data_buffer.scanner_constants.scanner_tesla_image_code, ...
                            space_dir_img_folder,'',outpath,1,datatype)
                         
                    end
                    %%% convenience prompts
                    
                    if ~opt_struct.skip_recon||opt_struct.force_ij_prompt
                        % display ij call to examine images.
                        [~,txt]=system('echo -n $ijstart');  %-n for no newline i think there is a smarter way to get system variables but this works for now.
                        ij_prompt=sprintf('%s -macro %s',txt, openmacro_path);
                        mat_ij_prompt=sprintf('system(''%s'');',ij_prompt);
                    end
                    if ~opt_struct.skip_write_civm_raw
                        %write_archive_tag(runno,spacename, slices, projectcode, img_format,civmid)
                        runnumbers(rindx)={[data_buffer.headfile.U_runno channel_code m_code]};
                        rindx=rindx+1;
                        
                    end
                    
                end
            end
        end
    else
        fprintf('No outputs written.\n');
    end
    if ~isempty(ij_prompt)&& ~opt_struct.skip_write_civm_raw
        fprintf('test civm image output from a terminal using following command\n');
        fprintf('  (it may only open the first and last in large sequences).\n');
        fprintf('\n\n%s\n\n\n',ij_prompt);
        fprintf('test civm image output from matlab using following command\n');
        fprintf('  (it may only open the first and last in large sequences).\n');
        fprintf('\n%s\n\n',mat_ij_prompt);
    end
    if ~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon
        archive_prompts=sprintf('%s%s',archive_prompts,...
            write_archive_tag(runnumbers,...
            data_buffer.engine_constants.engine_work_directory,...
            d_struct.z,data_buffer.headfile.U_code,datatype,...
            data_buffer.headfile.U_civmid,false));
        fprintf('initiate archive from a terminal using, (should change person to yourself). \n\n');
        fprintf(archive_prompts);
    end
    
end
fprintf(' Total rad_mat time is %f second\n',toc);

success_status=true;
