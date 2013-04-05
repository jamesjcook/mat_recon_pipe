function data_buffer=fft3d(data_buffer)

%just return the fftshifted ifft3 of the whole dang thing
data_buffer=fftshift(ifftn(fftshift(data_buffer)));