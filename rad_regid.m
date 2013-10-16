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
dim_order=data_buffer.input_headfile.([data_tag 'dimension_order' ]);
if  isfield (data_buffer.input_headfile,[data_tag 'rare_factor'])
    r=data_buffer.input_headfile.([data_tag 'rare_factor']);
    report_order=data_buffer.input_headfile.([data_tag 'axis_report_order']);
    dim_order_init=dim_order;
    dim_order=char(zeros(1,numel(dim_order_init)+1));
    output_order_init=data_buffer.headfile.('rad_mat_option_output_order');
    output_order=char(zeros(1,numel(output_order_init)+1));
    for d_num=1:numel(dim_order_init)
        dim_order(d_num)=dim_order_init(d_num);
        output_order(d_num)=output_order_init(d_num);
        if strcmp(dim_order_init(d_num),'c')
%         if strcmp(dim_order_init(d_num),'y')
            dim_order(d_num+1)='r';
            dim_order(d_num+2:d_num+2+numel(dim_order_init(d_num+1:end))-1)=dim_order_init(d_num+1:end);
            output_order(d_num+1)='r';
            output_order(d_num+2:d_num+2+numel(output_order_init(d_num+1:end))-1)=output_order_init(d_num+1:end);
            break
        end
    end
%     dim_order=%[y|x]cr[y/r|x/r]pzt
%     permute_code=zeros(size(dim_order));
%     for char=1:length(dim_order)
%         permute_code(char)=strfind(dim_order,data_buffer.headfile.('rad_mat_option_output_order')(char));
%     end
    
else
    r=1;
    output_order=data_buffer.headfile.('rad_mat_option_output_order');
end

% strfind(opt_struct.output_order(1),dim_order)


d_struct=struct;
d_struct.r=r;
d_struct.x=x;
d_struct.y=y;
d_struct.z=z;
% dind=strfind(dim_order,'y'); % get dimension index after which to place the r dim.


permute_code=zeros(size(dim_order));
for d_num=1:length(dim_order)
    permute_code(d_num)=strfind(dim_order,output_order(d_num));
end

d_struct.c=channels;
d_struct.p=params;
d_struct.t=timepoints;

% dimension order should be set in the headfile by the dumpheader perl
% function. 
% dim_placement=data_buffer.input_headfile.permute_code;
%xcprzyt
d_struct.y=d_struct.y/d_struct.r;
input_dimensions=zeros(size(dim_order));
for d_num=1:numel(dim_order)
    input_dimensions(d_num)=d_struct.(dim_order(d_num));
end
% input_dimensions=[d_struct.(dim_order(1)) d_struct.(dim_order(2))...
%     d_struct.(dim_order(3)) d_struct.(dim_order(4))...
%     d_struct.(dim_order(5)) d_struct.(dim_order(6))];
% input_dimensions_with_rare=input_dimensions;
% input_dimensions_with_rare(dind)=input_dimensions_with_rare(dind)/d_struct.r;
% input_dimensions_with_rare=[input_dimensions_with_rare(1:2)...
%     d_struct.r...
%     input_dimensions_with_rare(3:end)];
% if d_struct.r>1
%     permute_code_with_rare=permute_code;
%     permute_code_with_rare(permute_code_with_rare>2)=permute_code_with_rare(permute_code_with_rare>2)+1;
%     permute_code_with_rare=[permute_code_with_rare(1:2) 3 permute_code_with_rare(3:end)];
% end
d_struct.y=d_struct.y*d_struct.r;
d_struct.r=1;
output_dimensions=zeros(1,numel(data_buffer.headfile.('rad_mat_option_output_order')));
for d_num=1:numel(data_buffer.headfile.('rad_mat_option_output_order'))
    output_dimensions(d_num)=d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(d_num));
end

% output_dimensions=[...
%     d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(1))...
%     d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(2))...
%     d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(3))...
%     d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(4))...
%     d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(5))...
%     d_struct.(data_buffer.headfile.('rad_mat_option_output_order')(6))];

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