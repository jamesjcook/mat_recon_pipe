%% This function calculates K_trans, k_e, v_e, and v_p using the method published by Murase MRM 51:858-862 (2004)
%Note: k_e=K_trans/v_e

%K_trans=rate constant for the transfer of contrast from plasma to EES [unit=1/time]
%k_e=rate constant for the transfer of contrast from EES to plasma [unit=1/time]
%v_p=plasma volume (per unit volume of tissue, expressed in %)
%v_e=EES volume (per unit volume of tissue, expressed in %)


%%
function [K_trans, k_e, v_e, v_p]=calc_DCE_parameters(C, AIF, temp_rez, mat, runno)
%========INPUTS========
%C=matrix, the rows of C contain the time-concentration curves for different pixels (ex: C(1,:) is the time-concentration curve for pixel 1)
%AIF=arterial input function
%temp_rez=temporal resolution in seconds
%Note: AIF starts from time t=0. This corresponds to a time-concentration
%curve that has only one point at baseline before the rising portion of the
%curve caused by contrast inflow
%mat=matrix size
%runno=run number
%========OUTPUTS========
%K_trans=vector, the first element of the vector is the K_trans for the
%pixel that has a time-concentration curve represented by C(1,:) and
%similarly for the other element
%k_e, v_e, v_p have the same layout as K_trans

np = size(C,1); % number of pixels
nt = size(C,2); % number of timepoints

K_trans=zeros(1, np);
k_e=zeros(1, np);
v_e=zeros(1, np);
v_p=zeros(1, np);

A=zeros(nt, 3);

A(2:nt,1) = .5*temp_rez*cumsum(AIF(1:nt-1)+AIF(2:nt));
A(:,3) = AIF(1:nt);

for j=1:np
   
    C_t=C(j,:); %Tumor tissue concentration as a function of time
    
    A(2:nt,2) = -.5*temp_rez*cumsum(C_t(1:(nt-1))+C_t(2:nt));
    
    b=A\C_t';
   
    v_p(j)=b(3);
    k_e(j)=b(2);
    K_trans(j)=b(1)-v_p(j)*k_e(j);
    v_e(j)=K_trans(j)/k_e(j);
   
end

K_trans_nonfiltered=reshape(K_trans, mat, mat, mat);
k_e_nonfiltered=reshape(k_e, mat, mat, mat);
v_e_nonfiltered=reshape(v_e, mat, mat, mat);
v_p_nonfiltered=reshape(v_p, mat, mat, mat);

current_directory=pwd;
fid=fopen([runno '_Ktrans_nonfiltered.f32' ], 'w');
fwrite(fid, K_trans_nonfiltered, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

fid=fopen([runno '_ke_nonfiltered.f32' ], 'w');
fwrite(fid, k_e_nonfiltered, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

fid=fopen([runno '_ve_nonfiltered.f32' ], 'w');
fwrite(fid, v_e_nonfiltered, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

fid=fopen([runno '_vp_nonfiltered.f32' ], 'w');
fwrite(fid, v_p_nonfiltered, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

save('K_trans_nonfiltered', 'K_trans_nonfiltered', '-v7.3');
save('k_e_nonfiltered', 'k_e_nonfiltered', '-v7.3');
save('v_e_nonfiltered', 'v_e_nonfiltered', '-v7.3');
save('v_p_nonfiltered', 'v_p_nonfiltered', '-v7.3');


%% Constrain the values to be in the range [0 1] and save

K_trans=reshape(K_trans, mat, mat, mat);
k_e=reshape(k_e, mat, mat, mat);
v_e=reshape(v_e, mat, mat, mat);
v_p=reshape(v_p, mat, mat, mat);

K_trans(K_trans>1)=1; 
K_trans(K_trans<0)=0;

k_e(k_e>1)=1; 
k_e(k_e<0)=0;

v_e(v_e>100)=100; 
v_e(v_e<0)=0;

v_p(v_p>100)=100; 
v_p(v_p<0)=0;

fid=fopen([runno '_Ktrans.f32' ], 'w');
fwrite(fid, K_trans, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

fid=fopen([runno '_ke.f32' ], 'w');
fwrite(fid, k_e, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

fid=fopen([runno '_ve.f32' ], 'w');
fwrite(fid, v_e, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

fid=fopen([runno '_vp.f32' ], 'w');
fwrite(fid, v_p, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

save('K_trans', 'K_trans', '-v7.3');
save('k_e', 'k_e', '-v7.3');
save('v_e', 'v_e', '-v7.3');
save('v_p', 'v_p', '-v7.3');