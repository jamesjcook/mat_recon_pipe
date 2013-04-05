% This function writes header structures from the Bruker generated image
% directories. Assumes the function 'readBrukerHeader' was used to create
% the input structures.

function []=write_struc2headfile(h, file_name, imgformat, tag, ~)

%h1=header structure
%file_name=name of headfile (assumes file is in current directory)
%imgformat=(string) format of saved images (either 'raw' or 'f32')
%tag=(string) a string added at the beginning of some parameters in the header which are not essential for archiving.
%output_path=location where headfile will be saved

fid=fopen(file_name, 'a');
fprintf(fid, '%s\n', ['U_rplane=ax']);
fprintf(fid, '%s\n', ['alpha=' num2str(mean(h.FAvalues))]);
fprintf(fid, '%s\n', ['variable_alpha=' num2str(h.FAvalues)]);
fprintf(fid, '%s\n', ['bw=' num2str(h.PVM_EffSWh/1000)]);
fprintf(fid, '%s\n', ['dim_X=' num2str(h.PVM_Matrix(1))]);
fprintf(fid, '%s\n', ['dim_Y=' num2str(h.PVM_Matrix(1))]);
fprintf(fid, '%s\n', ['dim_Z=' num2str(h.PVM_Matrix(1))]);
fprintf(fid, '%s\n', ['fovx=' num2str(h.PVM_Fov(1))]);
fprintf(fid, '%s\n', ['fovy=' num2str(h.PVM_Fov(1))]);
fprintf(fid, '%s\n', ['fovz=' num2str(h.PVM_Fov(1))]);
fprintf(fid, '%s\n', ['te=' num2str(h.PVM_EchoTime)]); %Archive machine exptects this to be in units of usec
fprintf(fid, '%s\n', ['tr=' num2str(h.PVM_RepetitionTime*1000)]);
fprintf(fid, '%s\n', 'B_recon_type=Ergys_Keyhole');
fprintf(fid, '%s\n', 'B_tesla=bt7');
fprintf(fid, '%s\n', ['F_imgformat=' imgformat]);
% if strcmp(imgformat,'raw')
%     fprintf(fid, '%s\n', ['F_imgformat=' imgformat]);
% elseif strcmp(imgformat, 'f32')
%     fprintf(fid, '%s\n', ['U_imgformat=' imgformat]);
%     fprintf(fid, '%s\n', ['F_imgformat=raw']);
% else
%     error('Please specify correct image format')
% end
fprintf(fid, '%s\n', 'hfpmcnt=1');
fprintf(fid, '%s\n', 'U_status=ok');
fprintf(fid, '%s\n', 'B_header_type=Ergys_Recon');
fprintf(fid, '%s\n', ['repeat=' num2str(h.PVM_NRepetitions)]);
fprintf(fid, '%s\n', ['key_hole=' num2str(h.KeyHole)]);
fprintf(fid, '%s\n', ['total_nproj=' num2str(h.NPro)]);
fprintf(fid, '%s\n', ['undersampling_factor=' num2str(h.ProUndersampling)]);
fprintf(fid, '%s\n', ['baseline_time=' num2str(h.baseline_time)]);
fclose(fid);

f=fieldnames(h);

p=cell(length(f),1);
for i=1:length(f)
    p{i,1}=[tag f{i,1} '='];
end

p=[p struct2cell(h)];

dlmcell(file_name, p, '-a');
% copyfile(file_name, output_path);