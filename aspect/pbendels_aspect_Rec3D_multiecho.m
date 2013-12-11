function res = pbendels_aspect_Rec3D_multiecho(path)
% path = path image directory
res=0;
 d=load([path,'/recdata.dat']);
  nfile = fopen([path,'/aspect_me3d_rew.tnt']);
x=fread(nfile,1056,'char');
f=fread(nfile,d(1)*d(2)*d(3)*d(4)*2,'float');
fclose(nfile);
f_kp=f(1:2:end)+1i*f(2:2:end);
%
Nf=d(1);
Npe=d(2);
Npe2=d(3);
nechoes=d(8);
%
nsampling=Nf/nechoes;%x
dim=max([nsampling Npe]);%max(x,y)
fid=reshape(f_kp,nsampling,nechoes,Npe,Npe2);%reshape(data,x,echos,y,z)
image=zeros(dim,dim,nechoes*Npe2);
% Creating the images
n=1;
for i=1:nechoes
  %
    imageMat=squeeze(fid(:,i,:,:)); 
    im3d=fftshift(abs(fftn(imageMat,[dim,dim,Npe2])));
% 
for j=1:Npe2
    image(:,:,n)=squeeze(im3d(:,:,j));
    n=n+1;
end
  %
end
%
% 
    norm = max(max(max(image)));
     morm=norm/4095;
    %
        im = image/morm;
    % 
   
        final = im;
   sf=1/morm;
path=[path,'/RECDATA.DAT']; 
nfile=fopen([path,'a']);
fprintf(nfile,'%d\n',sf);
%can't print this file -- why?

fclose(nfile);

%save me3d3
path=[path,'/RECDATA.RAW']; 
    nfile=fopen(path,'w');
    fwrite(nfile,final,'float');
    fclose(nfile);
exit