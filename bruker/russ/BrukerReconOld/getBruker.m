function [img,hdr] = getBruker(patient_ID,study_name,scan_number,varargin)
% Pulls data from Bruker7T and places it in folder specified by
% ./getbruker.bash, a script created by Evan.  
%
% Example of command:  getBruker(20120803,'MGE_IV',31,1);
%
% Example of script: ./getbruker.bash 20120803 MGE_IV 31
%
% Russell Dibb, Duke University, 8/6/12

if ~ischar(patient_ID)
    patient_ID = num2str(patient_ID);
end
if ~ischar(study_name)
    study_name = num2str(study_name);
end
if ~ischar(scan_number)
    scan_number = num2str(scan_number);
end

cd('/Users/rmd22');
system(['./getbruker.bash ' patient_ID ' ' study_name ' ' scan_number]);

if exist('varargin','var')
    cd(['/Users/rmd22/Documents/MATLAB/11.rd.02/frombruker/' patient_ID '_' ...
        study_name '/' scan_number]);
    
    load('/Users/rmd22/Documents/MATLAB/11.rd.02/frombruker/stripMaskVars.mat');
    save stripMaskVars
    
    [img,hdr] = RussRecon('bruker','center','matsave',varargin{:});
    
    
    
end


end

 