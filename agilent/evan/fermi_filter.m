function data_buffer=fermi_filter(data_buffer,voldims,z_ind)

if nargin==1
    voldims=size(data_buffer);
    z_ind=1;
elseif nargin~=3
    error('incorrect number of input arguments');
end

w1=0.15;
w2=0.75;
mres=max(voldims); %get max array dimension
fermit=single(mres.*w1/2);   % fermi temp: increase for more curvature/smooth edge [default=.03]
fermiu=single(mres.*w2/2);  % fermi level: increase for larger window [default=.3]

dims=size(data_buffer); %get dims of data buffer
if length(dims)<3
    dims=[dims 1];
end

%assume that we are getting all of x and y, and set indices accordingly
if dims(1:2)~=voldims(1:2)
    error('x and y dims of chunk do not match dataset dims');
end
minx=-dims(1)/2;
maxx=dims(1)/2-1;
miny=-dims(2)/2;
maxy=dims(2)/2-1;

%we may not be getting all of z if this data is being processed in chunks
if dims(3)==voldims(3) %check if this is a chunk, i.e. not all of z
    minz=-dims(3)/2;
    maxz=dims(3)/2-1;
else %if its a chunk, get the chunk indices in z
    minz=z_ind-voldims(3)/2-1;
    maxz=minz+dims(3)-1;
end

%make x y and z variables for bsxfun
xvec=reshape(single(minx:maxx),[],1,1);
xvec=xvec.^2/(dims(1)/mres).^2;
yvec=reshape(single(miny:maxy),1,[],1);
yvec=yvec.^2/(dims(2)/mres).^2;
zvec=reshape(single(minz:maxz),1,1,[]);
zvec=zvec.^2/(dims(3)/mres).^2;

% computing the FERMI window
FW=1./(1+exp((sqrt(bsxfun(@plus,xvec,bsxfun(@plus,yvec,zvec)))-fermiu)/fermit));
FW=FW/max(FW(:));

%apply the fermi filter to the data 
data_buffer=data_buffer.*FW;
clear FW