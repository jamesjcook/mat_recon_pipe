test_case.dti=false;
test_case.lme=true;

if test_case.dti
load('loader_test_large_dti');
data_buffer.data=sparse(chunk_size/2*numel(chunks_to_load),1);
for chunk_num=8:35
    figure(chunk_num);
    load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
        binary_header_size, min_load_size, load_skip, data_in.precision_string, load_chunk_size, ...
        load_chunks,chunks_to_load(chunk_num),...
        data_in.disk_endian);
    data_buffer.data=reshape(data_buffer.data,[600,480,540]);
    imagesc(log(abs(data_buffer.data(:,:,size(data_buffer.data,3)/2))));
end

end
if test_case.lme
load('loader_test_large_multiecho');
chunks_to_load=chunks_to_load(1:2*2*2:end);
% chunks_to_load=chunks_to_load(end-1:end);
load_from_data_file(data_buffer, data_buffer.headfile.kspace_data_path, ....
    file_header, recon_strategy.min_load_size, recon_strategy.load_skip, data_in.precision_string, load_chunk_size, ...
    load_chunks,chunks_to_load,...
    data_in.disk_endian,recon_strategy.post_skip);

end