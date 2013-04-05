function [output,directory] = readBrukerDirectory(directory, varargin)
%%  readBrukerDirectory.m - Original by Evan Calabrese
%   rmd - added directory as an output for saved files
if nargin == 0
    directory = uigetdir('/~', 'Directory for data');
end
if(directory(end)~='/')
    directory = [directory '/'];
end
output.acqp = readBrukerHeader([directory 'acqp']);
output.method = readBrukerHeader([directory 'method']);
output.fid = readBrukerFID(directory, output.method);
output.subject = readBrukerHeader([directory '../subject']);

end