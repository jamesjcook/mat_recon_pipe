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
% dimensions=...
%     [data_buffer.input_headfile.dim_X,...
%     data_buffer.input_headfile.([data_buffer.input_headfile.S_scanner_tag 'channels']),...
%     data_buffer.input_headfile.ne,... % need to substitute varying parameter.
%     data_buffer.input_headfile.dim_Z,...
%     data_buffer.input_headfile.dim_Y,...
%     data_buffer.input_headfile.([data_buffer.input_headfile.S_scanner_tag 'volumes' ])/data_buffer.input_headfile.([data_buffer.input_headfile.S_scanner_tag 'channels'])/ data_buffer.input_headfile.ne...
%     ];

x=data_buffer.input_headfile.dim_X;
y=data_buffer.input_headfile.dim_Y;
z=data_buffer.input_headfile.dim_Z;
c=data_buffer.input_headfile.([data_tag 'channels'] );
params=data_buffer.input_headfile.ne;
timepoints=data_buffer.input_headfile.([data_tag 'volumes'])/c/params;
dimensions=[ x c params z y timepoints] ;
fprintf('Regriding :');
if strcmp(data_buffer.scanner_constants.scanner_vendor,'bruker')
fprintf('Bruker');
    % [x channels params z y timepoints]
    
    
    % d_reshape=reshape(data_buffer.data,[x channels p z y t]);
    % if cartesian
    
    data_buffer.data=reshape(data_buffer.data,[x c params*z y timepoints] );
    
    % resort data in logical order instead of interleaved.
    acq=true;
    if strcmp(data_buffer.input_headfile.vol_type,'2D')
        if acq %%% use acq key
            objlist_name=[data_buffer.input_headfile.U_prefix 'ACQ_obj_order'];
            objlist=data_buffer.input_headfile.(objlist_name);
            data_buffer.data(:,:,objlist+1,:)=data_buffer.data;
            
        else %%% use pvm key
            data_buffer.data=reshape(data_buffer.data,[x c params z y timepoints] );
            
            objlist_name=[data_buffer.input_headfile.U_prefix 'PVM_ObjOrderList'];
            objlist=data_buffer.input_headfile.(objlist_name);
            data_buffer.data(:,:,:,objlist+1,:)=data_buffer.data;
        end
    end
    data_buffer.data=reshape(data_buffer.data,dimensions);
    data_buffer.data=permute(data_buffer.data,[1 5 4 2 3 6] );
    
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
end
fprintf('\n');