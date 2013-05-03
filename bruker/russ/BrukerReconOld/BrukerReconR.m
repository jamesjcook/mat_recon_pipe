function [img,bruker] = BrukerReconR(bruker_dir)
% Original file by Evan Calbrese, 6/8/11
% rmd - added multi-echo read, 6/8/11
% rmd - adapted for newest data, 8/3/12
if isempty(bruker_dir)
   display('select directory containing fid file to recon')
   bruker=readBrukerDirectory();
else
    bruker=bruker_dir;
end
% Correct Bruker raw data with zero filling if array size is not 2^n
if prod([bruker.method.PVM_Matrix bruker.method.PVM_NEchoImages ...
        bruker.method.PVM_EncNReceivers]) ~= length(bruker.fid)
    [bruker,bruker.fid] = zerorid(bruker,bruker.fid);
    
end


if bruker.method.PVM_NEchoImages > 1
    if length(bruker.method.PVM_Matrix) < 3
        bruker.method.PVM_Matrix(1,3) = 1;
    end
    data_mat=reshape(bruker.fid,bruker.method.PVM_Matrix(1,1),  ...
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
        data_mat=reshape(bruker.fid, bruker.method.PVM_EncMatrix(1,1), bruker.method.PVM_EncMatrix(1,2), bruker.method.PVM_EncMatrix(1,3));
        img=fftshift(ifftn(data_mat));
    elseif length(bruker.method.PVM_Matrix)==2 && bruker.acqp.NSLICES>1
        data_mat=reshape(bruker.fid, bruker.method.PVM_EncMatrix(1,1), bruker.method.PVM_EncMatrix(1,2), bruker.acqp.NSLICES);
        img=zeros( bruker.method.PVM_EncMatrix(1,1), bruker.method.PVM_EncMatrix(1,2), bruker.acqp.NSLICES);
%         for s=1:bruker.acqp.NSLICES
%             img(:,:,s)=fftshift(ifftn(data_mat(:,:,s)));
%         end
        img=fftshift(ifft2(data_mat));        
    else
        data_mat=reshape(bruker.fid, bruker.method.PVM_Matrix(1,1), bruker.method.PVM_Matrix(1,2));
        img=fftshift(ifftn(data_mat));
    end
end



nii = make_nii(abs(img),bruker.method.PVM_SpatResol(1),[0 0 0],16);
out_file = [bruker_dir 'mag.nii'];
save_nii(nii,fullfile(out_file));

nii = make_nii(angle(img),bruker.method.PVM_SpatResol(1),[0 0 0],16);
out_file = [bruker_dir 'phase.nii'];
save_nii(nii,fullfile(out_file));
% 
% save bruker

end





