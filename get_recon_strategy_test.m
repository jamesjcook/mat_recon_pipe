function [recon_strategy,opt_struct]=get_recon_strategy_test(testcase)

if ~exist('testcase','var')
    error(' Did not specify test case, choose one of l_me, s3d, l_m3d');
end

test_case.(testcase)=1;
if isfield(test_case,'l_me')
    load('get_recon_strategy_test_large_multi_echo');
    [recon_strategy,opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo);
end
if isfield(test_case,'s3d')
    % 512,256,256 single 3d
    load('get_recon_strategy_test_single3d')
    [recon_strategy,opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo);
end
if isfield(test_case,'l_m3d')
    load('get_recon_strategy_test_many3D_large')
    [recon_strategy,opt_struct]=get_recon_strategy3(data_buffer,opt_struct,d_struct,data_in,data_work,data_out,meminfo);
end

