function rad_regid(data_buffer,c_dims)
% function to turn sampled points into their cartesian grid equivalent.
% when cartesian its just a reshape operation.
%

% dimension order is generally xcpzyt might depend on scanner,
%                           or xcpyzt
% channels might be reversed
% c=channels,
% p=echos,(could also be alphas?)
% t=time

%% get dimensions and dimension codes. 
data_tag=data_buffer.input_headfile.S_scanner_tag;

x=data_buffer.input_headfile.dim_X;
y=data_buffer.input_headfile.dim_Y;
z=data_buffer.input_headfile.dim_Z;
channels=data_buffer.input_headfile.([data_tag 'channels'] );
if isfield (data_buffer.input_headfile,[data_tag 'varying_parameter'])
    varying_parameter=data_buffer.input_headfile.([data_tag 'varying_parameter']);
else
    varying_parameter='';
end
if strcmp(varying_parameter,'echos')
    params=data_buffer.input_headfile.ne;
elseif strcmp(varying_parameter,'alpha')
    params=length(data_buffer.input_headfile.alpha_sequence);
elseif strcmp(varying_parameter,'tr')
    params=length(data_buffer.input_headfile.tr_sequence);
elseif regexpi(varying_parameter,',')
    error('MULTI VARYING PARAMETER ATTEMPTED:%s THIS HAS NOT BEEN DONE BEFORE.',varying_parameter);
else
    fprintf('No varying parameter\n');
    params=1;
end
timepoints=data_buffer.input_headfile.([data_tag 'volumes'])/channels/params;
dim_order=data_buffer.input_headfile.([data_tag 'dimension_order' ]);
if  isfield (data_buffer.input_headfile,[data_tag 'rare_factor'])
    r=data_buffer.input_headfile.([data_tag 'rare_factor']);
    % report_order=data_buffer.input_headfile.([data_tag 'axis_report_order']);
    % report order should already be handled by the dimension_order handwaving
    % which has gone on elsewhere.
    dim_order_init=dim_order;
    dim_order=char(zeros(1,numel(dim_order_init)+1));
    output_order_init=data_buffer.headfile.('rad_mat_option_output_order');
    output_order=char(zeros(1,numel(output_order_init)+1));
    for d_num=1:numel(dim_order_init)
        dim_order(d_num)=dim_order_init(d_num);
        output_order(d_num)=output_order_init(d_num);
        if strcmp(dim_order_init(d_num),'c')
            dim_order(d_num+1)='r';
            dim_order(d_num+2:d_num+2+numel(dim_order_init(d_num+1:end))-1)=dim_order_init(d_num+1:end);
            output_order(d_num+1)='r';
            output_order(d_num+2:d_num+2+numel(output_order_init(d_num+1:end))-1)=output_order_init(d_num+1:end);
            break
        end
    end
    
else
    r=1;
    output_order=data_buffer.headfile.('rad_mat_option_output_order');
end

d_struct=struct;
d_struct.r=r;
d_struct.x=x;
d_struct.y=y;
d_struct.z=z;
d_struct.c=channels;
d_struct.p=params;
d_struct.t=timepoints;

% make up the output_dimensions excluding the r(rare_factor) dimension.
output_dimensions=zeros(1,numel(data_buffer.headfile.('rad_mat_option_output_order')));
for d_num=1:numel(data_buffer.headfile.('rad_mat_option_output_order'))
    output_dimensions(d_num)=d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(d_num));
end

%% reformat/reshape/regrid
if( ~regexp(data_buffer.headfile.([data_tag 'vol_type']),'radial'))
    %% cartesian (literally all non-radial, if other sequences come up we'll have to deal)
    permute_code=zeros(size(dim_order));
    for d_num=1:length(dim_order)
        permute_code(d_num)=strfind(dim_order,output_order(d_num));
    end
    
    % dimension order should be set in the headfile by the dumpheader perl
    % function.
    % dim_placement=data_buffer.input_headfile.permute_code;
    %xcprzyt
    d_struct.y=d_struct.y/d_struct.r;
    input_dimensions=zeros(size(dim_order));
    for d_num=1:numel(dim_order)
        input_dimensions(d_num)=d_struct.(dim_order(d_num));
    end
    % these two lines are unnecessary so long as we dont try to use the
    % dimension struct again in this function. They are here to make sure
    % that should the function be expanded d_struct has accurate contents.
    d_struct.y=d_struct.y*d_struct.r;
    d_struct.r=1;

%%%   this code was moved to the generic part before we decide to branch for cartesian or radial

%     output_dimensions=zeros(1,numel(data_buffer.headfile.('rad_mat_option_output_order')));
%     for d_num=1:numel(data_buffer.headfile.('rad_mat_option_output_order'))
%         output_dimensions(d_num)=d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(d_num));
%     end
    
    %  THIS CODE WORKS< USE IT AS A TEST.
    % data_buffer.data=reshape(backup,[240,4,1,8,108,20,1]); %x c r z y/r  1 2 3 4 5
    % data_perm1423=permute(data_buffer.data,[1 4 5 6 3 2 7]);
    % data_perm1423=reshape(data_perm1423,[240 160 108 4]);
    % for i=1:108
    %     imagesc(abs(squeeze(data_perm1423(:,:,i,1))));
    %     pause(0.25);
    % end
    
    
    fprintf('Regriding/Reshaping :');
    % resort data in logical order instead of interleaved.
    
    % if d_struct.r>1
    %     data_buffer.data=reshape(data_buffer.data,input_dimensions_with_rare);
    %     data_buffer.data=permute(data_buffer.data,permute_code_with_rare);
    % else
    data_buffer.data=reshape(data_buffer.data,input_dimensions);
    data_buffer.data=permute(data_buffer.data,permute_code ); % put in image order.
    % end
    data_buffer.data=reshape(data_buffer.data,output_dimensions);% x yr z c
    
    if isfield(data_buffer.input_headfile,'dim_X_encoding_order')
        fprintf('Found X encoding order\n');
        xenc=data_buffer.input_headfile.dim_X_encoding_order;
        xenc=xenc+min(xenc)+1;
    else
        xenc=':';
    end
    if isfield(data_buffer.input_headfile,'dim_Y_encoding_order')
        fprintf('Found Y encoding order\n');
        yenc=data_buffer.input_headfile.dim_Y_encoding_order;
        yenc=yenc-min(yenc)+1;
    else
        yenc=':';
    end
    if isfield(data_buffer.input_headfile,'dim_Z_encoding_order')
        fprintf('Found Z encoding order\n');
        zenc=data_buffer.input_headfile.dim_Z_encoding_order;
        zenc=zenc-min(zenc)+1;
    else
        zenc=':';
    end
    data_buffer.data(xenc,yenc,zenc,:,:,:)=data_buffer.data;
else
    %% radial regridding.
    warning('Radial regridding! Still very experimental.')
        
    data_buffer.addprop('radial');
    oversample_factor=3;
    if isfield('rad_mat_option_grid_oversample_factor',data_buffer.headfile)
        fprintf('Using headfile oversampling of ');
        oversample_factor=data_buffer.headfile.rad_mat_option_grid_oversample_factor;
    else
        fprintf('Using default oversampling of ');
        data_buffer.headfile.rad_mat_option_grid_oversample_factor=oversample_factor;
    end
    fprintf('%d.\n',oversample_factor);
    
    data_buffer.radial=data_buffer.data;
    %moving data to radial is separated from the reshaping command to avoid copy on write
    data_buffer.radial=reshape(data_buffer.radial,...
        [data_buffer.headfile.ray_length,...
        d_struct.c,...
        data_buffer.headfile.rays_per_block*data_buffer.headfile.ray_blocks]);
    data_buffer.data=[];
    %%% for each vol?  do regrid?
    %%% 
    % traj and dcf are shaped into keys. 
    %re-grid per channel per key?
    %%% The whole re-gridding process might be avertable by useing static
    %%% trajectory, dcf and transforms. Presumably for a given acquisition
    %%% format we could pre-calculate the dcf, and then the transormation
    %%% matrix and use some other software(perhaps ANTS) to apply that
    %%% transoform.

    %%% must convert data to double precision 2 part vector from complex before
    %%% grid3_MAT
    %%% example
    % kspace_d=[kspace_r;kspace_i];
    % kspace_data2=reshape(kspace_d,[64,2,4,25740]);
    % kspace_data2=permute(kspace_data2,[2,1,3,4]);
    data_buffer.radial=[real(data_buffer.radial);imag(data_buffer.radial)];
    data_buffer.radial=reshape(data_buffer.radial, ...
        [data_buffer.headfile.ray_length,...
        2,...  % two part complex.
        d_struct.c,...
        d_struct.p,...
        data_buffer.headfile.rays_per_block,...
        data_buffer.headfile.ray_blocks]);
    %%% modify permute to account for n volumes as well....
    % working in complex,raylength,rays_perkey,channels,keys
    data_buffer.radial=permute(data_buffer.radial,[2,1,5,6,3,4]);
    % probably will end up in xyzKcp
%     crop_index_s=d_struct.x*oversample_factor-d_struct.x;
%     crop_index_e=d_struct.x*oversample_factor-2*d_struct.x;
%%% guess matlabpool size based on floor( mem avail/mem required)
    if matlabpool('size')==0 && data_buffer.headfile.rad_mat_option_matlab_parallel
        try
            matlabpool local 12
        catch err
            err_m=[err.message ];
            for e=1:length(err.stack)
                err_m=sprintf('%s\n \t%s:%i',err_m,err.stack(e).name,err.stack(e).line);
            end
            warning('Matlab pool failed to open with message, %s',err_m);
        end
    end
    fprintf('Prealocate output data\n');
    data=zeros([ oversample_factor*d_struct.x,oversample_factor*d_struct.x,oversample_factor*d_struct.x output_dimensions(4:end-1)],'single');
    data=complex(data,data);
    clear e err err_m;
    %     if ~data_buffer.headfile.('rad_mat_option_skip_combine_channels')
    %% window selective regrid 
    data_buffer.trajectory=reshape(data_buffer.trajectory,[3,data_buffer.headfile.ray_length,...
        data_buffer.headfile.rays_per_block,...
        data_buffer.headfile.ray_blocks_per_volume]);
    %jrKRcp
    dims=size(data);
    rdims=size(data_buffer.radial);
    if numel(size(data))>3
        data=reshape(data,[dims(1:3) prod(dims(4:end))]);

    end
    if numel(rdims>=5)
        data_buffer.radial=reshape(data_buffer.radial,[rdims(1:4)  prod(rdims(5:end))]);
    end
    for time_pt=1:d_struct.t
        %data_buffer.headfile.ray_blocks-(data_buffer.headfile.ray_blocks_per_volume-1)
        % need to put in variable freq cutoff here using mask method. will
        % multiply radial/traj/dcf by freq mask to get desired effect.
        startindex=data_buffer.headfile.ray_blocks_per_volume*(time_pt-1)+1;
        endindex  =data_buffer.headfile.ray_blocks_per_volume*(time_pt-1)+data_buffer.headfile.ray_blocks_per_volume;
        radial=data_buffer.radial(:,:,:,startindex:endindex,:); % currently  [r,i] x ray_length x rays_per_key x keys x channel x parameters 
        traj=  circshift(data_buffer.trajectory,[0 0 0 mod(time_pt,data_buffer.headfile.ray_blocks_per_volume)-1]); 
        dcf=   circshift(data_buffer.dcf,       [0 0 0 mod(time_pt,data_buffer.headfile.ray_blocks_per_volume)-1]);
        %
        if true % always use the sepearate channel code, have to investigate how channel combining works out.
            fprintf('Start Grid per channel\n');
            %             serial_process=true;
            %             if ~serial_process
            %                 fprintf('Parallel loop for regrid.');
            %                 parfor v=1:size(data_buffer.radial,5)
            %                     temp=...
            %                         grid3_MAT(double(radial(:,:,:,v)),...
            %                         traj,...
            %                         dcf,oversample_factor*d_struct.x,0);
            %                     % [s,e]=center_crop(oversample_factor*d_struct.x,d_struct.x);
            %                     % data(:,:,:,c_num,lnum1,lnum2)=complex(temp(1,s:e,s:e,s:e),temp(2,s:e,s:e,s:e));
            %                     data(:,:,:,v)=complex(single(temp(1,:,:,:)),single(temp(2,:,:,:)));
            %                 end
            %             else
            fprintf('Serial loop for regrid.\n');
            rd=size(radial);
%             Vt=d_struct.c*d_struct.p;
            for v=1:d_struct.c*d_struct.p
                temp=...
                    grid3_MAT(double(reshape(squeeze(radial(:,:,:,:,v)),[rd(1:2),rd(3)*rd(4)])),...
                    reshape(traj,[3,rd(2),rd(3)*rd(4)]),...
                    reshape(dcf,[rd(2),rd(3)*rd(4)]),oversample_factor*d_struct.x,8);
                data(:,:,:,v)=complex(single(temp(1,:,:,:)),single(temp(2,:,:,:)));
%                 data(:,:,:,v+(time_pt-1)*d_struct.c*d_struct.p)=complex(single(temp(1,:,:,:)),single(temp(2,:,:,:)));
                %1:vt
                % time_pt time_pt*
                % vt:2vt
                % 
            end
            if d_struct.t>1
                data=reshape(data,dims);
                save(['/tmp/temp_' num2str(time_pt) '.mat' ],'data','-v7.3');
            end
            %             end
%             data_buffer.data=data;
%             clear s e temp traj dcf radial data;
        else
            %%% experimental pass extra data to the re-gridder by duplicating
            %%% trajectory and dcf.
            % pushed above data_buffer.radial=reshape([real(data_buffer.radial);imag(data_buffer.radial)],[2,size(data_buffer.radial)]);
            %         data=zeros(output_dimensions,'single');
            traj=zeros(1,numel(data_buffer.trajectory)*d_struct.c);
            traj=reshape(traj,[3,data_buffer.headfile.ray_length,d_struct.c,data_buffer.headfile.rays_per_block*data_buffer.headfile.ray_blocks]);
            %             traj=data_buffer.trajectory;
            for c_num=1:d_struct.c-1
                traj(:,:,c_num,:)=data_buffer.trajectory;
            end
            dcf=zeros(1,numel(data_buffer.dcf)*d_struct.c);
            dcf=reshape(dcf,[data_buffer.headfile.ray_length,d_struct.c,data_buffer.headfile.rays_per_block*data_buffer.headfile.ray_blocks]);
            for c_num=1:d_struct.c-1
                dcf(:,c_num,:)=data_buffer.dcf;
            end
            for lnum1=1:d_struct.(output_order_init(5))
                for lnum2=1:d_struct.(output_order_init(6))
                    temp=...
                        grid3_MAT(double(data_buffer.radial),...
                        traj,...
                        dcf,oversample_factor*data_buffer.headfile.ray_length*2,8);
                    %                     t_dims=size(temp);
                    %                     r=temp(1,:,:,:);
                    %                     i=temp(2,:,:,:);
                    %                     data_buffer.data(:,:,:,1,lnum1,lnum2)=complex(r,i);
                    % [s,e]=center_crop(oversample_factor*d_struct.x,d_struct.x);
                    % data(:,:,:,c_num,lnum1,lnum2)=complex(temp(1,s:e,s:e,s:e),temp(2,s:e,s:e,s:e));
                    data(:,:,:,1,lnum1,lnum2)=complex(temp(1,:,:,:),temp(2,:,:,:));
                    clear temp;
                end
            end
            data_buffer.data=data;
            clear traj dcf radial data;
        end
    end
    %%% because of reasons we have to permute back on radial scans.
    %%% xyztcp  123564
    data_buffer.data=data;
    data_buffer.data=permute(data_buffer.data,[1,2,3,5,6,4]);

end
%% per scanner cleanup, currently no scanner specific code.
if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    fprintf('Bruker');
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
    fprintf('Aspect');
%     
% d=reshape(data_buffer.data, [306 128*64]);
%     it=zeros(256,128,64);
%     for i=1:64
%         it(:,:,i)=fftshift(ifft2(fftshift(d(51:end,i:64:end))));%figure(6);imagesc(log(abs(it(:,:,i))));
%         %pause(0.18);
%     end
%     
%     z=size(it,3);
%     objlist=[1:z/2; z/2+1:z];
%     objlist=objlist(:);
%     
%     it=it(:,:,objlist);
%     
%     for i=1:64
%         figure(6);
%         imagesc(log(abs(it(:,:,i))));
%         pause(0.18);
%     end
%     
%     y=size(it,2);
%     objlist=[y/2+1:y 1:y/2];
%     it2=it(:,objlist,:);
%     
%     for i=1:64
%         figure(6);
%         imagesc(log(abs(it2(:,:,i))));
%         pause(0.18);
%     end
else
    warning('Not bruker and Not Aspect no regid yet.');
end
fprintf('\n');