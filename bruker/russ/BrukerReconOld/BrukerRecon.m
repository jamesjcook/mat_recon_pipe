function img = BrukerRecon(bruker)
% Original file by Evan Calbrese, 6/8/11
% rmd - added multi-echo read, 6/8/11
% rmd - adapted for newest data, 8/3/12

if isempty(bruker)
   display('select directory containing fid file to recon')
   bruker=readBrukerDirectory();
end

display('select directory to save output NIfTI to')
save_path=uigetdir('/~', 'select save path');

if bruker.method.PVM_NEchoImages > 1
    if length(bruker.method.PVM_Matrix) < 3
        bruker.method.PVM_Matrix(1,3) = 1;
    end
    data_mat=reshape(bruker.fid, bruker.method.PVM_Matrix(1,1),  ...
        bruker.method.PVM_EncNReceivers*bruker.method.PVM_NEchoImages,  ...
        bruker.method.PVM_Matrix(1,2), bruker.method.PVM_Matrix(1,3));
    data_mat = permute(data_mat,[1 3 4 2]);
    data_mat = data_mat(:,:,:,1:2:end)+data_mat(:,:,:,2:2:end);
    img = zeros(size(data_mat));
    for k = 1:bruker.method.PVM_NEchoImages
        img(:,:,:,k) = fftshift(ifftn(data_mat(:,:,:,k)));
    end
    if strcmp(bruker.method.EchoAcqMode,'allEchoes') == 1
        img(:,:,:,2:2:end) = img(end:-1:1,:,:,2:2:end);
    end
else

    if length(bruker.method.PVM_Matrix)==3
        data_mat=reshape(bruker.fid, bruker.method.PVM_EncMatrix(1,1), bruker.method.PVM_EncMatrix(1,2), bruker.method.PVM_EncMatrix(1,3));
        img=fftshift(abs(ifftn(data_mat)));
        m=max(img(:));
        img=img/m*(2^15-1); %for converting to 16 bit
        nii=make_nii(img, bruker.method.PVM_SpatResol, [0 0 0], 512);
        out_file=strcat(bruker.subject.SUBJECT_name_string,'_',bruker.subject.SUBJECT_date,'.nii');
        save_nii(nii,fullfile(save_path,out_file));
    else
        %%% assuming 2d single slice acquisiotn, but that is easily wrong. 
        data_mat=reshape(bruker.fid, bruker.method.PVM_Matrix(1,1), bruker.method.PVM_Matrix(1,2));
%       above reshape not useful for the multi-2d sequcences.
%       data_mat=reshape(bruker.fid, bruker.acqp.ACQ_size(1,1), bruker.acqp.ACQ_size(1,2),bruker.acqp.NI);
   
     
        img=fftshift(abs(ifftn(data_mat)));
        m=max(img(:));
        img=img/m*(2^15-1); %for converting to 16 bit
        nii=make_nii(img, bruker.method.PVM_SpatResol, [0 0], 512);
        out_file=strcat(bruker.subject.SUBJECT_name_string,'_',bruker.subject.SUBJECT_date,'.nii');
        save_nii(nii,fullfile(save_path,out_file));
    end
end

end



