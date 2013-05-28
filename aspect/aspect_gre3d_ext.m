function res=aspect_gre3d_ext(path)
path1=[path,'\temp.dat'];
%
%temp.dat contains the current 3-D image file - the current accumulated sum
% of the previous averages
%
%index.dat must contain the current value of 'irep' (i.e. which average are
%we running). It should be an ASCII file created by the macro
irep=load([path,'\index.txt']);
%
res=1;
noise_box=9;

avr_mul=2;
noise_border=4;
signal_mul=3;
%
d=load([path,'\recdata.dat']);
nfile=fopen([path,'\savefile.tnt']);
x=fread(nfile,1056,'char');
nrec=1;
Nex=d(4);
%
f=fread(nfile,d(1)*d(2)*d(3)*nrec*2,'float');
fclose(nfile);
f=f(1:2:end)+1i*f(2:2:end);

tsample=d(5)*1e-6;
te=d(6)*1e-6;
Nf=d(1);
zero_pad=2;
Npe=d(2);
Npe2=d(3);
echo_ass=d(8);
bw=1/tsample;
pix_bw=1/tsample/(Nf*zero_pad);
fid=reshape(f, Nf,Npe2,Npe);
clear f
fid_FM=squeeze(fid(:,Npe2,:));
f=abs(fftshift(fft(fid_FM,Nf*zero_pad,1),1));
[dummy,pos]=max(f);
freq_f=(pos-Nf*zero_pad/2)*pix_bw;
gradf=diff(freq_f);
urf=bw*[0,cumsum((abs(gradf)>.9*bw))];
freq_f=freq_f+urf;
p=polyfit(0:1/(Npe-1):1,freq_f,4);
freq_drift=polyval(p,0:1/(Npe*Npe2-1):1);
%   freq_drift=zeros(1,Npe*Npe2);

f1=reshape(fid,Nf,Npe*Npe2);
ns=fix(-Nf/2*(1-echo_ass/100));
nf=ns+Nf-1;
for i=1:Npe*Npe2
    freq_cor=exp(2i*pi*freq_drift(i)*((ns:nf)*tsample+te));
    f1(:,i)=f1(:,i).*freq_cor';
end
fid1=reshape(f1,Nf,Npe2,Npe);
fid1(:,Npe2,:)=[];

% for center out k_space
if d(7)==1
	ind=reshape([Npe/2+2:Npe;Npe/2-1:-1:1],Npe-2,1);
    ind=[Npe/2+1;Npe/2;ind];
	fid1(:,:,ind)=fid1;
end

clear f1
dim=max(Nf,Npe);
zf=dim-Npe;
zfi=floor(zf/2)+mod(zf,2);
fid2=zeros(dim,Npe2-1,dim);
fid2(:,:,(zfi+1):zfi+Npe)=fid1;
clear fid1
%
imf=fftshift(fftn(fftshift(fid2)),1);
clear fid2
imf=permute(imf,[1,3,2]);
%reverse slice order
imf=imf(:,:,end:-1:1);

image=[];
image(:,:,:)=abs(squeeze(imf(:,:,:)));
%
image1=image(:,:,1:d(3)-1);
clear image imf
%I assume that image1 is the data file before normalization
d1=size(image1);
dim=max([d(1) d(2)]);
%read the file of existing image sum temp.dat
if irep>1
    nfile=fopen(path1,'r');
    exist_file=fread(nfile,'float');
    fclose(nfile)
    image_temp=reshape(exist_file,dim,dim,d(3)-1);
%
image_sum=image1+image_temp;     %this is the sum including the current average
else
image_sum=image1;
end
%
clear image_temp
%
%export the last frequency 
last_f(irep)=freq_f(Npe);
new_freq=last_f(irep);
ndata=[d(1) d(2) d(3) d(4) d(5) d(6) d(7) last_f(irep)];
ndata=ndata';
%
filename = [path,'\last_freq.txt'];
save(filename,'new_freq','-ascii');   
%save c:\NTNMR\last_freq.txt new_freq -ascii

%
%save the latest current sum (unless we reached the the last average)
if irep<Nex
nfile=fopen(path1,'w');
    fwrite(nfile,image_sum,'float');
    fclose(nfile)
   % if we have reached the last average
else
%
norm = max(max(max(image_sum)));
siz=d1(1)*d1(2)*d1(3);
morm=norm/4095;
image = image_sum/morm;
sf=1/morm;

clear image_sum
%
path1=[path,'\recdata.dat']; 
nfile=fopen(path1,'a');
fprintf(nfile,'%d\n',sf);
fclose(nfile);
%
path2=[path,'\recdata.raw']; 
nfile=fopen(path2,'w');
fwrite(nfile,image,'float');
end
exit
