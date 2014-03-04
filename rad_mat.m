function [img, success_status,data_buffer]=rad_mat(scanner,runno,input_data,options)
% [img, s, buffer]=RAD_MAT(scanner,runno,input,options)
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
% buffer   - the databuffer, including the headfile writeen to disk any any
%            other data left inside it. For all at once recons buffer.data 
%            should be the n-D reconstructed volumes after combining the channels. 

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
%% data refernece setup
img=0;
% success_status=false;
data_buffer=large_array;
% if ~isprop(data_buffer,'data')
%     data_buffer.addprop('data');
% else
%     disp('found prop');
%     pause(9);
% end
% if ~isfield(data_buffer,'data')
%     data_buffer.addprop('data');
% else
%     disp('found field');
%     pause(9);
% end
data_buffer.addprop('scanner_constants');
data_buffer.addprop('engine_constants');
data_buffer.addprop('headfile');     % ouput headfile to dump or partial output for multi sets.
data_buffer.addprop('input_headfile'); % scanner input headfile
data_buffer.headfile=struct;
clear ans;
%% insert rad_mat call into headfile comment.
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
%% define the possible options, so we can error for unrecognized options.
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
    'grid_oversample_factor', ' oversample grid multiplier, only used for radial regrid has a default of 3'
    '',                       ''
    };
beta_options={
    '',                       'Secondary, new, experimental options'
    'planned_ok',             ' special option which must be early in list of options, controls whether planned options are an error'
    'unrecognized_ok',        ' special option which must be early in list of options, controls whether arbitrary options are an error, this is so that alternate child functions could be passed the opt_struct variable and would work from there. This is also the key to inserting values into the headfile to override what our perlscript generates. '
    'debug_mode',             ' verbosity. use debug_mode=##'
    'study',                  ' set the bruker study to pull from, useful if puller fails to find the correct data'
    'U_dimension_order',      ' input_dimension_order will override whatever the perl script comes up with.'
    'vol_type_override',      ' if the processing script fails to guess the proper acquisition type(2D|3D|4D|radial) it can be specified.'
    'kspace_shift',           ' x:y:z shift of kspace, use kspace_shift=##:##:##' 
    'ignore_kspace_oversize', ' when we do our sanity checks on input data ignore kspace file being bigger than expected, this currently must be on for aspect data'
    'integrated_rolling',     ' use integrated image rolling, rolls images per channel of output PRIOR to saving. behavior likely bad with single specimen multi-coil images. '
    'post_rolling',           ' calculate roll post save to be run through roll_3d, if integrated_rolling is on this should calculate to zero(+/-1).'
    'output_order',           ' specify the order of your output dimensions. Default is xyzcpt. use output_oder=xyzcpt.'
    'channel_alias',          ' list of values for aliasing channels to letters, could be anything using this'
    'combine_method',         ' specify the method used for combining multi-channel data. supported modes are square_and_sum, or mean, use  combine_method=text'
    'skip_combine_channels',  ' do not combine the channel images'
    'write_complex',          ' should the complex output be written to th work directory. Will be written as rp(or near rp file) format.'
    'do_aspect_freq_correct', ' perform aspect frequency correction.'
    'pre_defined_headfile',   ' instead of loading the scanner data header load a pre-generated one.'
    'no_scanner_header',      ' the scanner header is invalid un-loadable or misisng for some reason, all required hf keys would need to be specified as options following the unrecognized_ok option. '
    'skip_load'               ' do not load data, implies skip regrid, skip filter, skip recon and skip resort'
    'skip_regrid',            ' do not regrid'
    'skip_filter',            ' do not filter data sets.'
    'skip_fft',               ' do not fft data, good short hand when saving kspace files'
    'skip_recon',             ' for re-writing headfiles only, implies skip filter, and existing_data'
    'skip_resort',            ' for 3D aspect acquisitions we turn by 90 and resort y and z after fft, this alows that to be skiped'
    'skip_resort_y',          ' for 3D aspect acquisitions we resort z after fft, this alows that to be skiped, other sorting will occur'
    'skip_resort_z',          ' for 3D aspect acquisitions we resort y after fft, this alows that to be skiped, other sorting will occur'
    'skip_rotate',            ' for 3D aspect images skip the 90degree rotation.'
    'force_ij_prompt',        ' force ij prompt on, it is normally ignored with skip_recon'
    'remove_slice',           ' removes a slice of the acquisition at the end, this is a hack for some acquisition types'
    'new_trajectory',         ' use measured trajectory instead of static one on recon enigne'
    'dcf_by_key',             ' calculate dcf by the key in acq'
    'dcf_recalculate',        ' do not use the saved dcf file'
    'dcf_iterations',         ' set number of iterations for dcf calculation, only used for radial'
    'radial_filter_method',   ' UFC or VFC, if blank uses none.'
    'open_volume_limit',      ' override the maximum number of volumes imagej will open at a time,default is 36. use open_volume_limit=##'
    'warning_pause',          ' length of pause after warnings (default 3). Errors outside matlab from the perl parsers are not effected. use warning_pause=##'
    'no_navigator',           ''
    '',                       ''
    };
planned_options={
    '',                       'Options we may want in the future, they might have been started. They could even be finished and very unpolished. '
    'write_phase',            ' write a phase output to the work directory'
    'fp32_magnitude',         ' write fp32 civm raws instead of the normal ones'
    'write_kimage',           ' write the regridded and filtered kspace data to the work directory.'
    'write_kimage_unfiltered',' write the regridded unfiltered   kspace data to the work direcotry.'
    'matlab_parallel',            ' use the matlab pool to parallelize.'
    'ignore_errors',          ' will try to continue regarless of any error'
    'asymmetry_mirror',       ' with echo asymmetry tries to copy 85% of echo trail to leading echo side.'
    'independent_scaling',    ' scale output images independently'
    'workspace_doubles',      ' use double precision in the workspace instead of single'
    'chunk_test_max',         ' maximum number of chunks to process before quiting. NOT a production option!'
    'chunk_test_min',         ' first chunks to process before. NOT a production option!'
    'image_return_type',      ' set the return type image from unscaled 32-bit float magnitude to something else.'
    'no_navigator',           ''
    'force_navigator',        ' Force the navigator selection code on for aspect scans, By default only SE SE classic and ME SE are expected to use navigator.'
    'roll_with_centroid',     ' calculate roll value using centroid(regionprops) method instead of by the luke/russ handy quick way'
%     'allow_headfile_override' ' Allow arbitrary options to be passed which will overwrite headfile values once the headfile is created/loaded'
    '',                       ''
    };
%% set option defaults
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
unrecognized_fields=struct;% place to put all the names of unrecognized options we recieved. They're assumed to all be headfile values. 
%opt_struct.combine_channels=true; % normally we want to combine channels
% opt_struct.display_kspace=false;
% opt_struct.display_output=false;
%
opt_struct.output_order='xyzcpt'; % order of dimensions on output. p is parameters, c is channels.
possible_dimensions=opt_struct.output_order;
opt_struct.combine_method='mean';

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
% opt_struct.combine_method='square_and_sum';
%% handle options cellarray.
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
            if ~isempty(str2double(value)) && ~isnan(str2double(value))
                value=str2double(value);
            end
            unrecognized_fields.(option)=value;
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
clear all_options beta_options beta_options_string e err_string o_num option parts planned_options planned_options_string specific_text standard_options standard_options_string value w warn_string;

%% set implied options
% output implication
if opt_struct.skip_write_civm_raw &&...
        ~opt_struct.write_complex &&...
        ~opt_struct.write_kimage &&...
        ~opt_struct.write_kimage_unfiltered &&...
        ~opt_struct.write_unscaled &&...
        ~opt_struct.write_unscaled_nD
    opt_struct.skip_fft=true;
end

% input implication
if opt_struct.skip_recon
    opt_struct.skip_load=true;
end
if opt_struct.skip_load
    opt_struct.skip_filter=true;
    opt_struct.skip_fft=true;
    opt_struct.skip_regrid=true;
end
if opt_struct.skip_filter
    
end
if opt_struct.skip_regrid
end
if opt_struct.skip_fft
    opt_struct.skip_write_civm_raw=true;
    opt_struct.write_complex=false;
    opt_struct.fp32magnitude=false;
    opt_struct.write_phase=false;
    opt_struct.write_unscaled=false;
    opt_struct.write_unscaled_nD=false;
end

if opt_struct.skip_write_civm_raw &&...
        ~opt_struct.write_complex &&...
        ~opt_struct.write_kimage &&...
        ~opt_struct.write_kimage_unfiltered &&...
        ~opt_struct.write_unscaled &&...
        ~opt_struct.write_unscaled_nD
    opt_struct.skip_fft=true;
end
%% option sanity checks and cleanup
if ~opt_struct.chunk_test_max
    opt_struct.chunk_test_max=Inf;
end
if ~opt_struct.chunk_test_min
    opt_struct.chunk_test_min=1;
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
if islogical(opt_struct.pre_defined_headfile)
%     if opt_struct.pre_defined_headfile
%         error('You wanted a pre_defined_headfile but you forgot to specify one');
%     end
%     opt_struct.pre_defined_headfile='';
end
clear possible_dimensions warn_string err_string char ks e o_num parts all_options beta_options beta_options_string planned_options planned_options_string standard_options standard_options_string temp test value w
%% dependency loading
rad_start=tic;
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
data_buffer.headfile.work_dir_path=[data_buffer.engine_constants.engine_work_directory '/' work_dir_name];
if opt_struct.overwrite
    opt_struct.puller_option_string=[' -o ' opt_struct.puller_option_string];
end
if opt_struct.existing_data && exist(data_buffer.headfile.work_dir_path,'dir') %||opt_struct.skip_recon
    opt_struct.puller_option_string=[' -e ' opt_struct.puller_option_string];
end
cmd_list=['puller_simple ' opt_struct.puller_option_string ' ' scanner ' ''' puller_data ''' ' data_buffer.headfile.work_dir_path];
data_buffer.headfile.comment{end+1}=['# \/ pull cmd ' '\/'];
data_buffer.headfile.comment{end+1}=['# ' cmd_list ];
data_buffer.headfile.comment{end+1}=['# /\ pull cmd ' '/\'];
if ~opt_struct.existing_data || ~exist(data_buffer.headfile.work_dir_path,'dir')  %&&~opt_struct.skip_recon
    if ~exist(data_buffer.headfile.work_dir_path,'dir') && opt_struct.existing_data
        warning('You wanted existing data BUT IT WASNT THERE!\n\tContinuing by tring to fetch new.');
        pause(1);
    end
    p_status =system(cmd_list);
    if p_status ~= 0 && ~opt_struct.ignore_errors
        error('puller failed:%s',cmd_list);
    end
end
clear cmd s datapath puller_data puller_data work_dir_name p_status;

%% load data header and insert unrecognized fields into headfile
if ~opt_struct.no_scanner_header
    data_buffer.input_headfile=load_scanner_header(scanner, data_buffer.headfile.work_dir_path ,opt_struct);
end
if ~isempty(opt_struct.pre_defined_headfile)||opt_struct.pre_defined_headfile==1
    if islogical(opt_struct.pre_defined_headfile)
        warning('Loading manual header from work directory manual.headfile');
        opt_struct.pre_defined_headfile=[data_buffer.headfile.work_dir_path '/manual.headfile' ];
    end
    
    if exist(opt_struct.pre_defined_headfile,'file')
        data_buffer.input_headfile=read_headfile(opt_struct.pre_defined_headfile);
    else
%             if opt_struct.pre_defined_headfile
        error('You wanted a pre_defined_headfile but you forgot to specify one');
%     end
    end
    
end
% data_buffer.headfile=combine_struct(data_buffer.headfile,unrecognized_fields);
data_buffer.input_headfile=combine_struct(data_buffer.input_headfile,unrecognized_fields);

%% combine with other setting files
% clean up fields and options
if isfield(data_buffer.input_headfile,'S_scanner_tag')
    data_tag=data_buffer.input_headfile.S_scanner_tag;
    bad_hf_path = [data_buffer.headfile.work_dir_path '/failed' runno '.headfile'];
    if exist(bad_hf_path,'file')
        % this will only happen rarely. but whatever. 
        delete(bad_hf_path); clear bad_hf_path;
    end
else
    bad_hf_path = [data_buffer.headfile.work_dir_path '/failed' runno '.headfile'];
    write_headfile(bad_hf_path,data_buffer.input_headfile);
    error('Failed to process scanner header from dump command ( %s )\nWrote partial hf to %s\nGIVE THE OUTPUT OF THIS TO JAMES TO HELP FIX THE PROBLEM. ',data_buffer.headfile.comment{end-1}(2:end),bad_hf_path);
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

data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.input_headfile,'combine');
data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.scanner_constants,false);
data_buffer.headfile=combine_struct(data_buffer.headfile,data_buffer.engine_constants,false);
% data_buffer.headfile=combine_struct(data_buffer.headfile,opt_struct,'rad_mat_option_');
% this was moved to just before the do_work section so these variables will
% be "fresher"

clear datapath dirext input input_data puller_data;
%% read input acquisition type from our header
% some of this might belong in the load data function we're going to need
vol_type=data_buffer.headfile.([data_tag 'vol_type']);
if opt_struct.vol_type_override~=0
    vol_type=opt_struct.vol_type_override;
    warning('Using override volume_type %s',opt_struct.vol_type_override);
end
% vol_type can be 2D or 3D or radial.
scan_type=data_buffer.headfile.([data_tag 'vol_type_detail']);
% vol_type_detail says the type of volume we're dealing with,
% this is set in the header parser perl modules the type can be
% single
% DTI
% MOV
% slab
% multi-vol
% multi-echo are normally interleaved, so we cut our chunk size in necho pieces


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
% end
% if ~exist('kspace.endian','var')
    warning('Input kspace endian unknown, header parser defficient!');
    data_in.disk_endian='';
end

% if kspace.bit_depth==32 || kspace.bit_depth==64
data_in.precision_string=[data_in.disk_data_type num2str(data_in.disk_bit_depth)];
% end
% if regexp(scan_type,'echo')
%     volumes=data_buffer.headfile.([data_tag 'echoes']);
%     if regexp(scan_type,'non_interleave')
%         interleave=false;
%     else
%         interleave=true;
%     end
% else
%     volumes=data_buffer.headfile.([data_tag 'volumes']);
%     if regexp(scan_type,'interleave')
%         interleave=true;
%     else
%         interleave=false;
%     end
% end
% volumes=data_buffer.headfile.([data_tag 'volumes']);
if regexp(scan_type,'channel')
    warning('multi-channel support still poor.');
end
%% read input dimensions to shorthand struct
d_struct=struct;
d_struct.x=data_buffer.headfile.dim_X;
d_struct.y=data_buffer.headfile.dim_Y;
d_struct.z=data_buffer.headfile.dim_Z;
d_struct.c=data_buffer.headfile.([data_tag 'channels'] );
if isfield (data_buffer.headfile,[data_tag 'varying_parameter'])
    varying_parameter=data_buffer.headfile.([data_tag 'varying_parameter']);
else
    varying_parameter='';
end
if strcmp(varying_parameter,'echos') || strcmp(varying_parameter,'echoes')
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

input_order=data_buffer.headfile.([data_tag 'dimension_order' ]);
%% set data acquisition parameters to determine how much to work on at a time and how.
% permute_code=zeros(size(input_order));
% for char=1:length(input_order)
%     permute_code(char)=strfind(opt_struct.output_order,input_order(char));
% end

% this mess gets the input and output dimensions using char arrays as
% dynamic structure element names.
% given the structure s.x, s.y, s.z the input_order='xzy' and
% outputorder='xyz'
% will set input to in=[x z y];
% and output to out=[x y z];
binary_header_size   =data_buffer.headfile.binary_header_size; %distance to first data point in bytes-standard block header.
load_skip            =data_buffer.headfile.block_header_size;  %distance between blocks of rays in file in bytes
ray_blocks           =data_buffer.headfile.ray_blocks;         %number of blocks of rays total, sometimes nvolumes, sometimes nslices, somtimes nechoes, ntrs nalphas
rays_per_block       =data_buffer.headfile.rays_per_block;     %number or rays per block of input data,
ray_length           =data_buffer.headfile.ray_length;         %number of samples on a ray, or trajectory

% if anything except radial
% if( ~regexp(data_buffer.headfile.([data_tag 'vol_type']),'.*radial.*'))
if strcmp(data_buffer.headfile.([data_tag 'vol_type']),'radial')
    % if radial
    input_dimensions=[ray_length d_struct.(input_order(2))...
        d_struct.(input_order(3)) rays_per_block ray_blocks];
else
    input_dimensions=[d_struct.(input_order(1)) d_struct.(input_order(2))...
    d_struct.(input_order(3)) d_struct.(input_order(4))...
    d_struct.(input_order(5)) d_struct.(input_order(6))];

end

output_dimensions=[d_struct.(opt_struct.output_order(1)) d_struct.(opt_struct.output_order(2))...
    d_struct.(opt_struct.output_order(3)) d_struct.(opt_struct.output_order(4))...
    d_struct.(opt_struct.output_order(5)) d_struct.(opt_struct.output_order(6))];
%% calculate bytes per voxel for RAM(input,working,output) and disk dependent on settings
% using our different options settings guess how many bytes of ram we need per voxel
% of, input, workspace, and output
data_out.disk_bytes_per_voxel=0;
data_out.RAM_bytes_per_voxel=0;
data_out.RAM_volume_multiplier=1;
data_in.RAM_volume_multiplier=1;
data_work.RAM_volume_multiplier=1;
data_work.RAM_bytes_per_voxel=0;
% volumes_in_memory_at_time=2; % part of the peak memory calculations. Hopefully supplanted with better way of calcultating in future
data_in.RAM_bytes_per_sample=2*data_in.disk_bit_depth/8; % input samples are always double because complex points are (always?) stored in 2 component vectors.
data_out.disk_bytes_header_per_out_vol=0;
data_out.disk_bytes_single_header=352; % this way we can do an if nii header switch.
% precision_bytes is multiplied by 2 because complex data takes one number
% for real and imaginary
if ~opt_struct.workspace_doubles
    data_work.precision_bytes=2*4;   % we try to keep our workspace to single precision complex.
else
    data_work.precision_bytes=2*8;   % use double precision workspace
end
if regexp(vol_type,'.*radial.*') % unfortunately radial requires double precision for the grid function for now.
    data_work.precision_bytes=2*8;
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
    
end
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
    data_out.RAM_bytes_per_voxel=data_out.RAM_bytes_per_voxel+data_work.precision_bytes*2;
    data_out.disk_bytes_header_per_out_vol=data_out.disk_bytes_header_per_out_vol+data_out.disk_bytes_single_header;
    data_work.RAM_bytes_per_voxel=data_work.RAM_bytes_per_voxel+data_work.precision_bytes;
end
if opt_struct.write_kimage_unfiltered
    data_out.disk_bytes_per_voxel=data_out.disk_bytes_per_voxel+data_out.precision_bytes;
    data_out.RAM_bytes_per_voxel=data_out.RAM_bytes_per_voxel+data_work.precision_bytes*2;
    data_work.RAM_bytes_per_voxel=data_work.RAM_bytes_per_voxel+data_work.precision_bytes;
end
if opt_struct.write_unscaled || opt_struct.write_unscaled_nD || opt_struct.write_phase|| opt_struct.write_complex 
%     output_
    data_out.RAM_bytes_per_voxel=data_out.RAM_bytes_per_voxel+data_work.precision_bytes;
    data_work.RAM_bytes_per_voxel=data_work.RAM_bytes_per_voxel+data_work.precision_bytes;
end
%% calculate expected disk usage and check free disk space.
% data_out.volumes=data_buffer.headfile.([data_tag 'volumes'])/d_struct.c;
data_work.volumes=data_buffer.headfile.([data_tag 'volumes']); % initalize to worst case before we run through possibilities below.
data_out.volumes=data_buffer.headfile.([data_tag 'volumes']);
if opt_struct.skip_combine_channels % while we're using the max n volumes this is unnecessary.
    data_out.volumes=data_buffer.headfile.([data_tag 'volumes']);
end

data_out.volume_voxels=...
    d_struct.x*...
    d_struct.y*...
    d_struct.z;
data_out.total_voxel_count=...
    data_out.volume_voxels*...
    data_out.volumes;

if regexp(vol_type,'.*radial.*')
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
else
    data_work.volume_voxels=data_out.volume_voxels;
    data_work.total_voxel_count=data_out.total_voxel_count;
end
data_out.disk_total_bytes=data_out.total_voxel_count*data_out.disk_bytes_per_voxel;
fprintf('Required disk space is %0.2fMB\n',data_out.disk_total_bytes/1024/1024);
% get free space
[~,local_space_bytes] = unix(['df ',data_buffer.engine_constants.engine_work_directory,' | tail -1 | awk ''{print $4}'' ']);
local_space_bytes=512*str2double(local_space_bytes); %this converts to bytes because default blocksize=512 byte
fprintf('Available disk space is %0.2fMB\n',local_space_bytes/1024/1024);
if data_out.disk_total_bytes<local_space_bytes|| opt_struct.ignore_errors
    fprintf('\t... Proceding with plenty of disk space.\n');
elseif local_space_bytes-data_out.disk_total_bytes < 0.1*local_space_bytes % warning at <10% of free remaining after output
    warning('Local disk space is low, may run out');
    pause(opt_struct.warning_pause);
else
    error('not enough free local disk space to reconstruct data, delete some files and try again');
end
clear local_space_bytes;
%% load_data parameter determination
display('Checking file size and calcualting RAM requirements...');
data_prefix=data_buffer.headfile.(['U_' 'prefix']);
meminfo=imaqmem; %check available memory

data_in.line_pad      =0;
data_in.line_points=d_struct.c*ray_length;
data_in.total_points = ray_length*rays_per_block*ray_blocks;
% the number of points in kspace that were sampled.
% for our number of input points.
data_in.min_load_bytes= 2*data_in.line_points*rays_per_block*(data_in.disk_bit_depth/8); % 8 bits per byte.
% minimum amount of bytes of data we can load at a time
%%   determine padding
% block_factors=factor(ray_blocks);
alt_agilent_channel_code=true;
if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    %% calculate padding for bruker
    if ( strcmp(data_buffer.headfile.([data_prefix 'GS_info_dig_filling']),'Yes')...
            || ~opt_struct.ignore_errors )...
%             && ~regexp(data_buffer.headfile.([data_tag 'vol_type']),'.*radial.*')  %PVM_EncZfRead=1 for fill, or 0 for no fill, generally we fill( THIS IS NOT WELL TESTED)
        %bruker data is usually padded out to a power of 2 or multiples of
        %powers of 2.
        % 3*2^6 
        % there may be a minimum padding of some number?
        % have now seen with a 400x2channel acq padding of 96
        mul=2^6*2;
        [F,~]=log2(d_struct.c*ray_length/(mul));
        if mod(d_struct.c*ray_length,(mul))>0&& F ~= 0.5
            data_in.line_points2 = 2^ceil(log2(d_struct.c*ray_length));
            data_in.line_points3 = ceil(((d_struct.c*(ray_length)))/(mul))*mul;
            data_in.line_points2 = min(data_in.line_points2,data_in.line_points3);
            data_in=rmfield(data_in,'line_points3');
        else
            data_in.line_points2=d_struct.c*ray_length;
        end
        data_in.line_pad  =   data_in.line_points2-d_struct.c*ray_length;
        data_in.line_points   =   data_in.line_points2;
        data_in.total_points = ray_length*rays_per_block*ray_blocks;
        % the number of points in kspace that were sampled.
        % this does not include header or padding
        data_in.min_load_bytes= 2*data_in.line_points*rays_per_block*(data_in.disk_bit_depth/8);
        % minimum amount of bytes of data we can load at a time, 
        % this includes our line padding but no our header bytes which 
        % we could theoretically skip.
        data_in=rmfield(data_in,'line_points2');
        clear mul F;
    else
        error(['Found no pad option with bruker scan for the first time,' ...
            'Tell james let this continue in test mode']);
        
%         data_input.sample_points = ray_length*rays_per_block/d_struct.c*ray_blocks;
%         % because ray_length is number of complex points have to doubled this.
%         min_load_size=   data_in.line_points*rays_per_block/d_struct.c*(kspace.bit_depth/8);
%         data_in.line_points=d_struct.c*ray_length;
    end
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
    %% calculate padding for aspect, only SE sequences so far that we can tell. 
    display('Aspect scan, data size uncertain');
    %TENC = 4
    %INTRLV = INTRLV
    %DISTANZA = 4
    %     if  strcmp(data_buffer.headfile.([data_prefix 'INTRLV']),'INTRLV')
    %
    %     end
    if opt_struct.force_navigator || strcmp(data_buffer.headfile.S_PSDname,'SE_') ...
            || strcmp(data_buffer.headfile.S_PSDname,'SE_CLASSIC_') 
%             || strcmp(data_buffer.headfile.S_PSDname,'ME_SE_')
        if ~opt_struct.no_navigator
            warning('Navigator per ray on, setting ray_padding value=navigator_length! Does not use navigator data!');
            data_in.line_points=ray_length+50;
            data_in.line_pad=50;
        end
    end
    data_in.total_points = ray_length*rays_per_block*ray_blocks;
    % because ray_length is number of complex points have to doubled this.
    data_in.min_load_bytes= 2*data_in.line_points*rays_per_block*(data_in.disk_bit_depth/8);
    % minimum amount of bytes of data we can load at a time,
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')
    %% No padding on agilent that we can tell.
    display('Agilent scan, data size uncertain');
    % agilent multi-channels handleing.... so far they acquire in xyc ...
    % order. 
    %%%%
    % this is only true for some multi channel agilent runs, REQUIRES MORE
    % TESTING alt_agilent_channel_code set just above open of this if else
    % chain
    if alt_agilent_channel_code
    data_in.line_points  = ray_length;
    ray_blocks=d_struct.c*ray_blocks;
    end
    % this is the only change to revert behavior
    %%%%%%
    data_in.total_points = ray_length*rays_per_block*d_struct.c*ray_blocks;
    % because ray_length is doubled, this is doubled too.
    data_in.min_load_bytes=2*data_in.line_points*rays_per_block*...
        (data_in.disk_bit_depth/8);
    % minimum amount of bytes of data we can load at a time,
else
    error('Stopping for unrecognized scanner_vendor, not sure if how to calculate the memory size.');
%     % not bruker, no ray padding...
%     data_input.sample_points = ray_length*rays_per_block*ray_blocks;
%     % because ray_length is doubled, this is doubled too.
%     min_load_size= data_in.line_points*rays_per_block*(kspace.bit_depth/8);
%     % minimum amount of bytes of data we can load at a time,
end
%% calculate expected input file size and compare to real size
% if we cant calcualte the file size its likely we dont know what it is
% we're loading, and therefore we would fail to reconstruct.
kspace_header_bytes  =binary_header_size+load_skip*(ray_blocks-1); 
% total bytes used in headers spread throughout the kspace data
if strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')&&alt_agilent_channel_code
    kspace_header_bytes  =binary_header_size+load_skip*(ray_blocks); 
    %%% TEMPORARY HACK TO FIX ISSUES WITH AGILENT
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')
    kspace_header_bytes  =binary_header_size+load_skip*ray_blocks*d_struct.c; 
end
kspace_data=2*(data_in.line_points*rays_per_block)*ray_blocks*(data_in.disk_bit_depth/8); % data bytes in file (not counting header bytes)
% kspace_data          =min_load_size*max_loads_per_chunk;
% total bytes used in data only(no header/meta info)
kspace_file_size     =kspace_header_bytes+kspace_data; % total ammount of bytes in data file.

fileInfo = dir(data_buffer.headfile.kspace_data_path);
if isempty(fileInfo)
    error('puller did not get data, check pull cmd and scanner');
end
measured_filesize    =fileInfo.bytes;

if kspace_file_size~=measured_filesize
    if (measured_filesize>kspace_file_size && opt_struct.ignore_kspace_oversize) || opt_struct.ignore_errors % measured > expected provisional continue
        warning('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=\t%d\nCalculated=\t%d\n',measured_filesize,kspace_file_size);
        % extra warning when acaual is greater than 10% of exptected
        remainder=measured_filesize-kspace_file_size;
        aspect_remainder=138443;
        if remainder/kspace_file_size> 0.1 && remainder~=aspect_remainder
            error(sprintf('Big difference between measured and calculated!\n\tSUCCESS UNLIKELY!'));
            pause( 2*opt_struct.warning_pause ) ;
        end
        
        
    else %if measured_filesize<kspace_file_size    %if measured < exected fail.
        error('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=\t%d\nCalculated=\t%d\n',measured_filesize,kspace_file_size);
    end
else
    fprintf('\t... Proceding with good file size.\n');
end
clear kspace_header_bytes kspace_file_size fileInfo measured_filesize;
%% calculate memory and chunk sizes
data_in.total_bytes_RAM=...
    data_in.RAM_volume_multiplier...
    *data_in.RAM_bytes_per_sample...
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
%     data_in.RAM_volume_multiplier   *data_in.RAM_bytes_per_sample  *data_in.total_points...
%     +data_work.RAM_volume_multiplier*data_work.RAM_bytes_per_voxel *data_work.total_voxel_count...
%     +data_out.RAM_volume_multiplier *data_out.RAM_bytes_per_voxel  *data_out.total_voxel_count; %...
%     +volumes_in_memory_at_time*data_in.total_points*d_struct.c*data_in.RAM_bytes_per_sample+data_work.total_voxel_count*data_out.RAM_bytes_per_voxel;
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
%%% max_loadable_chunk_size, and set c_dims 
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
    % min_load_size
    % load_skip
    % chunk_size
    % num_chunks
    % chunks_to_load(chunk_num)]
%     if true
    min_chunks=1;
    memory_space_required=maximum_RAM_requirement;
    % max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*ray_blocks*data_in.RAM_bytes_per_sample);
    max_loadable_chunk_size=((data_in.line_points*rays_per_block)*ray_blocks*data_in.RAM_bytes_per_sample);
    % the maximum chunk size for an exclusive data per volume reconstruction.
    c_dims=[ d_struct.x,...
        d_struct.y,...
        d_struct.z];
    warning('c_dims set poorly just to volume dimensions for now');
    chunk_size_bytes=max_loadable_chunk_size;
    num_chunks           =kspace_data/chunk_size_bytes;
    if floor(num_chunks)<num_chunks
        warning('Number of chunks did not work out to integer, things may be wrong!');
    end
    min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
    chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);       % chunk_size in data samples.
    if num_chunks>1 && ~opt_struct.ignore_errors
        error('not tested with more than one chunk yet');
    end
%     else
%         min_chunks=ceil(maximum_RAM_requirement/useable_RAM);
%         memory_space_required=(maximum_RAM_requirement/min_chunks); % this is our maximum memory requirements
%         % max_loadable_chunk_size=(data_input.sample_points*d_struct.c*(kspace.bit_depth/8))/min_chunks;
%         max_loadable_chunk_size=((data_in.line_points*rays_per_block)*ray_blocks*data_in.RAM_bytes_per_sample)...
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
%         num_chunks           =kspace_data/chunk_size_bytes;
%         if floor(num_chunks)<num_chunks
%             warning('Number of chunks did not work out to integer, things may be wrong!');
%         end
%         if data_in.min_load_bytes>chunk_size_bytes && ~opt_struct.skip_mem_checks && ~opt_struct.ignore_errors
%             error('Oh noes! blocks of data too big to be handled in a single chunk, bailing out');
%         end
%         
%         min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
%         chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);    % chunk_size in data samples.
%     end
elseif true
    % set variables
    %%%
    % binary_header_size % set above so we're good
    % min_load_size      % set according to data_in.min_load_bytes(this is in data values).
    % load_skip          % set above so we're good
    % chunk_size
    % num_chunks
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
    % starting with the last dimension see if  for each dimension see if any will fit with the data loaded.
    for rd=numel(recon_strategy.dim_string):-1:1
        if useable_RAM < data_in.total_bytes_RAM...
                +data_work.single_vol_RAM*prod(output_dimensions(4:rd))...
                +data_out.single_vol_RAM*prod(output_dimensions(4:rd))
            recon_strategy.dim_string(rd)=[];
        end
    end
    c_dims=output_dimensions(1:rd);
    % if we've removed all except for the first three dimensions do one more
    % check to see if we can fit all input in memory at once with a single
    % recon volume.
    if length(recon_strategy.dim_string)==3
        if d_struct.c>1 % if there are channels this is false no matter what here.
            %&& useable_RAM < data_work.single_vol_RAM*d_struct.c+data_in.total_bytes_RAM
            recon_strategy.channels_at_once=false;
        end
        if useable_RAM>=data_in.total_bytes_RAM+data_work.single_vol_RAM+data_out.single_vol_RAM
            recon_strategy.load_whole=true; 
        else
            recon_strategy.load_whole=false;
        end
    end
    % load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
    %     binary_header_size, min_load_size, load_skip, data_in.precision_string, chunk_size, ...
    %     num_chunks,chunks_to_load(chunk_num),...
    %     data_in.disk_endian);
    % binary_header_size % set above so we're good
    % min_load_size      % set according to data_in.min_load_bytes(this is in data values).
    % load_skip          % set above so we're good
    % chunk_size
    % num_chunks
    % chunks_to_load(chunk_num)
%     working_space=volumes_in_memory_at_time*data_work.total_voxel_count*data_out.RAM_bytes_per_voxel;
%     extra_RAM_bytes_required=0;
%     if regexp(vol_type,'.*radial.*')
%         sample_space_length=ray_length*rays_per_block*data_buffer.headfile.ray_blocks_per_volume;
%         extra_RAM_bytes_required=sample_space_length*3*data_out.RAM_bytes_per_voxel+sample_space_length*data_out.RAM_bytes_per_voxel;
%     end
%     vols_or_vols_plus_channels=floor((meminfo.TotalPhys-system_reserved_RAM-data_in.total_bytes_RAM-extra_RAM_bytes_required)/working_space);
    if recon_strategy.load_whole
        memory_space_required=data_in.total_bytes_RAM+data_work.single_vol_RAM*prod(output_dimensions(4:rd))+data_out.single_vol_RAM*prod(output_dimensions(4:rd));
        
        opt_struct.parallel_jobs=min(12,floor((useable_RAM-data_in.total_bytes_RAM)/data_work.single_vol_RAM*prod(output_dimensions(4:rd))+data_out.single_vol_RAM*prod(output_dimensions(4:rd))));
        % cannot have more than 12 parallel jobs in matlab.
        % max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*ray_blocks*data_in.RAM_bytes_per_sample);
        max_loadable_chunk_size=((data_in.line_points*rays_per_block)*ray_blocks*data_in.RAM_bytes_per_sample);
        min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
        
        %this chunk_size only works here because we know that we cut at
        %least one dimensions because we can only get here when we havnt
        %got enough memory for all at once. 
        if numel(recon_strategy.dim_string)<numel(output_dimensions)
            chunk_size_bytes=max_loadable_chunk_size/output_dimensions(numel(recon_strategy.dim_string)+1);
        else
            chunk_size_bytes=max_loadable_chunk_size/output_dimensions(end);
        end
        num_chunks      =kspace_data/chunk_size_bytes;
        chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);       % chunk_size in # of values (eg, 2*complex_points.
    else
        error('not tested with more than one load chunk yet');
    end
    if num_chunks>1
        recon_strategy.work_by_chunk=true;
        opt_struct.independent_scaling=true;
    end
    clear rd;
else
    min_chunks=ceil(maximum_RAM_requirement/useable_RAM);
    memory_space_required=(maximum_RAM_requirement/min_chunks); % this is our maximum memory requirements
    % max_loadable_chunk_size=(data_input.sample_points*d_struct.c*(kspace.bit_depth/8))/min_chunks;
    max_loadable_chunk_size=((data_in.line_points*rays_per_block+load_skip)*ray_blocks*data_in.RAM_bytes_per_sample)...
        /min_chunks;
    % the maximum chunk size for an exclusive data per volume reconstruction.
    
    c_dims=[ d_struct.x,...
        d_struct.y,...
        d_struct.z];
    warning('c_dims set poorly just to volume dimensions for now');
    
    max_loads_per_chunk=max_loadable_chunk_size/data_in.min_load_bytes;
    if floor(max_loads_per_chunk)<max_loads_per_chunk && ~opt_struct.ignore_errors
        error('un-even loads per chunk size, %f < %f have to do better job getting loading sizes',floor(max_loads_per_chunk),max_loads_per_chunk);
    end
    chunk_size_bytes=floor(max_loadable_chunk_size/data_in.min_load_bytes)*data_in.min_load_bytes;
    
    num_chunks           =kspace_data/chunk_size_bytes;
    if floor(num_chunks)<num_chunks
        warning('Number of chunks did not work out to integer, things may be wrong!');
    end
    if data_in.min_load_bytes>chunk_size_bytes && ~opt_struct.skip_mem_checks && ~opt_struct.ignore_errors
        error('Oh noes! blocks of data too big to be handled in a single chunk, bailing out');
    end
    
    min_load_size=data_in.min_load_bytes/(data_in.disk_bit_depth/8); % minimum_load_size in data samples.
    chunk_size=   chunk_size_bytes/(data_in.disk_bit_depth/8);    % chunk_size in data samples.
    if num_chunks>1 && ~opt_struct.ignore_errors
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
%     num_chunks=volumes;
%     max_blocks=blocks_per_vol;
%     if max_blocks*npoints*ntraces>memory_space_required
%         error('volume size is too large, consider closing programs and restarting')
%     end
% else %if its just one volume, see if we can do it all at once or need to do chunks
%     max_blocks=floor(memory_space_required/(ntraces*npoints)); %number of blocks we can work on at a time
%     num_chunks=ceil(nblocks/max_blocks);
% end
if num_chunks>1
    fprintf('\tmemory_required :%0.02fM, split into %d problems\n',memory_space_required/1024/1024,num_chunks);
    pause(3);
end
clear maximum_RAM_requirement useable_RAM ;

%% mem purging when we expect to fit.
%%% first just try a purge to free enough space.
if meminfo.AvailPhys<memory_space_required
    system('purge');
    meminfo=imaqmem;
end
%%% now prompt for program close and purge and update available mem.
while meminfo.AvailPhys<memory_space_required
    fprintf('%0.2fM/%0.2fM you have too many programs open.\n ',meminfo.AvailPhys/1024/1024,memory_space_required/1024/1024);
    reply=data_in('close some programs and then press enter >> (press c to ignore mem limit, NOT RECOMMENDED)','s');
    if strcmp(reply,'c')
        meminfo.AvailPhys=memory_space_required;
    else
        system('purge');
        meminfo=imaqmem;
    end
end
fprintf('    ... Proceding doing recon with %d chunk(s)\n',num_chunks);

clear ray_length2 ray_length3 fileInfo bytes_per_vox copies_in_memory kspace.bit_depth kspace.data_type min_chunks system_reserved_memory total_memory_required memory_space_required meminfo measured_filesize kspace_file_size kspace_data kspace_header_bytes F mul ;
%% collect gui info (or set testmode)
%check civm runno convention
% add loop while gui has not run successfully,
if ~regexp(data_buffer.headfile.U_runno,'^[A-Z][0-9]{5-6}.*')
    %~strcmp(runno(1),'S') && ~strcmp(runno(1),'N') || length(runno(2:end))~=5 || isnan(str2double(runno(2:end)))
    display('runno does not match CIVM convention, the recon will procede in testmode')
    opt_struct.testmode=1;
end
% if not testmode then create headfile
if  opt_struct.testmode
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
    gui_info=strsplit(gui_info_lines{l},':::');
    if length(gui_info)==2
        data_buffer.headfile.(['U_' gui_info{1}])=gui_info{2};
        data_buffer.input_headfile.(['U_' gui_info{1}])=gui_info{2};
        fprintf('adding meta line %s=%s\n', ['U_' gui_info{1}],data_buffer.headfile.(['U_' gui_info{1}]));
    else
        fprintf('ignoring line %s\n',gui_info_lines{l});
    end
end

if isfield(data_buffer.headfile,'U_specid')
    if regexp(data_buffer.headfile.U_specid,'.*;.*')
        fprintf('Mutliple specids entered in gui, forcing combine channels off! %s\n',data_buffer.headfile.U_specid);
        opt_struct.skip_combine_channels=true;
    end
end
if isempty(gui_info_lines) && ~opt_struct.ignore_errors
    error('GUI did not return values!');
end
clear gui_info gui_dump gui_info_lines l;
%% fancy dimension settings before reconstruction
%%% this data get for dimensions is temporary, should be handled better in
%%% the future.


%% do work.
% for each chunk, load chunk, regrid, filter, fft, (save)
% save not implemented yet, requires a chunk stitch funtion as well.
% for now assuming we didnt chunk and saves after the fact.
%        
%%% if radial, and we should load a trajectory, load that here?
% if regexpi(data_buffer.headfile.S_PSDname, strjoin(data_buffer.headfile.bruker_radial_methods,'|')
% load_bruker_traj
% end
%% insert unrecognized fields into headfile
data_buffer.headfile=combine_struct(data_buffer.headfile,unrecognized_fields);
clear fnum option value parts;
%%% last second stuff options into headfile
data_buffer.headfile=combine_struct(data_buffer.headfile,opt_struct,'rad_mat_option_');
chunks_to_load=1:num_chunks;
% for chunk_num=1:num_chunks
if opt_struct.matlab_parallel && opt_struct.parallel_jobs>1
    if matlabpool('size') ~= opt_struct.parallel_jobs && matlabpool('size')>0
        matlabpool close;
    end
    matlabpool(num2str(opt_struct.parallel_jobs));
end
%% give user last second feed back of what we're going to try to do. 
% print d_struct
% print dimension orders for input and output
% print expected load data size. 
% print load parameters, maybe explain what they mean
dim_order=data_buffer.input_headfile.([data_tag 'dimension_order' ]);
ds='';
for d_num=1:length(dim_order)
   ds=sprintf('%s %d',ds,d_struct.(dim_order(d_num)));
end
%  load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
%                 data_buffer.headfile.kspace_data_path, min_load_size, load_skip, data_in.precision_string, load_chunk_size, ...
%                 load_chunks,chunks_to_load(chunk_num),...
%                 data_in.disk_endian);
fprintf(['recon proceding of file at %s\n'...
    '\twith input order %s and sizes %s\n'...
    '\theader is %d bytes,\n'...
    '\tblock size is %d bytes,\n '...
    '\tloading %d blocks,\n',...
    '\tblock to block skip is %d bytes,\n'...
    '\tdata precision is %s, endian is %s.\n'],...
    data_buffer.headfile.kspace_data_path, ....
    dim_order, ds,...
    binary_header_size,...
    min_load_size,...
    chunk_size/min_load_size,...
    load_skip,...    
    data_in.precision_string,...
    data_in.disk_endian);

clear dim_order ds ;


    %% reconstruction
for chunk_num=opt_struct.chunk_test_min:min(opt_struct.chunk_test_max,num_chunks)
    time_chunk=tic;
    if ~opt_struct.skip_load
        %% Load data file
        fprintf('Loading data\n');
        %load data with skips function, does not reshape, leave that to regridd
        %program.
        time_l=tic;
        load_chunks=num_chunks;
        load_chunk_size=chunk_size;
        if recon_strategy.load_whole && num_chunks>1
            load_chunks=1;
            load_chunk_size=chunk_size*num_chunks;
        end
        %         temp_chunks=num_chunks;
        %         temp_size=chunk_size;
        %         if recon_strategy.load_whole && temp_chunks>1
        %             num_chunks=1;
        %             chunk_size=temp_size*temp_chunks;
        %         end

        if  chunk_num==1 || (  load_chunks>1 ) ||  ~isprop(data_buffer,'data') %~recon_strategy.load_whole &&
            % we load the data for only the first chunk of a load_whole, 
            % or for each/any chunk when num_chunks  > 1
            if ~isprop(data_buffer,'data')
                data_buffer.addprop('data');
            end
            load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
                binary_header_size, min_load_size, load_skip, data_in.precision_string, load_chunk_size, ...
                load_chunks,chunks_to_load(chunk_num),...
                data_in.disk_endian);
            
            if data_in.line_pad>0  %remove extra elements in padded ray,
                % lenght of full ray is spatial_dim1*nchannels+pad
                %         reps=ray_length;
                % account for number of channels and echoes here as well .
                if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
                    % padd beginning code
                    logm=zeros(data_in.line_points,1);
                    logm(data_in.line_points-data_in.line_pad+1:data_in.line_points)=1;
                    %             logm=logical(repmat( logm, length(data_buffer.data)/(ray_length),1) );
                    %             data_buffer.data(logm)=[];
                elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
                    % pad ending code
                    logm=ones((data_in.line_pad),1);
                    logm(data_in.line_points-data_in.line_pad+1:data_in.line_points)=0;
                else
                end
                logm=logical(repmat( logm, length(data_buffer.data)/(data_in.line_points),1) );
                data_buffer.data(logm)=[];
                warning('padding correction applied, hopefully correctly.');
                % could put sanity check that we are now the number of data points
                % expected given datasamples, so that would be
                % (ray_legth-ray_padding)*rays_per_blocks*ray_blocks_per_volume
                % NOTE: blocks_per_chunk is same as blocks_per_volume with small data,
                % expected_data_length=(data_in.line_points-data_input.line_padding)/d_struct.c...
                %     *rays_per_block*ray_blocks; % channels removed, things
                %     changed at some point to no longer divide by channel.
                expected_data_length=(data_in.line_points-data_in.line_pad)...
                    *rays_per_block*ray_blocks/load_chunks;
                if numel(data_buffer.data) ~= expected_data_length && ~opt_struct.ignore_errors;
                    error('Ray_padding reversal went awrry. Data length should be %d, but is %d',...
                        expected_data_length,numel(data_buffer.data));
                else
                    fprintf('Data padding retains correct number of elements, continuing...\n');
                end
            end
            
        end
%         if recon_strategy.load_whole && temp_chunks>1
%             num_chunks=temp_chunks;
%             chunk_size=temp_size;
%         end
        fprintf('Data loading took %f seconds\n',toc(time_l));
        clear l_time logm temp_chunks temp_size;
        %% load trajectory and do dcf calculation
        if( regexp(data_buffer.headfile.([data_tag 'vol_type']),'.*radial.*'))
            %% Load trajectory and shape it up.

            fprintf('Loading trajectory\n');
            t_lt=tic;
            % trajectory file should be in
            % workstation_data/data/trajectory/vendor/scanner/sequence/rootname_Mencmatrix_Kkeyhole_Uundersample
            %%% temporary add all paths thing.
            addpath(genpath('/Volumes/workstation_home/Software/recon/DCE/3D_NonCartesian_Reconstruction'))
            if regexp(data_buffer.scanner_constants.scanner_vendor,'bruker')
                trajectory_name='traj';
            else
                error('First trajectory load from non-bruker tell james');
            end
            %%% path hand waving adjusts path for static or new trajectory
            % new trajectories are copied to the static location
            % dcf will be calculated and saved in the static location
            % if we want to use a fresh trajectory its assumed that it is
            % only for the current scan so we do not copy, and our dcf file
            % will be recalculated in our scan directory.
            base_path=fileparts(data_buffer.headfile.kspace_data_path);
            trajectory_file_path=[base_path '/' trajectory_name ];
            static_base_path=[data_buffer.engine_constants.engine_data_directory '/' ...
                'trajectory/'...
                data_buffer.scanner_constants.scanner_vendor '/'...
                scanner '/'...
                data_buffer.headfile.S_PSDname '/' ...
                ];
            static_file_path = [static_base_path '/' ...
                trajectory_name ...
                '_M' num2str(data_buffer.headfile.traj_matrix) ...
                '_K' num2str(data_buffer.headfile.ray_blocks_per_volume) ...
                '_U' num2str(data_buffer.headfile.radial_undersampling) ];
            if ~exist(static_file_path,'file')
                if ~exist(static_base_path,'dir')
                    warning('Making trajectory storage directory %s\n',static_base_path);
                    [tc_status, tc_message]=mkdir(static_base_path);
                    if ~tc_status
                        error('Failed to make trajectory directory at %s.\n\t%s\n',static_base_path,tc_message);
                    end
                end
                [tc_status, tc_message]=copyfile(trajectory_file_path,static_file_path);
                %set permissions to all readable here.
                if ~tc_status
                    error('Failed to copy trajectory to %s.\n\t%s\n',static_file_path,tc_message);
                end
                clear tc_status tc_message;
                fprintf('New trajectory detected!, copying to %s\n',static_file_path);
                trajectory_file_path=static_file_path;
            end
            if ~opt_struct.new_trajectory
                trajectory_file_path=static_file_path;
            end
            %%% load the file
            if ~isprop(data_buffer,'trajectory')
                data_buffer.addprop('trajectory');
                fileid = fopen(trajectory_file_path, 'r', data_in.disk_endian);
                % data_buffer.trajectory = fread(fileid, Inf, ['double' '=>single']);
                data_buffer.trajectory = fread(fileid, Inf,'double');
                fclose(fileid);
                %             data_buffer.headfile.rays_acquired_in_total=length(data_buffer.trajectory)/(3*npts); %total number of views
                fprintf('The total number of trajectory co-ordinates loaded is %d\n', numel(data_buffer.trajectory)/3);
                data_buffer.trajectory=reshape(data_buffer.trajectory,...
                    [3,  data_buffer.headfile.ray_length,...
                    data_buffer.headfile.rays_per_volume]);
                fprintf('Trajectory loading took %f seconds.\n',toc(t_lt));
                clear t_lt fileid;
            else
                fprintf('\ttrajectory in memory.\n');
            end
            data_buffer.trajectory=reshape(data_buffer.trajectory,...
                [3,  data_buffer.headfile.ray_length,...
                data_buffer.headfile.rays_per_volume]);
            %% create a key centered frequencey cutoff filter,
            % when we dont have enough data to be centered we will circ shift
            % appropriatly
            opt_struct.radial_filter_postfix='';
            radial_filter_modifier=1;
            if ~isprop(data_buffer,'cutoff_filter')
                nyquist_cutoff=25;
                data_buffer.addprop('cutoff_filter');
                cutoff_filter=ones(data_buffer.headfile.ray_length,...
                    data_buffer.headfile.rays_per_block,...
                    data_buffer.headfile.ray_blocks_per_volume);
                if ischar(opt_struct.radial_filter_method)                
                    if strcmp(opt_struct.radial_filter_method,'UFC')
                        %%% UFC equivalent
                        cut_key_indices=[1:floor(data_buffer.headfile.ray_blocks_per_volume/2) ceil(data_buffer.headfile.ray_blocks_per_volume/2)+1:data_buffer.headfile.ray_blocks_per_volume];
                        opt_struct.radial_filter_postfix='_UFC';
                    elseif strcmp(opt_struct.radial_filter_method,'VFC')
                        %%% VCF equilvalent missing.
                        warning('VFC not implimented, using none.');
                        %cut_key_indices=[1:floor(data_buffer.headfile.ray_blocks_per_volume/2) ceil(data_buffer.headfile.ray_blocks_per_volume/2)+1:data_buffer.headfile.ray_blocks_per_volume];
                        opt_struct.radial_filter_postfix='_UFC';
                    else
                        error('Unrecognized radial filter method UFC and VFC supported');
                    end
                    radial_filter_modifier=data_buffer.headfile.ray_blocks_per_volume;
                    cutoff_filter(1:nyquist_cutoff,:,cut_key_indices)=0;
                end
                data_buffer.cutoff_filter=logical(cutoff_filter);
                %         data_buffer.cutoff_filter=reshape(data_buffer.trajectory,);
                clear cutoff_filter;
            end
            %% Calculate/load dcf
            % data_buffer.dcf=sdc3_MAT(data_buffer.trajectory, opt_struct.iter, x, 0, 2.1, ones(ray_length, data_buffer.headfile.rays_acquired_in_total));
            iter=data_buffer.headfile.radial_dcf_iterations;
          
            if ~isprop(data_buffer,'dcf')
                dcf_file_path=[trajectory_file_path '_dcf_I' num2str(iter) opt_struct.radial_filter_postfix '.mat' ];
                if opt_struct.dcf_by_key
                    data_buffer.trajectory=reshape(data_buffer.trajectory,[3,...
                        ray_length,...
                        data_buffer.headfile.rays_per_block,...
                        data_buffer.headfile.ray_blocks]);
                    dcf_file_path=[trajectory_file_path '_dcf_by_key_I' num2str(iter) '.mat'];
                end
                dcf=zeros(ray_length,data_buffer.headfile.rays_per_volume,radial_filter_modifier);
                %             t_struct=struct;
                %             dcf_struct=struct;
                %             for k_num=1:data_buffer.header.ray_blocks_per_volume
                %                 t_struct.(['key_' k_num])=squeeze(data_buffer.trajectory(:,:,k_num,:));
                %                 dcf_struct.(['key_' k_num])=zeros(data_buffer.headfile.rays_acquired_in_total,rays_length);
                %             end
                traj=data_buffer.trajectory;
                % permute(repmat(data_buffer.cutoff_filter,[1,3]),[4 1 2 3])
                %                 traj(data_buffer.cutoff_filter==0)=NaN;
                traj(permute(reshape(repmat(data_buffer.cutoff_filter,[3,1,1,1]),[ray_length,...
                    3, data_buffer.headfile.rays_per_block,...
                    data_buffer.headfile.ray_blocks]),[2 1 3 4])==0)=NaN;
                % for filter_key=1:radial_filter_modifier

                if exist(dcf_file_path,'file')&& ~opt_struct.dcf_recalculate
                    fprintf('Loading dcf to save effort.\n');
                    t_ldcf=tic;
                    load(dcf_file_path);
                    fprintf('DCF loaded in %f seconds.\n',toc(t_ldcf));
                    save_dcf=false;
                    clear t_ldcf;
                elseif ~opt_struct.dcf_by_key % && ~opt_struct.dcf_recalculate
                    fprintf('Calculating DCF...\n');
                    t_cdcf=tic;
                    try
                        dcf=sdc3_MAT(traj, iter, d_struct.x, 0, 2.1, ones(size(dcf)));
                    catch err
                        error('Failed to calculate dcf');
                    end
                    fprintf('DCF completed in %f seconds. \n',toc(t_cdcf));
                    save_dcf=true;
                    clear t_cdcf;
                else
                    if matlabpool('size')==0 && opt_struct.matlab_parallel
                        matlab_pool_size=d_struct.c;
                        try
                            matlabpool('local',matlab_pool_size)
                        catch err
                            err_m=[err.message ];
                            for e=1:length(err.stack)
                                err_m=sprintf('%s\n \t%s:%i',err_m,err.stack(e).name,err.stack(e).line);
                            end
                            warning('Matlab pool failed to open with message, %s',err_m);
                        end
                    end
                    
                    clear e err err_m;
                    fprintf('Calculating DCF per key...\n');
                    dcf_times=zeros(1,data_buffer.headfile.ray_blocks_per_volume);
                    try
                        for k_num=1:data_buffer.headfile.ray_blocks_per_volume
                            t_kdcf=tic;
                            dcf(:,:,k_num)=sdc3_MAT(squeeze(traj(:,:,:,k_num)), iter, d_struct.x, 0, 2.1, ones(ray_length,data_buffer.headfile.rays_per_block));
                            %                     dcf(:,:,k_num)=reshape(temp,[ray_length,...
                            %                         data_buffer.headfile.rays_per_block...
                            %                         ]); % data_buffer.headfile.ray_blocks/data_buffer.headfile.ray_blocks_per_volume could also be total_rays/rays_per_block
                            dcf_times(k_num)=toc(t_kdcf);
                            fprintf('DCF for key %d completed in %f seconds. \n',k_num,dcf_times(k_num));
                            %fprintf('Percent Complete %0.2f',dcf_times(k_num),100*numel(dcf_times(dcf_times~=0))/numel(dcf_times)
                            % this print is not parfor compatible because we're
                            % checking the indexes of dcf_times. too bad it'd be a
                            % great way to check who's done.
                        end
                    catch err
                        error('Failed to calculate dcf');
                    end
                    %%% save dcf just because
                    fprintf('dcf took %f seconds, un-parallel code would have taken %f seconds.\n',mean(dcf_times),sum(dcf_times));
                    save_dcf=true;
                    clear t_ldcf k_num dcf_times;
                end
                if save_dcf
                    t_sdcf=tic;
                    save(dcf_file_path,'dcf','-v7.3');
                    %set permissions to all writeable here.
                    fprintf('DCF saved in %f seconds\n',toc(t_sdcf));
                    clear t_sdcf;
                end
                data_buffer.addprop('dcf');
                data_buffer.dcf=dcf;
                clear save_dcf temp k_num dcf traj err;
                %             data_buffer.dcf=sdc3_MAT(t_struct.(['key_' k_num), opt_struct.iter, x, 0, 2.1);
                %             data_buffer.dcf=reshape(data_buffer.dcf,[data_buffer.headfile.ray_acquired_in_total,ray_length]);
            else
                fprintf('\tdcf in memory.\n');
            end
            data_buffer.trajectory=reshape(data_buffer.trajectory,[3,ray_length,rays_per_block,data_buffer.headfile.ray_blocks_per_volume]);
            data_buffer.dcf=reshape(data_buffer.dcf,[ray_length,rays_per_block,data_buffer.headfile.ray_blocks_per_volume]);
        end
        %% prep keyhole trajectory
        if ( regexp(scan_type,'keyhole'))
            % set up a binary array to mask points for the variable cutoff
            % this would be ray_length*keys*rays_per_key array
            % data_buffer.addprop('vcf_mask');
            % data_buffer.vcf_mask=calcmask;
            % frequency. Just ignoring right now
            if( ~regexp(data_buffer.headfile.([data_tag 'vol_type']),'.*radial.*'))
                error('Non-radial keyhole not supported yet');
            end
%             data_buffer.trajectoryectory=reshape(data_buffer.trajectoryectory,[3 ,data_buffer.headfile.ray_blocks_per_volume,data_buffer.headfile.ray_length]);
                        
        end
        %%% pre regrid data save.
        %     if opt_struct.display_kspace==true
        %         input_kspace=reshape(data_buffer.data,input_dimensions);
        %     end
        %% reformat/regrid kspace to cartesian
        % perhaps my 'regrid' should be re-named to 'reformat' as that is
        % more accurate especially for cartesian. 
        if ~opt_struct.skip_regrid
            if num_chunks>1
                data_buffer.headfile.processing_chunk=chunk_num;
            end
            rad_regid(data_buffer,c_dims);
            if  regexp(vol_type,'.*radial.*')
                if num_chunks==1
                    fprintf('Clearing traj,dcf and radial kspace data\n');
                    data_buffer.trajectory=[];
                    data_buffer.dcf=[];
                    data_buffer.radial=[];
                end
            end
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
            fprintf('Slice removal occured, updating zdim %f to %f,',d_struct.z,d_struct.z-1);
            d_struct.z=d_struct.z-1;
            data_buffer.headfile.dim_Z=d_struct.z;
            data_buffer.input_headfile.dim_Z=d_struct.z;
            dim_text='';
            for i=1:length(opt_struct.output_order)
                
                if ~strcmp(opt_struct.output_order(i),'z')
                    dim_text=[dim_text ':,'];
                else
                    dim_text=[dim_text '1:end-1,'];
                end
            end
%             dims=size(data_buffer.data);
dim_text=dim_text(1:end-1);
%%% this eval is an ugly way to handle our remove slice problem, a good
%%% solution should be found in the future. 
            data_buffer.data=eval([ 'data_buffer.data(' dim_text ')']);
%             dims(strfind(opt_struct.output_order,'z'))=dims(strfind(opt_struct.output_order,'z'))-1;
%             data_buffer.data=reshape(data_buffer.data,dims);
        end
        %% handle echo asymmetry
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
                pause(opt_struct.warning_pause);
                
                
                %do asym stuff...
            end
        else
            disp('No asymmetry handling');
        end
        %% kspace shifting
        %opt_struct.kspace_shift
        if min(opt_struct.kspace_shift) <0 || max(opt_struct.kspace_shift) > 0
            warning('Kspace shifting choosen. Very uncertain of consequences. Custom output order not supported! Radial not supported. Multi volume/channel not supported.');
            pause(opt_struct.warning_pause);
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
            dim_select.x=':';
            dim_select.y=':';
            figure(1);colormap gray;
            for tn=1:d_struct.t
                dim_select.t=tn;
                for zn=1:d_struct.z
                    dim_select.z=zn;
                    for cn=1:d_struct.c
                        dim_select.c=cn;
                        for pn=1:d_struct.p
                            dim_select.p=pn;
                            fprintf('z:%d c:%d p:%d\n',zn,cn,pn);
                            if opt_struct.skip_regrid
                                kslice=data_buffer.data(dim_select.(input_order(1)),dim_select.(input_order(2)),...
                                    dim_select.(input_order(3)),dim_select.(input_order(4)),...
                                    dim_select.(input_order(5)),dim_select.(input_order(6)));
                            else
                                kslice=data_buffer.data(...
                                    dim_select.(opt_struct.output_order(1)),...
                                    dim_select.(opt_struct.output_order(2)),...
                                    dim_select.(opt_struct.output_order(3)),...
                                    dim_select.(opt_struct.output_order(4)),...
                                    dim_select.(opt_struct.output_order(5)),...
                                    dim_select.(opt_struct.output_order(6)));
                            end
                            %kslice(1:size(data_buffer.data,1),size(data_buffer.data,2)+1:size(data_buffer.data,2)*2)=input_kspace(:,cn,pn,zn,:,tn);
                            imagesc(log(abs(squeeze(kslice)))), axis image;
                            %                             fprintf('.');
                            pause(4/d_struct.z/d_struct.c/d_struct.p);
                            %                         pause(1);
                            %                         imagesc(log(abs(squeeze(input_kspace(:,cn,pn,zn,:,tn)))));
                            %                             fprintf('.');
                            %                         pause(4/z/d_struct.c/d_struct.p);
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
            if ~isprop(data_buffer,'kspace')
                filter_input='data';
            else
                filter_input='kspace';
            end
            %  dim_string=sprintf('%d ',size(data_buffer.(filter_input),1),size(data_buffer.(filter_input),2),size(data_buffer.(filter_input),3));
            dim_string=sprintf('%d ',size(data_buffer.(filter_input)));
%             for d_num=4:length(output_dimensions)
%                 dim_string=sprintf('%s %d ',dim_string,output_dimensions(d_num));
%             end ; clear d_num;
            fprintf('Performing fermi filter on volume with size %s\n',dim_string );
            
            if strcmp(vol_type,'2D')
                % this requires regridding to place volume in same dimensions as the output dimensions
                % it also requires the first two dimensions of the output to be to be xy.
                % these asumptions may not always be true. 
                data_buffer.data=reshape(data_buffer.data,[ output_dimensions(1:2) prod(output_dimensions(3:end))] );
                data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
                    opt_struct.filter_width,opt_struct.filter_window,true);
                data_buffer.data=reshape(data_buffer.data,output_dimensions );
            %elseif strcmp(vol_type,'3D')
            elseif regexpi(vol_type,'3D|4D');
                 fermi_filter_isodim2_memfix_obj(data_buffer,...
                    opt_struct.filter_width,opt_struct.filter_window,false);

%                 data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
%                     opt_struct.filter_width,opt_struct.filter_window,false);
%             elseif strcmp(vol_type,'4D')
%                 data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
%                     opt_struct.filter_width,opt_struct.filter_window,false);
            elseif regexpi(vol_type,'radial');
                if isfield(data_buffer.headfile,'processing_chunk')
                    t_s=data_buffer.headfile.processing_chunk;
                    t_e=data_buffer.headfile.processing_chunk;
                else
                    t_s=1;
                    t_e=d_struct.t;
                end
                % for time_pt=1:d_struct.t
                for time_pt=t_s:t_e
                    %%%% load per time point radial here .... ?
%                     if d_struct.t>1
%                         load(['/tmp/temp_' num2str(time_pt) '.mat' ],'data','-v7.3');
%                         data_buffer.data=data;
%                     end
                    fermi_filter_isodim2_memfix_obj(data_buffer,...
                        opt_struct.filter_width,opt_struct.filter_window,false);
%                     if d_struct.t>1
%                         save(['/tmp/temp_' num2str(time_pt) '.mat' ],'data','-v7.3');
%                     end
                end
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
        if ~opt_struct.skip_fft
            %% fft
            fprintf('Performing FFT on');
            if strcmp(vol_type,'2D')
                fprintf('%s volumes\n',vol_type);
                if ~exist('img','var') || numel(img)==1;
                    img=zeros(output_dimensions);
                end
                %         xyzcpt
                dim_select.z=':';
                dim_select.x=':';
                dim_select.y=':';
                for cn=1:d_struct.c
                    dim_select.c=cn;
                    if opt_struct.debug_mode>=10
                        fprintf('channel %d working...\n',cn);
                    end
                    for tn=1:d_struct.t
                        dim_select.t=tn;
                        for pn=1:d_struct.p
                            dim_select.p=pn;
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
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6)))=fftshift(ifft2(fftshift(data_buffer.data(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))))));
                            if opt_struct.debug_mode>=20
                                fprintf('\n');
                            end
                        end
                    end
                end
                data_buffer.data=img;
                clear img;
            elseif regexp(vol_type,'.*radial.*')
                fprintf('%s volumes\n',vol_type);
                fprintf('Radial fft optimizations\n');
                %% timepoints
                if isfield(data_buffer.headfile,'processing_chunk')
                    t_s=data_buffer.headfile.processing_chunk;
                    t_e=data_buffer.headfile.processing_chunk;
                else
                    t_s=1;
                    t_e=d_struct.t;
                end
                %%% when we are over-gridding(almost all the time) we
                %%% should have a kspace property to work from. 
                if ~isprop(data_buffer,'kspace')
                    fft_input='data';
                else
                    fft_input='kspace';
                end
                for time_pt=t_s:t_e
                    %% multi-channel only
                    %data_buffer.headfile.radial_grid_oversample_factor;
                    dims=size(data_buffer.(fft_input));
                    [c_s,c_e]=center_crop(dims(1),d_struct.x);
                    if numel(size(data_buffer.(fft_input)))>3
                        data_buffer.(fft_input)=reshape(data_buffer.(fft_input),[dims(1:3) prod(dims(4:end))]);
                    end
                    % these per volume loops appear to cause a memory double.
                    if numel(data_buffer.data) ~= prod(output_dimensions)
                        data_buffer.data=[];
                        fprintf('Prealocate output data\n');
                        % data_buffer.data=zeros([ d_struct.x,d_struct.x,d_struct.x  prod(dims(4:end))],'single');
                        % data_buffer.data=complex(data_buffer.data,data_buffer.data);
                        data_buffer.data=complex(zeros([ d_struct.x,d_struct.x,d_struct.x  prod(dims(4:end))],'single'));
                    end
                    t_fft=tic;
                    for v=1:size(data_buffer.kspace,4)
                        temp =fftshift(ifftn(data_buffer.(fft_input)(:,:,:,v)));
                        data_buffer.data(:,:,:,v)=temp(c_s:c_e,c_s:c_e,c_s:c_e);
                    end
                end
                fprintf('FFT finished in %f seconds\n',toc(t_fft));
                data_buffer.headfile.grid_crop=[c_s,c_e];
                clear c_s c_e dims temp;
            else
                fprintf('%s volumes\n',vol_type);
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
%                     fprintf('permuting...');% permute calculated instead, instead of static % img=permute(img,[ 1 3 2 ]);
%                     permute_code=zeros(size(input_order));
%                     for d_num=1:length(input_order)
%                         permute_code(d_num)=strfind(input_order,opt_struct.output_order(d_num));
%                     end
%                     data_buffer.data=permute(data_buffer.data,permute_code ); % put in image order.
%                     clear d_num permute_code;
                    if ~opt_struct.skip_resort_z
                    fprintf('setting z resort...');
                    objlistz=[d_struct.z/2+1:d_struct.z 1:d_struct.z/2 ];
                    else 
                        objlistz=1:d_struct.z;
                    end
%                     data_buffer.data=circshift(data_buffer.data,[ 0 y/2 0
%                     ]);.
%                     objlisty=1:d_struct.y;
                    if ~opt_struct.skip_resort_y
                        fprintf('setting y resort...');
                        objlisty=[d_struct.y/2+1:d_struct.y 1:d_struct.y/2 ];
                    else 
                        objlisty=1:d_struct.y;
                    end
                    data_buffer.data(:,objlisty,objlistz,:,:,:,:)=data_buffer.data;
                    if ~opt_struct.skip_rotate
                    fprintf('rotating image by 90...');
                    data_buffer.data=imrotate(data_buffer.data,90);
                    end
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
                if strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')&& ~opt_struct.skip_resort
                    %             z=size(it,3);
                    % for SE_ scans these values have been true 1 time(s)
                    if d_struct.z>1 && mod(d_struct.z,2) == 0
                        objlistz=[1:d_struct.z/2;d_struct.z/2+1:d_struct.z];
                        objlistz=objlistz(:);
                        data_buffer.data=data_buffer.data(:,:,objlistz);
                    end
                    %             for i=1:64
                    %                 figure(6);
                    %                 imagesc(log(abs(it(:,:,i))));
                    %                 pause(0.18);
                    %             end
                    %             y=size(it,2);
                    if ~opt_struct.skip_resort_z
                        fprintf('setting z resort...');
                        objlistz=[d_struct.z/2+1:d_struct.z 1:d_struct.z/2 ];
                    else 
                        objlistz=1:d_struct.z;
                    end
                    data_buffer.data=data_buffer.data(:,objlistz,:);
                    %             for i=1:64
                    %                 figure(6);
                    %                 imagesc(log(abs(it2(:,:,i))));
                    %                 pause(0.18);
                    %             end
                end
            end
            %% display result images
            if opt_struct.display_output==true
                dim_select.x=':';
                dim_select.y=':';
                for zn=1:d_struct.z
                    dim_select.z=zn;
                    for tn=1:d_struct.t
                        dim_select.t=tn;
                        for pn=1:d_struct.p
                            dim_select.p=pn;
                            for cn=1:d_struct.c
                                dim_select.c=cn;
                                imagesc(log(abs(squeeze(data_buffer.data(...
                                    dim_select.(opt_struct.output_order(1)),...
                                    dim_select.(opt_struct.output_order(2)),...
                                    dim_select.(opt_struct.output_order(3)),...
                                    dim_select.(opt_struct.output_order(4)),...
                                    dim_select.(opt_struct.output_order(5)),...
                                    dim_select.(opt_struct.output_order(6))...
                                    ))))), axis image;
                                pause(4/d_struct.z/d_struct.c/d_struct.p);
                                
                            end
                        end
                        fprintf('%d %d\n',zn,tn);
                    end
                end
            end
            %% combine channel data
            if ~opt_struct.skip_combine_channels && d_struct.c>1
                if regexp(vol_type,'2D|3D')
                    % To respect the output order we use strfind.
                    fprintf('combining channel complex data with method %s\n',opt_struct.combine_method);
                    dind=strfind(opt_struct.output_order,'c'); % get dimension index for channels
                    %%% Removed the squeeze from our combine operation, better
                    %%% to maintain the dimensions of the data object.
                    if regexpi(opt_struct.combine_method,'mean')
                        % data_buffer.data=squeeze(mean(abs(data_buffer.data),dind));
                        data_buffer.data=mean(abs(data_buffer.data),dind);
                    elseif regexpi(opt_struct.combine_method,'square_and_sum')
                        % data_buffer.data=squeeze(mean(data_buffer.data.^2,dind));
                        data_buffer.data=sqrt(sum(abs(data_buffer.data).^2,dind));
                    else
                        %%% did not combine
                    end
                else
                    fprintf('Radial channel combine');
                    dind=4;
                    if isfield(data_buffer.headfile,'processing_chunk')
                        t_s=data_buffer.headfile.processing_chunk;
                        t_e=data_buffer.headfile.processing_chunk;
                    else
                        t_s=1;
                        t_e=d_struct.t;
                    end
                    % for time_pt=1:d_struct.t
                    for time_pt=t_s:t_e
%                         if d_struct.t>1
%                             load(['/tmp/temp_img' num2str(time_pt) '.mat' ],'data','-v7.3');
%                             data_buffer.data=data;
%                         end
                        if regexpi(opt_struct.combine_method,'mean')
                            % data_buffer.data=squeeze(mean(abs(data_buffer.data),dind));
                            data_buffer.data=mean(abs(data_buffer.data),dind);
                        elseif regexpi(opt_struct.combine_method,'square_and_sum')
                            % data_buffer.data=squeeze(mean(data_buffer.data.^2,dind));
                            data_buffer.data=sqrt(sum(abs(data_buffer.data).^2,dind));
                        else
                            %%% did not combine
                        end
%                         if d_struct.t>1
%                             %                         data=data_buffer.data;
%                             data=reshape(data_buffer.data,dims);
%                             save(['/tmp/temp_img' num2str(time_pt) '.mat' ],'data','-v7.3');
%                         end
                    end
                    fprintf('\tComplete.\n');
                end
                clear dind data;
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
            %% chunk save
            % while chunks are volumes this is entirely unnecessary.
            %             if num_chunks>1
            %                 fprintf('Saving chunk %d...',chunk_num);
            %                 work_dir_img_path_base=[ data_buffer.headfile.work_dir_path '/C' data_buffer.headfile.U_runno ] ;
            %                 save_complex(data_buffer.data,[work_dir_img_path_base '_' num2str(chunk_num) '.rp.out']);
            %                 fprintf('\tComplete\n');
            %             end
        else
           fprintf('Skipped fft');
           if opt_struct.remove_slice
               % even though we skipped the recon this will keep our
               % headfile value up to date.
               d_struct.z=d_struct.z-1;
               data_buffer.headfile.dim_Z=d_struct.z;
               data_buffer.input_headfile.dim_Z=d_struct.z;
           end
        end
        
    end % end skipload
    fprintf('Reconstruction Finished! Saving...');
    %% stich chunks together
    % this is not implimented yet.
    warning('this saving code is temporary it is not designed for chunks');
    %% save data
    % this needs a bunch of work, for now it is just assuming the whole pile of
    % data is sitting in memory awaiting saving, does not handle chunks or
    % anything correctly just now.
    
    %  mag=abs(raw_data(i).data);
    ij_prompt='';
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
        work_dir_img_path_base=[ data_buffer.headfile.work_dir_path '/' runno ] ;
        %% save uncombined channel niis.
        if ~opt_struct.skip_combine_channels && d_struct.c>1 && ~opt_struct.skip_recon && opt_struct.write_unscaled
            if ~exist([work_dir_img_path_base '.nii'],'file') || opt_struct.overwrite
                fprintf('Saving image combined with method:%s using %i channels to output work dir.\n',opt_struct.combine_method,d_struct.c);
                nii=make_nii(abs(data_buffer.data), [ ...
                    data_buffer.headfile.fovx/d_struct.x ...
                    data_buffer.headfile.fovy/d_struct.y ...
                    data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                save_nii(nii,[work_dir_img_path_base '.nii']);
            else
                warning('Combined Image already exists and overwrite disabled');
            end
        end
        
        max_mnumber=d_struct.t*d_struct.p-1;
        m_length=length(num2str(max_mnumber));
        if ~opt_struct.skip_combine_channels
            data_buffer.headfile.([data_tag 'volumes'])=data_buffer.headfile.([data_tag 'volumes'])/d_struct.c;
            d_struct.c=1;
        end
        %% ijmacro
        openmacro_path=sprintf('%s%s',work_dir_img_path_base ,'.ijm');
        if opt_struct.overwrite && exist(openmacro_path,'file')
            delete(openmacro_path);
        else
            warning('macro exists at:%s\n did you mean to enable overwrite?',openmacro_path);
        end
        %     end
        %        for tn=1:d_struct.t
        %         for cn=1:channels
        %             for pn=1:d_struct.p
%             'channels=1;\n',...
        openmacro_lines=strcat(...
            'channels=',num2str(d_struct.c),';\n' , ...
            'channel_alias="',opt_struct.channel_alias,'";\n',...
            'frames=', num2str(d_struct.t),';\n', ...
            'params=', num2str(d_struct.p),';\n', ...
            'slices=', num2str(d_struct.z),';\n', ...
            'volumes=', num2str(data_buffer.headfile.([data_tag 'volumes'])),';\n', ...
            'runno="', runno, '"',';\n', ...
            'runno_dir="', data_buffer.engine_constants.engine_work_directory, '/"+runno+""',';\n', ...
            'open_all_output="open";\n',...
            'if(slices==1){ open_all_output=""; }\n',...
            'sub_start=1',';\n', ...
            'sub_stop=sub_start+slices-1;\n', ...
            'for(framenum=1;framenum<=frames;framenum++) {\n', ...
            '    for(channelnum=1;channelnum<=channels;channelnum++) {\n', ...
            '    for(paramnum=1;paramnum<=params;paramnum++) {\n', ...
            '        if ( channels>1 ) { \n',...
            '            channel_code=substring(channel_alias,channelnum-1,channelnum);\n',...
            '        } else {\n',...
            '            channel_code="";\n',...
            '        }\n',...
            '        volumenum=(framenum-1)*params+paramnum;\n', ...
            '        if (volumes > 1 && volumes!=channels) {\n', ...
            '            num=d2s(volumenum-1,0);\n', ...
            '            digits=lengthOf(d2s(volumes/channels,0));\n', ...
            '            while(lengthOf(num)<digits && lengthOf(num) < 4 ) {\n', ...
            '               num="0"+num;\n', ...
            '            }\n', ...
            '            multi_suffix="_m"+num;\n', ...
            '        } else {\n', ...
            '          multi_suffix="";\n', ...
            '        }\n',...
            '\n', ...
            '        out_runno=""+runno+channel_code+multi_suffix;\n', ...
            '        output_dir=""+runno_dir+channel_code+multi_suffix+"/"+out_runno+"images";\n', ...
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
            '        rename(out_runno);\n',...
            '    }\n', ...
            '    }\n', ...
            '}\n', ...
            'run("Tile");\n', ...
            'if(slices==1){\n',...
            '    setSlice(round(slices/2);\n',...
            '}\n',...
            '\n',...
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
        %% write_unscaled_nD or independent_scaling
        dim_select.x=':';
        dim_select.y=':';
        dim_select.z=':';
        data_buffer.headfile.group_max_atpct='auto';
        data_buffer.headfile.group_max_intensity=0;
        if num_chunks==1
            if ~opt_struct.independent_scaling ||  ( opt_struct.write_unscaled_nD && ~opt_struct.skip_recon )
                data_buffer.headfile.group_max_atpct=0;
                for tn=1:d_struct.t
                    dim_select.t=tn;
                    for cn=1:d_struct.c
                        dim_select.c=cn;
                        for pn=1:d_struct.p
                            dim_select.p=pn;
                            tmp=abs(squeeze(data_buffer.data(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
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
                    fprintf('Writing debug outputs to %s\n',data_buffer.headfile.work_dir_path);
                    fprintf('\twrite_unscaled_nD save\n');
                    if ( strcmp(opt_struct.combine_method,'square_and_sum')|| strcmp(opt_struct.combine_method,'regrid')) && ~opt_struct.skip_combine_channels
                        nii=make_nii(abs(squeeze(data_buffer.data)), [ ...
                            data_buffer.headfile.fovx/d_struct.x ...
                            data_buffer.headfile.fovy/d_struct.y ...
                            data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                    else
                        nii=make_nii(log(abs(squeeze(data_buffer.data))), [ ...
                            data_buffer.headfile.fovx/d_struct.x ...
                            data_buffer.headfile.fovy/d_struct.y ...
                            data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                    end
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
        end
        %% save volumes
        % this could be changed to some kind of generic chunk along
        % dimension, then we could do a chunked dimension lookup using
        % dim_select.(chunk_d)
        if isfield(data_buffer.headfile,'processing_chunk')
            t_s=data_buffer.headfile.processing_chunk;
            t_e=data_buffer.headfile.processing_chunk;
        else
            t_s=1;
            t_e=d_struct.t;
        end
        % for time_pt=1:d_struct.t
        % need to change this around so that any piece can be the selected 
        % dimension for chunking on.
        for tn=t_s:t_e
            if num_chunks>1
                dim_select.t=1;
            else
                dim_select.t=tn;
            end
            for cn=1:d_struct.c
                dim_select.c=cn;
                for pn=1:d_struct.p
                    dim_select.p=pn;
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
                            dim_select.(opt_struct.output_order(1)),...
                            dim_select.(opt_struct.output_order(2)),...
                            dim_select.(opt_struct.output_order(3)),...
                            dim_select.(opt_struct.output_order(4)),...
                            dim_select.(opt_struct.output_order(5)),...
                            dim_select.(opt_struct.output_order(6))...
                            ));% pulls out one volume at a time.
                        %                         end
                    else
                        tmp='RECON_DISABLED';
                    end
                    %%%set channel header settings and mnumber codes for the filename
                    if d_struct.c>1
                        channel_code=opt_struct.channel_alias(cn);
                        if isfield(data_buffer.headfile,'U_specid')
                            s_exp='[0-9]{6}-[0-9]+:[0-9]+(;|)';
                            m_s_exp=cell(1,d_struct.c);
                            for rexp_c=1:d_struct.c
                                m_s_exp{rexp_c}=s_exp;
                            end
                            m_exp=strjoin(m_s_exp,';');
                            m_exp=['^' m_exp '$'];
                            if regexp(data_buffer.input_headfile.U_specid,m_exp)
                                specid_s=strsplit(data_buffer.input_headfile.U_specid,';');
                                data_buffer.headfile.U_specid=specid_s{cn};
                                data_buffer.headfile.U_specid_list=data_buffer.input_headfile.U_specid;
                                fprintf('Multi specid found in multi channel, assigning singular specid on output %s <= %s\n',data_buffer.headfile.U_specid,data_buffer.input_headfile.U_specid);
                            elseif regexp(data_buffer.headfile.U_specid,'.*;.*')
                                warning('Multi specid found in multi channel, but not the right number for the number of channels, \n\ti.e %s did not match regex. %s\n',data_buffer.input_headfile.U_specid,m_exp);

                            end
                            clear s_exp m_s_exp;
                        end

                    else
                        channel_code='';
                    end
                    %%%
                    %
                    if opt_struct.integrated_rolling
                        fprintf('Integrated Rolling code\n');
                        channel_code_r=[channel_code '_'];
                        if ~isfield(data_buffer.headfile, [ 'roll' channel_code_r 'corner_X' ])
                            input_center=get_wrapped_volume_center(tmp);
                            ideal_center=[d_struct.x/2,d_struct.y/2,d_struct.z/2];
                            shift_values=ideal_center-input_center;
                            for di=1:length(shift_values)
                                if shift_values(di)<0
                                    shift_values(di)=shift_values(di)+size(data_buffer.data,di);
                                end
                            end
                            data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' ])=shift_values(strfind(opt_struct.output_order,'x'));
                            data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' ])=shift_values(strfind(opt_struct.output_order,'y'));
                            data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' ])=shift_values(strfind(opt_struct.output_order,'z'));
                        else
                            shift_values=[ data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' ])
                            data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' ])
                            data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' ])
                            ];
                        end
                        fprintf('\tshift by :');
                        fprintf('%d,',shift_values);
                        fprintf('\n');
                        tmp=circshift(tmp,round(shift_values));
                    end
                    m_number=(tn-1)*d_struct.p+pn-1;
                    if d_struct.t> 1 || d_struct.p >1
                        m_code=sprintf(['_m%0' num2str(m_length) '.0f'], m_number);
                    else
                        m_code='';
                    end
                    space_dir_img_name =[ runno channel_code m_code];
                    

                                        
                    data_buffer.headfile.U_runno=space_dir_img_name;
                    
                    space_dir_img_folder=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '/' space_dir_img_name 'images' ];
                    work_dir_img_name_per_vol =[ runno channel_code m_code];
                    work_dir_img_path_per_vol=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '.work/' space_dir_img_name 'images' ];
                    work_dir_img_path=[work_dir_img_path_base channel_code m_code];
                    if d_struct.c > 1
                        data_buffer.headfile.work_dir=data_buffer.engine_constants.engine_work_directory;
                        data_buffer.headfile.runno_base=runno;
                    end
                    
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
                        fprintf('Writing debug outputs to %s\n',data_buffer.headfile.work_dir_path);
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
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                ))));
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path '_kspace.nii']);
                    end
                    %%% kimage_unfiltered
                    if opt_struct.write_kimage_unfiltered  && ~opt_struct.skip_load
                        fprintf('\twrite_kimage_unfiltered make_nii\n');
                        nii=make_nii(log(abs(data_buffer.kspace_unfiltered(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                ))));
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path '_kspace_unfiltered.nii']);
                    end
                    %%% unscaled_nii_save
                    if ( opt_struct.write_unscaled && ~opt_struct.skip_recon ) %|| opt_struct.skip_write_civm_raw
                        fprintf('\twrite_unscaled save\n');
                        nii=make_nii(abs(tmp), [ ...
                            data_buffer.headfile.fovx/d_struct.x ...
                            data_buffer.headfile.fovy/d_struct.y ...
                            data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
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
                        if ~opt_struct.skip_write_civm_raw || ~opt_struct.skip_write_headfile 
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
                        
                        dest=[space_dir_img_folder '/' space_dir_img_name '.headfile'];
                        fprintf('\twrite_headfile save \n\t\t%s\n',dest);
                        data_buffer.headfile.output_image_path=space_dir_img_folder;
                        write_headfile(dest,data_buffer.headfile,0);
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
                        fprintf(ofid,'%i %i : image dimensions.\n',d_struct.x,d_struct.y);
                        fprintf(ofid,'%i : image set zdim.\n', d_struct.z);
                        fprintf(ofid,'%i : histo_bins, %f : histo_percent\n',histo_bins,opt_struct.histo_percent);
                        fprintf(ofid,'x : user provided max voxel value? provided for max= none (if file used).\n');
                        fprintf(ofid,'%f : max voxel value used to construct histogram\n',data_buffer.headfile.group_max_intensity);
                        fprintf(ofid,' rad_mat convert_info_histo dump 2013/11/05\n');
                        fclose(ofid);
                        if ~recon_strategy.work_by_chunk
                            complex_to_civmraw(tmp,data_buffer.headfile.U_runno , ...
                                data_buffer.scanner_constants.scanner_tesla_image_code, ...
                                space_dir_img_folder,'',outpath,1,datatype)
                        end
                        
                    end
                    %%% convenience prompts

                    if ~opt_struct.skip_write_civm_raw
                        %write_archive_tag(runno,spacename, slices, projectcode, img_format,civmid)
                        runnumbers(rindx)={data_buffer.headfile.U_runno};
                        rindx=rindx+1;
                        
                    end
                    
                end
            end
        end
    else
        fprintf('No outputs written.\n');
    end

    if (num_chunks>1)
        fprintf('chunk_time:%0.2f\n',toc(time_chunk));
    end
end
%% convenience prompts

if ~opt_struct.skip_recon||opt_struct.force_ij_prompt
    % display ij call to examine images.
    [~,txt]=system('echo -n $ijstart');  %-n for no newline i think there is a smarter way to get system variables but this works for now.
    ij_prompt=sprintf('%s -macro %s',txt, openmacro_path);
    mat_ij_prompt=sprintf('system(''%s'');',ij_prompt);
end
if ~isempty(ij_prompt)&& ~opt_struct.skip_write_civm_raw
    fprintf('test civm image output from a terminal using following command\n');
    fprintf('  (it may only open the first and last in large sequences).\n');
    fprintf('\n\n%s\n\n\n',ij_prompt);
    fprintf('test civm image output from matlab using following command\n');
    fprintf('  (it may only open the first and last in large sequences).\n');
    fprintf('\n%s\n\n',mat_ij_prompt);
end
if ~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon && isfield(data_buffer.headfile,'U_code')
    archive_tag_output=write_archive_tag(runnumbers,...
        data_buffer.engine_constants.engine_work_directory,...
        d_struct.z,data_buffer.headfile.U_code,datatype,...
        data_buffer.headfile.U_civmid,false);
    fprintf('initiate archive from a terminal using following command, (should change person to yourself). \n\n\t%s\n\n OR run archiveme in matlab useing \n\tsystem(''%s'');\n',archive_tag_output,archive_tag_output);
    
    %%% sepearate the runnumberes by channel.
    %% post recon rolling
    if ~opt_struct.integrated_rolling || opt_struct.post_rolling
        %     sorted_runs=runno_group_sort(runnumbers);
        %     sort_str=strjoin(sorted_runs',' ');
        %     chan_strings=strsplit(sort_str,'#');
        chan_strings=cell(1,d_struct.c);
        
        %http://www.mathworks.com/help/images/ref/regionprops.html#bqkf8ln
        cmd_list=cell(1,d_struct.c);
        
        

        for c_r=1:d_struct.c
            run_postexp='';
            data_postfix='';
            if d_struct.t > 1 || d_struct.p > 1
                run_postexp= '_m[0-9]+';
                data_postfix='_m0' ;
            end
            if ( d_struct.c > 1 )
                data_postfix=[opt_struct.channel_alias(c_r) data_postfix];
                run_postexp=[opt_struct.channel_alias(c_r) run_postexp];
%                 data_postfix='';
            end
            %%% need to move the regexp handcling for non channel
            %%% images here.
            run_regexp=['([^ ]*'  run_postexp ')+'];
            runs{c_r}=regexp(strjoin(sort(runnumbers)',' '),run_regexp,'tokens');
            for j=1:length(runs{c_r})
                chan_strings{c_r}{j}=runs{c_r}{j}{1};
            end
            if length(chan_strings{c_r})>1
               run_string=strjoin(chan_strings{c_r},' ');
            else 
                run_string=chan_strings{c_r}{1};
            end
            %%%% not finding c position programatically right now, should fix that.
            %             new_center=[0,0,0];
            data_vol=data_buffer.data(:,:,:,c_r,1,1);

            if opt_struct.integrated_rolling && opt_struct.post_rolling
                disk_path= [ data_buffer.headfile.work_dir '/' ...
                    data_buffer.headfile.runno_base data_postfix '/' ...
                    data_buffer.headfile.runno_base data_postfix 'images' '/' ];
                fprintf('Crazy double roll calculation requested, loading path%s\n',disk_path);
                data_vol=read_civm_image(disk_path );
            end
            if opt_struct.roll_with_centroid
                new_center=get_volume_centroid(data_vol);
            else
                new_center=get_wrapped_volume_center(data_vol);
            end
            %%%% could use hist followed by extrema or derivative and find
            center=[d_struct.x/2,d_struct.y/2,d_struct.z/2];
            diff=new_center-center;
            %         diff(3)=-diff(3);
            %         diff(2)=-diff(2);
            for di=1:length(diff)
                if diff(di)<0
                    diff(di)=diff(di)+size(data_buffer.data,di);
                end
            end
            roll.x(c_r)=round(diff(1));
            roll.y(c_r)=round(diff(2));
            roll.z(c_r)=round(diff(3));
            
            %     xroll=diff(1)+d_struct.x;
            %     yroll=diff(2)+d_struct.y;
            %     xroll=round(centroid(1)-d_struct.x/2);
            %     yroll=d_struct.y-round(centroid(2)-d_struct.y/2);
            %     zroll=round(centroid(3)-d_struct.z/2);
            cmd_list{c_r}=sprintf('roll_3d -x %d -y %d -z %d %s;',roll.x(c_r),roll.y(c_r), roll.z(c_r), run_string);
        end
        fprintf('Use terminal to run roll_3d with command, (Replace the number''s with your deisred roll, example values are a best guess based on a find minimum calculation.)\n%s\n\n', strjoin(cmd_list,'\n'));
        fprintf('OR run roll_3d in matlab using \n');
        
        roll_prompt='';
        for cmd_n=1:length(cmd_list)
            roll_prompt=sprintf('%ssystem(''%s'');\n',roll_prompt,cmd_list{cmd_n});
        end
        fprintf('%s',roll_prompt);
    end
    
end


%% End of line set output
%%% handle image return type at somepoint in future using image_return_type
%%% option, for now we're just going to magnitude. 
img=abs(data_buffer.data);
success_status=true;
fprintf('\nTotal rad_mat time is %f second\n',toc(rad_start));