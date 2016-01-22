%% hacky stub to recon multi-part bruker
% Should add support to radmat in the future for multi-part fetch load of files.
o_scan_ids=[];
if exist('scan_ids','var')
    o_scan_ids=scan_ids;
end

%patient_id='151216';
%patient_id='20151216';
patient_id='20160107';
%scan_ids=[100,101,102,103,104,105,106,107];
% scan_ids=[157,158,159,160,161,162,163,164];
% scan_ids=[165,166,167,168,169,170,171,172];
%scan_ids=[179,180,181,182,183,184,185,186];
scan_ids=[13,14,15,16];

% scan_ids=191:240;
%bruker_study='Sequence'; % may not be required.
bruker_study='72mm'; % may not be required.

%%% FOR NOW auto setting rest runnumber to BTESTCHUNKING_first_to_last
runno=['BTESTCHUNKING_' bruker_study '_' num2str(scan_ids(1)) 'to' num2str(scan_ids(end)) ];
rad_mat_options={'skip_filter'};
rad_mat_options_full_only={'debug_stop_load'};%'ignore_kspace_oversize'};%
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
% can calculate with numel(scan_ids)*dim_Z

%%% set testing options to a blank cell to make archivable outputs.
% testing_options={};
testing_options={'skip_write_civm_raw','skip_write_headfile','write_unscaled_nD','planned_ok','write_kimage'};
% these options say we wont write civm raw, or headfile
% we will write an unscaled nifti file with all the data to our work directory
% and
% will write an log scale absolute image of kspace as a nifti to see that we read kspace
% properly.

data_dir=getenv('BIGGUS_DISKUS');
data_files={};
%% get component data and reconstruct.
runno_workdir= sprintf('/%s/%s.work',data_dir,runno);
system(sprintf('mkdir -p %s',runno_workdir));


partial_options={};
%%% to skip reconning the partials, uncomment following line 
%%% THIS WILL SPEED THINGS UP A LOT.
% partial_options={'skip_recon'};
pda=cell(1,length(scan_ids));
for sn=1:length(scan_ids)
    pull_dir{sn}=sprintf('/%s/%s_%i.work/',data_dir,runno,scan_ids(sn));
    if ~exist(pull_dir{sn},'dir') ...
        || (isempty(pda{sn}) && sn == length(scan_ids) )
        [~,~,pda{sn}]=rad_mat('nemo',sprintf('%s_%i',runno,scan_ids(sn)),sprintf ('%s*/%i',patient_id,scan_ids(sn)) ,...
            [ {'existing_data','overwrite'},...
            testing_options,partial_options,...
            rad_mat_options,...
            required_options_for_unknown_sequence]);
    end
    data_files{sn}=sprintf('%s/fid',pull_dir{sn});
end
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
%testing_options=[testing_options,{'debug_stop_regrid'}]
% 
required_options_to_multi_part=[required_options_to_multi_part,{sprintf('ray_blocks=%i', pda{end}.headfile.dim_Z*numel(scan_ids)),sprintf('dim_Z=%i',pda{end}.headfile.dim_Z*numel(scan_ids))}];
[s,i,da]=rad_mat('nemo',runno,'MULTI_PART_HACKERY',[ {'existing_data','overwrite'},...
    testing_options,...
    rad_mat_options,...
    rad_mat_options_full_only,...
    required_options_to_multi_part]);
%,'unrecognized_ok','dim_Z=256','ray_blocks_per_volume=256'});

