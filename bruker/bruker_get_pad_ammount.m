function [ray_padding ray_length]=bruker_get_pad_ammount(bruker_header)
%

data_prefix='';
data_buffer.input_headfile=bruker_header;

channels=data_buffer.input_headfile.([data_prefix 'PVM_EncNReceivers']);
matrix=data_buffer.input_headfile.([data_prefix 'PVM_EncMatrix']);
ray_length=matrix(1);
if strcmp(data_buffer.input_headfile.([data_prefix 'GS_info_dig_filling']),'Yes')  %PVM_EncZfRead=1 for fill, or 0 for no fill, generally we fill( THIS IS NOT WELL TESTED)
    %bruker data is usually padded out to a power of 2 or multiple of 3*2^6
    if mod(channels*ray_length,(2^6*3))>0
        ray_length2 = 2^ceil(log2(channels*ray_length));
        ray_length3 = ceil(((channels*(ray_length)))/(2^6*3))*2^6*3;
        if ray_length3<ray_length2
            ray_length2=ray_length3;
        end
    else
        ray_length2=channels*ray_length;
    end
    ray_padding  =ray_length2-channels*ray_length;
    ray_length   =ray_length2;
%     input_points = 2*ray_length*rays_per_block/channels*ray_blocks;    % because ray_length is number of complex points have to doubled this.
%     min_load_size= ray_length*rays_per_block/channels*(in_bitdepth/8); % amount of bytes of data to load at a time,
    
end
end