function save_complex(vol,path,normal_mode)
% function save_complex(vol,path),
% saves an interleaved 32-bit float complex file
% need to repair the save_complex function to save a sallyish rp complex file
%
% have to test alternate ways to construct the savable portion
%
% make small test_array
% cast as 8bit and save
% test against pre behavior
%

% memusage is vol+2xvol for the complex file, might be 3xvol, for a working
% space.
precision=class(vol);
warning('THIS SAVED IMAGINARY FIRST, USE NIFTI COMPLEX IN THE FUTURE');
if exist('normal_mode','var')
    fprintf('Operating in "NORMAL" mode, saving in one big go\n');
%     pause(3);
    dims=size(vol);
    interleave=zeros([2,dims]);
    interleave(1:2:end)=imag(vol);
    interleave(2:2:end)=real(vol);
    fid=fopen(path,'w','l');
    if fid == -1
        error('could not open output path');
    end
    fwrite(fid,interleave,precision,'l');
    fclose(fid);
else
    % vectorize, and save some N-MB at a time.
    MB=1; % experimentally found 1MB at a time faster than 10, or 100.
    % 3MB also tried.
    write_count=4;
    if strcmp(precision,'double')
        write_count=8;
    end
    buffer_length=MB*1024^2/(2*write_count);
    fid=fopen(path,'w','l');
    if fid == -1
        error('could not open output path');
    end
    vol=vol(:);
    written=0;
    while written<numel(vol)
        if written+buffer_length<numel(vol)
        else
            %             fprintf('last segment\n');
            buffer_length=numel(vol)-written;
        end
        buffer = vol(written+1:written+buffer_length);
        interleave=zeros([2,size(buffer)]);
        interleave(1:2:end)=imag(buffer);
        interleave(2:2:end)=real(buffer);
        interleave=interleave(:);
        
        if ~exist('uint8mode','var')
            %% write like use.
            write_count=fwrite(fid,interleave,precision,'l');
            %             system(['ls -lh ' path]);
            if write_count~=numel(interleave)
                error('write error');
            end
        else
            %%
            buffer = typecast(interleave, 'uint8');
            write_count=fwrite(fid,buffer,'uint8');
            if write_count~=numel(buffer)
                error('write error');
            end
        end
        written=written+buffer_length;
        
    end
    fclose(fid);
    
end