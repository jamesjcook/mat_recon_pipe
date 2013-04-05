function rp_ca=load_complex(complex_file,dims,precision,endian,componentboolean)
% function complex=load_rp_file(paht_to_complex,dims,precision,endian,componentboolean)
% loads an interleaved complex file to a variable,
% if this is not cartesian data, 
%   dims should be just the number of points, 
% compentne boolean looks for complex_file.i and complex_file.r to load
% instead of complex_file.
% 
% assumes all header bytes are in beginning of file, 
% 32-bit float('single') little-endian data, is default. others not well
% tested

if ~exist('bitdepth','var')
    precision='single';
    bytes_per_point=4;
elseif strcmp(bitdepth,'single')
    bytes_per_point=4;
elseif strcmp(bitdepth,'double') 
    bytes_per_point=8;
elseif strcmp(bitdepth,'unint16') ||strcmp(bitdepth,'float16')
    bytes_per_point=2
elseif strcmp(bitdepth,'unint32')
    bytes_per_point=4;
else 
    error('bad precision');
end

if ~exist('componentboolean','var')
    componentboolean=0;
end


if ~exist('endian','var')
    endian='l';
end

data_points=1;
for i=1:length(dims)
    data_points=data_points*dims(i);
end
%multiply datapointsby 2 becuase complex doubles the data.




if componentboolean
    data_bytes=data_points*bytes_per_point;
    if ~exist([complex_file '.i'] ,'file') || ~exist([complex_file '.i'],'file')
        error(' name.i and name.r file not found')
    end
    i_file=[complex_file '.i'];
    fileInfo = dir(i_file);
    fileSize = fileInfo.bytes;
    headersize=fileSize-data_bytes;
    if headersize>data_bytes
        error('Header bigger than data, that cant be right');
    elseif  headersize<0
        error('Header less than 0, that cant be right');
    elseif headersize==0
        warning('load_complex:header','Header is 0 bytes big');
    end
    
    fid=fopen(i_file,'r',endian);
    if fid==-1
        error(['could not load rp file' i_file ]);
    end
    
    fseek(fid,headersize,-1);
    data(1,:)=fread(fid,inf,precision,0,endian);
    fclose(fid);
    
    
    fileInfo=[]; fileSize=[];
    r_file=[complex_file '.r'];
    fileInfo = dir(r_file);
    fileSize = fileInfo.bytes;
    headersize=fileSize-data_bytes;
    if headersize>data_bytes
        error('Header bigger than data, that cant be right');
    elseif  headersize<0
        error('Header less than 0, that cant be right');
    elseif headersize==0
        warning('load_complex:header','Header is 0 bytes big');
    end
    
    fid=fopen(r_file,'r',endian);
    if fid==-1
        error(['could not load rp file' r_file ]);
    end
    
    fseek(fid,headersize,-1);
    data(2,:)=fread(fid,inf,precision,0,endian);
    fclose(fid);
    
    
    
    
    
    data=reshape(data,[2 data_points]);
else
    data_bytes=2*data_points*bytes_per_point;
    if ~exist(complex_file,'file')
        error('file not found');
    end
    fileInfo = dir(complex_file);
    fileSize = fileInfo.bytes;
    headersize=fileSize-data_bytes;
    if headersize>data_bytes
        warning('Header bigger than data, that cant be right');
    elseif  headersize<0
        warning('Header less than 0, that cant be right');
    elseif headersize==0
        warning('load_complex:header','Header is 0 bytes big');
    end
    
    fid=fopen(complex_file,'r',endian);
    if fid==-1
        error(['could not load rp file' complex_file ]);
    end
    
    fseek(fid,headersize,-1);
    data=fread(fid,inf,precision,0,endian);
    fclose(fid);
    data=reshape(data,[2 data_points]);
end


% data=permute(data,[2 3 4 5 1]);
% r=data(:,:,:,:,1);
% i=data(:,:,:,:,2);

rp_ca=reshape(complex(squeeze(data(1,:)),squeeze(data(2,:))),dims);
% reshape()

end

function rjunk
fd=fopen(filename,'r',flag);
skip=fread(fd,[1 head/2],'short');  %header
% skip=fread(fd,[2 dim1],'int');  %baseline

raw=zeros(dim1,dim2,dim3);
for z=1:dim3
    %     z
    for y=1:dim2
        %         y
        dump=fread(fd,[2 dim1],'int');
        raw(:,y,z)=squeeze(dump(2,1:end)+1i*dump(1,:));
        %         raw(:,y,z)=squeeze([0,dump(2,1:end-1)]+1i*dump(1,:));
        %         if ( mod(((z-1)*dim2+y),2048)==0)
        %             %z,y
        %             skip=fread(fd,[2 dim1],'int');
        %         end
    end
end
fclose(fd);

end