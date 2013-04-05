function [niiout scale]=save_agilent_img(data_buffer,volnum,nvols,scannercode,runno,res,headfile,scale_boolean,magnitude_boolean,phase_boolean,slice_boolean)

%set scale to NaN until it is assigned
scale=NaN;

%% check arguments
if nargin<7
    error('not enough input arguments');
elseif nargin==7
    scale_boolean=1;
    magnitude_boolean=1;
    phase_boolean=0;
    slice_boolean=1;
elseif nargin~=11
    error('too many input arguments');
end


%% get local volume
local_volume=get_local_vol;


%% make magnitude images
if magnitude_boolean==1
    if ~isreal(data_buffer)
        data_buffer=abs(data_buffer);
    end
    
    %get scale info
    sorted=sort(data_buffer(:));
    ind=round(0.995*length(sorted));
    scale=32767/sorted(ind);
    clear sorted
    
    %decide wether or not to scale
    if ~isfloat(data_buffer)
        bitd='int16';
        nii=make_nii(data_buffer,res,[0 0 0],4);
    elseif scale_boolean==1;
        bitd='int16';
        data_buffer=int16(data_buffer.*scale);
        nii=make_nii(data_buffer,res,[0 0 0],4);
    else
        bitd='single';
        nii=make_nii(data_buffer,res,[0 0 0],16);
    end
    
    %make output directories if they dont already exist, delete them and
    %remake if they do exist, this is important so that only the correct
    %images are archived
    resultpath=[local_volume '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1)];
    if ~exist(resultpath,'dir')
        mkdir(resultpath);
    elseif exist(resultpath,'dir')
        rmdir(resultpath,'s');
        mkdir(resultpath);
    end
    if ~exist([resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images'],'dir')
        mkdir([resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images']);
    elseif exist([resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images'],'dir');
        rmdir([resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images'],'s');
        mkdir([resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images']);
    end
    
    %save nifti volume
    niiout=[resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) '.nii'];
    save_nii(nii,niiout);
    
    %slice writer
    if slice_boolean==1;
        for slice=1:size(data_buffer,3)
            slicefid=fopen([resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) scannercode '.' sprintf('%04i',slice) '.raw'],'w+');
            fwrite(slicefid,data_buffer(:,:,slice),bitd,0,'b');
            fclose(slicefid);
        end
    end
    
    %write headfile
    if isstruct(headfile)
        headfile_out=[resultpath '/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images/' runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) '.headfile'];
        headfile.S_runno=[runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1)];
        write_headfile(headfile,headfile_out);
        write_tagfile([runno '_m' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1)],headfile.dim_Z,headfile.U_code,headfile.U_civmid);
    end
end



%% make phase images

if phase_boolean==1
    if ~isreal(data_buffer)
        data_buffer=angle(data_buffer);
    else
        error('you said to make phase images but input data buffer is all real!');
    end
    %we never want to convert phase to 16 bit so no scaling
    bitd='float';
    
    %make output directories if they dont already exist
    resultpath=[local_volume '/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1)];
    if ~exist(resultpath,'dir')
        mkdir(resultpath);
    else
        display('result directory already exists and existing contents will not be deleted but may be overwritten, do not get confused')
    end
    if ~exist([resultpath '/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images'],'dir')
        mkdir([resultpath '/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images']);
    end
    
    %save nifti volume
    nii=make_nii(data_buffer,res,[0 0 0],16);
    niiout=[resultpath '/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) '.nii'];
    save_nii(nii,niiout);
    
    %slice writer
    if slice_boolean==1;
        for slice=1:size(data_buffer,3)
            slicefid=fopen([resultpath '/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) scannercode '.' sprintf('%04i',slice) '.raw'],'w+');
            fwrite(slicefid,data_buffer(:,:,slice),bitd,0,'b');
            fclose(slicefid);
        end
    end
    %write headfile
    if isstruct(headfile)
        headfile_out=[resultpath '/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) 'images/' runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1) '.headfile'];
        headfile.S_runno=[runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1)];
        write_headfile(headfile,headfile_out);
        write_tagfile([runno '_p' sprintf(['%0' num2str(numel(num2str(nvols))) 'i'],volnum-1)],headfile.dim_Z,headfile.U_code,headfile.U_civmid);
    end
end