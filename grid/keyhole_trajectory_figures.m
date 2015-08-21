
% traj is our trajectory shaped up and ready to process through the scott
% regrid functions. Dimensions are just assumed default.
trajI=reshape(traj,[64,1980,13,3]);

window_length=13;
figure(1);plot3(squeeze(trajI(64,:,:,1)),squeeze(trajI(64,:,:,2)),squeeze(trajI(64,:,:,3)),'.');
%% ERGYS filter calculation.
%the same code is used for VCF, and UCF, the difference being that the
%increment is 0 for UCF.
% % mat2=size(kspace_traj_full,2); % normally 64.
% % incrmnt=((mat2/Nyquist_cutoff)-1) * ...
% %     1/ ...
% %     (floor(window_length/2)-1);
% %     ks=size(k);
% %     k=reshape(k,[ks(1),ks(2),ks(3)/window_length,window_length]);
% %     for i=1:window_length  %operate from -6:+6
% %         if i~=round(window_length/2)
% %             kp=abs(i-round(window_length/2))-1;
% %             cf=(Nyquist_cutoff+round(kp*incrmnt*Nyquist_cutoff)); %cutoff frequency
% %             k(:,1:cf,:,i)=NaN;
% %         end
% %     end
% %     shiftval=zeros(1,ndims(k));
% %     shiftval(end)=abs(key_number)-round(window_length/2);
% %     k=circshift(k,shiftval);
Nyquist_cutoff=25;  % ergy's was alwys 25 for a 64 pt ray.
incrmnt=0;
% plot ucf illustration
ucf=struct;
for kn=1:13
    dn=sprintf('t%i',kn);
    tsize=size(trajI);
    ucf.(dn)=zeros(tsize(2:ndims(trajI)));
    for tn=1:13
        kp=abs(kn-round(window_length/2))-1;
        cf=(Nyquist_cutoff+round(kp*incrmnt*Nyquist_cutoff)); %cutoff frequency
        displaypoint=64-cf;
        if tn==kn
            displaypoint=64;
        end
        ucf.(dn)(:,tn,:)=squeeze(trajI(displaypoint,:,tn,:));
    end
end
figure(2);plot3(ucf.t1(:,:,1),ucf.t1(:,:,2),ucf.t1(:,:,3),'.');

mat2=size(trajI,1); % normally 64.
incrmnt=((mat2/Nyquist_cutoff)-1) * ...
    1/ ...
    (floor(window_length/2)-1);
%plot vcf illustration
vcf=struct;
for kn=1:13
    dn=sprintf('t%i',kn);
    tsize=size(trajI);
    vcf.(dn)=zeros(tsize(2:ndims(trajI)));
    for tn=1:13
        kp=abs(tn-round(window_length/2))-1;
        cf=(Nyquist_cutoff+round(kp*incrmnt*Nyquist_cutoff)); %cutoff frequency
        displaypoint=64-cf;
        if tn==kn
            displaypoint=64;
        end
        if displaypoint==0
            displaypoint=1;
        end
        vcf.(dn)(:,tn,:)=squeeze(trajI(displaypoint,:,tn,:));
    end
end

figure(3);plot3(vcf.t1(:,:,1),vcf.t1(:,:,2),vcf.t1(:,:,3),'.');
rng=1:3;
plot3(vcf.t1(:,rng,1),vcf.t1(:,rng,2),vcf.t1(:,rng,3),'.');
rng=[1,5:7];
plot3(vcf.t1(:,rng,1),vcf.t1(:,rng,2),vcf.t1(:,rng,3),'.');

clear ucf vcf trajI;