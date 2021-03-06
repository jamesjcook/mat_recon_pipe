%% This script calculates K_trans, k_e, v_e, and v_p for a given dataset
% C_tracer needs to be calculated first.
clc
scans_dir='E:\Scans_20120321\B00373\From_Scanner\Undersampled_recon_no_SW\'; %Directory containing the tracer concentration (C_tracer) 4D volume
cd(scans_dir);
load C_tracer

runno='00373';
repeat=40; %Same as repeat in multikey_repeat in scanner
key_hole=13;
mat=128; %Final recon matrix size
time_points=size(C_tracer,3)/mat; %Number of time points after contrast injection
temp_rez=9.9; %sec


%% Reshape C_tracer
C=ones(mat^3, time_points);
for i=1:time_points
    indx=((i-1)*mat+1):(i*mat);
    v_i=C_tracer(:,:,indx);
    v_i=v_i(:);
    C(:,i)=v_i;
end


%% Get arterial input function
t=0:(time_points-1);
t=t*temp_rez; %Time in seconds (needs to be in seconds in order to be used in the AIF expression)

D=0.5; %Dose [mmol/kg]
a1=0.0516; a2=0.082; %units [kg/L]
m1=0.045; m2=1.3045; %units [s-1]

Cp=D*(a1*exp(-t*m1)+a2*exp(-t*m2)); %Arterial input function from Loveless, Yankeelov MRM 2011.


%% Calculate the DCE parameters (uses the method published by Murase MRM 51:858-862 (2004))

tic
[K_trans, k_e, v_e, v_p]=calc_DCE_parameters(C, Cp, temp_rez, mat, runno);
toc