options={'existing_data','overwrite','warning_pause=0','debug_mode=50',...
    'skip_write_civm_raw','skip_write_headfile','write_unscaled','skip_filter','use_new_bruker_padding'};%,'ignore_errors'};%,'ignore_kspace_oversize'};

try % 128 scott
rad_mat('nemopv6','test_RM_nemopv6_jcn_UTE3D_20170125_20170124_084234_121205_1_3_20170124_s21',{'20170124_084234_121205_1_3','21'},options);
catch err
    warning(err.message);
end

try % 128 bruker
rad_mat('nemopv6','test_RM_nemopv6_UTE3D_20170124_084234_121205_1_3_20170124_s13',{'20170124_084234_121205_1_3','13'},options);
catch err
    warning(err.message);
end

try
rad_mat('nemopv6','test_RM_nemopv6_RARE_20170124_084234_121205_1_3_20170124_s06',{'20170124_084234_121205_1_3','6'},options);
rad_mat('nemopv6','test_RM_nemopv6_MGE_20170124_084234_121205_1_3_20170124_s09',{'20170124_084234_121205_1_3','9'},options);
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



