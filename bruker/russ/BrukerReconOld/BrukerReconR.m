function [img,bruker] = BrukerReconR
% Original file by Evan Calbrese, 6/8/11
% rmd - added multi-echo read, 6/8/11
% rmd - adapted for newest data, 8/3/12

bruker.acqp = readBrukerHeader(['acqp']);
bruker.method = readBrukerHeader(['method']);
data = readBrukerFID('',bruker.method);
bruker.subject = readBrukerHeader(['../subject']);

if bruker.method.PVM_NEchoImages > 1
    if length(bruker.method.PVM_Matrix) < 3
        bruker.method.PVM_Matrix(1,3) = 1;
    end
    data_mat=reshape(data,bruker.method.PVM_Matrix(1,1),  ...
        bruker.method.PVM_EncNReceivers*bruker.method.PVM_NEchoImages,  ...
        bruker.method.PVM_Matrix(1,2), bruker.method.PVM_Matrix(1,3));
    data_mat = permute(data_mat,[1 3 4 2]);
    data_mat = data_mat(:,:,:,1:2:end)+data_mat(:,:,:,2:2:end);
    img = zeros(size(data_mat));
    for k = 1:bruker.method.PVM_NEchoImages
        img(:,:,:,k) = fftshift(ifftn(fftshift(data_mat(:,:,:,k)))); %second fftshift necesary?
    end
    if strcmp(bruker.method.EchoAcqMode,'allEchoes') == 1
        img(:,:,:,2:2:end) = img(end:-1:1,:,:,2:2:end);
    end
else

    if length(bruker.method.PVM_Matrix)==3
        data_mat=reshape(data, bruker.method.PVM_EncMatrix(1,1), bruker.method.PVM_EncMatrix(1,2), bruker.method.PVM_EncMatrix(1,3));
        img=fftshift(ifftn(data_mat));
    else
        data_mat=reshape(data, bruker.method.PVM_Matrix(1,1), bruker.method.PVM_Matrix(1,2));
        img=fftshift(ifftn(data_mat));
    end
end



% nii = make_nii(abs(img),bruker.method.PVM_SpatResol,[0 0 0],16);
% out_file = 'mag.nii';
% save_nii(nii,fullfile(save_path,out_file));
% 
% nii = make_nii(angle(img),bruker.method.PVM_SpatResol,[0 0 0],16);
% out_file = 'phase.nii';
% save_nii(nii,fullfile(save_path,out_file));
% 
% save bruker

end





