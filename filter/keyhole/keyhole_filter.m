function filter=keyhole_filter(ray_length,key_length,kspace_length,filter_type,data)
% filter=KEYHOLE_FILTER(data,ray_length,key_length,kspace_length)
% Implements a step function keyhole filter. Becuase of th way our
% acquisitions were done this is the only appropriate way to filter.
%
% That will likely cahnge in the future
%
% data is just the data being filtered
% ray_legnth is the lenght of one ray
% key_length is the number of rays in a key
% kspace_length is the number of keys
%
% filter_type  set how the filter works, either UCF or VCF, defaults to UCF.
%
% filter a boolean maek where 1 is a point we're keeping.


% traj is our trajectory shaped up and ready to process through the scott
% regrid functions. Dimensions are just assumed default.
% ray_length=64;
% key_length=1980;
% kspace_length=13;% length of a full sized kspace in keys.
filter_dims=[ray_length,key_length,kspace_length];
if exist('data','var')
    insize=size(data);
    data=reshape(data,filter_dims);
    if(size(data,ndims(data))==3)
        feps=zeros(tsize(2:ndims(data))); %filter end point s
        fepsi=zeros(tsize(2:ndims(data))); % filter end points inverted(makes a better picture)
    end
end


Nyquist_cutoff=round(ray_length*25/64);  % ergy's was alwys 25 for a 64 pt ray.
incrmnt=0;
if exist('filter_type','var')
    if strcmp(filter_type,'UCF')
        % already set increment to 0, we're good here.
    elseif strcmp(filter_type,'VCF')
        incrmnt=((ray_length/Nyquist_cutoff)-1) * ...
            1/ ...
            (floor(kspace_length/2)-1);
    end
end
% plot filter illustration if we're given trajectories
filter=ones(filter_dims,'uint8');

kn=round(kspace_length/2);
for tn=1:kspace_length
    kp=abs(kn-round(kspace_length/2))-1;
    if tn~=kn
        cf=(Nyquist_cutoff+round(kp*incrmnt*Nyquist_cutoff)); %cutoff frequency
    else
        cf=0;
    end
    filter(1:cf,:,tn)=0;%:end
    if exist('data','var') && (size(data,ndims(data))==3)
        displaypoint=ray_length-cf+1;
        feps.(dn)(:,tn,:)=squeeze(data(cf,:,tn,:));
        fepsi.(dn)(:,tn,:)=squeeze(data(displaypoint,:,tn,:));
    end
end
% end
% data(filter==0)=NaN;

if exist('data','var')
    % filter=reshape(filter,insize);
end