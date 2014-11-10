function imglist=rad_mat_bunch(scanner,input,rad_options)
% RAD_MAT_BUNCH(scanner,input)
% input is either 
%    'Name.list', the list file on the scanner(like radish_scale_bunch).
%  OR the parameters to list maker.
%    'runno study series count'
%    'runno study series count first_num

% look at radish_scale_bunch
% see what work needs to translate into rad_mat.
% should we support load multiple files or should we just wrap rad_mat with a rad_mat_bunch.

ts=tic;
%%%% To properly drop radish_scale_bunch relying on radish.
% add param_file support to rad_mat
% add the radish gui error checking to rad_mat
% 
% modify radish scale bunch to call rad_mat from the command line.
% 
% fix rad_mat to be callable from the command line. 
% example list format
%studyname/series##.fid;outrunno, studyname/series##.fid;outrunno

%% list load
%%% if not list input
%         "runnumber:$runno\n".
% 		  "study:    $study\n".
% 		  "series:   $series\n".
% 		  "scans:    $count\n".
% 		  "first_num:$m_start\n");

sc=load_scanner_dependency(scanner);
ec=load_engine_dependency;
% =ec.scanner_data_directory;

if ( regexpi(input,'^[a-zA-Z][0-9]{5,6}\w*[.]list$'))
    list_file=input;
    input=strsplit(input,'.');
    base_runno=input{1}; 
else % make list
    %     specid_s=strsplit(data_buffer.input_headfile.U_specid,';');
    input=strsplit(input,' ');
    base_runno=input{1};
%     scanner_study=input{2};
%     scanner_series=input{3};
%     nscanns=input{4};
%     if numel(input)>4
%         starting_num=input{5};
%     else
%         starting_num='';
%     end
    list_file=[base_runno '.list'];
%     error('generating list on fly not supported yet');
% cmd=sprintf('ssh sc.scanner_user@system ~/bin/listmaker %s,input);
% system(cmd);
end
% ssh omega@kammy \$HOME/bin/listmaker
% get list.
%usage: puller_simple  device file/folder local_dest_dir  result_file_basename(blank for no change)
cmd=sprintf('puller_simple -of file %s %s %s.work',scanner,list_file,base_runno);
disp(cmd);
system(cmd);


%% load list
%S65460.list
% list='S65460_01/ser02.fid;S65460_m01, S65460_01/ser03.fid;S65460_m02, S65460_01/ser04.fid;S65460_m03, S65460_01/ser05.fid;S65460_m04, S65460_01/ser06.fid;S65460_m05, S65460_01/ser07.fid;S65460_m06, S65460_01/ser08.fid;S65460_m07';
list=radish_load_info_stub(sprintf('%s/%s.work/%s',ec.engine_work_directory,base_runno,list_file));
list=strsplit(list,', '); 
opts={'debug_mode=0','warning_pause=0','skip_fft=0','skip_write_temp_headfile','write_complex'};
if exist('rad_options','var')
opts=[opts,rad_options];
end
%% param gen % integrated!
%%%     eval $GUI_APP \'`ls ${WKS_SETTINGS}/engine_deps/engine_${RECON_HOSTNAME}_radish_dependencies` $@ \'
%%% scanner new filename.
% [~]=system(sprintf('%s '' %s %s %s.param'' ',getenv('GUI_APP') ,...
%     ec.engine_constants_path ,...%    ec.engine_recongui_menu_path ,...
%     scanner ,... %     ' ' sc.scanner_tesla ...
%     base_runno ...
%     ));
%     
%% run recons
runno_text='';
runno_list=cell(1,numel(list));
runno_openmacro_paths=cell(1,numel(list));
runno_roll_prompts=cell(1,numel(list));
for i=1:numel(list)
    le=strsplit(list{i},';');
    data=le{1};
    runno=le{2};
    runno_list{i}=runno;
    %foreach piece of data
    [~,~,imglist.(['img' num2str(i)])]=rad_mat(scanner,runno,data,[opts,sprintf('param_file=%s.param',base_runno)]);
    runno_text=sprintf('%s %s',runno_text,runno);
    runno_openmacro_paths{i}=imglist.(['img' num2str(i)]).headfile.rad_mat_ij_macro;
    runno_roll_prompts{i}=imglist.(['img' num2str(i)]).headfile.rad_mat_roll_prompt;
end
imglist.runo_text=runno_text;

%% combine output into single image, scaleit save it.
cmd=sprintf('reform_group %s', runno_text);
system(cmd);
toc(ts)

%% convenience prompts
%%% view
%  -eval "macro code"
% -run "runMacro("path");
[~,txt]=system('echo -n $ijstart');  %-n for no newline i think there is a smarter way to get system variables but this works for now.
% ij_prompt=sprintf('%s -macro %s',txt,strjoin(runno_openmacro_paths, ' -macro '));
% ij_prompt=sprintf('%s -run ''runMacro("%s");''',txt,strjoin(runno_openmacro_paths,'");runMacro("'));
ij_prompt=sprintf('%s -eval ''run("CIVM RunnoOpener","headfile=%s/%s.headfile loadallheadfiles volume_combine_threshold=1");''',txt,imglist.img1.headfile.output_image_path,imglist.img1.headfile.U_runno);
mat_ij_prompt=sprintf('system(''%s'');',ij_prompt);
% /panoramaspace/S65460_m01/S65460_m01images/S65460_m01.headfile
fprintf('test civm image output from a terminal using following command\n');
fprintf('  (it may only open the first and last in large sequences).\n');
fprintf('\n\n%s\n\n\n',ij_prompt);
fprintf('test civm image output from matlab using following command\n');
fprintf('  (it may only open the first and last in large sequences).\n');
fprintf('\n%s\n\n',mat_ij_prompt);
imglist.ij_prompt=ij_prompt;

%%%archivetag
archive_tag_output=sprintf('archiveme %s %s',imglist.img1.headfile.U_civmid,strjoin(runno_list, ' '));
fprintf('initiate archive from a terminal using following command, (should change person to yourself). \n\n\t%s\n\n OR run archiveme in matlab useing \n\tsystem(''%s'');\n',archive_tag_output,archive_tag_output);
imglist.archive_tag_output=archive_tag_output;
%%% roll prompt
%         data_buffer.headfile.rad_mat_roll_prompt=roll_prompt;
% roll_3d -x %d -y %d -z %d %s;
runno_list(1)=[];
fprintf('%s %s\n',strtrim(runno_roll_prompts{1}),strjoin(runno_list,' '));
imglist.runno_roll_prompts=runno_roll_prompts;
