function CA=agilent_load_complex(file_path,dims)
% agi_matlab complex reconed data is little endian 2 part, 
% file_path.i and
% file_path.r.
disp('OBSOLTE');
end

if 0 %% dont run
fid= fopen([file_path '.r'],'r');
if fid==-1
    error(['Could not open file ' file_path]);
end
re=reshape(fread(fid,inf,'single',0,'l'),dims);
fclose(fid);

fid= fopen([file_path '.i'],'r');
if fid==-1
    error(['Could not open file ' file_path]);
end
im=reshape(fread(fid,inf,'single',0,'l'),dims);
fclose(fid);

CA=complex(im,re);
end