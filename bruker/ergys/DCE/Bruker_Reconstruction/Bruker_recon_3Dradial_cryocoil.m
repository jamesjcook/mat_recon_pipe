%% This function recons images using the regredding method

function [final_recon_im] = Bruker_recon_3Dradial_cryocoil(runno, dv, kv, dcfv, mat)

%===============INPUTS====================
%runno=run number
%dv=k-space data
%kv=k-space coordinates for the data in dv
%dcfv=density compensation factors
%mat=reconstruction matrix size
%acq=index of acquisition

osf=3; %Oversampling factor
kw=3; %Kernel width
RecoScaleChan1=1; %These are variable names used in the Bruker magnet. Use if experimenting with weighted sum of squares recon.
RecoScaleChan2=1;

mat2=mat/2;
kdata_ch1=dv(:,1:mat2,:); %Channel 1
kdata_ch2=dv(:,(mat2+1):end,:); %Channel 2

recon_mat=mat*osf;
grid_volume_ch1=grid3_MAT(kdata_ch1, kv, dcfv, recon_mat, 0);
grid_data_real=grid_volume_ch1(1:2:end); %Real data
grid_data_imag=grid_volume_ch1(2:2:end); %Imaginary data
grid_data=complex(grid_data_real, grid_data_imag);
grid_data=reshape(grid_data, recon_mat, recon_mat, recon_mat);
f=hamming_window_3D(recon_mat); %Calculate filter
grid_data=grid_data.*f; %Apply filter
image_ch1=fftshift(abs(ifftn(grid_data)));
image_ch1=crop_center_3D(image_ch1, mat); %Crop center

grid_volume_ch2=grid3_MAT(kdata_ch2, kv, dcfv, recon_mat, 0);
grid_data_real=grid_volume_ch2(1:2:end); %Real data
grid_data_imag=grid_volume_ch2(2:2:end); %Imaginary data
grid_data=complex(grid_data_real, grid_data_imag);
grid_data=reshape(grid_data, recon_mat, recon_mat, recon_mat);
f=hamming_window_3D(recon_mat); %Calculate filter
grid_data=grid_data.*f; %Apply filter
image_ch2=fftshift(abs(ifftn(grid_data)));
image_ch2=crop_center_3D(image_ch2, mat); %Crop center

final_recon_im=sqrt((RecoScaleChan1*image_ch1).^2+(RecoScaleChan2*image_ch2).^2); %Sum of squares (SoS) reconstruction (image domain)


%% Save image
image_name=[runno '.f32'];
fid=fopen(image_name, 'w');
fwrite(fid, final_recon_im, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);