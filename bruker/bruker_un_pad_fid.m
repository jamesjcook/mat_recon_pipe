function fid=bruker_un_pad_fid(fid,ray_padding,ray_length)



data_buffer.data=fid;
        % lenght of full ray is spatial_dim1*nchannels+pad
%         reps=ray_length;
% account for number of channels and echos here as well . 
        logm=zeros((ray_length-ray_padding)/4,1);
        logm(ray_length-ray_padding+1:ray_length)=1;
        logm=logical(repmat( logm, length(data_buffer.data)/(ray_length),1) );
        data_buffer.data(logm)=[];
        warning('padding correction applied, hopefully correctly.');
        % could put sanity check that we are now the number of data points
        % expected given datasamples, so that would be
        % (ray_legth-ray_padding)*rays_per_blocks*blocks_per_chunk
        % NOTE: blocks_per_chunk is same as blocks_per_volume with small data,
%         if numel(data_buffer.data) ~= (ray_length-ray_padding)/channels*rays_per_block
%             error('Ray_padding reversal went awrry. Data length should be %d, but is %d',(ray_length-ray_padding)/channels*rays_per_block,numel(data_buffer.data));
%         else
%             fprintf('Data padding retains corrent number of elements, continuing...\n');
%         end

fid=data_buffer.data;
end