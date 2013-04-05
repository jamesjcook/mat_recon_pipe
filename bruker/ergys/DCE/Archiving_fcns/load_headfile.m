% This function loads a headfile structure given the full path of the file

function hdfile=load_headfile(input_path)

%Input path needs to be a string

fid=fopen(input_path);
c=textscan(fid, '%c', 'EndOfLine', '\r'); c=c';
fclose(fid);
%split into lines
%split each line into 2 part cell
% add each entry to headfile.(name)=value