function puller(data_buffer,opt_struct,scanner,puller_data,output)
% function puller(data_buffer,opt_struct,scanner,puller_data)
% pull the data to local machine

if ~exist('output','var')
    if ~isfield(data_buffer.headfile,'work_dir_path') ...
            && isfield(data_buffer.headfile,'U_runno') ...
            && isprop(data_buffer,'engine_constants') ...
            && isfield(data_buffer.engine_constants,'engine_work_directory')
        work_dir_name= [data_buffer.headfile.U_runno '.work'];
        data_buffer.headfile.work_dir_path=[data_buffer.engine_constants.engine_work_directory '/' work_dir_name];
        output=data_buffer.headfile.work_dir_path;
    else
        output='';
    end
else
   % data_buffer.headfile.work_dir_path=output;
end
if ~isfield(opt_struct,'puller_option_string')
    opt_struct.puller_option_string = '';
end
if isfield(opt_struct,'overwrite') && opt_struct.overwrite==1
    opt_struct.puller_option_string=[' -o ' opt_struct.puller_option_string];
else 
    opt_struct.overwrite=0;
end
if  isfield(opt_struct,'existing_data') && opt_struct.existing_data==1 %&& (exist(output,'dir') || isempty(output) )
    opt_struct.puller_option_string=[' -e ' opt_struct.puller_option_string];
else
    opt_struct.existing_data=0;
end

% cmd_list=['puller_simple ' opt_struct.puller_option_string ' ' scanner ' ''' puller_data ''' ' output];
cmd_list=sprintf('puller_simple -r %s %s %s %s',opt_struct.puller_option_string,scanner,puller_data,output);

if ~isfield(data_buffer.headfile,'comment')
    data_buffer.headfile.comment={};
end
data_buffer.headfile.comment{end+1}=['# \/ pull cmd ' '\/'];
data_buffer.headfile.comment{end+1}=['# ' cmd_list ];
data_buffer.headfile.comment{end+1}=['# /\ pull cmd ' '/\'];
if ~opt_struct.existing_data || ~exist(output,'dir')  %&&~opt_struct.skip_recon
    if ~exist(output,'dir') && opt_struct.existing_data
        warning(sprintf('You wanted existing data BUT IT WASNT THERE Or I dont know how to look!\n\tContinuing by tring to fetch new.\nMaybe puller will understand you.'));
        pause(1);
    end
    p_status =system(cmd_list);
    if p_status ~= 0 ...
            && ( ~isfield(opt_struct,'ignore_errors') || ~opt_struct.ignore_errors )
        error('puller failed:%s',cmd_list);
    end
end
%clear cmd s datapath puller_data puller_data work_dir_name p_status;
end
