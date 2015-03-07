function rout=indx_calc(rpos,rdims)
% given some number rpos, assuming fasteset to slowest in rdims, what
% position(index) would it be

rout=zeros(size(rdims));

for rd=1:length(rdims)
    rout(rd)=mod(rpos,rdims(rd));
    if rout(rd)==0
        rout(rd)=rdims(rd);
    end
        rpos=1+(rpos-rout(rd))/rdims(1);
end
