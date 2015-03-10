test_case.lme=true;
test_case.n3d=true;
if test_case.lme
load('get_recon_strategy_test');
[recon_strategy_lme,opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo);
end
if test_case.n3d
load('get_recon_strategy_test_single3d')
[recon_strategy,opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo);
end