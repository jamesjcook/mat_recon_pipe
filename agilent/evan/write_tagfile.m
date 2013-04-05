function write_tagfile(runno,slices,project,civmid)

local_volume=get_local_vol;

fid=fopen([local_volume '/Archive_Tags/READY_' runno],'w+');
fprintf(fid,'%s\n',[runno ',' local_volume(10:end) ',' num2str(slices) ',' project ',.raw']);
fprintf(fid,'%s\n',['# recon_person=' civmid]);
fprintf(fid,'%s\n','# tag_file_creator=Evan');
fclose(fid);