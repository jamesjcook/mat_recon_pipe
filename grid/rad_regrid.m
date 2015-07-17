function rad_regrid(data_buffer,c_dims)
% function to turn sampled points into their cartesian grid equivalent.
% when cartesian its just a reshape operation.
%

% dimension order is generally xcpzyt might depend on scanner,
%                           or xcpyzt
% channels might be reversed
% c=channels,
% p=echoes,(could also be alphas?)
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
if regexpi(varying_parameter,'.*echo.*')% strcmp(varying_parameter,'echos') || strcmp(varying_parameter,'echoes')
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
if numel(c_dims)<numel(dim_order)
    dim_order=c_dims;
end
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

% if numel(dim_order)<numel(output_order)
%     for d_num=1:length(output_order)
%         dpos=strfind(dim_order,output_order(d_num));
%         if isempty(dpos)
%             dim_order(end+1)=output_order(d_num);
%         end
%     end
% end
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
if( ~strcmp(data_buffer.headfile.([data_tag 'vol_type']),'radial'))
% if( regexp(data_buffer.headfile.([data_tag 'vol_type']),'2D|3D|4D'))
    %% cartesian (literally all non-radial, if other sequences come up we'll have to deal)
%     permute_mask=zeros(size(dim_order));
%     for d_num=1:length(dim_order)
%         %     for d_num=1:length(c_dims)
%         dpos=strfind(output_order,dim_order(d_num));
% %         dpos=strfind(dim_order,output_order(d_num));
%         if ~isempty(dpos)
%             permute_code(d_num)=dpos;
%         end
%     end
%     
%     
permute_code=[];
    for d_num=1:length(output_order)
        %     for d_num=1:length(c_dims)
        dpos=strfind(dim_order,output_order(d_num));
%         dpos=strfind(dim_order,output_order(d_num));
        if ~isempty(dpos)
            permute_code(end+1)=dpos;
        end
    end
%     permute_code(permute_code==0)=[];
    
    
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
    if numel(data_buffer.data)~=prod(input_dimensions)
        [l,n,f]=get_dbline('rad_regrid');
        eval(sprintf('dbstop in %s at %d',f,l+3));
        warning('YOUR RECON WILL NOT COMPLETE PROPERLY GET JAMES RIGHT NOW. YOU HAVE BEEN PUT INTO DEBUG MODE TO SOLVE THE PROBLEM ON THE FLY.');
    end
    data_buffer.data=reshape(data_buffer.data,input_dimensions);
    data_buffer.data=permute(data_buffer.data,permute_code ); % put in image order(or at least in fft order).
    % end
    
    %following reshape is what remove rare facor dimension
        data_buffer.data=reshape(data_buffer.data,output_dimensions(1:numel(c_dims)));% x yr z c
    %%%%%
    %%%%%
    %squeeze data, might cause issues!
    data_buffer.data=squeeze(data_buffer.data);
    output_order_init=output_order;
    output_order=char(zeros(1,numel(size(data_buffer.data))));
    end_dims=char(zeros(1,numel(output_order_init)-numel(output_order)));
    edc=1;%end dim counter
    odc=1;%extra dim counter
    for d_num=1:numel(output_order_init)
        if d_struct.(output_order_init(d_num)) ~= 1
            output_order(odc)=output_order_init(d_num);
            odc=odc+1;
        else
            end_dims(edc)=output_order_init(d_num);
            edc=edc+1;
        end
    end
    output_order=[output_order, end_dims];
    %%%%%
    
    encoding_sort=false;
    es_f={'X','Y','Z'};
    for es_n=1:length(es_f) % foreach encoding X Y Z
        eid=es_f{es_n}; %encoding letter.
        if isfield(data_buffer.input_headfile,['dim_' eid '_encoding_order'])
            fprintf('Found %s encoding order\n',eid);
            enc.(eid)=data_buffer.input_headfile.(['dim_' eid '_encoding_order']);
            enc.(eid)=enc.(eid)-min(enc.(eid))+1;
            if ~seqtest(enc.(eid))
                warning('ENCODING BANDAID IN EFFECT, ENCODING FOR %s, SPECIFIED BUT SEQUENTIAL, IT WILL BE IGNORED!',eid);
                encoding_sort=true;
            end
        else
            enc.(eid)=':';
        end
    end
    if exist('barkeala','var')
        if isfield(data_buffer.input_headfile,'dim_X_encoding_order')
            fprintf('Found X encoding order\n');
            xenc=data_buffer.input_headfile.dim_X_encoding_order;
            xenc=xenc+min(xenc)+1;
            if ~seqtest(xenc)
                warning('ENCODING BANDAID IN EFFECT, ENCODING %s,SPECIFIED BUT SEQUENTIAL, SO IT WAS IGNORED!',enc.(eid));
                encoding_sort=true;
            end
        else
            xenc=':';
        end
        if isfield(data_buffer.input_headfile,'dim_Y_encoding_order')
            fprintf('Found Y encoding order\n');
            yenc=data_buffer.input_headfile.dim_Y_encoding_order;
            yenc=yenc-min(yenc)+1;
            if ~seqtest(yenc)
                warning('ENCODING BANDAID IN EFFECT, ENCODING %s,SPECIFIED BUT SEQUENTIAL, SO IT WAS IGNORED!',enc.(eid));
                encoding_sort=true;
            end
        else
            yenc=':';
        end
        if isfield(data_buffer.input_headfile,'dim_Z_encoding_order')
            fprintf('Found Z encoding order\n');
            zenc=data_buffer.input_headfile.dim_Z_encoding_order;
            zenc=zenc-min(zenc)+1;
            if ~seqtest(zenc)
                encoding_sort=true;
            end
        else
            zenc=':';
        end
    end
    if encoding_sort
        data_buffer.data(enc.X,enc.Y,enc.Z,:,:,:)=data_buffer.data;
    end
else
    %% radial regridding.
    warning('Radial regridding! Still very experimental.')
    
    oversample_factor=3;
    if isfield(data_buffer.headfile,'radial_grid_oversample_factor')
        fprintf('Using oversampling of ');
        oversample_factor=data_buffer.headfile.radial_grid_oversample_factor;
    else
        fprintf('Using regrid function default oversampling of ');
        data_buffer.headfile.radial_grid_oversample_factor=oversample_factor;
    end
    fprintf('%d.\n',oversample_factor);
    
    % could do an isfield test as well and then set som bool to allow for
    % struct.
    if ~isprop(data_buffer,'radial')
        data_buffer.addprop('radial');
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
    end

    % probably will end up in xyzKcp
%     crop_index_s=d_struct.x*oversample_factor-d_struct.x;
%     crop_index_e=d_struct.x*oversample_factor-2*d_struct.x;
%%% guess matlabpool size based on floor( mem avail/mem required)
    if matlabpool('size')==0 && data_buffer.headfile.rad_mat_option_matlab_parallel
        matlab_pool_size=d_struct.c;
        try
            matlabpool('local',matlab_pool_size)
        catch err
            err_m=[err.message ];
            for e=1:length(err.stack)
                err_m=sprintf('%s\n \t%s:%i',err_m,err.stack(e).name,err.stack(e).line);
            end
            warning('Matlab pool failed to open with message, %s',err_m);
        end
    end
    %%% we need an oversample space to work in to prevent re-allocating all
    %%% the time
    if isfield(data_buffer.headfile,'processing_chunk')
        t_s=data_buffer.headfile.processing_chunk;
        t_e=data_buffer.headfile.processing_chunk;
        do_not_process_time=1;
    else
        t_s=1;
        t_e=d_struct.t;
        do_not_process_time=0;
    end
    if oversample_factor==1
        output_field='data';
    else
        output_field='kspace';
        if ~isprop(data_buffer,'kspace')
            data_buffer.addprop('kspace');
            fprintf('Prealocate regrid data\n');
            if ~strcmp(data_buffer.headfile.rad_mat_option_combine_method,'regrid')
                data_buffer.(output_field)=complex(zeros([ oversample_factor*d_struct.x,oversample_factor*d_struct.x,oversample_factor*d_struct.x output_dimensions(4:end-do_not_process_time)],'single'));
            else
                %%% double checked this, i've got this if condition
                %%% correct. We're skipping the channel dimension.
                data_buffer.(output_field)=complex(zeros([ oversample_factor*d_struct.x,oversample_factor*d_struct.x,oversample_factor*d_struct.x output_dimensions(5:end-do_not_process_time)],'single'));
            end
        end

    end
    
    % if ~isprop(data_buffer,'kspace')
    %     data=zeros([ oversample_factor*d_struct.x,oversample_factor*d_struct.x,oversample_factor*d_struct.x output_dimensions(4:end-1)],'single');
    %     data=complex(data,data);
    
    % data_buffer.addprop('oversample_space');
    % data_buffer.oversample_space=data;
    % else
    % 
    % end
    clear e err err_m;
    %     if ~data_buffer.headfile.('rad_mat_option_skip_combine_channels')
    %% window selective regrid 
    data_buffer.trajectory=reshape(data_buffer.trajectory,[3,data_buffer.headfile.ray_length,...
        data_buffer.headfile.rays_per_block,...
        data_buffer.headfile.ray_blocks_per_volume]);
    %jrKRcp
    dims=size(data_buffer.(output_field));
    rdims=size(data_buffer.radial);
    if numel(size(data_buffer.(output_field)))>3
        data_buffer.(output_field)=reshape(data_buffer.(output_field),[dims(1:3) prod(dims(4:end))]);

    end
    if numel(rdims>=5)
        data_buffer.radial=reshape(data_buffer.radial,[rdims(1:4)  prod(rdims(5:end))]);
    end

    % for time_pt=1:d_struct.t
    for time_pt=t_s:t_e
        %data_buffer.headfile.ray_blocks-(data_buffer.headfile.ray_blocks_per_volume-1)
        % need to put in variable freq cutoff here using mask method. will
        % multiply radial/traj/dcf by freq mask to get desired effect.
        if time_pt==2
            disp('break_point');
        end
%         index_start=data_buffer.headfile.ray_blocks_per_volume*(time_pt-1)+1;
%         index_end  =data_buffer.headfile.ray_blocks_per_volume*(time_pt-1)+data_buffer.headfile.ray_blocks_per_volume;
        index_start=time_pt-(floor(data_buffer.headfile.ray_blocks_per_volume/2));
        index_end  =(index_start-1)+data_buffer.headfile.ray_blocks_per_volume;
        %%% move the frequency filter for the first and last timepoints where we dont
        %%% have enough data for centered reconstruction yet
        %%% all data is saved centered, so complete data is the first key.
        % if index_start< ceil(data_buffer.headfile.ray_blocks_per_volume/2)
        if index_start < 1
            index_start=1;
            index_end=(index_start-1)+data_buffer.headfile.ray_blocks_per_volume;
            f_filter=circshift(data_buffer.cutoff_filter,[0 0 index_start-ceil(data_buffer.headfile.ray_blocks_per_volume/2)]);
            dcf=   circshift(data_buffer.dcf,       [0 0 floor(data_buffer.headfile.ray_blocks_per_volume/2)-mod(time_pt,data_buffer.headfile.ray_blocks_per_volume)+1]);
        elseif index_end > size(data_buffer.radial,4)
            f_filter=circshift(data_buffer.cutoff_filter,[0 0 index_end-size(data_buffer.radial,4)]);
            index_end=size(data_buffer.radial,4);
            index_start=size(data_buffer.radial,4)-(data_buffer.headfile.ray_blocks_per_volume-1);
            dcf=   circshift(data_buffer.dcf,       [0 0 mod(time_pt,data_buffer.headfile.ray_blocks_per_volume)]);
        else
            dcf=data_buffer.dcf;
            f_filter=data_buffer.cutoff_filter;
        end

        radial=data_buffer.radial(:,:,:,index_start:index_end,:); % currently  [r,i] x ray_length x rays_per_key x keys x timepoints x channel x parameters (and p is normall 1)
%         traj=  circshift(data_buffer.trajectory,[0 0 0 mod(time_pt,data_buffer.headfile.ray_blocks_per_volume)-1]); 
%         dcf=   circshift(data_buffer.dcf,       [0 0 0 mod(time_pt,data_buffer.headfile.ray_blocks_per_volume)-1]);
        traj=  circshift(data_buffer.trajectory,[0 0 0 -mod(index_start,data_buffer.headfile.ray_blocks_per_volume)+1]);
%         f_filter=circshift(data_buffer.cutoff_filter,[ 0 0 -mod(time_pt,data_buffer.headfile.ray_blocks_per_volume)+1]);

        %%%%
%         %% apply cutoff filter
        %         nyquist_cutoff
        % later this should be improved to remove these points.
%         for r_c=1:size(radial,1)
%             for t_num=1:size(radial,5)
%2 
%                 temp=squeeze(radial(r_c,:,:,:,t_num));
%                 temp(f_filter==0)=NaN;
%                 radial(r_c,:,:,:,t_num)=temp;
%1
%                 radial(r_c,:,:,:,t_num)=squeeze(radial(r_c,:,:,:,t_num)).*f_filter
%             end
%         end
%         for t_num=1:size(traj,1)
            %1
            % traj(t_num,:,:,:,:)=squeeze(traj(t_num,:,:,:,:)).*f_filter;
%2             
%             temp=squeeze(traj(t_num,:,:,:,:));
%             temp(f_filter==0)=[];
%             traj(t_num,:,:,:,:)=temp;
%         end
%         dcf=dcf.*f_filter;
%         dcf(f_filter==0)=[];
        
        process_volumes=d_struct.c*d_struct.p;  %%%%  *(t_e-t_s+1)
        %%
        if strcmp(data_buffer.headfile.rad_mat_option_combine_method,'regrid')
            %%%% make traj/dcf longer by n channels
            % could probably be made cleaner but this should work.
            process_volumes=process_volumes/d_struct.c;
            ts=size(traj);
            traj=repmat(data_buffer.trajectory,ones(1, numel(ts(1:end-1))),d_struct.c);
            ds=size(dcf);
            dcf=repmat(data_buffer.dcf,ones(numel(ds(1:end-1))),d_struct.c );
            rs=size(radial);
            radial=reshape(radial,[rs(1:3), rs(4)*d_struct.c,d_struct.p]);
            clear ts ds rs;
        end

        %% do regrid
        if true % always use the sepearate channel code, have to investigate how channel combining works out.
            fprintf('Start Grid per channel\n');

            fprintf('Serial loop for regrid.\n');
            d_r=size(radial);
            d_t=size(traj);
            d_d=size(dcf);
            % Vt=d_struct.c*d_struct.p;
            holding_zone=data_buffer.(output_field);
            data_buffer.(output_field)=[];
            % perhaps an ungly eval could be used to parfor at the channel
            % level or some others...
            % radial(repmat(size(radial,1),f_filter)=[];
            % repmat(data_buffer.dcf,ones(numel(ds(1:end-1))),d_struct.c
%             rf=zeros(size(radial));
            
%             f_r=repmat(f_filter,[d_r(1),d_r(5)]);% 128,7920,13 =>  [64,2,1920,4,13];
            f_r=repmat(f_filter,[2,1,1, d_r(5:end)]);% 128,1980,13,4
            f_r=reshape(f_r,[d_r(2),2,d_r(3)*d_r(4),d_r(5:end)]);
            f_r=permute(f_r,[2,1,3,4,5]);
            radial=reshape(radial,[d_r(1:2),d_r(3)*d_r(4),d_r(5:end)]);
            radial(f_r==0)=[];
            alenght=numel(radial)/2/d_r(5:end);
            
            radial=reshape(radial,[2,alenght,d_r(5:end)]);
            clear f_r;

            time_cd=time_pt;
            if  t_s==t_e
                time_cd=1;
            elseif t_s>1
                warning('t_s over 1 but not equal to t_e never tested!');
                time_cd=time_cd-(t_s-1);
            end

            %%% process one timepoint worth of data.            
            for v=1:process_volumes
                temp=...
                    grid3_MAT(double(radial(:,:,v)),...
                    traj,...
                    dcf,oversample_factor*d_struct.x,8);
                %(:,:,:,:,time_cd)=(time_cd-1)
                %time_pt 1, v1-2, time_pt 2, v3-4, time_pt3, 5-6, time_pt 4, 7-8
                %1 v
                %(pv*(tp-1))+v
                hz_idx=v+(time_cd-1)*process_volumes;
                holding_zone(:,:,:,hz_idx)=complex(single(temp(1,:,:,:)),single(temp(2,:,:,:)));
%                 imagesc(log(abs(holding_zone(:,:,192,v))))
            end
            %%% handle time timefoollery in case we did a range of
            %%% timepoints, or just one that wasnt the first.

            data_buffer.(output_field)=holding_zone;
            clear holding_zone hz_idx;

        else
            %% 
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
                    data_buffer.(output_field)(:,:,:,1,lnum1,lnum2)=complex(temp(1,:,:,:),temp(2,:,:,:));
                    clear temp;
                end
            end
            data_buffer.data=data;
            clear traj dcf radial data;
        end
    end
    %%% because of reasons we have to permute back on radial scans.
    %%% xyztcp  123564
    data_buffer.(output_field)=reshape(data_buffer.(output_field),dims);
    data_buffer.(output_field)=permute(data_buffer.(output_field),[1,2,3,5,6,4]);
%     if oversample_factor~=1
%         data_buffer.kspace=re_gridded_data;
%     else
%         data_buffer.data=re_gridded_data;
%         data_buffer.data=re_gridded_data;
%     end
    

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
end

function [status,c,d]=seqtest(q)
status=0;
a=diff(q);

b=find([a inf]>1);

c=diff([0 b]);% length of the sequences
if numel(c)==1 && c==length(q)
    status=1;
end

d=cumsum(c);% endpoints of the sequences
end
