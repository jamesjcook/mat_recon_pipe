function scott_grid(data_buffer,opt_struct,data_in,data_work,data_out)
% go and call on scott's  functionized example grid.
if ~exist('data_buffer','var')
    load /Volumes/workstation_home/software/recon/External/ScottHaileRobertson/Duke-CIVM-MRI-Tools/DukePackage/Recon/ReconScripts/Bruker/ScottDemoVarLoad_B02124;
end
if ~isfield(opt_struct,'nThreads')
    opt_struct.nThreads = feature('numCores');
end
if ~isfield(opt_struct,'window_width')
    opt_struct.window_width=13;
end
% Dirty find and setup function should fail if we dont have them.
% run([getenv('WORKSTATION_HOME') '/recon/External/ScottHaileRobertson/CIVM_MATLAB_Libs/setup.m']);
run([getenv('WORKSTATION_HOME') '/recon/External/ScottHaileRobertson/Duke-CIVM-MRI-Tools/setup.m']);
run([getenv('WORKSTATION_HOME') '/recon/External/ScottHaileRobertson/GE-MRI-Tools/setup.m']);
run([getenv('WORKSTATION_HOME') '/recon/External/ScottHaileRobertson/Non-Cartesian-Reconstruction/setup.m']);

% this function was mostly gutted and stuffed into sliding window recon
% different parameters should be passed via the opt_struct
sliding_window_recon(data_buffer,opt_struct,data_in,data_work,data_out);
