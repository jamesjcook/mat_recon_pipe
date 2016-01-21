function [success_status,img, buffer]=rad_mat_chunk(scanner,runno,input,options)
% function [success_status,img, buffer]=RAD_MAT_CHUNK(scanner,runno,input,options)
% hacky  multi-part bruker recon
%
% Should add support directly into rad_mat in the future for multi-part fetch load of files.
% this currently operates just like rad_mat with the caveat, input is
% patientid, and a vector of scanids

%%% this test set actually worked. The only sucessful test.
% can test straight from comandline using
% rad_mat_chunk('nemo','BTEST',{'2016107',13:16});
if ~iscell(input) && strcmp(input,'testdata')
    scanner='nemo';
    patient_id='20160107';
    scan_ids=[13,14,15,16];
    bruker_study='72mm'; % may not be required.
    %%% FOR TEST DATA ONLY auto setting rest runnumber to RAD_MAT_CHUNK_first_to_last
    runno=['RAD_MAT_CHUNK_' bruker_study '_' num2str(scan_ids(1)) 'to' num2str(scan_ids(end)) ];
    %%% set testing options to a blank cell to make archivable outputs.
    testing_options={'skip_write_civm_raw','skip_write_headfile','write_unscaled_nD','planned_ok','write_kimage'};
    % these options say we wont write civm raw, or headfile
    % we will write an unscaled nifti file with all the data to our work directory
    % and
    % will write an log scale absolute image of kspace as a nifti to see that we read kspace
    % properly.
    partial_options={'testmode'};
    %%% to skip reconning the partials, uncomment following line
    %%% THIS WILL SPEED THINGS UP A LOT.
else
    testing_options={};
    patient_id=input{1};
    scan_ids=input{2};
    partial_options={'skip_recon','testmode'};
end
if ~exist('options','var')
    options={};
end
if ~strcmp(scanner,'nemo')...
        && ~strcmp(scanner,'centospc')
    error('THIS HAS ONLY BEEN DONE ON THE BRUKER SCANNER NEMO. WE ONLY EXPECT IT TO WORK ON THE nemo OR centospc SCANNER!');
end
rad_mat_options={'warning_pause=0',['param_file=rad_mat_chunk_',patient_id,strjoin(strsplit(num2str(14:18),' '),'_')]};
rad_mat_options_full_only={};
%% options for rad mat split up into chunks.
required_options_for_unknown_sequence={'debug_mode=50'};
% required_options_to_multi_part=[required_options_for_unknown_sequence,{'unrecognized_ok','ray_blocks=512','dim_Z=512'}];
required_options_to_multi_part=[required_options_for_unknown_sequence,{'unrecognized_ok'}];  % 
% ray_blocks and dim_z option moved to be auto calculated.
% ,'input_order=xcypzt' this is wrong.
% debug_mode must be >=50 to use unknown sequences
% we are overriding variables found in the headfile, so we need
% unrecognized_ok.
% ray_blocks and dim_Z are being over ridden with the total z, This will
% change for different acquisition types, but these two work for our
% current test set.
% can calculate with numel(scan_ids)*dim_Z, Calculated verisons done at
% final rad_mat call.

data_dir=getenv('BIGGUS_DISKUS');
%% get component data and reconstruct.
data_files=cell(1,length(scan_ids));
pull_dir=cell(1,length(scan_ids));
pda=cell(1,length(scan_ids));
sn=1;
pull_dir{sn}=sprintf('/%s/%s_%i.work/',data_dir,runno,scan_ids(sn));
[~,~,pda{sn}]=rad_mat(scanner,sprintf('%s_%i',runno,scan_ids(sn)),sprintf ('%s/%i',patient_id,scan_ids(sn)) ,...
    [ testing_options,'skip_recon',...
    rad_mat_options,...
    required_options_for_unknown_sequence,...
    options]);
data_files{sn}=sprintf('%s/fid',pull_dir{sn});
parfor sn=2:length(scan_ids)
    pull_dir{sn}=sprintf('/%s/%s_%i.work/',data_dir,runno,scan_ids(sn));
    [~,~,pda{sn}]=rad_mat(scanner,sprintf('%s_%i',runno,scan_ids(sn)),sprintf ('%s/%i',patient_id,scan_ids(sn)) ,...
        [ testing_options,partial_options,...
        rad_mat_options,...
        required_options_for_unknown_sequence,...
        options]);
    data_files{sn}=sprintf('%s/fid',pull_dir{sn});
end
runno_workdir= sprintf('/%s/%s.work',data_dir,runno);
system(sprintf('mkdir -p %s',runno_workdir));
cmd=sprintf('cp -Ppf %s/* %s',pull_dir{end},runno_workdir);
fprintf('%s\n\n',cmd);
system(cmd);

cmd=sprintf('rm %s/fid',runno_workdir);
fprintf('%s\n\n',cmd);
system(cmd);


%% concatenate data to new file
cmd=sprintf('cat %s > %s/fid',strjoin(data_files,' '),runno_workdir);
fprintf('%s\n\n',cmd);
system(cmd);

%fh=read_headfile(sprintf('%s/bruker.headfile',runno_workdir));
% fh=pda.headfile;


%% customized rad_mat call
% 
required_options_to_multi_part=[required_options_to_multi_part,{sprintf('ray_blocks=%i', pda{end}.headfile.dim_Z*numel(scan_ids)),sprintf('dim_Z=%i',pda{end}.headfile.dim_Z*numel(scan_ids))}];
[success_status,img, buffer]=rad_mat(scanner,runno,['rad_mat_chunk',patient_id,strjoin(strsplit(num2str(14:18),' '),'_')],[ {'existing_data','overwrite'},...
    testing_options,...
    rad_mat_options,...
    rad_mat_options_full_only,...
    required_options_to_multi_part,...
    options]);
%,'unrecognized_ok','dim_Z=256','ray_blocks_per_volume=256'});

