% This function re-arranges the reconstructed volumes in the current
% directory and calculates the contrast concentration curves using
% "calc_con_3D". Look at "calc_con_3D" for a detailed description on how
% the concentration is calculated.


function []=prepare_volumes_and_calc_conc_3D(DCE_runno, repeat, key_hole, temp_rez, baseline_time, varFA_TR, FAvalues, varFAstack, mat, TR_dyn, FA_dyn)


%% Pre-injection
S0_points=floor(baseline_time/temp_rez)-1; %Number of (time points-1) before contrast injection, i.e. in this protocol contrast was injected after the 15th time point (key)
S0=zeros(mat^3, S0_points); %Signal before injection
for j=1:S0_points;
    vol_name= [DCE_runno '_m' num2str(j) '.f32'];
    vol=open_raw(vol_name, mat);
    vol=vol(:);
    S0(:,j)=vol;
end
S0=sum(S0,2)/S0_points; %Average volumes to increase SNR


%% Post-injection
St_points=key_hole*repeat-S0_points; %Number of points post-injection
S_t=zeros(mat^3, St_points); %Signal vs. time after injection
for i=(S0_points+1):key_hole*repeat
    vol_name= [DCE_runno '_m' num2str(i) '.f32'];
    vol=open_raw(vol_name, mat);
    vol=vol(:);
    S_t(:,(i-S0_points))=vol;
    fclose('all');
end

[C_tracer]=calc_con_3D(varFA_TR, FAvalues, varFAstack, mat, TR_dyn, FA_dyn, S0, S_t);

ctracer_name=[DCE_runno '_tracer_concentration_' num2str(size(S_t, 2)) 'timepoints.f32'];
fid=fopen(ctracer_name, 'w');
fwrite(fid, C_tracer, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

save('C_tracer', 'C_tracer', '-v7.3'); %Need to have for TDC analysis
