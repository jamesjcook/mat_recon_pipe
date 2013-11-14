% This function calculates Ktrans, ke, ve, and vp.

% Ergys Subashi
% June, 2012


function []=DCE_calc_Ktrans(Patient_ID, Study, DCE_runno, DCE_Scan_ID, D)

%% INPUTS
% =========examples=========
% DCE_runno='B99999test'; %Needs to be a string
% Patient_ID='20111007'; %Needs to be a string
% Study='20120501'; %Usually the date (needs to be a string)
% D=injection dose in [mmol/kg]. (Ergys uses 0.5 mmol/kg)

local_dir='/androsspace'; cd(local_dir);
DCE_dir=[local_dir '/' DCE_runno '.work'];
transferred_dir=[DCE_dir '/' Patient_ID '_' Study];
cd(transferred_dir);
cd(num2str(DCE_Scan_ID));
method_header=readBrukerHeader('method');
mat=method_header.PVM_Matrix; mat=mat(1);
mat2=mat/2;
TR_dyn=method_header.PVM_RepetitionTime;
key_hole=method_header.KeyHole; n_projs=method_header.NPro;
repeat=method_header.PVM_NRepetitions;
temp_rez=n_projs*TR_dyn/(key_hole*1000); %Temporal resolution in seconds
cd(DCE_dir);

tStart=tic;
load C_tracer
time_points=size(C_tracer,3)/mat; %Number of time points after contrast injection


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

a1=0.0516; a2=0.082; %units [kg/L]
m1=0.045; m2=1.3045; %units [s-1]

Cp=D*(a1*exp(-t*m1)+a2*exp(-t*m2)); %Arterial input function from Loveless, Yankeelov MRM 2011.


%% Calculate the DCE parameters (uses the method published by Murase MRM 51:858-862 (2004))

calc_DCE_parameters(C, Cp, temp_rez, mat, DCE_runno);

tElapsed=toc(tStart);
display(['Calculating Ktrans, ke, ve, and vp took ' num2str(tElapsed/60) ' minutes'])