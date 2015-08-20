function gui_info_collect(data_buffer,opt_struct)
%% collect gui info (or set testmode)
%check civm runno convention
% add loop while gui has not run successfully,
if isempty(regexp(data_buffer.headfile.U_runno,'^[A-Z][0-9]{5,6}.*', 'once'))
    %~strcmp(runno(1),'S') && ~strcmp(runno(1),'N') || length(runno(2:end))~=5 || isnan(str2double(runno(2:end)))
    display('runno does not match CIVM convention, the recon will procede in testmode')
    opt_struct.testmode=1;
end
%opt_struct.param_file
% if not testmode then create headfile
gui_info_lines='';
if islogical(opt_struct.param_file) && ~opt_struct.testmode
    if opt_struct.param_file
        warn('You tried to specifiy a param file, but forgot to enter it.');
        pause( opt_struct.warning_pause ) ;
    end
    if opt_struct.debug_mode>=10
        display('Gathering gui info ...');
    end
    data_buffer.engine_constants.engine_recongui_menu_path;
    gui_cmd=sprintf(['$GUI_APP ' ...
        ' ''' data_buffer.engine_constants.engine_constants_path ...
        ' ' data_buffer.engine_constants.engine_recongui_menu_path ...
        ' ' data_buffer.scanner_constants.scanner_tesla ...
        ' ''']);
    fprintf('%s\n',gui_cmd);
    [~, gui_dump]=system(gui_cmd);
    use_GUI_DUMP=true;
    %opt_struct.param_file
elseif ~islogical(opt_struct.param_file)
    if ~exist([ data_buffer.engine_constants.engine_recongui_paramfile_directory '/' opt_struct.param_file ],'file')
        %%% this should also support regen of param file....
        [~, param_file_name, e]=fileparts(opt_struct.param_file);
        param_file_name=[param_file_name e ];
%         data_buffer.scanner_constants.scanner_host_name
        [~]=system(sprintf('%s '' %s %s %s'' ',getenv('GUI_APP') ,...
            data_buffer.engine_constants.engine_constants_path ,...%    ec.engine_recongui_menu_path ,...
            data_buffer.headfile.U_scanner ,... %     ' ' sc.scanner_tesla ...
            param_file_name ...
            ));
    end
    if ~exist([ data_buffer.engine_constants.engine_recongui_paramfile_directory '/' opt_struct.param_file ],'file')
        error('Param file %s/%s failed to generate!',data_buffer.engine_constants.engine_recongui_paramfile_directory,opt_struct.param_file );
    end
    use_GUI_DUMP=false;
    pf=read_headfile([ data_buffer.engine_constants.engine_recongui_paramfile_directory '/' opt_struct.param_file ]);
    data_buffer.input_headfile=combine_struct(data_buffer.input_headfile,pf,'U_');
    data_buffer.headfile      =combine_struct(data_buffer.headfile,pf,'U_');
    % pf.fields=fieldnames(pf);
    % gui_info_lines=cell(numel(pf.fields),1);
    % for fn=1:numel(pf.fields)
    %     gui_info_lines{fn}=[pf.fields(fn) ':::' pf.(pf.fields{fn}) ];
    % end
elseif opt_struct.testmode
    display('this recon will not be archiveable, rerun same command with skip_recon to rewrite just the headfile using the gui settings.');
    %     data_buffer.engine_constants.engine_recongui_menu_path;
    if false
        [~, gui_dump]=system(['$GUI_APP ' ...
            ' ''' data_buffer.engine_constants.engine_constants_path ...
            ' ' data_buffer.engine_constants.engine_recongui_menu_path ...
            ' ' data_buffer.scanner_constants.scanner_tesla ...
            ' ' 'check' ...
            ' ''']);
        gui_info_lines=strtrim(strsplit(gui_dump,' '));
        gui_dump=strjoin(gui_info_lines,':::test\n');
        
    end
    use_GUI_DUMP=false;
end

if use_GUI_DUMP
    gui_info_lines=strtrim(strsplit(gui_dump,'\n'));
    for l=1:length(gui_info_lines)
        gui_info=strsplit(gui_info_lines{l},':::');
        if length(gui_info)==2
            data_buffer.headfile.(['U_' gui_info{1}])=gui_info{2};
            data_buffer.input_headfile.(['U_' gui_info{1}])=gui_info{2};
            fprintf('adding meta line %s=%s\n', ['U_' gui_info{1}],data_buffer.headfile.(['U_' gui_info{1}]));
        else
            fprintf('ignoring gui input line:%s\n',gui_info_lines{l});
        end
    end
    if isempty(gui_info_lines) && ~opt_struct.ignore_errors
        error('GUI did not return values! gui returned %s',gui_dump);
    end
end

clear gui_info gui_dump gui_info_lines l pf use_GUI_DUMP;
end