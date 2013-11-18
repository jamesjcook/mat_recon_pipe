function [] = Bruker_recon_3Dradial_cryocoil(runno, dv, kv, dcfv, mat, acq, keynumber)
%Bruker_recon_3Dradial_cryocoil(runno, dv, kv, dcfv, mat, acq, keynumber)
% lukes's example code that does one acq's reconstruction. 
% the whole acq worth of data, co-ords and density compensation must be loaded, 
% these are dv, kv and dcfv respectively.
% the save code is just dumped to the end for now.
%===============INPUTS====================
%runno=run number
%dv=k-space data
%kv=k-space coordinates for the data in dv
%dcfv=density compensation factors
%mat=reconstruction matrix size
%acq=index of acquisition
%keynumber=keynumber (D'oh!!!!)
 
osf=3; %Oversampling factor
kw=3; %Kernel width
RecoScaleChan1=1; %These are variable names used in the Bruker magnet. Use if experimenting with weighted sum of squares recon.
RecoScaleChan2=1;
mat2=mat/2;
recon_mat=mat*osf;
nchannels=4;% 1 2 3 4
kdata=zeros([2, 64, 25740, nchannels]);
kdata(:,:,:,1)=dv(:,1:mat2,:); %Channel 1
c2=mat2+1;
kdata(:,:,:,2)=dv(:,c2:c2+63,:); %Channel 2
c3=c2+64;
kdata(:,:,:,3)=dv(:,(c3:c3+63),:); %Channel 1
c4=c3+64;
kdata(:,:,:,4)=dv(:,c4:end,:); %Channel 2
 
 
tic
img=zeros([mat mat mat nchannels],'single');
% matlabpool local 2    % SAVE FOR LATER, opening matlab pool is slow
% parfor ind=1:2
for ind=1:nchannels
    grid_data=grid3_MAT(kdata(:,:,:,ind), kv, dcfv, recon_mat, 8);  % 0=nonthreaded, 8=threaded
    grid_datac=complex(grid_data(1:2:end), grid_data(2:2:end));
    grid_datac=reshape(grid_datac, repmat(recon_mat,[1 3]));
    % COMMENT THESE LINES FOR PHASE
%    grid_dataf=hamming_window_3D(recon_mat).*grid_datac; % apply filter
    grid_dataf=fermi_filter_isodim2(grid_datac);         % test LX filter
    img_ift=fftshift(abs(ifftn(grid_dataf)));            % ifft
    img(:,:,:,ind)=crop_center_3D(img_ift, mat);         % crop center
end
% matlabpool close
toc
 
final_recon_im=sqrt((RecoScaleChan1*img(:,:,:,1)).^2 ...
    +(RecoScaleChan2*img(:,:,:,2)).^2 ...
    +(RecoScaleChan2*img(:,:,:,3)).^2 ...
    +(RecoScaleChan2*img(:,:,:,4)).^2 ...
    ); %Sum of squares (SoS) reconstruction (image domain)

%% Save image
%image_name=['\B' runno '_acq' num2str(acq) '_key' num2str(keynumber) '.raw'];
image_name=['B' runno '_acq' num2str(acq) '_key' num2str(keynumber) '.raw'];
%fid=fopen([current_directory image_name], 'w');
fid=fopen(image_name, 'w');
fwrite(fid, final_recon_im, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);
t=toc;
display(['Reconstructing key ' num2str(keynumber) ' of acquisition ' num2str(acq) ' took ' num2str(t) ' seconds'])
