function headfile=load_scanner_header(scanner,directory,name)
%function headfile=load_scanner_header(scanner,directory,name)
% function to load a scanner header and turn it into a civm headfile
% struct in memory. 
% 
% Uses perl script to parse(since i've written good ones of those already)
% 
% input 
% scanner, scanner name (as we would normally specify on command line)
% direcyory, directory of data files
% name,    name of temp headfile to save to directory. can be blank and
% we'll save scanner_vendor.headfile
% currently supports bruker or agilent scanners. Could be expanded
% easily enought. Perhaps uspect support as i've written similar parsing
% code for that.
% 
if ~exist('directory','var')
    help load_scanner_header;
    error('Must specify scanner and direcyory');
%     directory=scanner;
%     scanner='';
end
if ~exist('name','var')
    sdeps=load_scanner_dependency(scanner);
    name=[sdeps.scanner_vendor '.headfile'];
end

% prefix=['perl /recon_home/script/dir_radish/modules/script/pipeline_utilities/'];
% plprgext='.pl';
% 
% prefix='';
% plprgext='';
options=[' -o '];
% cmd=[prefix 'dumpHeader' plprgext options ' ' scanner ' ' directory ' ' name];
cmd=['dumpHeader'  options ' ' scanner ' ' directory ' ' name];
fprintf('running header dumper\n\t%s\n',cmd);
[s]=system(cmd);

headfile=read_headfile([ directory '/' name ]);

headfile.comment{end+1}=['# \/ header dump cmd ' '\/'];
headfile.comment{end+1}=['# ' cmd ];
headfile.comment{end+1}=['# /\ header dump cmd ' '/\'];