function headfile=load_scanner_header(scanner,directory,name,opt_struct)
%function headfile=load_scanner_header(scanner,directory,name,opt_struct)
% function to load a scanner header and turn it into a civm headfile
% struct in memory. 
% 
% Uses perl script to parse(since i've written good ones of those already)
% 
% input 
% scanner, scanner name (as we would normally specify on command line)
% directory, directory of data files
% name,    name of temp headfile to save to directory. can be blank and
% we'll save scanner_vendor.headfile
% opt_struct option struct from rad mat, can be blank. We're only using it
% for the debug_mode value. So it could also be an int.
% currently supports aspect or bruker or agilent scanners. Could be expanded
% easily enought. Perhaps uspect support as i've written similar parsing
% code for that.
% 
if ~exist('directory','var')
    help load_scanner_header;
    error('Must specify scanner and directory');
%     directory=scanner;
%     scanner='';
end
if isstruct(name)||isnumeric(name)
    opt_struct=name;
    clear name;
end
if ~exist('name','var')
    sdeps=load_scanner_dependency(scanner);
    name=[sdeps.scanner_vendor '.headfile'];
end
if exist('opt_struct','var')
    if isnumeric(opt_struct)
        opt_struct.debug_mode=opt_struct;
    end
    if isfield(opt_struct,'debug_mode')
        debug_string=[' -d' num2str(opt_struct.debug_mode)];
    else
        debug_string=[' -d' num2str(5)];
    end
else
    debug_string='';
end 

% prefix=['perl /recon_home/script/dir_radish/modules/script/pipeline_utilities/'];
% plprgext='.pl';
% 
% prefix='';
% plprgext='';
options=[debug_string ' -o '];
% cmd=[prefix 'dumpHeader' plprgext options ' ' scanner ' ' directory ' ' name];
cmd=['dumpHeader'  options ' ' scanner ' ' directory ' ' name];
fprintf('running header dumper\n\t%s\n',cmd);
[s]=system(cmd);

headfile=read_headfile([ directory '/' name ]);

headfile.comment{end+1}=['# \/ header dump cmd ' '\/'];
headfile.comment{end+1}=['# ' cmd ];
headfile.comment{end+1}=['# /\ header dump cmd ' '/\'];
