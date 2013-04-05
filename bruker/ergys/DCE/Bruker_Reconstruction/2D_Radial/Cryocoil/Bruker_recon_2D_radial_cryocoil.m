%% This script reconstructs 2D radial data acquired with the cryocoil in the Bruker magnet. The reconstruction currently works for:
% 1) FID acquisitions (cannot recon GRE acquisitions)

clc
%% INPUTS
mat=64; %Reconstruction matrix size
mat2=mat/2;

RecoScaleChan1=1; %These are variable names used in the Bruker magnet. Use if experimenting with weighted sum of squares recon
RecoScaleChan2=1;


%% Get FID and trajectory data
dmat=128; %data matrix
kdata_complex=open_Bruker_2D_fid(dmat); 
kdata_complex((mat+1):end,:)=[];
kdata_complex_ch1=kdata_complex(1:mat2,:); %Channel 1
kdata_complex_ch2=kdata_complex((mat2+1):end,:); %Channel 2

[coord, nviews]=open_Bruker_2Dtraj(mat2);  
coord=Bruker_reshape_kspace_coords(coord);

%% Reconstruct
osf=2;
kwidth=osf;
recon_mat_osf=mat*osf;

dcf = calcdcflut(coord, mat);

[gdat_ch1] = gridkb(coord,kdata_complex_ch1,dcf,recon_mat_osf,kwidth,osf); %Gridding with Kaiser-Bessel kernel (from Brian Hargreaves, Stanford)
f=hamming_window_2D(recon_mat_osf); %Calculate filter
gdat_ch1=gdat_ch1.*f; %Apply filter

recon_im_ch1 = fftshift(abs(ifftn(gdat_ch1)));
image_ch1=crop_center_2D(recon_im_ch1, mat);
% figure; imagesc(image_ch1), colormap gray, axis off square tight
% title('Reconstructed Image (Channel 1)', 'FontSize', 18)

[gdat_ch2] = gridkb(coord,kdata_complex_ch2,dcf,recon_mat_osf,kwidth,osf); %Gridding with Kaiser-Bessel kernel (from Brian Hargreaves, Stanford)
gdat_ch2=gdat_ch2.*f; %Apply filter

recon_im_ch2 = fftshift(abs(ifftn(gdat_ch2)));
image_ch2=crop_center_2D(recon_im_ch2, mat);
% figure; imagesc(image_ch2), colormap gray, axis off square tight
% title('Reconstructed Image (Channel 2)', 'FontSize', 18)

final_recon_im=sqrt((RecoScaleChan1*image_ch1).^2+(RecoScaleChan2*image_ch2).^2); %Sum of squares (SoS) reconstruction (image domain)
figure; imagesc(final_recon_im), colormap gray, axis off square tight
title('Reconstructed Image (Final SoS image)', 'FontSize', 18)
