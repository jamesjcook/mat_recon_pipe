function [success_status,img, data_buffer]=rad_mat(scanner,runno,input_data,options)
% [success_status,img, buffer]=RAD_MAT(scanner,runno,input,options)
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
%          - list file support? List in radish_scale_bunch format? via
%          listmaker.
% option   - for a list and explaination use 'help'.
%
% status   - status 1 for success, and 0 for failures.
%            (following matlab boolean, true/false)
% img      - complex output volume in the output_order, in chunked recon will only
%            be the last chunk
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
% testing
% testing
% testing
% testing
% testing
% specifically for GRE aspect and RARE Bruker scans
% testing
% add scanner image reformat support, could add inverse fft to load step,
% testing
% did i mention testing?
if verLessThan('matlab', '8.1.0.47')
    error('Requires Matlab version 8.1.0.47 (2013a) or newer. Relies heavily on string handling functions new in 2013. They could be re-implemented if you''re so inclined.');
end
%% arg check or help
if ( nargin<3)
    if nargin==0
        help rad_mat; %('','','',{'help'});
    else
        rad_mat('','','','help');
    end
end
%% data reference setup
% img=0;
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
data_buffer.headfile.U_scanner=scanner;
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
warn_string='';
err_string='';
if length(runno)>16
    warn_string=sprintf('%s\nRunnumber too long for db\n This scan will not be archiveable.',warn_string);
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
    'skip_write_temp_headfile','Skip writing our temporary headfile before we try to load our data and reconstruct it'
    'write_unscaled',         ' save unscaled nifti''s in the work directory '
    'write_unscaled_nD',      ' save unscaled multi-dimensional nifti in the work directory '
    'display_kspace',         ' display re-gridded kspace data prior to reconstruction, will showcase errors in regrid and load functions'
    'display_output',         ' display reconstructed image after the resort and transform operations'
    'regrid_method',          ' redgrid function used, scott or sdc3_mat'
    'radial_mode',            ' radial regrid mode, fast or good. A simple parameter swap based on Scott''s recommendations.'
    'grid_oversample_factor', ' oversample grid multiplier, only used for radial regrid has a default of 3'
    '',                       ''
    };
beta_options={
    '',                       'Secondary, new, experimental options'
    'planned_ok',             ' special option which must be early in list of options, controls whether planned options are an error'
    'unrecognized_ok',        ' special option which must be early in list of options, controls whether arbitrary options are an error, this is so that alternate child functions could be passed the opt_struct variable and would work from there. This is also the key to inserting values into the headfile to override what our perlscript generates. '
    'debug_mode',             ' verbosity. use debug_mode=##'
    'study',                  ' set the bruker study to pull from, useful if puller fails to find the correct data'
    'alt_encoding_assign',    ' switch encoding assignment from data=data(encode)  to  data(encode)=data'
    'use_new_bruker_padding', ' use padding calculation based on information from john. Sometimes this will help a scan get through. Its missing one critiacl piece from bruker, where they tell us which dimensions are lumpte dtogether before paddint.  '
    'U_dimension_order',      ' input_dimension_order will override whatever the perl script comes up with.'
    'vol_type_override',      ' if the processing script fails to guess the proper acquisition type(2D|3D|4D|radial) it can be specified.'
    'kspace_shift',           ' x:y:z shift of kspace, use kspace_shift=##:##:##' 
    'ignore_kspace_oversize', ' when we do our sanity checks on input data ignore kspace file being bigger than expected, this currently must be on for aspect data'
    'integrated_rolling',     ' use integrated image rolling, rolls images per channel of output PRIOR to saving. behavior likely bad with single specimen multi-coil images. '
    'post_rolling',           ' calculate roll post save to be run through roll_3d, if integrated_rolling is on this should calculate to zero(+/-1).'
    'output_order',           ' specify the order of your output dimensions. Default is xyzcpt. use output_oder=xyzcpt.'
    'channel_alias',          ' list of values for aliasing channels to letters, could be anything using this'
    'combine_method',         ' specify the method used for combining multi-channel data. supported modes are square_and_sum, or mean, use  combine_method=text'
    'combine_kspace',         ' combine dimensions in kspace, use combine_kspace=text, text is a string at least one character long. Remember p is used for changing parameters'
    'combine_kspace_method',  ' mechod to combine kspace, should be comma separated list if there is more than one.'
    'skip_combine_channels',  ' do not combine the channel images'
    'omit_channels',          ' ignore bad channels. a comma separated list, ex omit_channels=2,3,4'
    'write_complex',          ' should the complex output be written to th work directory. Will be written as rp(or near rp file) format.'
    'do_aspect_freq_correct', ' perform aspect frequency correction.'
    'param_file',             ' GUI param file input'
    'pre_defined_headfile',   ' instead of loading the scanner data header load a pre-generated one.'
    'no_scanner_header',      ' the scanner header is invalid un-loadable or misisng for some reason, all required hf keys would need to be specified as options following the unrecognized_ok option. '
    'skip_load'               ' do not load data, implies skip regrid, skip filter, skip recon and skip resort'
    'skip_regrid',            ' do not regrid'
    'skip_filter',            ' do not filter data sets.'
    'force_filter',           ' if we specify phase filter is set to off, and we dont write civm raw, this inverts that behavior.' 
    'skip_fft',               ' do not fft data, good short hand when saving kspace files'
    'skip_postreform',        ' for images requireing a call to refromer, skip that step.'
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
    'display_radial_filter',  ' show the radial filter via imshow'
    'open_volume_limit',      ' override the maximum number of volumes imagej will open at a time,default is 36. use open_volume_limit=##'
    'warning_pause',          ' length of pause after warnings (default 3). Errors outside matlab from the perl parsers are not effected. use warning_pause=##'
    'no_navigator',           ' aspect spinecho? scans have a navigator of 50 points, this forces that off.'
    'ij_custom_macro',        ' use custom macro to load file instead of CIVM_RunnoOpener macro'
    'idf',                    ' Interactive data fiddling(or insert word of preference): Just before fft, we may need to edit kspace for some reason, The puts a debug stop right there. '
    '',                       ''
    };
planned_options={
    '',                       'Options we may want in the future, they might have been started. They could even be finished and very unpolished. '
    'write_phase',            ' write a phase output to the work directory'
    'fp32_magnitude',         ' write fp32 civm raws instead of the normal ones'
    'write_kimage',           ' write the regridded and filtered kspace data to the work directory.'
    'write_kspace_complex',   ' instead of a kspace magnitude, write it as a complex nifti'
    'write_kimage_unfiltered',' write the regridded unfiltered   kspace data to the work direcotry.'
    'write_complex_component',' write the complex image outputs by compnent.'
    'nifti_complex_only',     ' do not write rp.outs'
    'write_mat_format',       ' write the complex image components in mat format'
    'matlab_parallel',        ' use the matlab pool to parallelize.'
    'reprocess_rp',           ' load and reprocess rp file saved by write_complex. Mostly useful in case of error on write or process interruption.'
    'ignore_errors',          ' will try to continue regarless of any error'
    'asymmetry_mirror',       ' with echo asymmetry tries to copy 85% of echo trail to leading echo side.'
    'independent_scaling',    ' scale output images independently'
    'workspace_doubles',      ' use double precision in the workspace instead of single'
    'chunk_test_max',         ' maximum number of chunks to process before quiting. NOT a production option!'
    'chunk_test_min',         ' first chunks to process before. NOT a production option!'
    'recon_operation_min',    ' first recon operation to do. NOT a production option!'
    'recon_operation_max',    ' last recon operation to do. NOT a production option!'
    'image_return_type',      ' set the return type image from unscaled 32-bit float magnitude to something else.'
    'no_navigator',           ''
    'force_navigator',        ' Force the navigator selection code on for aspect scans, By default only SE SE classic and ME SE are expected to use navigator.'
    'roll_with_centroid',     ' calculate roll value using centroid(regionprops) method instead of by the luke/russ handy quick way'
%     'allow_headfile_override' ' Allow arbitrary options to be passed which will overwrite headfile values once the headfile is created/loaded'
    'force_write_archive_tag',' force archive tag write even if we didnt do antyhing'
    'force_load_partial',     ' modifies loading behavior to load partial if we''re reconning partial'
    'debug_stop_recon_strategy',' sets debug point just prior to creation of the recon_strategy struct'
    'debug_stop_load',        ' sets debug point just prior to running load'
    'debug_stop_regrid',      ' sets debug point just prior to regridding(reshapping)'
    'debug_stop_filter',      ' sets debug point just prior to running filter'
    'debug_stop_fft',         ' sets debug point just prior to running fft'
    'debug_stop_save',        ' sets debug point just prior to saving'
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
opt_struct.radial_mode='good';
opt_struct.regrid_method='scott';
% opt_struct.combine_method='square_and_sum';
%% handle options cellarray.
% look at all before erroring by placing into cellarray err_strings or
% warn_strings.

for o_num=1:length(options)
    option=options{o_num};
    if isempty(option)
        continue;
    end
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
            else
                try
                    vx=eval(['[' value ']']); %the simplified eval statment can cause errors on string entries.
                catch
                end
                if exist('vx','var') % try to turn it into a matrix...
                    value = eval(['[' value ']']);
                end
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
        va=str2num(value);
        vb=str2double(value);
        if numel(va)>numel(vb)
            value=va;
        else
            value=vb;
        end
        clear va vb;
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

if opt_struct.write_phase && ~opt_struct.skip_filter && ~opt_struct.force_filter
    warning('FILTER FORCED OFF FOR WRITING PHASE IMAGE');
    pause(opt_struct.warning_pause);
    opt_struct.skip_filter=true;
    opt_struct.skip_write_civm_raw=true;
    opt_struct.write_unscaled=true;
end

% output implication
% input implication

if opt_struct.skip_recon
    opt_struct.skip_load=true;
end
if opt_struct.skip_load
    opt_struct.skip_filter=true;
    opt_struct.skip_fft=true;
    opt_struct.skip_regrid=true;
    opt_struct.write_kimage=false;
    opt_struct.write_kimage_unfiltered=false;
    if ~opt_struct.reprocess_rp
        opt_struct.skip_write=true;
    end
end
if opt_struct.skip_write_civm_raw &&...
        ~opt_struct.write_complex &&... 
        ~opt_struct.write_phase &&...
        ~opt_struct.write_unscaled &&...
        ~opt_struct.write_unscaled_nD  && ...
        ~opt_struct.write_complex_component
    %         ~opt_struct.write_kimage &&...
    %         ~opt_struct.write_kimage_unfiltered &&...
    opt_struct.skip_fft=true;
end
if opt_struct.write_kimage && opt_struct.skip_filter
    opt_struct.write_kimage=false;
    opt_struct.write_kimage_unfiltered=true;
end

if opt_struct.skip_filter
    warning('Skipping filter, you may not be able to compare data with other runs');
%     opt_struct.skip_write_civm_raw=true;
%     opt_struct.write_unscaled=true;
end
if opt_struct.skip_regrid
end
if opt_struct.skip_fft && ~opt_struct.reprocess_rp
    opt_struct.skip_write_civm_raw=true;
    opt_struct.write_complex=false;
    opt_struct.fp32magnitude=false;
    opt_struct.write_phase=false;
    opt_struct.write_unscaled=false;
    opt_struct.write_unscaled_nD=false;
end


%% option sanity checks and cleanup
if ~opt_struct.chunk_test_max
    opt_struct.chunk_test_max=Inf;
end
if ~opt_struct.chunk_test_min
    opt_struct.chunk_test_min=1;
end
if ~opt_struct.recon_operation_max
    opt_struct.recon_operation_max=Inf;
end
if ~opt_struct.recon_operation_min
    opt_struct.recon_operation_min=1;
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
elseif regexpi(opt_struct.kspace_shift,'^AUTO$')
   warning('kspace_shift set to auto');
else
    kspace_shift_string='kspace_shift params incorrect. Must be comma separated list of integers, with at most 3 elements.';
    if ~opt_struct.ignore_errors
        error(kspace_shift_string);
    else
        warning(kspace_shift_string);
    end
end
if ~islogical(opt_struct.omit_channels)
%     opt_struct.omit_channels=str2num(opt_struct.omit_channels);
    if numel(opt_struct.omit_channels)<1 || ~isnumeric(opt_struct.omit_channels)
        error('omit channels failed to process');
    else 
        fprintf('Omitting channels :\n\t');fprintf('%i ',opt_struct.omit_channels);fprintf('\n');
    end
end

if length(opt_struct.output_order)<length(possible_dimensions)
    for char=1:length(possible_dimensions)
        test=strfind(opt_struct.output_order,possible_dimensions(char));
        if isempty(test)
            warning('missing dimension %s, appending to end of list',possible_dimensions(char));
            opt_struct.output_order=sprintf('%s%s',opt_struct.output_order,possible_dimensions(char));
        end
    end
end

if ~islogical(opt_struct.U_dimension_order) ...
    && length(opt_struct.U_dimension_order)<length(possible_dimensions)
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
if opt_struct.skip_filter && ~opt_struct.reprocess_rp
    opt_struct.filter_imgtag='_unfiltered';
else
    opt_struct.filter_imgtag='';
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
if isfield(data_buffer.scanner_constants,'scanner_tesla_image_code')
    data_buffer.headfile.S_tesla=data_buffer.scanner_constants.scanner_tesla_image_code;
else
    data_buffer.headfile.S_tesla='';
    data_buffer.scanner_constants.scanner_tesla='';
    data_buffer.scanner_constants.scanner_tesla_image_code='';
end


clear o_num options option all_options standard_options standard_options_string beta_options beta_options_string planned_options planned_options_string specific_text value err_strings warn_strings e w parts;

%% collect gui info (or set testmode)
%if ~isempty(regexp(runno,'^[A-Z][0-9]{5,}.*$', 'once'))
    gui_info_collect(data_buffer,opt_struct);
%end
if isfield(data_buffer.headfile,'U_specid')
    if regexp(data_buffer.headfile.U_specid,'.*;.*')
        fprintf('Mutliple specids entered in gui, forcing combine channels off! %s\n',data_buffer.headfile.U_specid);
        opt_struct.skip_combine_channels=true;
    end
end

%% data pull and build header from input
 dirext='';
if isfield(data_buffer.scanner_constants,'scanner_vendor')
    if strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')
        if ~regexpi(input_data{end},'fid')
            % if ! endswith fid, add fid
            dirext='.fid';
        end
    end
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
if isfield(data_buffer.scanner_constants,'scanner_data_directory')
    datapath=[data_buffer.scanner_constants.scanner_data_directory '/' puller_data ];
    data_buffer.input_headfile.origin_path=datapath;
else
    data_buffer.input_headfile.origin_path='UNKNOWN_LIMITED_SCANNER_SUPPORT';
end
% display(['data path should be omega@' scanner ':' datapath ' based on given inputs']);
% display(['base runno is ' runno ' based on given inputs']);
puller(data_buffer,opt_struct,scanner,puller_data);

%% load data header and insert unrecognized fields into headfile
if ~opt_struct.no_scanner_header
    data_buffer.input_headfile=load_scanner_header(scanner, data_buffer.headfile.work_dir_path ,opt_struct);
    if isfield(data_buffer.input_headfile,'U_scanner_vendor')
        data_buffer.scanner_constants.scanner_vendor=data_buffer.input_headfile.U_scanner_vendor;
    end
end
% disp(scanner_vendor);

if ~islogical(opt_struct.pre_defined_headfile)||opt_struct.pre_defined_headfile==1
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
    error('Failed to process scanner header from dump command ( %s )\nWrote partial hf to %s\nGIVE THE OUTPUT OF THIS TO JAMES TO HELP FIX THE PROBLEM.\nS_scanner_tag not found!\n',data_buffer.headfile.comment{end-1}(2:end),bad_hf_path);
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


%% read input dimensions to shorthand structs
[d_struct,data_in,data_work,data_out]=create_meta_structs(data_buffer,opt_struct);

% get free space
if ismac
    df_field=4;
elseif isunix
    df_field=3;
elseif ispc   
    df_field=4;
end
% [~,local_space_bytes] = unix(['df ',data_buffer.engine_constants.engine_work_directory,' | tail -1 | awk ''{print $' num2str(df_field) '}'' ']);
[~,local_space_bytes] = system(['df ',data_buffer.engine_constants.engine_work_directory,' | tail -1 | awk ''{print $' num2str(df_field) '}'' ']);
local_space_bytes=512*str2double(local_space_bytes); %this converts to bytes because default blocksize=512 byte
if isnan(local_space_bytes)
    db_inplace('rad_mat','some kinda error finding free disk space');
end

fprintf('Available disk space is %0.2fMB\n',local_space_bytes/1024/1024);
if data_out.disk_total_bytes<local_space_bytes|| opt_struct.ignore_errors
    fprintf('\t... Proceding with plenty of disk space.\n');
elseif local_space_bytes-data_out.disk_total_bytes < 0.1*local_space_bytes % warning at <10% of free remaining after output
    warning('Local disk space is low, may run out');
    pause(opt_struct.warning_pause);
else
    error('not enough free local disk space to reconstruct data, delete some files and try again');
end

if strcmp(data_in.vol_type,'radial') && strcmp(opt_struct.regrid_method,'scott')
    fprintf('Radial scott recon, standard filter disabled, using scott filter. Standard fft code disabled, using scott iterative\n');
    opt_struct.skip_filter=true;
    opt_struct.skip_fft=true;
end

clear local_space_bytes df_field;
%% load_data parameter determination
display('Checking file size and calcualting RAM requirements...');
data_prefix=data_buffer.headfile.(['U_' 'prefix']);

%%   determine padding
% block_factors=factor(data_in.ray_blocks);
alt_agilent_channel_code=true;
data_in.line_pad=0;
if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    %% calculate padding for bruker
    
    %~strcmp(data_buffer.headfile.([data_prefix 'GO_block_size']),'continuous')
    if (  ( ~isempty(regexpi(data_buffer.headfile.([data_prefix 'GO_block_size']),'standard'))  ...
            &&  ~isempty(regexpi(data_buffer.headfile.([data_prefix 'GS_info_dig_filling']),'Yes')) )...
            ) %&& ~opt_struct.ignore_errors )
        %if ~exist('USE_REVERSE_ENGINEERED_PADDING_CALC','var')
        if opt_struct.use_new_bruker_padding
            warning('NEW PADDING CALCULATION IN USE, PROBABLY DOENST ACCOUNT FOR CHANNEL DATA CORRECTLY');
            data_in.line_points  = d_struct.c*data_in.ray_length;
            
            
            pad_interval=1024;
            
            pad_bytes=pad_interval-rem(2*data_in.line_points*(data_in.disk_bit_depth/8),pad_interval);
            data_in.line_pad=pad_bytes/(2*(data_in.disk_bit_depth/8));
            data_in.line_points=data_in.line_points+data_in.line_pad;
            %             data_in.line_pad=96;%in complex samples
            %             data_in.line_points=896;% in complex samples
            
            data_in.total_points = data_in.ray_length*data_in.rays_per_block*d_struct.c*data_in.ray_blocks;
        
        else
    %if ( strcmp(data_buffer.headfile.([data_prefix 'GS_info_dig_filling']),'Yes')...
            %|| ~opt_struct.ignore_errors )
%             && ~regexp(data_in.vol_type,'.*radial.*')  %PVM_EncZfRead=1 for fill, or 0 for no fill, generally we fill( THIS IS NOT WELL TESTED)
        %bruker data is usually padded out to a power of 2 or multiples of
        %powers of 2.
        % 3*2^6 
        % there may be a minimum padding of some number?
        % have now seen with a 400x2channel acq padding of 96
        mul=2^6*2;
        [F,~]=log2(d_struct.c*data_in.ray_length/(mul));
        % somehow for john's rare acquisition the data_in.rays_per_block includes
        % the channel information, This causes my line_points to be off,
        % which caues my min_load_bytes to be off. We'll set special var
        % here to fix that. 
        % Alex had an acquisition fail due to this.       d_struct.c*<1 
        % Modifing to divide out the channels and hope padding holds.
        effective_c=d_struct.c;
%         if isfield(data_buffer.headfile,'B_rare_factor')&& ~strcmp(data_in.vol_type,'radial')
%             if data_buffer.headfile.B_rare_factor==1 %&& exist('neverrun_var','var')
%                 effective_c=1;
%             end
%         end
        if mod(d_struct.c*data_in.ray_length,(mul))>0&& F ~= 0.5
            data_in.line_points2 = 2^ceil(log2(effective_c*data_in.ray_length));
            data_in.line_points3 = ceil(((effective_c*(data_in.ray_length)))/(mul))*mul;
            data_in.line_points2 = min(data_in.line_points2,data_in.line_points3);
            data_in=rmfield(data_in,'line_points3');
        else
            data_in.line_points2=d_struct.c*data_in.ray_length;
        end
        data_in.line_pad  =   data_in.line_points2-d_struct.c*data_in.ray_length;
        data_in.line_points   =   data_in.line_points2;
        data_in.total_points = data_in.ray_length*data_in.rays_per_block*data_in.ray_blocks;
        % the number of points in kspace that were sampled.
        % this does not include header or padding
        % data_in.min_load_bytes= 2*data_in.line_points*data_in.rays_per_block*(data_in.disk_bit_depth/8);
        
        % somehow for john's rare acquisition the data_in.rays_per_block includes
        % the channel information, This causes my line_points to be off,
        % which caues my min_load_bytes to be off. We'll set special var
        % here to fix that. 
        % Alex had an acquisition fail due to this.       d_struct.c*<1 
        % Modifing to divide out the channels and hope padding holds.
        % it seems more correct to just not calculate in the channels to
        % begin with, tha tis done above.
        if isfield(data_buffer.headfile,'B_rare_factor')&& ~strcmp(data_in.vol_type,'radial')
            if data_buffer.headfile.B_rare_factor==1 && strcmp(data_buffer.headfile.S_PSDname,'MDEFT') 

                % && exist('neverrun_var','var')
%                 data_in.line_points   = data_in.ray_length;
                data_in.line_points  = data_in.line_points/d_struct.c;
                data_in.line_pad     = data_in.line_pad/d_struct.c;
                data_in.total_points = data_in.ray_length*data_in.rays_per_block*data_in.ray_blocks;
                % data_in.min_load_bytes= 2*data_in.line_points*data_in.rays_per_block*(data_in.disk_bit_depth/8);
            end
        end
            
        % minimum amount of bytes of data we can load at a time, 
        % this includes our line padding but no our header bytes which 
        % we could theoretically skip.
        data_in=rmfield(data_in,'line_points2');
        clear mul F;
        end
    else
        data_in.line_points  = d_struct.c*data_in.ray_length;
        data_in.total_points = data_in.ray_length*data_in.rays_per_block*d_struct.c*data_in.ray_blocks;
        warning(['Found no pad option with bruker scan for the first time,' ...
            'Tell james let this continue in test mode']);
                
%         data_input.sample_points = data_in.ray_length*data_in.rays_per_block/d_struct.c*data_in.ray_blocks;
%         % because data_in.ray_length is number of complex points have to doubled this.
%         recon_strategy.min_load_size=   data_in.line_points*data_in.rays_per_block/d_struct.c*(kspace.bit_depth/8);
%         data_in.line_points=d_struct.c*data_in.ray_length;
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
            data_in.line_points=data_in.ray_length+50;
            data_in.line_pad=50;
        end
    end
    data_in.total_points = data_in.ray_length*data_in.rays_per_block*data_in.ray_blocks;
    % because data_in.ray_length is number of complex points have to doubled this.
    % data_in.min_load_bytes= 2*data_in.line_points*data_in.rays_per_block*(data_in.disk_bit_depth/8);
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
    data_in.line_points  = data_in.ray_length;
    data_in.ray_blocks=d_struct.c*data_in.ray_blocks;
    end
    % this is the only change to revert behavior
    %%%%%%
    data_in.total_points = data_in.ray_length*data_in.rays_per_block*d_struct.c*data_in.ray_blocks;
    % because data_in.ray_length is doubled, this is doubled too.
    % data_in.min_load_bytes=2*data_in.line_points*data_in.rays_per_block* (data_in.disk_bit_depth/8);
    % minimum amount of bytes of data we can load at a time,
else
    error(['Stopping for unrecognized scanner_vendor:', data_buffer.scanner_constants.scanner_vendor,', not sure if how to calculate the memory size.']); 
%     % not bruker, no ray padding...
%     data_input.sample_points = data_in.ray_length*data_in.rays_per_block*data_in.ray_blocks;
%     % because data_in.ray_length is doubled, this is doubled too.
%     recon_strategy.min_load_size= data_in.line_points*data_in.rays_per_block*(kspace.bit_depth/8);
%     % minimum amount of bytes of data we can load at a time,
end

%% calculate expected input file size and compare to real size
% if we cant calcualte the file size its likely we dont know what it is
% we're loading, and therefore we would fail to reconstruct.
data_in.kspace_header_bytes  =data_in.binary_header_bytes+data_in.ray_block_hdr_bytes*(data_in.ray_blocks-1); 
% total bytes used in headers spread throughout the kspace data
if strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')&&alt_agilent_channel_code
    data_in.kspace_header_bytes  =data_in.binary_header_bytes+data_in.ray_block_hdr_bytes*(data_in.ray_blocks); 
    %%% TEMPORARY HACK TO FIX ISSUES WITH AGILENT
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent')
    data_in.kspace_header_bytes  =data_in.binary_header_bytes+data_in.ray_block_hdr_bytes*data_in.ray_blocks*d_struct.c; 
end
data_in.kspace_data=2*(data_in.line_points*data_in.rays_per_block)*data_in.ray_blocks*(data_in.disk_bit_depth/8); % data bytes in file (not counting header bytes)
% data_in.kspace_data          =recon_strategy.min_load_size*max_loads_per_chunk;
% total bytes used in data only(no header/meta info)
calculated_kspace_file_size     =data_in.kspace_header_bytes+data_in.kspace_data; % total ammount of bytes in data file.

fileInfo = dir(data_buffer.headfile.kspace_data_path);
if isempty(fileInfo)
    error('puller did not get data, check pull cmd and scanner');
end
measured_filesize    =fileInfo.bytes;
data_buffer.headfile.kspace_file_size=measured_filesize;
if calculated_kspace_file_size~=measured_filesize
    aspect_remainder=138443;% a constant amount of bytes that aspect scans have to spare.
    remainder=measured_filesize-calculated_kspace_file_size;
    if (measured_filesize>calculated_kspace_file_size && opt_struct.ignore_kspace_oversize) || opt_struct.ignore_errors % measured > expected provisional continue
        warning('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=\t%d\nCalculated=\t%d\n\n\tYou could try again adding the use_new_bruker_padding option.',measured_filesize,calculated_kspace_file_size);
        
        % extra warning when acaual is greater than 10% of exptected
        
        if remainder/calculated_kspace_file_size> 0.1 && remainder~=aspect_remainder
            msg=sprintf(['Big difference between measured and calculated!\n' ...
                '\tSUCCESS UNLIKELY!\n' ...
                'ignore_kspace_oversize enabled, but more than 10%% data will be ignored']);
            if strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
                error(msg);
            else
                warning(msg);
            end
            pause( 2*opt_struct.warning_pause ) ;
        end
    else %if measured_filesize<kspace_file_size    %if measured < exected fail.
        if strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect') && remainder==aspect_remainder
            warning('Measured data file size and calculated dont match. However this is Aspect data, and we match our expected remainder! \nMeasured=\t%d\nCalculated=\t%d\n\tAspect_remainder=%d\n\n\tYou could try again adding the use_new_bruker_padding option.',measured_filesize,calculated_kspace_file_size,aspect_remainder);
        else
            error('Measured data file size and calculated dont match. WE''RE DOING SOMETHING WRONG!\nMeasured=\t%d\nCalculated=\t%d\n\n\tYou could try again adding the use_new_bruker_padding option.',measured_filesize,calculated_kspace_file_size);
        end
    end
else
    fprintf('\t... Proceding with good file size.\n');
end
clear data_in.kspace_header_bytes kspace_file_size fileInfo measured_filesize;

%% set the recon strategy dependent on memory requirements
meminfo=imaqmem; %check available memory
if opt_struct.debug_stop_recon_strategy
    db_inplace('rad_mat','debug stop requested prior to recon strategy');
end
[recon_strategy,opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo);
if recon_strategy.recon_operations>data_buffer.headfile.([data_tag 'volumes'])
    save([data_buffer.headfile.work_dir_path '/insufficient_mem_stop.mat']);
    %     [l,n,f]=get_dbline('rad_mat');
    %     eval(sprintf('dbstop in %s at %d',f,l+3));
    if ~opt_struct.ignore_errors
        db_inplace('rad_mat','Cannot proceede sanely on this recon engine due to insufficient RAM');
    end
end
%% mem purging when we expect to fit.
%%% first just try a purge to free enough space.
if meminfo.AvailPhys<recon_strategy.memory_space_required
    system('purge');
    meminfo=imaqmem;
end
%%% now prompt for program close and purge and update available mem.
while meminfo.AvailPhys<recon_strategy.memory_space_required
    fprintf('%0.2fM/%0.2fM you have too many programs open.\n ',meminfo.AvailPhys/1024/1024,recon_strategy.memory_space_required/1024/1024);
    user_response=input('close some programs and then press enter >> (press c to ignore mem limit, NOT RECOMMENDED)','s');
    if strcmp(user_response,'c')
        meminfo.AvailPhys=recon_strategy.memory_space_required;
    else
        system('purge');
        meminfo=imaqmem;
    end
end
fprintf('    ... Proceding doing recon with %d chunk(s)\n',recon_strategy.num_chunks);

clear data_in.ray_length2 data_in.ray_length3 fileInfo bytes_per_vox copies_in_memory kspace.bit_depth kspace.data_type min_chunks system_reserved_memory total_memory_required memory_space_required meminfo measured_filesize kspace_file_size kspace_data data_in.kspace_header_bytes F mul user_response ;
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
%% insert unrecognized fields into headfile again
data_buffer.headfile=combine_struct(data_buffer.headfile,unrecognized_fields);
clear fnum option value parts;
%%% last second stuff options into headfile
data_buffer.headfile=combine_struct(data_buffer.headfile,opt_struct,'rad_mat_option_');
chunks_to_load=1:recon_strategy.num_chunks;
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
%                 data_buffer.headfile.kspace_data_path, recon_strategy.min_load_size, recon_strategy.load_skip, data_in.precision_string, load_chunk_size, ...
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
    data_in.binary_header_bytes,...
    recon_strategy.min_load_size*(data_in.disk_bit_depth/8),...
    recon_strategy.chunk_size/recon_strategy.min_load_size,...
    recon_strategy.load_skip,...    
    data_in.precision_string,...
    data_in.disk_endian);

 if ~opt_struct.skip_write_temp_headfile
    hf_path=[data_buffer.headfile.work_dir_path '/' 'rad_mat.headfile'];
    fprintf('\ttemp headfile save \n\t\t%s\n',hf_path);
%     data_buffer.headfile.output_image_path=space_dir_img_folder;
    write_headfile(hf_path,data_buffer.headfile,0);
    % insert validate_header perl script check here?
 end

clear dim_order ds hf_path ;

% runno_list=cell(1,prod(ouput_dimensions(4:end)));
%% reconstruction
%%% have to change this from chunk_num 1... end to recon_operation 1...n, 
%%% in most cases recon_ops are exactly chunks, however a few condiditons
%%% bunk that. 
% reference to chunk in opt_struct should be fixed to recon_operation.
work_dir_img_path_base=[ data_buffer.headfile.work_dir_path '/' runno ] ;
ij_prompt=''; % init a blank ij_prompt
for recon_num=opt_struct.recon_operation_min:min(opt_struct.recon_operation_max,recon_strategy.recon_operations);
% for recon_num=1:recon_strategy.recon_operations
    meminfo=imaqmem;
    if meminfo.AvailPhys<recon_strategy.memory_space_required
        fprintf('%0.2fM/%0.2fM you have too many programs open.\n ',meminfo.AvailPhys/1024/1024,recon_strategy.memory_space_required/1024/1024);
        system('purge');
    end
    time_chunk=tic;
    if ~opt_struct.skip_load
        %% Load data file
        fprintf('Loading data\n');
        %load data with skips function, does not reshape, leave that to regridd
        %program.
        if opt_struct.debug_stop_load
            db_inplace('rad_mat','Debug stop at load requested.')
        end
        time_l=tic;
        file_chunks=recon_strategy.num_chunks; %load_chunks may not be used for aything helpful, here or in load_file. ...
        load_chunk_size=recon_strategy.chunk_size;
        file_header=data_in.binary_header_bytes;
        %%%  
        % loader section configure to handle possibilities. 
        % shorthand of names, load_whole=lh, workbychunk=wbc, workbysubchunk=wbsc
        % load whole, process whole, lh=t,wbc=f,wbsc=f
        % load whole, process chunk, lh=t,wbc=t,wbsc=f
        % load chunk, process chunk, lh=f, wbc=t,wbsc=f
        % load chunk, process by subchunk, ? lh=f wbc=t,wbsc=t
        % load partial, process by subchunk, lh=f, wtc=f, wbsc=f\
        % really only conerened with what parts to load, 
        % so we either load whole, load chunk or we load partial. 
        if recon_strategy.load_whole 
            %&& recon_strategy.num_chunks>1 && ~recon_strategy.work_by_sub_chunk && recon_strategy.load_skip==0
            % this is a speed optimization, and clouding the problem. 
%             file_chunks=1;
%             load_chunk_size=(recon_strategy.chunk_size+recon_strategy.load_skip)*recon_strategy.num_chunks;
            chunks_to_load=1:recon_strategy.num_chunks;
            if recon_strategy.work_by_chunk && ~isprop(data_buffer,'kspace')
                addprop(data_buffer,'kspace');
            end
        elseif recon_strategy.work_by_sub_chunk 
            file_header=data_in.binary_header_bytes+(recon_num-1)*recon_strategy.min_load_size*(data_in.disk_bit_depth/8);
            chunks_to_load=1:recon_strategy.num_chunks;
            load_chunk_size=recon_strategy.chunk_size;
        elseif recon_strategy.work_by_chunk % || ~recon_strategy.load_whole
            chunks_to_load=recon_num;
        else 
            [debug_base,~,~]=fileparts(data_buffer.headfile.kspace_data_path);
            debug_file=sprintf('%s/matlab_debug_loading.mat',debug_base);
            save(debug_file);
            warning('Unsupported recon condition, saved matlab workspace to %s',debug_file);
        end
        %         temp_chunks=recon_strategy.num_chunks;
        %         temp_size=recon_strategy.chunk_size;
        %         if recon_strategy.load_whole && temp_chunks>1
        %             recon_strategy.num_chunks=1;
        %             recon_strategy.chunk_size=temp_size*temp_chunks;
        %         end
        
        % This loading code is running TOO often. I need to move this
        % if stament around.
%         if  recon_num==1 || (  file_chunks>1 ) ||  ~isprop(data_buffer,'data') %~recon_strategy.load_whole &&
        if  recon_num==1 || ~recon_strategy.load_whole
            % we load the data for only the first chunk of a load_whole, 
            % or for each/any chunk when recon_strategy.num_chunks  > 1
           
            if ~isprop(data_buffer,'data')
                data_buffer.addprop('data');
            end
            load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
                file_header, recon_strategy.min_load_size, recon_strategy.load_skip, data_in.precision_string, load_chunk_size, ...
                file_chunks,chunks_to_load,...
                data_in.disk_endian,recon_strategy.post_skip);
            
            if data_in.line_pad>0  %remove extra elements in padded ray,
                % lenght of full ray is spatial_dim1*nchannels+pad
                %         reps=data_in.ray_length;
                % account for number of channels and echoes here as well .
                if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
                    % padd beginning code
                    logm=zeros(data_in.line_points,1);
                    logm(data_in.line_points-data_in.line_pad+1:data_in.line_points)=1;
                    %             logm=logical(repmat( logm, length(data_buffer.data)/(data_in.ray_length),1) );
                    %             data_buffer.data(logm)=[];
                elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
                    % pad ending code
                    logm=ones((data_in.line_pad),1);
                    logm(data_in.line_points-data_in.line_pad+1:data_in.line_points)=0;
                else
                end
                logm=logical(repmat( logm, length(data_buffer.data)/(data_in.line_points),1) );
                if opt_struct.debug_stop_load
                    warning('USING ADDIONAL MEMORY TO STORE PRE_PAD CORRECTION KSPACE');
                    pause(3*opt_struct.warning_pause);
                    data_buffer.addprop('padded_kspace');
                    % data_buffer.padded_kspace=reshape(data_buffer.data,[data_in.line_points data_in.input_dimensions(3:end)]);
                    data_buffer.padded_kspace=data_buffer.data;
                end
                data_buffer.data(logm)=[];
                warning('padding correction applied, hopefully correctly.');
                % could put sanity check that we are now the number of data points
                % expected given datasamples, so that would be
                % (ray_legth-ray_padding)*data_in.rays_per_blocks*data_in.ray_blocks_per_volume
                % NOTE: blocks_per_chunk is same as blocks_per_volume with small data,
                % expected_data_length=(data_in.line_points-data_input.line_padding)/d_struct.c...
                %     *data_in.rays_per_block*data_in.ray_blocks; % channels removed, things
                %     changed at some point to no longer divide by channel.
                % BRUKER FLASH scans broke this rule. had to fix this for alex. New calculation shouldnt be breakable, there may be exceptions for radial(ofcourse:(  
                % expected_data_length=(data_in.line_points-data_in.line_pad)...
                %     *data_in.rays_per_block*data_in.ray_blocks/numel(chunks_to_load);
                expected_data_length=prod(data_in.ds.Sub(recon_strategy.w_dims));
                if numel(data_buffer.data) ~= expected_data_length && ~opt_struct.ignore_errors;
                    error('Ray_padding reversal went awry. Data length should be %d, but is %d',...
                        expected_data_length,numel(data_buffer.data));
                else
                    fprintf('Data padding retains correct number of elements, continuing...\n');
                end
            end
            
        end
%         if recon_strategy.load_whole && temp_chunks>1
%             recon_strategy.num_chunks=temp_chunks;
%             recon_strategy.chunk_size=temp_size;
%         end
        fprintf('Data loading took %f seconds\n',toc(time_l));
        clear l_time logm temp_chunks temp_size;
        %% load trajectory and do dcf calculation
        if( ~isempty(regexp(data_in.vol_type,'.*radial.*', 'once')))
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
                    if opt_struct.display_radial_filter
                        imagesc(reshape(cutoff_filter,[size(cutoff_filter,1),numel(cutoff_filter)/size(cutoff_filter,1)]))
                    end
                else
                    fprintf('\tNot filtering radial data\n');
                end
                data_buffer.cutoff_filter=logical(cutoff_filter);
                clear cutoff_filter;
            end
            %% Calculate/load dcf 
            % this is the sdc3_MAT code, which is depreciated. This was never completed to full satisfaction.
            % data_buffer.dcf=sdc3_MAT(data_buffer.trajectory, opt_struct.iter, x, 0, 2.1, ones(data_in.ray_length, data_buffer.headfile.rays_acquired_in_total));
            iter=data_buffer.headfile.radial_dcf_iterations;
          
            if ~isprop(data_buffer,'dcf') && strcmp(opt_struct.regrid_method,'sdc3_mat')
                dcf_file_path=[trajectory_file_path '_dcf_I' num2str(iter) opt_struct.radial_filter_postfix '.mat' ];
                if opt_struct.dcf_by_key
                    data_buffer.trajectory=reshape(data_buffer.trajectory,[3,...
                        data_in.ray_length,...
                        data_buffer.headfile.rays_per_block,...
                        data_buffer.headfile.ray_blocks]);
                    dcf_file_path=[trajectory_file_path '_dcf_by_key_I' num2str(iter) '.mat'];
                end
                dcf=zeros(data_in.ray_length,data_buffer.headfile.rays_per_volume,radial_filter_modifier);
                %             t_struct=struct;
                %             dcf_struct=struct;
                %             for k_num=1:data_buffer.header.data_in.ray_blocks_per_volume
                %                 t_struct.(['key_' k_num])=squeeze(data_buffer.trajectory(:,:,k_num,:));
                %                 dcf_struct.(['key_' k_num])=zeros(data_buffer.headfile.rays_acquired_in_total,rays_length);
                %             end
                traj=data_buffer.trajectory;
                % permute(repmat(data_buffer.cutoff_filter,[1,3]),[4 1 2 3])
                %                 traj(data_buffer.cutoff_filter==0)=NaN;
                traj(permute(reshape(repmat(data_buffer.cutoff_filter,[3,1,1,1]),[data_in.ray_length,...
                    3, data_buffer.headfile.rays_per_block,...
                    data_buffer.headfile.ray_blocks_per_volume]),[2 1 3 4])==0)=NaN;
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
                            dcf(:,:,k_num)=sdc3_MAT(squeeze(traj(:,:,:,k_num)), iter, d_struct.x, 0, 2.1, ones(data_in.ray_length,data_buffer.headfile.rays_per_block));
                            %                     dcf(:,:,k_num)=reshape(temp,[data_in.ray_length,...
                            %                         data_buffer.headfile.rays_per_block...
                            %                         ]); % data_buffer.headfile.ray_blocks/data_buffer.headfile.ray_blocks_per_volume could also be total_rays/data_in.rays_per_block
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
                %             data_buffer.dcf=reshape(data_buffer.dcf,[data_buffer.headfile.ray_acquired_in_total,data_in.ray_length]);
            else
                fprintf('\tdcf in memory.\n');
            end
            data_buffer.trajectory=reshape(data_buffer.trajectory,[3,data_in.ray_length,data_in.rays_per_block,data_buffer.headfile.ray_blocks_per_volume]);
            if  isprop(data_buffer,'dcf')
                data_buffer.dcf=reshape(data_buffer.dcf,[data_in.ray_length,data_in.rays_per_block,data_buffer.headfile.ray_blocks_per_volume]);
            end
        end
        %% prep keyhole trajectory
        if ( regexp(data_in.scan_type,'keyhole'))
            % set up a binary array to mask points for the variable cutoff
            % this would be data_in.ray_length*keys*rays_per_key array
            % data_buffer.addprop('vcf_mask');
            % data_buffer.vcf_mask=calcmask;
            % frequency. Just ignoring right now
            if( isempty(regexp(data_in.vol_type,'.*radial.*', 'once')))
                error('Non-radial keyhole not supported yet');
            end
%             data_buffer.trajectoryectory=reshape(data_buffer.trajectoryectory,[3 ,data_buffer.headfile.ray_blocks_per_volume,data_buffer.headfile.ray_length]);
                        
        end
        %%% pre regrid data save.
        %     if opt_struct.display_kspace==true
        %         input_kspace=reshape(data_buffer.data,data_in.input_dimensions);
        %     end
        %% reformat/regrid kspace to cartesian
        % perhaps my 'regrid' should be re-named to 'reformat' as that is
        % more accurate especially for cartesian. 
        %%enhance to handle load_whole vs work_by_chunk.
        if ~opt_struct.skip_regrid
            if opt_struct.debug_stop_regrid
                warning('USING ADDIONAL MEMORY TO STORE PRE_GRID KSPACE');
                pause(3*opt_struct.warning_pause);
                data_buffer.addprop('unshaped_kspace');
                data_buffer.unshaped_kspace=data_buffer.data;
                db_inplace('rad_mat','Debug stop requested.');
            end
            if recon_strategy.num_chunks>1 && recon_strategy.recon_operations>1 %%%&& ~isempty(regexp(vol_type,'.*radial.*', 'once'))
                data_buffer.headfile.processing_chunk=recon_num;
            end
            if ~strcmp(data_in.vol_type,'radial') || strcmp(opt_struct.regrid_method,'sdc3_mat')
                if ~recon_strategy.load_whole
                    rad_regrid(data_buffer,recon_strategy.w_dims);%%%% w_dims is WRONG for load whole!!!
                elseif recon_num==1 && recon_strategy.load_whole
                    rad_regrid(data_buffer,data_in.input_order);%%%% w_dims is WRONG for load whole!!!
                    if recon_strategy.recon_operations>1
                        data_buffer.kspace=data_buffer.data;
                    end
                end
                if recon_strategy.load_whole && recon_strategy.work_by_chunk
                    %%% decode w_dims and op_dims?
                    warning('Load_whole, work_by_(sub)_chunk not well tested');
                    data_buffer.data=data_buffer.kspace(:,:,:,recon_num);
                end
            elseif strcmp(data_in.vol_type,'radial') && strcmp(opt_struct.regrid_method,'scott')
                scott_grid(data_buffer,opt_struct,data_in,data_work,data_out); % lets make scott grid responsible for loading and closing system matrices.
            else 
                db_inplace('rad_mat','Unknown grid error');
            end
            %% when omitting channels, as in the case we have bad channel data,
            % remove the bad channel data, and fix the data objects to refer to the reduced number of channels.
            if opt_struct.omit_channels
                % fix data_work, data_out, recon_srategy?
                channel_dim=strfind(data_out.output_order,'c');
                total_channels=data_work.ds.dim_sizes(channel_dim);
                
                data_work.ds.dim_sizes(channel_dim)=data_work.ds.dim_sizes(channel_dim)-numel(opt_struct.omit_channels);
                data_work.volumes=data_work.ds.dim_sizes(channel_dim)*data_work.volumes/total_channels;
                
                data_out.ds.dim_sizes(channel_dim)=data_out.ds.dim_sizes(channel_dim)-numel(opt_struct.omit_channels);
                data_out.output_dimensions(channel_dim)=data_out.output_dimensions(channel_dim)-numel(opt_struct.omit_channels);
                data_out.volumes=data_out.ds.dim_sizes(channel_dim)*data_out.volumes/total_channels;
                data_buffer.headfile.A_channels=data_buffer.headfile.A_channels-numel(opt_struct.omit_channels);
                d_struct.c=d_struct.c-numel(opt_struct.omit_channels);
                
%                 recon_strategy.op_dims
                
                % get a permute code to move the channel dimension to the
                % front of the array.
                pc=1:ndims(data_buffer.data);
                pc(channel_dim)=[];
                pc=[ pc channel_dim];
                ds=size(data_buffer.data); % get the sizes to reshape by.
                ds=ds(pc);
                data_buffer.data=permute(data_buffer.data,pc);
                data_buffer.data=reshape(data_buffer.data,[prod(ds(1:end-1)), ds(end)] );
                % sort these descending as we'll be eliminating indices.
                tc=sort(opt_struct.omit_channels,2,'descend');
                if exist('slowremovechannel','var')
                    for chsk=1:length(opt_struct.omit_channels)
                        data_buffer.data(:,tc(chsk))=[];
                        fprintf('remove channel %i...\n',tc(chsk));
                        %                     tmp=data_buffer.data(:,:,:,1,:);
                    end
                else
                    % A=setxor(A,B)
                    % A=A(setdiff(1:length(A),ind));
                    data_buffer.data=data_buffer.data(:,setdiff(1:size(data_buffer.data,ndims(data_buffer.data)),opt_struct.omit_channels));
                end
                ds(end)=ds(end)-numel(opt_struct.omit_channels);% we put channels last so the dimension to fix will always be end
                data_buffer.data=reshape(data_buffer.data,ds);
                data_buffer.data = ipermute(data_buffer.data,pc);
                fprintf('Channel removal complete!\n');
                clear ds pc tc chsk;
            end
            if  ~isempty(regexp(data_in.vol_type,'.*radial.*', 'once')) && strcmp(opt_struct.regrid_method,'sdc3_mat')
                if recon_strategy.num_chunks==1
                    fprintf('Clearing traj,dcf and radial kspace data\n');
                    data_buffer.trajectory=[];
                    data_buffer.dcf=[];
                    data_buffer.radial=[];
                end
            end
        else
            data_buffer.data=reshape(data_buffer.data,data_in.input_dimensions);
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
        if ~isnumeric(opt_struct.kspace_shift)
            if regexpi(opt_struct.kspace_shift,'AUTO')
                fprintf('AUTO Kspace Centering\n');
                dim_select.x=':';
                dim_select.y=':';
                dim_select.z=':';
                for tn=1:d_struct.t
                    dim_select.t=tn;
                    for cn=1:d_struct.c
                        dim_select.c=cn;
                        for pn=1:d_struct.p
                            dim_select.p=pn;
                            tmp=squeeze(data_buffer.data(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                ));
                            %                             channel_code=opt_struct.channel_alias(cn);
                            %                             channel_code_r=[channel_code '_'];
                            channel_code_r='';
                            input_center=get_wrapped_volume_center(tmp);
                            ideal_center=[d_struct.x/2,d_struct.y/2,d_struct.z/2];
                            shift_values=ideal_center-input_center;
                            for di=1:length(shift_values)
                                if shift_values(di)<0
                                    shift_values(di)=shift_values(di)+size(data_buffer.data,di);
                                end
                            end
                            if ~isfield(data_buffer.headfile, [ 'roll' channel_code_r 'corner_X' ])
                                data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' ])=shift_values(strfind(opt_struct.output_order,'x'));
                                data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' ])=shift_values(strfind(opt_struct.output_order,'y'));
                                data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' ])=shift_values(strfind(opt_struct.output_order,'z'));
                                fprintf('\tSet Roll value\n');
                            else
                                % check that existing values are the same or
                                % similar. lets set tollerance at 5%.
                                shift_values2=[ data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' ])
                                    data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' ])
                                    data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' ])
                                    ];
                                for v=1:length(shift_values) 
                                    if shift_values(v) ~= shift_values2(v)
                                        if abs(shift_values2(v)-shift_values(v))>data_out.output_dimensions(v)*0.05
                                            warning('change for shift values, %d over 5%, one %d, two %d.',v,shift_values(v),shift_values2(v));
                                            pause(opt_struct.warning_pause);
                                            shift_values(v)=shift_values2(v);
                                        end
                                    end
                                end
                                fprintf('\tExisting Roll value\n');
                            end
                            fprintf('\tshift by :');
                            fprintf('%d,',shift_values);
                            fprintf('\n');
                            tmp=circshift(tmp,round(shift_values));
                            data_buffer.data(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                )=tmp;
                        end
                    end
                end
                opt_struct.kspace_shift=0;
            end
        end
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
        if opt_struct.display_kspace>=1
            pan_nd_image(data_buffer,opt_struct);
        end
        %% write kspace unfiltered image log(abs(img))
        % should modify this to handle any of the reasons to preserve here
        % instead of taking up additional memory. 
        if opt_struct.write_kimage_unfiltered
%             data_buffer.addprop('kspace_unfiltered');
%             data_buffer.kspace_unfiltered=data_buffer.data;
%             
            %%% should move the kspace writing code to here with a check if it already exists, in the case we're iterating over it for some reason.
           
            kimg_code='';
            if recon_strategy.recon_operations>1 || length(recon_strategy.recon_operations)>1
                kimg_code=sprintf(['_r%' num2str(length(recon_strategy.recon_operations)) 'd'],recon_num);
            end
            kimg_path=[work_dir_img_path_base kimg_code '_kspace' opt_struct.filter_imgtag '.nii'];
            fprintf('\twrite_kimage make_nii\n');
            fprintf('\t\t save_nii\n');
            if ~opt_struct.write_kspace_complex
                nii=make_nii(log(abs(squeeze(data_buffer.data))));
            else
                nii=make_nii(((squeeze(data_buffer.data))));
            end
            save_nii(nii,kimg_path);clear nii kimg_path;
        end
        %% combine dimensions in kspace
        % combine kspace by letter string, 
        % if more than one letter specified combine in order.
        if ~islogical(opt_struct.combine_kspace)
            for ks_d=1:length(opt_struct.combine_kspace)
                if islogical(opt_struct.combine_kspace_method)
                    data_buffer.data=mean(data_buffer.data,strfind(opt_struct.output_order,opt_struct.combine_kspace(ks_d)));
                elseif regexpi(opt_struct.combine_kspace_method,'max')
                    data_buffer.data=max(data_buffer.data,[],strfind(opt_struct.output_order,opt_struct.combine_kspace(ks_d)));
                elseif regexpi(opt_struct.combine_kspace_method,'mean')
                    data_buffer.data=mean(data_buffer.data,strfind(opt_struct.output_order,opt_struct.combine_kspace(ks_d)));
                elseif regexpi(opt_struct.combine_kspace_method,'sum')
                    data_buffer.data=sum(data_buffer.data,strfind(opt_struct.output_order,opt_struct.combine_kspace(ks_d)));
                else
                    error(['combine_kspace_method ' opt_struct.combine_kspace_method ' unrecognized']);
                end
                data_out.output_dimensions(strfind(opt_struct.output_order,opt_struct.combine_kspace(ks_d)))=1;
                data_buffer.headfile.([data_tag 'volumes'])=data_buffer.headfile.([data_tag 'volumes'])/d_struct.(opt_struct.combine_kspace(ks_d));
                d_struct.(opt_struct.combine_kspace(ks_d))=1;
            end
        end
        %% filter kspace data
        if ~opt_struct.skip_filter
            if opt_struct.debug_stop_filter
                [l,~,f]=get_dbline('rad_mat');
                eval(sprintf('dbstop in %s at %d',f,l+3));
                warning('Debug stop requested.');
            end
            
            filter_input='data';
            if isprop(data_buffer,'kspace') && recon_strategy.recon_operations==1
                filter_input='kspace';
            end
            %  dim_string=sprintf('%d ',size(data_buffer.(filter_input),1),size(data_buffer.(filter_input),2),size(data_buffer.(filter_input),3));
            dim_string=sprintf('%d ',size(data_buffer.(filter_input)));
            %             for d_num=4:length(data_out.output_dimensions)
            %                 dim_string=sprintf('%s %d ',dim_string,data_out.output_dimensions(d_num));
            %             end ; clear d_num;
            fprintf('Performing fermi filter on volume with size %s\n',dim_string );
            
            if strcmp(data_in.vol_type,'2D')
                %% Filter 2D
                % this requires regridding to place volume in same dimensions as the output dimensions
                % it also requires the first two dimensions of the output to be to be xy.
                % these asumptions may not always be true.
                data_buffer.data=reshape(data_buffer.data,[ data_out.output_dimensions(1:2) prod(data_out.output_dimensions(3:end))] );
                data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
                    opt_struct.filter_width,opt_struct.filter_window,true);
                data_buffer.data=reshape(data_buffer.data,data_out.output_dimensions );
                %elseif strcmp(data_in.vol_type,'3D')
            elseif regexpi(data_in.vol_type,'3D|4D');
                %% Filter 3D|4D non-radial
                fermi_filter_isodim2_memfix_obj(data_buffer,...
                    opt_struct.filter_width,opt_struct.filter_window,false,filter_input);
                
                %                 data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
                %                     opt_struct.filter_width,opt_struct.filter_window,false);
                %             elseif strcmp(data_in.vol_type,'4D')
                %                 data_buffer.data=fermi_filter_isodim2(data_buffer.data,...
                %                     opt_struct.filter_width,opt_struct.filter_window,false);
            elseif regexpi(data_in.vol_type,'radial');
                %% Filter Radial
                mem_efficient_filter=true;
                if mem_efficient_filter;
                    fermi_filter_isodim2_memfix_obj(data_buffer,...
                        opt_struct.filter_width,opt_struct.filter_window,false);
                else
                    if isfield(data_buffer.headfile,'processing_chunk')
                        t_s=data_buffer.headfile.processing_chunk;
                        t_e=data_buffer.headfile.processing_chunk;
                        fermi_filter_isodim2_memfix_obj(data_buffer,...
                            opt_struct.filter_width,opt_struct.filter_window,false);
                    else
                        t_s=1;
                        t_e=d_struct.t;
                        vol_select.z=':';
                        vol_select.x=':';
                        vol_select.y=':';
                        vol_select.c=':';
                        vol_select.p=':';
                        if ~isprop(data_buffer.filter_vol_select)
                            data_buffer.addprop('filter_vol_select');
                        end
                        % for time_pt=1:d_struct.t
                        dind=strfind(opt_struct.output_order,'t');
                        for time_pt=t_s:t_e  %xyzcpt
                            vol_select.t=time_pt;
                            data_buffer.filter_vol_select=vol_select;
                            %%%% load per time point radial here .... ?
                            %                     if d_struct.t>1
                            %                         load(['/tmp/temp_' num2str(time_pt) '.mat' ],'data','-v7.3');
                            %                         data_buffer.data=data;
                            %                     end
                            
                            fermi_filter_isodim2_memfix_obj(data_buffer,...
                                opt_struct.filter_width,opt_struct.filter_window,false);
                        end
                        clear vol_select;
                    end
                end
            else
                warning('%svol_type not specified, DID NOT PERFORM FILTER. \n can use vol_type_override=[2D|3D] to overcome headfile parse defficiency.',data_tag);
                pause(opt_struct.warning_pause);
            end
            %
        else
            fprintf('skipping fermi filter\n');
        end
        %% write kspace image log(abs(img))
        kimg_code='';
        if recon_strategy.recon_operations>1 || length(recon_strategy.recon_operations)>1
            kimg_code=sprintf(['_%' num2str(length(recon_strategy.recon_operations)) 'd'],recon_num);
        end
        fig_id=disp_vol_center(data_buffer.data,1,300+recon_num,[work_dir_img_path_base kimg_code '_kimage_preview' ] );
        if fig_id>0
            set(fig_id,'Name',sprintf('kspace_pre_fft_r%i',recon_num));
        end
        if opt_struct.write_kimage && ~( opt_struct.write_kimage_unfiltered && opt_struct.skip_filter)
            %%% should move the kspace writing code to here with a check if it already exists, in the case we're iterating over it for some reason.
            %             if  ~isprop(data_buffer,'kspace')
            %                 data_buffer.addprop('kspace');
            %                 data_buffer.kspace=data_buffer.data;
            %             end
            %             if opt_struct.write_kimage && ~opt_struct.skip_filter && ~opt_struct.skip_load
            fprintf('\twrite_kimage make_nii\n');
            if ~opt_struct.write_kspace_complex
                nii=make_nii(log(abs(squeeze(data_buffer.data))));
            else
                nii=make_nii(data_buffer.data);
            end
            fprintf('\t\t save_nii\n');

            save_nii(nii,[work_dir_img_path_base kimg_code '_kimage.nii']);clear nii;
        end       
        
        %% interactive kspace editing
        % sometimes we have bad views in ksapce, this will auto stop hre to
        % let us edit in progfresss
        if opt_struct.idf
            if srtcmp(data_buffer.headfile.S_PSDname,'mge3d')
                warning('special handling for just gary''s gre errors due to supposed power glitch, else dbhere. This a terribly incomplete solution. should do better.');
                data_buffer.data(1:40,:,:)=0;
                data_buffer.data(2245:end,:,:)=0;
            else
                db_inplace('rad_mat','Interactive data fiddling(or insert word of preference)');
            end
        end
        
        
        %% fft, resort, cut bad data, and display
        if ~opt_struct.skip_fft
            %% fft
            if opt_struct.debug_stop_fft
                [l,~,f]=get_dbline('rad_mat');
                eval(sprintf('dbstop in %s at %d',f,l+3));
                warning('Debug stop requested.');
            end
            fprintf('Performing FFT on ');
            if strcmp(data_in.vol_type,'2D')
                %% fft-2D
                fprintf('%s volumes\n',data_in.vol_type);
%                 if ~exist('img','var') || numel(img)==1;
%                     img=zeros(data_out.output_dimensions);
%                 end
                %         xyzcpt
                if ( exist('old_way','var')  ) 
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
%                             img(...
%                                 dim_select.(opt_struct.output_order(1)),...
%                                 dim_select.(opt_struct.output_order(2)),...
%                                 dim_select.(opt_struct.output_order(3)),...
%                                 dim_select.(opt_struct.output_order(4)),...
%                                 dim_select.(opt_struct.output_order(5)),...
%                                 dim_select.(opt_struct.output_order(6)))=fftshift(ifft2(fftshift(data_buffer.data(...
%                                 dim_select.(opt_struct.output_order(1)),...
%                                 dim_select.(opt_struct.output_order(2)),...
%                                 dim_select.(opt_struct.output_order(3)),...
%                                 dim_select.(opt_struct.output_order(4)),...
%                                 dim_select.(opt_struct.output_order(5)),...
%                                 dim_select.(opt_struct.output_order(6))))));
                            data_buffer.data=fftshift(fftshift(ifft(ifft(fftshift(fftshift(data_buffer.data,1),2),[],1),[],2),1),2);

                            
                            if opt_struct.debug_mode>=20
                                fprintf('\n');
                            end
                        end
                    end
                end
                else
%                     w_dims=size(data_buffer.data);
%                     if ( numel(w_dims)> 4 ) 
                    data_buffer.data=fftshift(fftshift(ifft(ifft(fftshift(fftshift(data_buffer.data,1),2),[],1),[],2),1),2);
                    if opt_struct.debug_mode>=20
                        fprintf('\n');
                    end
                    clear w_dims;
                end
%                 data_buffer.data=img;
%                 clear img;
            elseif ~isempty(regexp(data_in.vol_type,'.*radial.*', 'once'))
                %% fft-radial
                fprintf('%s volumes\n',data_in.vol_type);
                fprintf('Radial fft optimizations\n');
                %%% timepoints handling
                if isfield(data_buffer.headfile,'processing_chunk')
                    %                     t_s=data_buffer.headfile.processing_chunk;
                    %                     t_e=data_buffer.headfile.processing_chunk;
                else
                    %                     t_s=1;
                    %                     t_e=d_struct.t;
                end
                %%% when we are over-gridding(almost all the time) we
                %%% should have a kspace property to work from.
                if ~isprop(data_buffer,'kspace')
                    fft_input='data';
                else
                    fft_input='kspace';
                end
                %                 if ~isprop(data_buffer,'kspace')
                %                     data_buffer.addprop('kspace');
                %                     fft_input='kspace';
                %                     data_buffer.kspace=data_buffer.data;
                %                     data_buffer.data=[];
                %                 else
                %                     fft_input='kspace';
                %                 end
                %                 for time_pt=t_s:t_e %%% this timepoint code only works when we're processing a single timepoint of data.
                %% multi-channel only
                dims=size(data_buffer.(fft_input));
                enddims=dims(4:end);
                [c_s,c_e]=center_crop(dims(1),d_struct.x);
                if numel(size(data_buffer.(fft_input)))>3
                    data_buffer.(fft_input)=reshape(data_buffer.(fft_input),[dims(1:3) prod(dims(4:end))]);
                end
                if numel(data_buffer.data) ~= prod(data_out.output_dimensions)
                    data_buffer.data=[];
                    fprintf('Prealocate output data\n');
                    % data_buffer.data=zeros([ d_struct.x,d_struct.x,d_struct.x  prod(dims(4:end))],'single');
                    % data_buffer.data=complex(data_buffer.data,data_buffer.data);
                    data_buffer.data=complex(zeros([ d_struct.x,d_struct.x,d_struct.x  prod(dims(4:end))],'single'));
                end
                t_fft=tic;
                fprintf('\t fft start\n\t');
                for v=1:size(data_buffer.(fft_input),4)
                    fprintf('%d ',v);
                    temp =fftshift(ifftn(data_buffer.(fft_input)(:,:,:,v)));
                    data_buffer.data(:,:,:,v)=temp(c_s:c_e,c_s:c_e,c_s:c_e);
                end
                %                 end
                dims=size(data_buffer.data);
                data_buffer.data=reshape(data_buffer.data,[ dims(1:3) enddims]);
                fprintf('FFT finished in %f seconds\n',toc(t_fft));
                data_buffer.headfile.grid_crop=[c_s,c_e];
                clear c_s c_e dims temp;
            else
                %% fft-3D+(not radial)
                fprintf('%s volumes\n',data_in.vol_type);
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
                % data_buffer.data=fftshift(fftshift(fftshift(ifft(ifft(ifft(data_buffer.data,[],1),[],2),[],3),1),2),3);
                % bad result has in checkerboard LX helped find solution
                % missing fftshifts prior to fft required.
                data_buffer.data=fftshift(fftshift(fftshift(ifft(ifft(ifft(fftshift(fftshift(fftshift(data_buffer.data,1),2),3),[],1),[],2),[],3),1),2),3);
                % fft with a change in res : ) not sure how/when this would
                % work... 
                
                %output=dim_X*1.4;test=fftshift(fftshift(fftshift(ifft(ifft(ifft(fftshift(fftshift(fftshift(padarray(data_buffer.data,[round((output-160)/2),round((output-160)/2),round((output-160)/2)],0,'both'),1),2),3),[],1),[],2),[],3),1),2),3);disp_vol_center(test,0,100);
%                 data_buffer.data=fftshift(ifftn(fftshift(data_buffer.data)));%%% THIS WAY IS CORRECT< MUST TEST PHASE (angle) TO PROVE OTHER METHODS.
                
                
            end
            %% resort images flip etc
            if strcmp(data_in.vol_type,'3D') && ~opt_struct.skip_resort
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
                elseif(strcmp(data_buffer.scanner_constants.scanner_vendor,'agilent') )
                    
                    if isfield(data_buffer.input_headfile,'alternate_echo_reverse' )
                        objlistx=1:d_struct.x;
                        objlisty=1:d_struct.y;
                        objlistz=1:d_struct.z;
                        if data_buffer.input_headfile.alternate_echo_reverse >= 1 && data_buffer.input_headfile.ne>1
                            objlistx=d_struct.x:-1:1;
                            fprintf('performing echo dimorder swapping ...');

                            if data_buffer.input_headfile.alternate_echo_reverse==3
                                param_swap_start=1;
                                param_swap_step=2;
                            elseif data_buffer.input_headfile.alternate_echo_reverse==4
                                param_swap_start=1;
                                param_swap_step=1;
                            else
                                param_swap_start=2;
                                param_swap_step=2;
                            end
                            dind=strfind(opt_struct.output_order,'p');
                            if dind~=5 %output_order
                                warning('THIS CODE WAS NOT SET UP TO ALLOW A CHANGE TO DEFAULT DIMENSION OUTPUT ORDER');
                            end
                            for tsn=1:d_struct.t
                                for csn=1:d_struct.c
                                    for psn=param_swap_start:param_swap_step:d_struct.p
                                        data_buffer.data(objlistx,objlisty,objlistz,csn,psn,tsn)=data_buffer.data(:,:,:,csn,psn,tsn);
                                    end
                                end
                            end
                            clear csn tsn psn param_swap_start param_swap_end;
                        end
                    end
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
                if ~exist('old_way','var')
                    pan_nd_image(data_buffer,opt_struct);
                else
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
            end
            %% combine channel data
            % should make collapse dimension function.
            if ~opt_struct.skip_combine_channels && d_struct.c>1
                if regexp(data_in.vol_type,'2D|3D')
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
                    %                     tind=strfind(opt_struct.output_order,'t');
                    dind=strfind(opt_struct.output_order,'c');
                    if isfield(data_buffer.headfile,'processing_chunk')
                        %                         t_s=data_buffer.headfile.processing_chunk;
                        %                         t_e=data_buffer.headfile.processing_chunk;
                    else
                        %                         t_s=1;
                        %                         t_e=d_struct.t;
                    end
                    % for time_pt=1:d_struct.t
%                     for time_pt=t_s:t_e
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
%                     end
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
            %             if recon_strategy.num_chunks>1
            %                 fprintf('Saving chunk %d...',chunk_num);
            %                 work_dir_img_path_base=[ data_buffer.headfile.work_dir_path '/C' data_buffer.headfile.U_runno ] ;
            %                 save_complex(data_buffer.data,[work_dir_img_path_base '_' num2str(chunk_num) '.rp.out']);
            %                 fprintf('\tComplete\n');
            %             end
        else
           fprintf('Skipped fft\n');
           if opt_struct.remove_slice
               % even though we skipped the recon this will keep our
               % headfile value up to date.
               d_struct.z=d_struct.z-1;
               data_buffer.headfile.dim_Z=d_struct.z;
               data_buffer.input_headfile.dim_Z=d_struct.z;
           end
        end
    end % end skipload
    %% save data
    % this needs a bunch of work, for now it is just assuming the whole pile of
    % data is sitting in memory awaiting saving, does not handle chunks or
    % anything correctly just now.
    if opt_struct.debug_stop_save
        [l,~,f]=get_dbline('rad_mat');
        eval(sprintf('dbstop in %s at %d',f,l+3));
        warning('Debug stop requested.');
    end
    %% sort headfile details
    %  mag=abs(raw_data(i).data);
    if opt_struct.skip_combine_channels
        channel_images=d_struct.c;
    else
        channel_images=1;
    end
    if ~exist('runnumbers','var')
        runnumbers=cell(channel_images*d_struct.p*d_struct.t,1);
        rindx=1;
    end
    if (opt_struct.fp32_magnitude==true)
        datatype='fp32';
    else
        datatype='raw';
    end
    data_buffer.headfile.F_imgformat=datatype;
    %%%set channel header settings and mnumber codes for the filename
    d_pos=indx_calc(recon_num,data_out.ds.Sub(recon_strategy.op_dims));
    d_s=struct; % we later check for fields, but this is only defined if we have operation dimensions left after our working dimensions. 
    %for all at once recons we wont have any dimensions to operate over.
    for dx=1:length(recon_strategy.op_dims)
        d_s.(recon_strategy.op_dims(dx))=d_pos(dx);
    end
    clear dx;
    if d_struct.c>1 && isfield(d_s,'c')
        channel_code=opt_struct.channel_alias(d_s.c);
        if isfield(data_buffer.headfile,'U_specid')
            s_exp='[0-9]{6}-[0-9]+:[0-9]+(;|)';
            m_s_exp=cell(1,d_struct.c);
            for rexp_c=1:d_struct.c
                m_s_exp{rexp_c}=s_exp;
            end
            m_exp=strjoin(m_s_exp,';');
            m_exp=['^' m_exp '$'];
            if regexp(data_buffer.headfile.U_specid,m_exp)
                specid_s=strsplit(data_buffer.headfile.U_specid,';');
                data_buffer.headfile.U_specid=specid_s{cn};
                data_buffer.headfile.U_specid_list=data_buffer.headfile.U_specid;
                fprintf('Multi specid found in multi channel, assigning singular specid on output %s <= %s\n',data_buffer.headfile.U_specid,data_buffer.headfile.U_specid);
            elseif regexp(data_buffer.headfile.U_specid,'.*;.*')
                warning('Multi specid found in multi channel, but not the right number for the number of channels, \n\ti.e %s did not match regex. %s\n',data_buffer.headfile.U_specid,m_exp);
                
            end
            clear s_exp m_s_exp;
        end
        
    else
        d_s.c=1;
        channel_code='';
    end
    m_code='';
    max_mnumber=d_struct.t*d_struct.p-1;% should generalize this to any dimension except xyzc
    m_length=length(num2str(max_mnumber));
    if recon_strategy.work_by_chunk || recon_strategy.work_by_sub_chunk
        if exist('d_s','var')
            m_number=(d_s.t-1)*d_struct.p+d_s.p-1;
        else
            m_number=0;
        end
        if d_struct.t> 1 || d_struct.p >1
            m_code=sprintf(['_m%0' num2str(m_length) '.0f'], m_number);
        else
        end
        
        
    end
    if ~opt_struct.skip_combine_channels && d_struct.c>1
        data_buffer.headfile.([data_tag 'volumes'])=data_buffer.headfile.([data_tag 'volumes'])/d_struct.c;
        d_struct.c=1;
    end
    space_dir_img_name =[ runno channel_code m_code];
    data_buffer.headfile.U_runno=space_dir_img_name;
    
    space_dir_img_folder=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '/' space_dir_img_name 'images' ];
    %     work_dir_img_name_per_vol =[ runno channel_code m_code];
    %     work_dir_img_path_per_vol=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '.work/' space_dir_img_name 'images' ];
    work_dir_img_path=[work_dir_img_path_base channel_code m_code];
    
    if d_struct.c > 1
        data_buffer.headfile.work_dir_path=data_buffer.engine_constants.engine_work_directory;
        data_buffer.headfile.runno_base=runno;
    end
    if ~isfield(data_buffer.headfile,'fovx')
        warning('No fovx');
        data_buffer.headfile.fovx=data_buffer.headfile.dim_X;
    end
    if ~isfield(data_buffer.headfile,'fovy')
        warning('No fovy');
        data_buffer.headfile.fovy=data_buffer.headfile.dim_Y;
    end
    if ~isfield(data_buffer.headfile,'fovz')
        warning('No fovz');
        data_buffer.headfile.fovz=data_buffer.headfile.dim_Z;
    end
    %% load rp file for reprocessing
    rp_path2=[work_dir_img_path  '.rp.out'];
    rp_path=[work_dir_img_path opt_struct.filter_imgtag '.rp.out'];
    if ~exist(rp_path,'file')
        rp_path=rp_path2;
%         opt_struct.skip_filter=false;
    end
        
    if opt_struct.skip_load && opt_struct.reprocess_rp ...
            && exist(rp_path,'file')
        if ~isprop(data_buffer,'data')
            data_buffer.addprop('data');
        end
        fprintf('Loading rp.out for reprocessing');
        % other load_complex calls ignore extra options, presubably rp.out is standardish.
        data_buffer.data=load_complex(rp_path, ...
            data_out.ds.Sub(recon_strategy.w_dims),'single','l',false,false); 
        % ,'single','b',0); 
    end
    clear rp_path rp_path2;
    %% save outputs
    fprintf('Reconstruction %d of %d Finished!\n',recon_num,recon_strategy.recon_operations);
    if ~opt_struct.skip_write
        fprintf('Saving...\n');
        %% save uncombined channel niis.
        if ~opt_struct.skip_combine_channels && d_struct.c>1 && ~opt_struct.skip_recon && opt_struct.write_unscaled
            if ~exist([work_dir_img_path_base '.nii'],'file') || opt_struct.overwrite
                fprintf('Saving image combined with method:%s using %i channels to output work dir.\n',opt_struct.combine_method,d_struct.c);
                nii=make_nii(abs(data_buffer.data), [ ...
                    data_buffer.headfile.fovx/d_struct.x ...
                    data_buffer.headfile.fovy/d_struct.y ...
                    data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                save_nii(nii,[work_dir_img_path_base opt_struct.filter_imgtag '.nii']);
            else
                warning('Combined Image already exists and overwrite disabled');
            end
        end
        %% write_unscaled_nD or group_scaling
        dim_select.x=':';
        dim_select.y=':';
        dim_select.z=':';
        data_buffer.headfile.group_max_atpct='auto';
        data_buffer.headfile.group_max_intensity=0;
        if opt_struct.write_unscaled_nD && ...
                (recon_strategy.work_by_chunk ||recon_strategy.work_by_sub_chunk )
            warning('nD unscaled save only supports all at once recon');
        elseif ~recon_strategy.work_by_chunk && ~recon_strategy.work_by_sub_chunk 
            if ~opt_struct.independent_scaling ||  ( opt_struct.write_unscaled_nD && ~opt_struct.skip_recon )
                % if group scale, or write_unscaled_nd.  why do we want
                % this for unscaled nd? its unscaled!
                data_buffer.headfile.group_max_atpct=0;
                if ~exist('old_way','var')
                    if opt_struct.skip_combine_channels 
                        c_div=data_out.ds.Sub('c');
                    else
                        c_div=1;
                    end
                    for vn=1:prod(data_in.ds.Sub(recon_strategy.op_dims))% for vn=1:numel(data_buffer.data)/(prod(data_out.ds.Sub(recon_strategy.w_dims))/c_div)
                        d_pos=indx_calc(vn,data_out.ds.Sub(recon_strategy.op_dims));%matlab has a function for this... its used int he mouse stitch code. i forgot it now .
                        % for dx=1:length(recon_strategy.op_dims)
                        %     d_s.(recon_strategy.op_dims(dx))=d_pos(dx);
                        % end
                        ed_string=strjoin(strsplit(num2str(d_pos),' '),',');
                        if ~isempty(ed_string)
                            tmp=abs(eval(['data_buffer.data(:,:,:,' strjoin(strsplit(num2str(d_pos),' '),',') ')' ]));
                        else
                            if numel(size(data_buffer.data))~=3
                                warning('data_buffer dims greater than 3 but didnt figure out which part we''re saving.');
                            end
                            tmp=abs(data_buffer.data);
                        end
%                         tmp=sort(tmp(:)); only needed when not doing
%                         perentile, should check performance of the two.
                        m_tmp=max(tmp(:)); % maybe do unshape, reshape for speed?
                        p_tmp=prctile(tmp(:),opt_struct.histo_percent);
                        if m_tmp>data_buffer.headfile.group_max_intensity
                            data_buffer.headfile.group_max_intensity=m_tmp;
                        end
                        if data_buffer.headfile.group_max_atpct<p_tmp
                            data_buffer.headfile.group_max_atpct=p_tmp;
                        end
                    end
                else
                    error('old_way bad');
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
                                if m_tmp>data_buffer.headfile.group_max_intensity
                                    data_buffer.headfile.group_max_intensity=m_tmp;
                                end
                                if data_buffer.headfile.group_max_atpct<p_tmp
                                    data_buffer.headfile.group_max_atpct=p_tmp;
                                end
                            end
                        end
                    end
                end
                if ( opt_struct.write_unscaled_nD && ~opt_struct.skip_recon ) %|| opt_struct.skip_write_civm_raw
                    fprintf('Writing debug outputs to %s\n',data_buffer.headfile.work_dir_path);
                    fprintf('\twrite_unscaled_nD save\n');
                    if ( strcmp(opt_struct.combine_method,'square_and_sum') ...
                            || strcmp(opt_struct.combine_method,'regrid')) && ~opt_struct.skip_combine_channels
                        nii=make_nii(abs(squeeze(data_buffer.data)), [ ...
                            data_buffer.headfile.fovx/d_struct.x ...
                            data_buffer.headfile.fovy/d_struct.y ...
                            data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                    else
                        nii=make_nii(abs(squeeze(data_buffer.data)), [ ...
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
        if recon_strategy.work_by_chunk||recon_strategy.work_by_sub_chunk|| ~recon_strategy.load_whole
            %% arbitrarychunksave.
            warning('this saving code a work in progress for chunks');
            %if length(w_dims)>3  foreach outputimage , saveimgae.
            if ( length(recon_strategy.w_dims)>3 && islogical(opt_struct.omit_channels) )
                [l,~,f]=get_dbline('rad_mat');
                eval(sprintf('dbstop in %s at %d',f,l+3));
                warning('w_dims CANT BE BIGGER THAN 3 YET!');
            end
            %%%% HAHA for each dim of w_dims outside xyz! we can
            %%%% for each output type
            %%%% save each output image

            %%% set param value in output
            % if te
            if isfield(data_buffer.headfile,'te_sequence')
                data_buffer.headfile.te=data_buffer.headfile.te_sequence(d_s.p);
            end
            % if tr
            if isfield(data_buffer.headfile,'tr_sequence')
                data_buffer.headfile.tr=data_buffer.headfile.tr_sequence(d_s.p);
            end
            % if alpha
            if isfield(data_buffer.headfile,'alpha_sequence')
                data_buffer.heafdile.alpha=data_buffer.headfile.alpha_sequence(d_s.p);
            end
            %% disp messages
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
                           
            %% pull single vol to save
            if ( opt_struct.write_complex ...
                    || opt_struct.write_complex_component ...
                    || opt_struct.write_unscaled ...
                    || ~opt_struct.skip_write_civm_raw) ...
                    &&( ~opt_struct.skip_recon  || opt_struct.reprocess_rp )
                fprintf('Extracting image channel:%0.0f param:%0.0f timepoint:%0.0f\n',d_s.c,d_s.p,d_s.t);
                tmp=data_buffer.data; % error! not pulling out expected
                %data
                %                 data_buffer.data=reshape(data_buffer.data,data_out.output_dimensions);
                %                 tmp=data_buffer.data(:,:,:,d_s.c,d_s.p,d_s.t); % ERROR Not handling output dimensionality!
                if numel(tmp)<prod(data_out.output_dimensions(1:3))
                    error('Save file not right, chunking error likly');
                end
            else
                tmp='RECON_DISABLED';
            end
            %% integrated rolling
            %
            %if opt_struct.integrated_rolling && numel(tmp)>=1024
            if numel(tmp)>=1024 % && opt_struct.integrated_rolling
                %db_inplace('rad_mat','db_testing rollcode');
                % this code never runs? what....
                channel_code_r=[channel_code '_'];
                field_postfix='';
                if ~opt_struct.integrated_rolling
                    fprintf('Calculating Recommended Roll\n');
                    field_postfix='_recommendation';
                else
                    fprintf('Integrated Rolling code\n');
                end
                if ~isfield(data_buffer.headfile, [ 'roll' channel_code_r 'corner_X' field_postfix])                    
                    [input_center,first_voxel_offset]=get_wrapped_volume_center(tmp,2);
                    ideal_center=[d_struct.x/2,d_struct.y/2,d_struct.z/2];
                    shift_values=ideal_center-input_center;
                    for di=1:length(shift_values)
                        if shift_values(di)<0
                            shift_values(di)=shift_values(di)+size(data_buffer.data,di);
                        end
                    end
                    data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' field_postfix ])=shift_values(strfind(opt_struct.output_order,'x'));
                    data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' field_postfix ])=shift_values(strfind(opt_struct.output_order,'y'));
                    data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' field_postfix ])=shift_values(strfind(opt_struct.output_order,'z'));
                    fprintf('\tSet Roll value\n');
                else
                    shift_values=[ data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' field_postfix ])
                        data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' field_postfix ])
                        data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' field_postfix ])
                        ];
                    first_voxel_offset=[1,1,1];
                    fprintf('\tExisting Roll value\n');
                end
                fprintf('\tshift by :');
                fprintf('%d,',shift_values);
                fprintf('\n');
                if opt_struct.integrated_rolling
                    tmp=circshift(tmp,round(shift_values));
                end
            elseif numel(tmp)<1024 &&~opt_struct.ignore_errors
                db_inplace('rad_mat','dataset wrong size, cannot continue');
            end
            %% save types.
            %% complex save
            %%% write imaginary and real components of complex data
            if opt_struct.write_complex_component && ~opt_struct.skip_recon
                if ~opt_struct.write_mat_format
                    fov = [data_buffer.headfile.fovx,...
                        data_buffer.headfile.fovy,...
                        data_buffer.headfile.fovz];
                    voxsize = fov./[data_buffer.headfile.dim_X data_buffer.headfile.dim_Y data_buffer.headfile.dim_Z];
                    origin=first_voxel_offset.*voxsize;
                    save_nii(make_nii(imag(tmp),voxsize,origin./voxsize-size(tmp)/2),[work_dir_img_path opt_struct.filter_imgtag '_i.nii']);
                    save_nii(make_nii(real(tmp),voxsize,origin./voxsize-size(tmp)/2),[work_dir_img_path opt_struct.filter_imgtag '_r.nii']);
                    write_headfile([work_dir_img_path opt_struct.filter_imgtag '_cplx_c.headfile'],data_buffer.headfile,0);
                else
                    save([work_dir_img_path opt_struct.filter_imgtag '.mat'],'img_imaginary','img_real','-v7.3');
                    write_headfile([work_dir_img_path opt_struct.filter_imgtag '_mat.headfile'],data_buffer.headfile,0);
                end
                clear img_real img_imaginary;
            end
            if ( opt_struct.write_complex  || recon_strategy.work_by_chunk || recon_strategy.work_by_sub_chunk ) ...
                    && ~opt_struct.skip_recon && ~opt_struct.skip_load && ~opt_struct.nifti_complex_only
                fprintf('\twrite_complex (radish_format) save\n');
                save_complex(tmp,[ work_dir_img_path opt_struct.filter_imgtag '.rp.out']);
            end

            if opt_struct.write_phase && ~opt_struct.skip_recon
                fprintf('\twrite_phase \n');
                nii=make_nii(angle(tmp), [ ...
                    data_buffer.headfile.fovx/d_struct.x ...
                    data_buffer.headfile.fovy/d_struct.y ...
                    data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                fprintf('\t\t save_nii\n');
                save_nii(nii,[work_dir_img_path opt_struct.filter_imgtag '_phase.nii']);
                clear nii;
            end
            
            %%% save unscaled nifti?
            
            %%% unscaled_nii_save
            if ( opt_struct.write_unscaled && ~opt_struct.skip_recon ) %|| opt_struct.skip_write_civm_raw
                fprintf('\twrite_unscaled save\n');
                tmp=abs(tmp);
                nii=make_nii(tmp, [ ...
                    data_buffer.headfile.fovx/d_struct.x ...
                    data_buffer.headfile.fovy/d_struct.y ...
                    data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                fprintf('\t\t save_nii\n');
                save_nii(nii,[work_dir_img_path opt_struct.filter_imgtag '.nii']);
                clear nii;
            end
            
            %% civmraw save
            if ~exist(space_dir_img_folder,'dir') || opt_struct.ignore_errors
                if ~opt_struct.skip_write_civm_raw || ~opt_struct.skip_write_headfile || opt_struct.write_complex
                    mkdir(space_dir_img_folder);
                end
            elseif ~opt_struct.overwrite
                % the folder existed, however we were not set for
                % overwrite
                error('Output directory existed! NOT OVERWRITING SOMEONE ELSES DATA UNLESS YOU TELL ME!, use overwrite option.');
            end
            if ~opt_struct.skip_write_headfile
                hf_path=[space_dir_img_folder '/' space_dir_img_name '.headfile'];
                fprintf('\twrite_headfile save \n\t\t%s\n',hf_path);
                data_buffer.headfile.output_image_path=space_dir_img_folder;
                write_headfile(hf_path,data_buffer.headfile,0);
                % insert validate_header perl script check here?
            end
            
            
            
            if (opt_struct.write_complex || ~opt_struct.skip_write_civm_raw ) ...
                    && (~opt_struct.skip_recon || opt_struct.reprocess_rp)
                fprintf('\tconvert_info_histo save\n');
                histo_bins=numel(tmp);
                if opt_struct.independent_scaling || recon_strategy.work_by_chunk || recon_strategy.work_by_sub_chunk
                    img_s=sort(abs(tmp(:)));
                    data_buffer.headfile.group_max_intensity=max(img_s);
                    data_buffer.headfile.group_max_atpct=img_s(round(numel(img_s)*opt_struct.histo_percent/100));%throwaway highest % of data... see if that helps.
                    fprintf('\tMax for scale = %f\n',data_buffer.headfile.group_max_atpct);
                    %                         else
                    %                              data_buffer.headfile.group_max_atpct= data_buffer.headfile.group_max_atpct;
                    clear img_s;
                end
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
                if ~opt_struct.skip_write_civm_raw && (~opt_struct.skip_recon || opt_struct.reprocess_rp)
                    if ~recon_strategy.work_by_chunk && ~recon_strategy.work_by_sub_chunk
                        fprintf('\tcivm_raw save\n');
                        % alternatively,
                        % ~recon_stragey.recon_operations>1    % : p
                        complex_to_civmraw(tmp,data_buffer.headfile.U_runno , ...
                            data_buffer.scanner_constants.scanner_tesla_image_code, ...
                            space_dir_img_folder,'',outpath,1,datatype)
                    end
                end
            end
            %%% convenience prompts
            %                     if ~opt_struct.skip_write_civm_raw||recon_strategy.num_chunks>1 %
            %                     when wouldnt i want the list of expected run numbers?
            %write_archive_tag(runno,spacename, slices, projectcode, img_format,civmid)
            runnumbers(rindx)={data_buffer.headfile.U_runno};
            rindx=rindx+1;
            
            %                     end
            
            
        else
            %% timepointonlychunksave
%             if (numel(data_buffer.data) == prod(data_out.output_dimensions) )
%             data_bufer.data=reshape(data_buffer.data,data_out.output_dimensions);
%             else
%                 warning('data_out dimensions issue');
%             end
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
            if recon_strategy.num_chunks>1&&recon_strategy.recon_operations>1
                dim_select.t=1;
            else
                dim_select.t=tn;
            end
            for cn=1:d_struct.c
                dim_select.c=cn;
                for pn=1:d_struct.p
                    dim_select.p=pn;
                    
                    %% pull single vol to save
                    if ~opt_struct.skip_recon && ( ...
                            opt_struct.write_complex ...
                            || opt_struct.write_complex_component ...
                            || opt_struct.write_unscaled ...
                            || ~opt_struct.skip_write_civm_raw)
                        fprintf('Extracting image channel:%0.0f param:%0.0f timepoint:%0.0f\n',cn,pn,tn);
                        if ~isempty(regexp(data_in.vol_type,'.*radial.*', 'once')) && strcmp(opt_struct.regrid_method,'scott')&& recon_num==1
                            oo=[ data_out.ds.Rem('c') 'c'];
                            data_out.output_dimensions(strfind(data_out.output_order,'c'))=1;
                            data_out.ds.dim_sizes=data_out.output_dimensions;
                            data_out.ds.dim_sizes=data_out.ds.Sub(oo);
                            data_out.ds.dim_order=oo;
                            data_out.output_dimensions=data_out.ds.Sub(oo);
                            data_out.output_order=oo;
                        elseif  ~isempty(regexp(data_in.vol_type,'.*radial.*', 'once')) && strcmp(opt_struct.regrid_method,'scott')&& recon_num~=1
                            warning('POSSIBLE REGRID RADIAL ERROR');
                        end
                        tmp=squeeze(data_buffer.data(...
                            dim_select.(data_out.output_order(1)),...
                            dim_select.(data_out.output_order(2)),...
                            dim_select.(data_out.output_order(3)),...
                            dim_select.(data_out.output_order(4)),...
                            dim_select.(data_out.output_order(5)),...
                            dim_select.(data_out.output_order(6))...
                            ));% pulls out one volume at a time.
                        
                        %                         end
                        if numel(tmp)<prod(data_out.ds.Sub('xyz')) && ~strcmp(opt_struct.radial_mode,'fast')%output_dimensions(1:3))
                            error('Save file not right, chunking error likely');
                        end
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
                            if regexp(data_buffer.headfile.U_specid,m_exp)
                                specid_s=strsplit(data_buffer.headfile.U_specid,';');
                                data_buffer.headfile.U_specid=specid_s{cn};
                                data_buffer.headfile.U_specid_list=data_buffer.headfile.U_specid;
                                fprintf('Multi specid found in multi channel, assigning singular specid on output %s <= %s\n',data_buffer.headfile.U_specid,data_buffer.headfile.U_specid);
                            elseif regexp(data_buffer.headfile.U_specid,'.*;.*')
                                warning('Multi specid found in multi channel, but not the right number for the number of channels, \n\ti.e %s did not match regex. %s\n',data_buffer.headfile.U_specid,m_exp);

                            end
                            clear s_exp m_s_exp;
                        end

                    else
                        channel_code='';
                    end
                    
                    %% integrated rolling
                    %
                    channel_code_r=[channel_code '_'];
                    field_postfix='';
                    if ~opt_struct.integrated_rolling
                        fprintf('Calculating Recommended Roll\n');
                        field_postfix='_recommendation';
                    else
                        fprintf('Integrated Rolling code\n');
                    end
                    if ~isfield(data_buffer.headfile, [ 'roll' channel_code_r 'corner_X' field_postfix])
                        [input_center,first_voxel_offset]=get_wrapped_volume_center(tmp,2);
                        ideal_center=[d_struct.x/2,d_struct.y/2,d_struct.z/2];
                        shift_values=ideal_center-input_center;
                        for di=1:length(shift_values)
                            if shift_values(di)<0
                                shift_values(di)=shift_values(di)+size(data_buffer.data,di);
                            end
                        end
                        data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' field_postfix ])=shift_values(strfind(opt_struct.output_order,'x'));
                        data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' field_postfix ])=shift_values(strfind(opt_struct.output_order,'y'));
                        data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' field_postfix ])=shift_values(strfind(opt_struct.output_order,'z'));
                        fprintf('\tSet Roll value\n');
                    else
                        shift_values=[ data_buffer.headfile.([ 'roll' channel_code_r 'corner_X' field_postfix ])
                            data_buffer.headfile.([ 'roll' channel_code_r 'corner_Y' field_postfix ])
                            data_buffer.headfile.([ 'roll' channel_code_r 'first_Z' field_postfix ])
                            ];
                        first_voxel_offset=[1,1,1];
                        fprintf('\tExisting Roll value\n');
                    end
                    fprintf('\tshift by :');
                    fprintf('%d,',shift_values);
                    fprintf('\n');
                    if opt_struct.integrated_rolling
                        tmp=circshift(tmp,round(shift_values));
                    end
                    m_number=(tn-1)*d_struct.p+pn-1;
                    if d_struct.t> 1 || d_struct.p >1
                        m_code=sprintf(['_m%0' num2str(m_length) '.0f'], m_number);
                    else
                        m_code='';
                    end
                    space_dir_img_name =[ runno channel_code m_code];
                    
%                     if(recon_strategy.num_chunks>1)
%                         out_runnos.(space_dir_img_name)=1; %make a struct of our runnums
%                     end    

                    %% sort headfile details
                    data_buffer.headfile.U_runno=space_dir_img_name;

                    space_dir_img_folder=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '/' space_dir_img_name 'images' ];
%                     work_dir_img_name_per_vol =[ runno channel_code m_code];
%                     work_dir_img_path_per_vol=[data_buffer.engine_constants.engine_work_directory '/' space_dir_img_name '.work/' space_dir_img_name 'images' ];
                    work_dir_img_path=[work_dir_img_path_base channel_code m_code];
                    if d_struct.c > 1
                        data_buffer.headfile.work_dir_path=data_buffer.engine_constants.engine_work_directory;
                        data_buffer.headfile.runno_base=runno;
                    end
                    %%% set param value in output
                    % if te
                    if isfield(data_buffer.headfile,'te_sequence') && numel(data_buffer.headfile.te_sequence)>=pn
                        data_buffer.headfile.te=data_buffer.headfile.te_sequence(pn);
                    end
                    % if tr
                    if isfield(data_buffer.headfile,'tr_sequence') && numel(data_buffer.headfile.tr_sequence)>=pn
                        data_buffer.headfile.tr=data_buffer.headfile.tr_sequence(pn);
                    end
                    % if alpha
                    if isfield(data_buffer.headfile,'alpha_sequence')&& numel(data_buffer.headfile.alpha_sequence)>=pn
                        data_buffer.heafdile.alpha=data_buffer.headfile.alpha_sequence(pn);
                    end
                    
                    %% disp messages
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
                    
                    %% save types.
                    %%% complex save
                    %%% write imaginary and real components of complex data
                    if opt_struct.write_complex_component && ~opt_struct.skip_recon
                        if ~opt_struct.write_mat_format
                            fov = [data_buffer.headfile.fovx,...
                                data_buffer.headfile.fovy,...
                                data_buffer.headfile.fovz];
                            voxsize = fov./[data_buffer.headfile.dim_X data_buffer.headfile.dim_Y data_buffer.headfile.dim_Z];
                            origin=first_voxel_offset.*voxsize;
                            save_nii(make_nii(imag(tmp),voxsize,origin./voxsize-size(tmp)/2),[work_dir_img_path opt_struct.filter_imgtag '_i.nii']);
                            save_nii(make_nii(real(tmp),voxsize,origin./voxsize-size(tmp)/2),[work_dir_img_path opt_struct.filter_imgtag '_r.nii']);
                            write_headfile([work_dir_img_path opt_struct.filter_imgtag '_cplx_c.headfile'],data_buffer.headfile,0);
                        else
                            save([work_dir_img_path opt_struct.filter_imgtag '.mat'],'img_imaginary','img_real','-v7.3');
                            write_headfile([work_dir_img_path opt_struct.filter_imgtag '_mat.headfile'],data_buffer.headfile,0);
                        end
                        clear img_real img_imaginary;
                    end
                    if opt_struct.write_complex && ~opt_struct.skip_recon && ~opt_struct.nifti_complex_only
                        fprintf('\twrite_complex (radish_format) save\n');
                        save_complex(tmp,[ work_dir_img_path '.rp.out']);
                    end
                    if opt_struct.write_phase && ~opt_struct.skip_recon
                        fprintf('\twrite_phase \n');
                        nii=make_nii(angle(tmp), [ ...
                            data_buffer.headfile.fovx/d_struct.x ...
                            data_buffer.headfile.fovy/d_struct.y ...
                            data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path opt_struct.filter_imgtag '_phase.nii']);
                        clear nii;
                        %%%%phasewrite(tmp,[work_dir_img_path
                    end
                    %%% kimage_
                    if isprop(data_buffer,'kspace')
                    if opt_struct.write_kimage && ~opt_struct.skip_filter && ~opt_struct.skip_load
                        fprintf('\twrite_kimage make_nii\n');
                        
                        if ~opt_struct.write_kspace_complex
                            nii=make_nii(log(abs(data_buffer.kspace(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                ))));
                        else
                            nii=make_nii(((data_buffer.kspace(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                ))));
                        end
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path '_kimage.nii']);
                    end
                    end
                    if isprop(data_buffer,'kspace_unfiltered')
                    %%% kimage_unfiltered
                    if opt_struct.write_kimage_unfiltered  && ~opt_struct.skip_load
                        fprintf('\twrite_kimage_unfiltered make_nii\n');
                        if ~opt_struct.write_kspace_complex
                            nii=make_nii(log(abs(data_buffer.kspace_unfiltered(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                ))));
                        else
                        nii=make_nii(((data_buffer.kspace_unfiltered(...
                                dim_select.(opt_struct.output_order(1)),...
                                dim_select.(opt_struct.output_order(2)),...
                                dim_select.(opt_struct.output_order(3)),...
                                dim_select.(opt_struct.output_order(4)),...
                                dim_select.(opt_struct.output_order(5)),...
                                dim_select.(opt_struct.output_order(6))...
                                ))));
                        end
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path '_kspace_unfiltered.nii']);
                    end
                    end
                    %%% unscaled_nii_save
                    if ( opt_struct.write_unscaled && ~opt_struct.skip_recon ) %|| opt_struct.skip_write_civm_raw
                        fprintf('\twrite_unscaled save\n');
                        if ~isfield(data_buffer.headfile,'fovx')
                            warning('No fovx');
                            data_buffer.headfile.fovx=data_buffer.headfile.dim_X;
                        end
                        if ~isfield(data_buffer.headfile,'fovy')
                            warning('No fovy');
                            data_buffer.headfile.fovy=data_buffer.headfile.dim_Y;
                        end
                        if ~isfield(data_buffer.headfile,'fovz')
                            warning('No fovz');
                            data_buffer.headfile.fovz=data_buffer.headfile.dim_Z;
                        end
                        nii=make_nii(abs(tmp), [ ...
                            data_buffer.headfile.fovx/d_struct.x ...
                            data_buffer.headfile.fovy/d_struct.y ...
                            data_buffer.headfile.fovz/d_struct.z]); % insert fov settings here ffs....
                        fprintf('\t\t save_nii\n');
                        save_nii(nii,[work_dir_img_path opt_struct.filter_imgtag '.nii']);
                    end
                    
                    %%% civmraw save
                    if ~exist(space_dir_img_folder,'dir') || opt_struct.ignore_errors
                        if ~opt_struct.skip_write_civm_raw || ~opt_struct.skip_write_headfile || opt_struct.write_complex
                            mkdir(space_dir_img_folder);
                        end
                    elseif ~opt_struct.overwrite
                        % the folder existed, however we were not set for
                        % overwrite
                        error('Output directory existed! NOT OVERWRITING SOMEONE ELSES DATA UNLESS YOU TELL ME!, use overwrite option.');
                    end
                    if ~opt_struct.skip_write_headfile
                        hf_path=[space_dir_img_folder '/' space_dir_img_name '.headfile'];
                        fprintf('\twrite_headfile save \n\t\t%s\n',hf_path);
                        data_buffer.headfile.output_image_path=space_dir_img_folder;
                        write_headfile(hf_path,data_buffer.headfile,0);
                        % insert validate_header perl script check here?
                    end
                    if (opt_struct.write_complex || ~opt_struct.skip_write_civm_raw ) ...
                            && (~opt_struct.skip_recon || opt_struct.reprocess_rp)
                        fprintf('\tconvert_info_histo save\n');
                        histo_bins=numel(tmp);
                        if opt_struct.independent_scaling
                            img_s=sort(abs(tmp(:)));
                            data_buffer.headfile.group_max_intensity=max(img_s);
                            data_buffer.headfile.group_max_atpct=img_s(round(numel(img_s)*opt_struct.histo_percent/100));%throwaway highest % of data... see if that helps.
                            fprintf('\tMax for scale = %f\n',data_buffer.headfile.group_max_atpct);
                            %                         else
                            %                              data_buffer.headfile.group_max_atpct= data_buffer.headfile.group_max_atpct;
                            clear img_s;
                        end
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
                        
                        
                        if ~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon
                            if ~recon_strategy.work_by_chunk && ~recon_strategy.work_by_sub_chunk
                                fprintf('\tcivm_raw save\n');
                                % alternatively,
                                % ~recon_stragey.recon_operations>1    % : p
                                complex_to_civmraw(tmp,data_buffer.headfile.U_runno , ...
                                    data_buffer.scanner_constants.scanner_tesla_image_code, ...
                                    space_dir_img_folder,'',outpath,1,datatype)
                            end
                        end
                    end
                    %%% convenience prompts
%                     if ~opt_struct.skip_write_civm_raw||recon_strategy.num_chunks>1 %
%                     when wouldnt i want the list of expected run numbers?
                        %write_archive_tag(runno,spacename, slices, projectcode, img_format,civmid)
                        runnumbers(rindx)={data_buffer.headfile.U_runno};
                        rindx=rindx+1;
                        
%                     end
                    
                end
            end
            %% save ijmacro
            if recon_num==1 && exist('work_dir_img_path_base','var')
                openmacro_path=sprintf('%s%s',work_dir_img_path_base ,'.ijm');
                if opt_struct.overwrite && exist(openmacro_path,'file') ...
                        && recon_num==1 && recon_strategy.recon_operations==1 && tn==1
                    delete(openmacro_path);
                elseif exist(openmacro_path,'file')
                    warning('macro exists at:%s\n did you mean to enable overwrite?',openmacro_path);
                end
                if exist('hf_path','var') ...
                        && recon_num==1 && recon_strategy.recon_operations==1 && tn==1
                    write_convenience_macro(data_buffer,openmacro_path,opt_struct,hf_path);
                end
            end
        end
        end

    elseif opt_struct.skip_write && ( ~opt_struct.skip_recon || ~opt_struct.skip_fft )
        fprintf('No outputs written.\n');
%         stop here to allow a manual save during execution.
    else
        fprintf('No outputs written.\n');
    end
    if (recon_strategy.num_chunks>1)
        fprintf('chunk_time:%0.2f\n',toc(time_chunk));
    end
    clear tmp;
%populate our ij_prompt
if (~opt_struct.skip_recon&&exist('openmacro_path','var') )||opt_struct.force_ij_prompt
    % display ij call to examine images.
    [~,txt]=system('echo -n $ijstart');  %-n for no newline i think there is a smarter way to get system variables but this works for now.
    ij_prompt=sprintf('%s -macro %s',txt, openmacro_path);
    mat_ij_prompt=sprintf('system(''%s'');',ij_prompt);
    data_buffer.headfile.rad_mat_ij_macro=openmacro_path;
    data_buffer.headfile.rad_mat_ij_macro_prompt=ij_prompt;
end


end
post_commands={};
%% stich chunks together
% this is not implimented yet.

%% run group reformer for select datasets.
if recon_strategy.num_chunks>1&&~opt_struct.skip_write&&~opt_struct.skip_write_civm_raw %recon_strategy.work_by_chunk
    if ~exist('runnumbers','var')
        error('Run numbers were not defined, cannot reform_group');
    end
    runnumbers=runnumbers(~cellfun('isempty',runnumbers)) ;
    if numel(runnumbers) >1 && recon_strategy.recon_operations>1
        if size(runnumbers,2)==1
            c=sprintf(['reform_group '  strjoin(runnumbers',' ') ]);
        else
            c=sprintf(['reform_group '  strjoin(runnumbers,' ') ]);
        end
    end
    if ~opt_struct.skip_postreform && exist('c','var')
        system(c);
    end
end

%% convenience prompts
if ~isempty(ij_prompt)&& ~opt_struct.skip_write_civm_raw
    fprintf('test civm image output from a terminal using following command\n');
    fprintf('  (it may only open the first and last in large sequences).\n');
    fprintf('\n\n%s\n\n\n',ij_prompt);
    fprintf('test civm image output from matlab using following command\n');
    fprintf('  (it may only open the first and last in large sequences).\n');
    fprintf('\n%s\n\n',mat_ij_prompt);
    post_commands{end+1}=ij_prompt;
end

if opt_struct.force_write_archive_tag || (~opt_struct.skip_write_civm_raw && ~opt_struct.skip_recon )
    if isfield(data_buffer.headfile,'U_code')
        archive_tag_output=write_archive_tag(runnumbers,...
            data_buffer.engine_constants.engine_work_directory,...
            d_struct.z,data_buffer.headfile.U_code,datatype,...
            data_buffer.headfile.U_civmid,false);
        fprintf('initiate archive from a terminal using following command, (should change person to yourself). \n\n\t%s\n\n OR run archiveme in matlab useing \n\tsystem(''%s'');\n',archive_tag_output,archive_tag_output);
    end
    warning('THIS CODE IS NOT WELL TESTED');
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
                disk_path= [ data_buffer.headfile.work_dir_path '/' ...
                    data_buffer.headfile.runno_base data_postfix '/' ...
                    data_buffer.headfile.runno_base data_postfix 'images' '/' ];
                fprintf('Crazy double roll calculation requested, loading path%s\n',disk_path);
                data_vol=read_civm_image(disk_path );
            end
            if opt_struct.roll_with_centroid
                new_center=get_volume_centroid(data_vol);
            else
                new_center=get_wrapped_volume_center(data_vol,2);
            end
            %%%% could use hist followed by extrema or derivative and find
            % center=[d_struct.x/2,d_struct.y/2,d_struct.z/2];
%             center=size(data_buffer.data)/2;
            center=[data_out.output_dimensions(strfind(data_out.output_order,'x')),...
                data_out.output_dimensions(strfind(data_out.output_order,'y')),...
                data_out.output_dimensions(strfind(data_out.output_order,'z'))]/2;
            for cidx=numel(center):-1:1
                if center(cidx)<1
                    center(cidx)=[];
                end
            end
            diff=new_center-center;
            %         diff(3)=-diff(3);
            %         diff(2)=-diff(2);
            for di=1:length(diff)
                if diff(di)<0
                    diff(di)=diff(di)+size(data_buffer.data,di);
                end
            end
            if numel(diff)<3
                t=diff;
                diff=zeros(3,1);
                diff(1:numel(t))=t;
            end
            roll.x(c_r)=round(diff(1));
            roll.y(c_r)=round(diff(2));
            roll.z(c_r)=round(diff(3));
            
            %     xroll=diff(1)+d_struct.x;
            %     yroll=diff(2)+d_struct.y;
            %     xroll=round(centroid(1)-d_struct.x/2);
            %     yroll=d_struct.y-round(centroid(2)-d_struct.y/2);
            %     zroll=round(centroid(3)-d_struct.z/2);
            cmd_list{c_r}=sprintf('roll_3d -x %d -y %d -z %d %s',roll.x(c_r),roll.y(c_r), roll.z(c_r), run_string);
        end
        fprintf('Use terminal to run roll_3d with command, (Replace the number''s with your deisred roll, example values are a best guess based on a find minimum calculation.)\n%s\n\n', strjoin(cmd_list,'\n'));
        fprintf('OR run roll_3d in matlab using \n');
        
        roll_prompt='';
        for cmd_n=1:length(cmd_list)
            roll_prompt=sprintf('%ssystem(''%s'');\n',roll_prompt,cmd_list{cmd_n});
        end
        fprintf('%s',roll_prompt);
        data_buffer.headfile.rad_mat_roll_prompt=strjoin(cmd_list,'\n');
        post_commands{end+1}=data_buffer.headfile.rad_mat_roll_prompt;
    end
    
end
cmd_outfile=[  data_buffer.headfile.work_dir_path '/' 'post_commands.txt' ];
fprintf('Calculated terminal commands saved to \n\t%s.\n',cmd_outfile); 
co_fid=fopen(cmd_outfile,'w+');
if co_fid<=0
    warning('couldnt open cmd_output ');
else
fprintf(co_fid,'%s\n',strjoin(post_commands,'\n'));
fclose(co_fid);
end
%% End of line set output
%%% handle image return type at somepoint in future using image_return_type
%%% option, for now we're just going to magnitude. 
if ~isprop(data_buffer,'data') 
    fprintf('no data outputs\n');
    img=0;
elseif numel(data_buffer.data)>0
    img=abs(data_buffer.data);
end
success_status=true;
fprintf('\nTotal rad_mat time is %f second\n',toc(rad_start));
fprintf('\n');
