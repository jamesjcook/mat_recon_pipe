function pan_nd_image(data_buffer)
%%%
% order info, 

 disp_pause=opt_struct.display_kspace;
 if disp_pause==1
     disp_pause=5;
 end
 disp_pause=disp_pause/prod(dims);
 
 figure(1);colormap gray;
dims=size(data_buffer.data);
data_buffer.data=reshape(data_buffer.data,[dims(1:2) prod(dims(3:end))]);
for dn=1:size(data_buffer.data,3)
%     imagesc((log(abs(squeeze(kslice))))), axis image; % imagesc
%     imagesc((log(abs(squeeze(data_buffer.data(:,:,dn)))))), axis image; % imagesc
imshow(log(abs(squeeze(data_buffer.data(:,:,dn)))));
    pause(disp_pause);
end
data_buffer.data=reshape(data_buffer.data,dims);
if false
for dx=1:prod(dims(3:end))
    %         kslice=zeros(size(data_buffer.data,1),size(data_buffer.data,2)*2);
    %         kslice=zeros(x,y);
    
    selector=zeros(length(dims(3:end)),1);
    for dl=3:length(dims)
        if(dx>dims(dl))
            selector(dl-2)=mod(dx-prod(dims(dl+1:end)),dims(dl));
        end
    end
    disp(selector');
    %     kslice=data_buffer.data(...
    %         dim_select.(opt_struct.output_order(1)),...
    %         dim_select.(opt_struct.output_order(2)),...
    %         dim_select.(opt_struct.output_order(3)),...
    %         dim_select.(opt_struct.output_order(4)),...
    %         dim_select.(opt_struct.output_order(5)),...
    %         dim_select.(opt_struct.output_order(6)));
    %kslice(1:size(data_buffer.data,1),size(data_buffer.data,2)+1:size(data_buffer.data,2)*2)=input_kspace(:,cn,pn,zn,:,tn);
%     kslice=data_buffer.data(':',':',selector);
%     imshow((log(abs(squeeze(kslice)))), axis image); % imagesc
    %                             fprintf('.');
%     pause(disp_pause);
end
end

if false
    %             for tn=1:d_struct.t
    if isfield(data_buffer.headfile,'processing_chunk')
        t_s=data_buffer.headfile.processing_chunk;
        t_e=data_buffer.headfile.processing_chunk;
    else
        t_s=1;
        t_e=d_struct.t;
    end
    for tn=t_s:t_e
        if recon_strategy.num_chunks>1
            dim_select.t=1;
        else
            dim_select.t=tn;
        end
        for zn=1:d_struct.z
            dim_select.z=zn;
            for cn=1:d_struct.c
                dim_select.c=cn;
                for pn=1:d_struct.p
                    dim_select.p=pn;
                    fprintf('z:%d c:%d p:%d\n',zn,cn,pn);
                    if opt_struct.skip_regrid
                        kslice=data_buffer.data(dim_select.(input_order(1)),dim_select.(input_order(2)),...
                            dim_select.(input_order(3)),dim_select.(input_order(4)),...
                            dim_select.(input_order(5)),dim_select.(input_order(6)));
                    else
                        kslice=data_buffer.data(...
                            dim_select.(opt_struct.output_order(1)),...
                            dim_select.(opt_struct.output_order(2)),...
                            dim_select.(opt_struct.output_order(3)),...
                            dim_select.(opt_struct.output_order(4)),...
                            dim_select.(opt_struct.output_order(5)),...
                            dim_select.(opt_struct.output_order(6)));
                    end
                    %kslice(1:size(data_buffer.data,1),size(data_buffer.data,2)+1:size(data_buffer.data,2)*2)=input_kspace(:,cn,pn,zn,:,tn);
                    imagesc(log(abs(squeeze(kslice)))), axis image;
                    %                             fprintf('.');
                    pause(disp_pause);
                    %                             pause(4/d_struct.z/d_struct.c/d_struct.p);
                    %                         pause(1);
                    %                         imagesc(log(abs(squeeze(input_kspace(:,cn,pn,zn,:,tn)))));
                    %                             fprintf('.');
                    %                         pause(4/z/d_struct.c/d_struct.p);
                    %                         pause(1);
                    if(strfind(input_order,'p'))>numel(recon_strategy.c_dims)
                        pn=d_struct.p;
                    end
                end
                fprintf('\n');
                if(strfind(input_order,'c'))>numel(recon_strategy.c_dims)
                    cn=d_struct.c;
                end
            end
        end
        if(strfind(input_order,'t'))>numel(recon_strategy.c_dims)
            tn=d_struct.t;
        end
            end
end    