%This function reshapes the kspace coordinates to be in the format required
%by the dcf calculating function and gridding recon

function k=Bruker_reshape_kspace_coords(k_in)

npts=size(k_in, 2);
nviews=size(k_in, 3);

x=k_in(1,:,:); x=squeeze(x); x=x(:);
y=k_in(2,:,:); y=squeeze(y); y=y(:);

k=complex(x, y);