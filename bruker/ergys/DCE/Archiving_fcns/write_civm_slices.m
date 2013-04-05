% This function writes slices to be saved according to the CIVM convention.

function [scaling_factor]=write_civm_slices(runno, vol, mat, im_format, scaling_flag)

%======INPUTS======
%runno=run number (including extensions such at TI, M0 etc)
%vol=volume to be archived
%mat=size of image (assuming isotropic matrix)
%im_format=(string: either 'civmraw' or 'f32') archiving format
%scaling_flag=flag to indicate whether images should be scaled (1=scale image, 0=do not scale)
%=====OUTPUT======
%scaling_factor=factor converting images to 16bit, unsigned, big endian format
%Slices from vol in the specified format

scaling_factor=max(vol(:));

if strcmp(im_format,'f32')
    for j=1:mat
        if scaling_flag==0;
            slice_im=vol(:,:,j);
        else
            slice_im=(vol(:,:,j)/scaling_factor)*(2^15-1); %Scaling
        end
        indx=gen_archiving_slice_indx(j, 1000);
        slice_name=[runno 'bt7sim.' indx '.' im_format];
        fid=fopen(slice_name, 'w');
        fwrite(fid, slice_im, 'float32', 'b'); %Big-endian ordering (this is how images are archived)
        fclose(fid);
    end
elseif strcmp(im_format,'civmraw')
    for j=1:mat
        if scaling_flag==0;
            slice_im=vol(:,:,j);
        else
            slice_im=(vol(:,:,j)/scaling_factor)*(2^15-1); %Scaling and converting to 16-bit (lab convention);
        end
        indx=gen_archiving_slice_indx(j, 1000);
        slice_name=[runno 'bt7sim.' indx '.' 'raw'];
        fid=fopen(slice_name, 'w');
        fwrite(fid, slice_im, 'uint16', 'b'); %Big-endian ordering (this is how images are archived)
        fclose(fid);
    end
else
    error('Please specify the correct image format (either f32 or civmraw) for archiving')
end