function rad_regid(data_buffer,c_dims)
% function to turn sampled points into their cartesian grid equivalent.
% when cartesian its just a simple reshape operation.
%

% dimension order is generally xceyzt might depend on scanner. echos and
% channels might be reversed
% c=channels,
% e=echos,
% t=time

data_tag=data_buffer.input_headfile.S_scanner_tag;
dimensions=...
    [data_buffer.input_headfile.dim_X,...
    data_buffer.input_headfile.([data_buffer.input_headfile.S_scanner_tag 'channels']),...
    data_buffer.input_headfile.ne,... % need to substitute varying parameter.
    data_buffer.input_headfile.dim_Y,...
    data_buffer.input_headfile.dim_Z,...
    data_buffer.input_headfile.([data_buffer.input_headfile.S_scanner_tag 'volumes' ])...
    ];

x=data_buffer.input_headfile.dim_X;
y=data_buffer.input_headfile.dim_Y;
z=data_buffer.input_headfile.dim_Z;
c=data_buffer.input_headfile.([data_tag 'channels'] );
p=data_buffer.input_headfile.ne;
t=data_buffer.input_headfile.([data_tag 'volumes'])/c/p;
dimensions=[ x c p z y t] ;



% d_reshape=reshape(data_buffer.data,[x channels p z y t]);
% if cartesian

data_buffer.data=reshape(data_buffer.data,[x c p*z y t] );
objlist_name=[data_buffer.input_headfile.U_prefix 'ACQ_obj_order'];
objlist=data_buffer.input_headfile.(objlist_name);
data_buffer.data(:,:,objlist+1,:)=data_buffer.data;

data_buffer.data=reshape(data_buffer.data,dimensions);
data_buffer.data=permute(data_buffer.data,[1 5 4 2 3 6] );


% maybe we should squeeze....
% if not cartesian
% error('never done any real regridding');