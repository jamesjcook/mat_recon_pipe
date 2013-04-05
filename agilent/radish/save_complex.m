function save_complex(vol,path)
% function save_complex(vol,path), 
% saves an interleaved 32-bit float complex file 

% memusage is vol+2xvol for the complex file, might be 3xvol, for a working
% space.
    precision='single';
%     tic
    dims=size(vol);
%     re=real(vol);
%     im=imag(vol);
    comp=zeros([2,dims]);
%     comp(1,:,:,:)=real(vol);
%     comp(2,:,:,:)=imag(vol);
    comp(1:2:end)=imag(vol);
    comp(2:2:end)=real(vol);
    fid=fopen(path,'w','l'); 
    if fid == -1
        error('could not open output path');
    end
    fwrite(fid,comp,precision,'l');
    fclose(fid);
%     t=toc;
        
% raw_data=fread(file,inf,'int'); %read the raw data
% raw_data=reshape((raw_data(1:2:end) + 1i*raw_data(2:2:end)),xdim,ydim,zdim); %reshape into complex array
%     fwrite(fileID, A, precision, skip, machineformat)
%     fread(fileID, sizeA, precision, skip, machineformat)
end