function agilent_saveprocparhf(path,prefix)
% function agilent_saveprocparhf('/path/to/file','prefix')
% loads a procpar file in directory path, using readprocpar
% then saves the contents of the procpar to a civm format headfile at path/procpar.headfile
% 
%
if ~exist('prefix','var')
    prefix='';
end
%% read procpar and add rhuser var for radish benefit
procpar=readprocpar(path,0);
procpar.rhuser21={'2500'}; % really should move this to the dumpAgilent code, or convert this to be entirely dedicated to dumpAgilentHeader,for now left the dumpAgilent1 script to be very simple.


%% set outpath and write struct hf
[p,n,ext]=fileparts(path);
out_hf=[p '/procpar.headfile'];
structToHeadfile(out_hf,procpar,prefix)

end
