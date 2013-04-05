function rad_mat(input)
% rad_mat
% does part or recon proecssing in matlab.
% hope to have this load(partial or full)
% regrid(partial or full)
% filter(partial or full)
% fft (partial or full)
% save.

data_buffer=large_array;
data_buffer.addprop('data');

% check if chunkable, or should we chunk.
% if chunking
% get num chunks to run

% foreach chunk

data_buffer.data=load_data(input,chunk); 
regrid(data_buffer.data,regrid_method);
filter(data_buffer.data);
fft(data_buffer.data);

savedata(data_buffer.data);

% end foreachchunk
 

%foreach volume
make_civm_images();
