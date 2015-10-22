data_buffer=B02124;
% trajI=struct2array(data_buffer.used_trajectory);
ray_length=64;
key_length=1980;
kspace_length=13;% length of a full sized kspace in keys.
ep=64;
for kn=1:kspace_length
    dn=sprintf('t%i',kn);
    ucf=data_buffer.used_trajectory;
    dx=size(ucf.(dn));
    ucf.(dn)(ucf.(dn)>5)=NaN;
    figure(kn);plot3(ucf.(dn)(ep:ep:end,1),ucf.(dn)(ep:ep:end,2),ucf.(dn)(ep:ep:end,3),'.');
    figure(kspace_length+1);imagesc(reshape(ucf.(dn)(:,1),[64*13,1980]));
%     tsize=size(trajI);
%    ucf.(dn)=zeros(tsize(2:ndims(trajI)));
%     for tn=1:kspace_length
%         kp=abs(kn-round(kspace_length/2))-1;
%         cf=(Nyquist_cutoff+round(kp*incrmnt*Nyquist_cutoff)); %cutoff frequency
%         displaypoint=ray_length-cf;
%         if tn==kn
%             displaypoint=ray_length;
%         end
%         ucf.(dn)(:,tn,:)=squeeze(trajI(displaypoint,:,tn,:));
%     end
pause(1);
end
