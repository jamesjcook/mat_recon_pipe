function scaled_group_recon(fidpath,workpath,max_blocks,ntraces,npoints,bitdepth,voldims,nvols,scannercode,runno,res,phase_boolean,headfile)
%% prep work
%set min_scale to inf so we can always find something smaller later
min_scale=inf;

%% make the complex output files
for volnum=1:nvols
    %define complex outpath
    complex_outpath=[workpath '/' runno '_complex_out_' num2str(volnum-1) '.mat'];
    %if complex out file does not exist then create it
    if ~exist(complex_outpath,'file')
        display(['working on volume ' num2str(volnum) ' of ' num2str(nvols)]);
        display('reading fid in to memory');
        data_buffer=load_fid(fidpath,max_blocks,ntraces,npoints,bitdepth,volnum,voldims);
        display('applying fermi filter');
        data_buffer=fermi_filter(data_buffer);
        display('doing 3d ifft');
        data_buffer=fft3d(data_buffer);
        display('saving complex output')
        dummy=0;
        save(complex_outpath,'dummy','-v7.3');%save a dummy variable to avoid MATLAB compression when saving complex data
        save(complex_outpath,'data_buffer','-append');
    else
        display('complex output file found in work directory, ifft will not be redone');
        display('loading complex output from disk');
        load(complex_outpath);
    end
    
    %set booleans for save_agilent_img
    if phase_boolean==1
        magnitude_boolean=0;
        slice_boolean=1;
        type='phase';
    else
        magnitude_boolean=1;
        slice_boolean=0;
        type='magnitude';
    end
    scale_boolean=0;
    
    %save unscaled nifti volume only for now
    display(['saving ' type ' volume ' num2str(volnum) ' of ' num2str(nvols)]);
    [niiout{volnum} scale]=save_agilent_img(data_buffer,volnum,nvols,scannercode,runno,res,headfile,scale_boolean,magnitude_boolean,phase_boolean,slice_boolean);
    
    %get smallest scale multiplier for group recon
    if scale<min_scale
        min_scale=scale;
    end
end

clear data_buffer

save([workpath '/group_scale.mat'],'min_scale'); %save scale number to mat file

runnos_list=''; %make a blank string to concatenate later
%% group scaling of magnitude images
if magnitude_boolean==1
    %do group scaling
    display(['doing group scaling of magnitude images using scale factor ' num2str(min_scale)]);
    for i=1:length(niiout)
        nii=load_nii(niiout{i});
        nii.img=int16(nii.img.*min_scale);
        
        %overwrite unscaled niftis
        display(['writing scaled volume ' num2str(i) ' of ' num2str(length(niiout))]);
        nii=make_nii(nii.img,nii.hdr.dime.pixdim(2:4),[0 0 0],4);
        save_nii(nii,niiout{i});
        
        %write scaled slices
        display(['writing scaled slices for volume ' num2str(i) ' of ' num2str(length(niiout))]);
        for slice=1:size(nii.img,3)
            [path name ext]=fileparts(niiout{i});
            slicefid=fopen([path '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],i-1) 'images/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],i-1) scannercode '.' sprintf('%04i',slice) '.raw'],'w+');
            fwrite(slicefid,nii.img(:,:,slice),'int16',0,'b');
            fclose(slicefid);
        end
        runnos_list=[runnos_list runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],i-1) ' '];
    end
end


%% now that we are all done, some optional steps

%rolling in y
resp=0;
while ~strcmp(resp,'n')
    resp=input('Would you like to roll your volume data in y? >> ','s');
    if strcmp(resp,'y')
        display('positive numbers will move the image down in y and negative numbers will move it up in y');
        roll=input('What roll? >> ');
        for i=1:length(niiout)
            display(['rolling dataset ' num2str(i) ' of ' num2str(length(niiout))]);
            nii=load_nii(niiout{i});
            data_buffer=circshift(nii.img,[0 roll 0]);
            save_agilent_img(data_buffer,i,nvols,scannercode,runno,res,headfile,0,1,0,1);
            save([workpath '/roll.mat'],'roll');
        end
        resp='n';
    elseif ~strcmp(resp,'n');
        display('please enter y or n');
    end
end

display('use the following to archive your results');
display(' ');
display(['archiveme ' headfile.U_civmid ' ' runnos_list]);
display(' ');

display('use the following to tensor recon your results');
display(' ');
display(['tensor_create ' headfile.U_civmid ' ' headfile.U_code ' ' headfile.U_code ' params ' num2str(i) ' ' runnos_list]);
display(' ');

% 
% %reordering of b0 volumes
% resp=0;
% while ~strcmp(resp,'n')
%     resp=input('Would you like to reorder your data? >> ','s');
%     if strcmp(resp,'y')
%         bzero_inds=input('enter bzero numbers as vector >> ');
%         tmp=niiout;
%         niiout(1:length(bzero_inds))=tmp(bzero_inds);
%         tmp(bzero_inds)=[];
%         niiout((length(bzero_inds)+1):end)=tmp;
%         resp='n';
%     elseif ~strcmp(resp,'n');
%         display('please enter y or n');
%     end
% end
% 
% 
% %affine registration to b0 volume for eddy current correction
% resp=0;
% while ~strcmp(resp,'n')
%     resp=input('Would you like to register your data to the first image? >> ','s');
%     if strcmp(resp,'y')
%         niiout=dti_prereg(niiout);
%         resp='n';
%     elseif ~strcmp(resp,'n');
%         display('please enter y or n');
%     end
% end
% 
% 
% %make 4d nifti
% resp=0;
% while ~strcmp(resp,'n')
%     resp=input('Would you like to make a 4d NIfTI? >> ','s');
%     if strcmp(resp,'y')
%         niioutpath=[niiout{1}(1:end-4) '_nii4d.nii'];
%         make_4dnifti(niioutpath,NaN,niiout{:});
%         resp='n';
%     elseif ~strcmp(resp,'n');
%         display('please enter y or n');
%     end
% end
