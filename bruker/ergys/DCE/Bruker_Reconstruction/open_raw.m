%This function opens *.raw volume images.

%im_name=image name (string). Image is assumed to be 16bit unsigned or 32bit float (look at code to see which one is used)
%im_size=image size

function im=open_raw(im_name, im_size)

fp = fopen(im_name,'r','l'); %little endian byte order
im = fread(fp,inf,'float32'); 
% im = fread(fp,inf,'uint16'); 

im=reshape(im, im_size, im_size, im_size);

