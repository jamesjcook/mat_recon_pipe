function data_buffer=fftzd(data_buffer)

%compute the 1d ifft along z, assume that z is the third dimension
data_buffer=fftshift(ifft(fftshift(data_buffer,3),[],3),3);
