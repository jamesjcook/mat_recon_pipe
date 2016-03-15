function puller(data_buffer,opt_struct,scanner,puller_data,output)
% function puller(data_buffer,opt_struct,scanner,puller_data)
% pull the data to local machine

if ~exist('output','var')
    if ~isfield(data_buffer.headfile,'work_dir_path')&& isfield(data_buffer.headfile,'U_runno')
        work_dir_name= [data_buffer.headfile.U_runno '.work'];
        data_buffer.headfile.work_dir_path=[data_buffer.engine_constants.engine_work_directory '/' work_dir_name];
        output=data_buffer.headfile.work_dir_path;
    end
else
   % data_buffer.headfile.work_dir_path=output;
end

if opt_struct.overwrite
    opt_struct.puller_option_string=[' -o ' opt_struct.puller_option_string];
end
if opt_struct.existing_data && exist(output,'dir') %||opt_struct.skip_recon
    opt_struct.puller_option_string=[' -e ' opt_struct.puller_option_string];
end

cmd_list=['puller_simple ' opt_struct.puller_option_string ' ' scanner ' ''' puller_data ''' ' output];
if ~isfield(data_buffer.headfile,'comment')
    data_buffer.headfile.comment={};
end
data_buffer.headfile.comment{end+1}=['# \/ pull cmd ' '\/'];
data_buffer.headfile.comment{end+1}=['# ' cmd_list ];
data_buffer.headfile.comment{end+1}=['# /\ pull cmd ' '/\'];
if ~opt_struct.existing_data || ~exist(output,'dir')  %&&~opt_struct.skip_recon
    if ~exist(output,'dir') && opt_struct.existing_data
        warning('You wanted existing data BUT IT WASNT THERE!\n\tContinuing by tring to fetch new.');
        pause(1);
    end
    p_status =system(cmd_list);
    if p_status ~= 0 && ~opt_struct.ignore_errors
        error('puller failed:%s',cmd_list);
    end
end
%clear cmd s datapath puller_data puller_data work_dir_name p_status;
end
