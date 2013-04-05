% This script concatenates reconstructed volumes and calculates the
% contrast concentration curves
fclose('all'), clc

% load FAvalues
% load varFAstack

runno='00373';
scans_dir='E:\Scans_20120321\B00373\From_Scanner\UFC_SW\'; %Directory containing the scans of a given day
cd(scans_dir);
repeat=40; %Same as repeat in multikey_repeat in scanner
key_hole=13;
mat=128; %Final recon matrix size

TR=5; %(ms). TR for the variable flip-angle acquisition
TR_dyn=5; %(ms). TR for DCE acquisition
FA_dyn=10; %(degrees). Flip angle for DCE acquisition

%% Pre-injection
tic
S0=[]; %Signal before injection
S0_points=14; %Number of (time points-1) before contrast injection, i.e. in this protocol contrast was injected after the 15th time point (key)

for j=1:floor(S0_points/key_hole);
for i=1:key_hole 
    vol_name= ['B' runno '_acq' num2str(j) '_key' num2str(i) '.raw'];
    vol=open_raw(vol_name, mat);
    % vol=permute(vol, [3 1 2]); %reslice in coronal plane
    vol=vol(:);
    S0=[S0 vol];
end
end

j=j+1;
for i=1:mod(S0_points, key_hole) 
    vol_name= ['B' runno '_acq' num2str(j) '_key' num2str(i) '.raw'];
    vol=open_raw(vol_name, mat);
    % vol=permute(vol, [3 1 2]); %reslice in coronal plane
    vol=vol(:);
    S0=[S0 vol];
end
S0=sum(S0,2)/S0_points; %Average volumes to increase SNR


%% Post-injection
S_t=[]; %Signal vs. time after injection

for i=(mod(S0_points, key_hole)+1):key_hole
    vol_name= ['B' runno '_acq' num2str(j) '_key' num2str(i) '.raw'];
    vol=open_raw(vol_name, mat);
    % vol=permute(vol, [3 1 2]); %reslice in coronal plane
    vol=vol(:);
    S_t=[S_t vol];
end

new_j=j+1;
for j=new_j:repeat 
    for i=1:key_hole 
        vol_name= ['B' runno '_acq' num2str(j) '_key' num2str(i) '.raw'];
        vol=open_raw(vol_name, mat);
        % vol=permute(vol, [3 1 2]); %reslice in coronal plane
        vol=vol(:);
        S_t=[S_t vol];
    end
    fclose('all');
end


[C_tracer]=calc_con_3D(TR, FAvalues, varFAstack, mat, TR_dyn, FA_dyn, S0, S_t);
toc

current_directory=pwd;
fid=fopen([current_directory '\B' runno '_tracer_concentration_' num2str(size(S_t, 2)) 'timepoints.raw' ], 'w');
fwrite(fid, C_tracer, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

save('C_tracer', 'C_tracer', '-v7.3'); %Need to have for TDC analysis
