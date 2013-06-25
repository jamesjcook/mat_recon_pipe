function rad_regid(data_buffer,c_dims)
% function to turn sampled points into their cartesian grid equivalent.
% when cartesian its just a simple reshape operation.
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
if  isfield (data_buffer.input_headfile,[data_tag 'rare_factor'])
    r=data_buffer.input_headfile.([data_tag 'rare_factor']);
else
    r=1;
end

dim_order=data_buffer.input_headfile.([data_tag 'dimension_order' ]);
% strfind(opt_struct.output_order(1),dim_order)


d_struct=struct;
d_struct.r=r;
d_struct.x=x;
d_struct.y=y;
d_struct.z=z;
dind=strfind(dim_order,'y'); % get dimension index after which to place the r dim.


permute_code=zeros(size(dim_order));
for char=1:length(dim_order)
    permute_code(char)=strfind(dim_order,data_buffer.headfile.('rad_mat_option_output_order')(char));
end

d_struct.c=channels;
d_struct.p=params;
d_struct.t=timepoints;

% dimension order should be set in the headfile by the dumpheader perl
% function. 
% dim_placement=data_buffer.input_headfile.permute_code;
%xcprzyt
input_dimensions=[d_struct.(dim_order(1)) d_struct.(dim_order(2))...
    d_struct.(dim_order(3)) d_struct.(dim_order(4))...
    d_struct.(dim_order(5)) d_struct.(dim_order(6))];
input_dimensions_with_rare=input_dimensions;
input_dimensions_with_rare(dind)=input_dimensions_with_rare(dind)/d_struct.r;
input_dimensions_with_rare=[input_dimensions_with_rare(1:2)...
    d_struct.r...
    input_dimensions_with_rare(3:end)];
if d_struct.r>1
    permute_code_with_rare=permute_code;
    permute_code_with_rare(permute_code_with_rare>2)=permute_code_with_rare(permute_code_with_rare>2)+1;
    permute_code_with_rare=[permute_code_with_rare(1:2) 3 permute_code_with_rare(3:end)];
end
output_dimensions=[...
    d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(1))...
    d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(2))...
    d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(3))...
    d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(4))...
    d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(5))...
    d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(6))];

%  THIS CODE WORKS< USE IT AS A TEST. 
% data_buffer.data=reshape(backup,[240,4,1,8,108,20,1]); %x c r z y/r  1 2 3 4 5
% data_perm1423=permute(data_buffer.data,[1 4 5 6 3 2 7]);
% data_perm1423=reshape(data_perm1423,[240 160 108 4]);
% for i=1:108
%     imagesc(abs(squeeze(data_perm1423(:,:,i,1))));
%     pause(0.25);
% end


fprintf('Regriding/Reshaping :');
if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
    fprintf('Bruker');
    % resort data in logical order instead of interleaved.
    % permute might need to be left until our 3dft's are done.
    %     acq=false;
    if d_struct.r>1
        data_buffer.data=reshape(data_buffer.data,input_dimensions_with_rare);
        data_buffer.data=permute(data_buffer.data,permute_code_with_rare);
    else
        data_buffer.data=reshape(data_buffer.data,input_dimensions);
        data_buffer.data=permute(data_buffer.data,permute_code ); % put in image order.
    end
    data_buffer.data=reshape(data_buffer.data,output_dimensions);% x yr z c

    
    %% handle encoding order swaps
    %%% old way
    %     objlist_name=[data_buffer.input_headfile.U_prefix 'PVM_ObjOrderList'];% belongs to z dim.
    %     objlist=data_buffer.input_headfile.(objlist_name);
    %     if length(objlist)<d_struct.z
    %         warning('objlist was not defind, trying %s%s',data_tag,'encoding_order');
    %         objlist_name=[data_tag 'encoding_order'];% belongs to z dim.
    %         objlist=data_buffer.input_headfile.(objlist_name);
    %     end
    %     while min(objlist)<1
    % %         fprintf('%i  \n',objlist+1);
    %         objlist=objlist+1;
    % %         pause(0.1);
    %     end
    %     if length(objlist)==d_struct.z
    %         try
    %             data_buffer.data(:,:,objlist+1,:,:,:)=data_buffer.data;
    %         catch err
    %             disp(err);
    %             error(err.identifier);
    %         end
    %     else
    %         warning('Object list not used for dataset.');
    %         pause(data_buffer.headfile.rad_mat_option_warning_pause);
    %     end
    %%% new way gets info from headfile.
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
    
%     data_buffer.data=padarray(data_buffer.data,[0 2 0 0 0 0],0 );
    
%     if strcmp(data_buffer.input_headfile.([data_tag 'vol_type']),'2D') %xcrzy
%         objlist_name=[data_buffer.input_headfile.U_prefix 'ACQ_obj_order'];
%         objlist=data_buffer.input_headfile.(objlist_name);
%         data_buffer.data(:,:,objlist+1,:,:,:,:)=data_buffer.data;
%         
%     elseif strcmp(data_buffer.input_headfile.([data_tag 'vol_type']),'3D')%xcryz
%         data_buffer.data=reshape(data_buffer.data,input_dimensions );
%         objlist_name=[data_buffer.input_headfile.U_prefix 'PVM_ObjOrderList'];% belongs to z dim.
%         objlist=data_buffer.input_headfile.(objlist_name);
%         data_buffer.data(:,:,objlist+1,:,:,:)=data_buffer.data;
% 
%     end
    %     else
    %         data_buffer.data=reshape(data_buffer.data,dimensions);
    %         data_buffer.data=permute(data_buffer.data,permute_code );
    %     end
    
    % [ x y z c p t ]
    
    % maybe we should squeeze....
    % if not cartesian
    % error('never done any real regridding');
elseif strcmp(data_buffer.scanner_constants.scanner_vendor,'aspect')
    fprintf('Aspect');
     %[ x z y ] 
    data_buffer.data=reshape(data_buffer.data,[ x z y ] );
    %%% this resorting code doesnt do what is expected, it is disabled for
    %%% now. Perhaps i cant resort prior to fft for 3D volumes? 
%     objlist=[((z/2)+1):z  1:(z/2) ];
%     data_buffer.data(:,objlist,:)=data_buffer.data;
%     data_buffer.data=permute(data_buffer.data,[ 1 3 2 ]);
else
    warning('Not bruker and Not Aspect no regid yet.');
end
fprintf('\n');