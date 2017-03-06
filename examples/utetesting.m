options={'existing_data','overwrite','warning_pause=0','debug_mode=50',...
    'skip_write_civm_raw','write_unscaled','skip_filter','use_new_bruker_padding','skip_mem_checks'};%,'ignore_errors'};%,'ignore_kspace_oversize'};

try % 128 scott
%[success_status_jcnUTE3D,img_jcnUTE3D, data_buffer_jcnUTE3D]=rad_mat('nemopv6','test_RM_nemopv6_jcn_UTE3D_20170125_20170124_084234_121205_1_3_20170124_s21',{'20170124_084234_121205_1_3','21'},options);
[success_status_jcnUTE3D,img_jcnUTE3D, data_buffer_jcnUTE3D]=rad_mat('nemopv6','test_RM_nemopv6_jcn_UTE3D_20170125_121205_1_3_1_3_20170131_09_20170131_s17',{'121205_1_3_1_3_20170131_09','17'},options);

!open /androsspace/test_RM_nemopv6_jcn_UTE3D_20170125_20170124_084234_121205_1_3_20170124_s21.work
!open /panoramaspace/test_RM_nemopv6_jcn_UTE3D_20170125_121205_1_3_1_3_20170131_09_20170131_s17.work
catch err
    warning(err.message);
end
try % 128 bruker
% [success_status_UTE3D,img_UTE3D, data_buffer_UTE3D]=rad_mat('nemopv6','test_RM_nemopv6_UTE3D_20170124_084234_121205_1_3_20170124_s13',{'20170124_084234_121205_1_3','13'},options);
[success_status_UTE3D,img_UTE3D, data_buffer_UTE3D]=rad_mat('nemopv6','test_RM_nemopv6_UTE3D_121205_1_3_1_3_20170131_09_20170131_s05',{'121205_1_3_1_3_20170131_09','5'},options);

!open /androsspace/test_RM_nemopv6_UTE3D_20170124_084234_121205_1_3_20170124_s13.work
!open /panoramaspace/test_RM_nemopv6_UTE3D_121205_1_3_1_3_20170131_09_20170131_s05.work
catch err
    warning(err.message);
end
% variables with 69 points( matrix+ramp)
% PVM_TrajBx, PVM_TrajBy, PVM_TrajBz
% PVM_TrajKx, PVM_TrajKy, PVM_TrajKz
% variable with 100 points, hmm...
% ACQ_gradient_amplitude=100 <<<< !!!!

%%% !compare_headfiles test_RM_nemopv6_UTE3D_20170124_084234_121205_1_3_20170124_s13 test_RM_nemopv6_jcn_UTE3D_20170125_20170124_084234_121205_1_3_20170124_s21
%%% !compare_headfiles test_RM_nemopv6_UTE3D_121205_1_3_1_3_20170131_09_20170131_s05 test_RM_nemopv6_jcn_UTE3D_20170125_121205_1_3_1_3_20170131_09_20170131_s17
return;
stop;


try
    rad_mat('nemopv6','test_RM_nemopv6_RARE_20170124_084234_121205_1_3_20170124_s06',{'20170124_084234_121205_1_3','6'},options);
    !open /androsspace/test_RM_nemopv6_RARE_20170124_084234_121205_1_3_20170124_s06.work
    rad_mat('nemopv6','test_RM_nemopv6_MGE_20170124_084234_121205_1_3_20170124_s09',{'20170124_084234_121205_1_3','9'},options);
    !open /androsspace/test_RM_nemopv6_MGE_20170124_084234_121205_1_3_20170124_s09.work
catch err
    warning(err.message);
end

try % 400 scott
rad_mat('nemopv6','test_RM_nemopv6_jcn_UTE3D_20170125_20170124_084234_121205_1_3_20170124_s14',{'20170124_084234_121205_1_3','14'},options);
catch err
    warning(err.message);
end

try % 440 bruker
rad_mat('nemopv6','test_RM_nemopv6_UTE3D_20170124_084234_121205_1_3_20170124_s30',{'20170124_084234_121205_1_3','30'},options);
catch err
    warning(err.message);
end

try % unknown scott
rad_mat('nemopv6','test_RM_nemopv6_jcn_UTE3D_20170125_20170124_084234_121205_1_3_20170124_s17',{'20170124_084234_121205_1_3','17'},options);
catch err
    warning(err.message);
end



