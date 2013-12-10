function res = pbendels_aspect_se3d_classic_sf(path)
res=1



%[FUN#ExpDim-UEXIT([Nf],[tsample],[Npe],[Npe2],[n_slice],[intrlv],[echo_asym],[0])]
%NF = campioni, tsample = dwell, npe = codifiche, npe2 = codifiche_3d, n_slice = z, 
d=load([path,'/recdata.dat']);

[Nf]=d(1);
[tsample]=d(2)*1e-6;
[Npe]=d(3);
[Npe2]=d(4);
[n_slice]=d(5);
echo_asym=d(7);
nf_nav=50;

noise_box=9;
avr_mul=2;
noise_border=4;
signal_mul=3;

nfile=fopen([path,'/aspect_se_rew3.tnt']);
x=fread(nfile,1056,'char');
f=fread(nfile,(Nf+nf_nav)*n_slice*Npe2*Npe*2,'float');
fclose(nfile);
f=f(1:2:end)+1i*f(2:2:end);

dim=max([Nf,Npe]);
fidfm=reshape(f,(Nf+nf_nav),n_slice*Npe2*Npe);
fidfm=fidfm(1:50,:);

s=size(fidfm);

 pass_ind=0:1/(s(2)-1):1;
 jj=[];
 for j=1:s(2)
     if std(diff(unwrap(angle(fidfm(:,j)))))>.25*pi
         jj=[jj,j];
     end
 end
 pass_ind(jj)=[];
 fidfm(:,jj)=[];



fr=abs(fftshift(fft(fidfm,Nf,1),1));
[dummy,pos]=max(fr);
freq_f=(pos-Nf/2-1)/1000e-6/(Nf/50); % f=(dpoints/T)/zf_factor
p=polyfit(pass_ind,freq_f,4);
freq_drift=polyval(p,0:1/(n_slice*Npe2*Npe-1):1);
%figure
% plot(freq_drift)
fi=reshape(f,Nf+nf_nav,n_slice*Npe2*Npe);
fi(1:nf_nav,:)=[];
fic=zeros(Nf,n_slice*Npe2*Npe);

ns=fix(-Nf/2*(1-echo_asym/100));
nf=ns+Nf-1;
for i=1:n_slice*Npe2*Npe
    fc=fi(:,i);
    freq_cor=exp(2i*pi*freq_drift(i)*((ns:nf)*tsample));
%     freq_cor=1;
    fic(:,i)=fc.*freq_cor';
end

acq_dim='2d';
if Npe2>1 acq_dim='3d'; end 
switch acq_dim
    case '2d'
        fidc=reshape(fic,Nf,n_slice,Npe);
        image=zeros(dim,dim,n_slice);
        for i=1:n_slice
            im2d=fftshift(abs(fftn(squeeze(fidc(:,i,:)),[dim,dim])),1);
            image(:,:,i)=im2d;
        end
    case '3d'
        fidc=reshape(fic,Nf,Npe2,Npe);
        fidcp=permute(fidc,[2,1,3]);
        image=fftshift(abs(fftn(fidcp,[Npe2,dim,dim])));

        % image=fftshift(image,1);
        image=fftshift(permute(image,[2,3,1]),2);
end
d=size(image);
if n_slice*Npe2==1, d(3)=1; end
siz=d(1)*d(2)*d(3);
norm=pbendels_norm_image(d,image,noise_box,noise_border,avr_mul,signal_mul);
%norm=pbendels_norm_image(d,imf,noise_box,noise_border,avr_mul,signal_mul)
image1=image;
image=image1/norm*4095;
morm=4095;
pr=sum(sum(sum(image>4095)))/siz*100;
while pr > .05
    morm=morm*.9;
    image=image1/norm*morm;
    pr=sum(sum(sum(image>4095)))/siz*100;
end
image=(image<4095).*image+(image>4095)*4095;

    sf=morm/norm;
if(isnan(sf)),sf=1;,end
path1=[path,'/recdata.dat']; 
nfile=fopen(path1,'a');
fprintf(nfile,'%d\n',sf);
fclose(nfile);


path=[path,'/recdata.raw']; 
nfile=fopen(path,'w');
fwrite(nfile,image,'float');
fclose(nfile);
exit


