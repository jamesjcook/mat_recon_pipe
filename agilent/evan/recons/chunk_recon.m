function chunk_recon(fidpath,max_blocks,ntraces,npoints,bitdepth,voldims,scannercode,runno,res,workpath,headfile)

%% warning about how this thing works
sprintf('\n');
display('Performing chunkwise recon of large dataset');
display('this will work MUCH faster if your dataset arrays have a large number of integer factors');
display('if for example, your array dimensions are prime, then recon will be done one slice at a time');
display('this recon also assumes that you can fit the entire magnitude or phase image into memory');
display('the work output of this program is not standard. No complex output data are saved');
display('the x-chunk data in the work directory are essentially image data divided into chunks along the x-dimension');
sprintf('\n');

%% determine number of z-slices and number of x-slices we can work with at a time

% z-slices
% find integer factors of z-resolution
zfactors=integer_factors(voldims(3));
% find the smallest integer factor to divide data that stays below memory limit
zfactor_npoints=prod([voldims 2])./zfactors;
zdivisor=zfactors(find(zfactor_npoints<(max_blocks*npoints*ntraces),1,'first'));
display(['looks like we can work on ' num2str(voldims(3)/zdivisor) ' z-slices at a time']);
% find out how many points that is
zfactor_npoints=voldims(1)*voldims(2)*(voldims(3)/zdivisor)*2;

% x-slices
% find integer factors of x-resolution
xfactors=integer_factors(voldims(1));
% find the smallest integer factor to divide data that stays below memory limit
xfactor_npoints=prod([voldims 2])./xfactors;
xdivisor=xfactors(find(xfactor_npoints<(max_blocks*npoints*ntraces),1,'first'));
display(['looks like we can work on ' num2str(voldims(1)/xdivisor) ' x-slices at a time']);
% find out how many points that is
% xfactor_npoints=(voldims(1)/xdivisor)*voldims(2)*voldims(3)*2;


%% do 2D ifft on z chunks

if ~exist([workpath '/ifft2d.work'],'file')
    % create output work file
    ifft2d_out=fopen([workpath '/ifft2d.work'],'w+');
    
    %z chunk loop
    for zchunk=1:zdivisor
        display(['working on z-chunk ' num2str(zchunk) ' of ' num2str(zdivisor)]);
        
        % load z chunk from fid file
        display('loading data from fid file');
        data_buffer=load_fid(fidpath,zfactor_npoints/(npoints*ntraces),ntraces,npoints,bitdepth,zchunk,[voldims(1) voldims(2) voldims(3)/zdivisor]);
        
        % apply partial fermi filter
        display('applying fermi filter')
        z_ind=1+((zchunk-1)*(voldims(3)/zdivisor)); %this is the z slice index of the current chunk
        data_buffer=fermi_filter(data_buffer,voldims,z_ind);
        
        % do the 2d ifft and fftshift on the z chunk
        display('performing 2d ifft in x and y');
        data_buffer=fft2d(data_buffer);
        
        % write output to disk
        display('writing completed z chunk to disk');
        %interleave real and imaginary column vector before writing
        interleaved=zeros(prod([size(data_buffer) 2]),1,'single');
        interleaved(1:2:end)=real(data_buffer);
        interleaved(2:2:end)=imag(data_buffer);
        fwrite(ifft2d_out,interleaved,'single');
        clear interleaved
    end
else
    display('found work file, skipping x and y ifft')
    ifft2d_out=fopen([workpath '/ifft2d.work'],'r');
end


%% do the 1D ifft on x chunks

%x chunk loop
for xchunk=1:xdivisor
    if ~exist([workpath '/xchunk_' sprintf('%03i',xchunk)],'file')
        display(['working on x-chunk ' num2str(xchunk) ' of ' num2str(xdivisor)]);
        
        %do initial fseek
        fseek(ifft2d_out,(xchunk-1)*(voldims(1)/xdivisor)*2*4,'bof');
        
        % load x chunk from work file
        display('loading data from work file, this could take a while');
        nb4skip=num2str((voldims(1)/xdivisor)*2); % number of values to read before skipping values
        b2skip=((voldims(1)-(voldims(1)/xdivisor))*2*4); %bytes to skip, essentially points to skip *4 for single precisison
        data_buffer=fread(ifft2d_out,(voldims(1)/xdivisor)*voldims(2)*voldims(3)*2,[nb4skip '*single=>single'],b2skip);
        %now convert to complex array
        data_buffer=reshape(complex(data_buffer(1:2:end),data_buffer(2:2:end)),(voldims(1)/xdivisor),voldims(2),voldims(3));
        
        % fermi filter has already been applied in the z chunk loop
        
        % do the 1d ifft and fftshift on the x chunk
        display('performing 1d ifft in z');
        data_buffer=fftzd(data_buffer);
        
        % write output to disk
        display('writing completed x chunk to disk');
        %write magnitude or phase x chunks to disk, just magnitude for now
        data_buffer=abs(data_buffer);
        chunkout=fopen([workpath '/xchunk_' sprintf('%03i',xchunk)],'w+');
        fwrite(chunkout,data_buffer,'single');
        fclose(chunkout);
    else
        display(['found x chunk number ' num2str(xchunk) ' of ' num2str(xdivisor) ' in work folder, skipping 1D ifft in z']);
    end
end


%% concatenate completed x chunks into a single image

%clear matlab memory
clear interleaved data_buffer

%preallocate image array
img=zeros(voldims,'single');

%x chunk loop
for xchunk=1:xdivisor
    display(['reading image part ' num2str(xchunk) ' of ' num2str(xdivisor)]);
    xchunk_file=fopen([workpath '/xchunk_' sprintf('%03i',xchunk)],'r');
    img((1+(xchunk-1)*voldims(1)/xdivisor):(xchunk*voldims(1)/xdivisor),:,:)=reshape(fread(xchunk_file,inf,'single=>single'),(voldims(1)/xdivisor),voldims(2),voldims(3));
    fclose(xchunk_file);
end

% write output
save_agilent_img(img,1,1,scannercode,runno,res,headfile,1,1,0,1);



