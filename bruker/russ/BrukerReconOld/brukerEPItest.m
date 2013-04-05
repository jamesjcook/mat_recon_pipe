% brukerEPItest.m

m = bruker.method.PVM_EncMatrix(1);             % Frequency encode direction
n = bruker.method.PVM_EncMatrix(2);             % Phase encode 1 direction
if length(bruker.method.PVM_EncMatrix) < 3
    p = 1;
else
    p = bruker.method.PVM_EncMatrix(3);         % Phase encode 2 direction
end
echoes = bruker.method.PVM_NEchoImages;         % Number of echoes
nrecs = bruker.method.PVM_EncNReceivers;        % Number of receivers
segments = bruker.method.PVM_EpiNShots;

% dw = bruker.method.PVM_DwNDiffExp;

% data_mat = reshape(bruker.fid,nrecs,m,n,p,dw);
% data_mat = permute(data_mat,[1 3 4 5 2]);

data_mat = reshape(bruker.fid,m,nrecs,n,p);
data_mat = permute(data_mat,[1 3 4 2]);

figure(2)
subplot(211); show(squeeze(abs(data_mat(:,40,:,1))));

mag(:,:,:,1) = fftshift(ifftn(fftshift(data_mat(:,:,:,1))));


subplot(212); show(squeeze(abs(mag(:,40,:,1))));

SliceBrowser(abs(mag(:,:,:,1)));