
% bruker tests
patient_id='20120115';
nums=[ 9 10 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 ];
% nums=[ 9 10 12 23 25 26 27 ];
% nums=27;
% nums=[  10 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 ];
%fail_list='List of failed runs:';
fail_list='';
for i=1:length(nums)
    num=nums(i);
    try
        mg=rad_mat('nemo',['B1337_' num2str(num)],{patient_id,num2str(num)},{'warning_pause=0','study=Rat','overwrite','testmode','write_unscaled','skip_recon','existing_data'});
        %         if s==0
%         fail_list=sprintf('%s\n%s',fail_list,num2str(num));
        %         else
        %         end
    catch err
        %         if s==0
        err_m=[err.message ];
        for e=1:length(err.stack)
            err_m=sprintf('%s\n \t%s:%i',err_m,err.stack(e).name,err.stack(e).line);
        end
        fail_list=sprintf('%sbad_scan:%s\nerr_m%s',fail_list,num2str(num),err_m);
        %         else
        %         end
    end


end
%         img=rad_mat('nemo',['Btest_' patient_id '_' num2str(num)],{patient_id,num2str(num)},{'warning_pause=0','study=Rat','overwrite','testmode','write_unscaled'});

fprintf('List of failed runs:%s\n',fail_list);