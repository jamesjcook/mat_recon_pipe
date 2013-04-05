% This function writes header structures from the Bruker generated image
% directories. Assumes the function 'readBrukerHeader' was used to create
% the input structures.

function []=write_headfile(headfile, output)

% make sure headfile is a struct
if ~isstruct(headfile)
    error('input must be a structure!')
end

% open output file for writing
fid=fopen(output, 'w+');

% make sure file is writeable
if fid==-1
    error(['cannot open output file ' output]);
end

% get field names
params=fieldnames(headfile);

% write each field on a new line as a string
for i=1:numel(params)
    fieldval=getfield(headfile,params{i});
    if ~ischar(fieldval)
        fieldval=num2str(fieldval);
    end
    if strcmp(params{i},'PSDName') %insert regex check for doublunderscores later(i'll fix that) i liked that solution.  me too but fuck regex
      fprintf(fid,'%s\n',['PSD Name=' fieldval]);  
    else
    fprintf(fid,'%s\n',[params{i} '=' fieldval]);
    end
end

% close output file
fclose(fid);

% display success message
display(['headfile written to ' output]);
end