function res = pb_aspect_rec_dwi3d(path)
% path = path image directory
res = 0;
path1=[path,'/temp_sedwib.dat'];
path2=[path,'/temp_sedwia.dat'];
    d=load([path,'/recdata.dat']);
nfile=fopen([path,'/aspect_se3D_diffusion.tnt']);
x=fread(nfile,1056,'char');
f=fread(nfile,d(1)*d(2)*d(3)*2,'float');
fclose(nfile);
f_kp=f(1:2:end)+1i*f(2:2:end);
%
ibval=d(7); % current b-value index
iav=d(6); %index of the current external average
Nf=d(1)-100;
Nex=d(4);
nav_points=100;
Npe=d(2);
n_slice=d(3);
n_diff=d(8);
dim=max([Nf Npe]);
%
dwell_nav=4e-5;
 %IF WE ARE AT iexp>1 WE NEED TO READ THE TEMPORARY FILE FROM DISK
if ibval>1
    image_temp(n_slice,dim,dim,ibval-1)=0;
    nfile=fopen(path1,'r');
    exist_file=fread(nfile,'float');
    fclose(nfile)
    save reco_temp
    image_temp=reshape(exist_file,n_slice,dim,dim,ibval-1);
end
%
fksp(n_slice,Npe,Nf)=0+1i*0;
fnav(nav_points)=0+1i*0;
 %separate k-space data from navigator data (the navigator is in the center
 %of k-space, and we take it from the center slce
 center_slice=n_slice/2;
 center_row=Npe/2;
%
 for islice=1:n_slice
     for irow=1:Npe
         istart=((islice-1)*Npe+(irow-1))*d(1)+nav_points+1;
         ifinish=istart+Nf-1;
         fksp(islice,irow,[1:Nf])=f_kp([istart:ifinish]);
     end
 end
 %find the navigator in each slice-encode block
  tsample=d(5)*1e-6;
 samp_nav=nav_points;
zero_pad=4;
bw=1/dwell_nav;
pix_bw=1/dwell_nav/(samp_nav*zero_pad);
 for iblock=1:n_slice
     nav_start=d(1)*((iblock-1)*Nf+center_row)+1;
     nav_end=nav_start+nav_points-1;
     fnav(iblock,[1:nav_points])=f_kp(nav_start:nav_end);
     spec_nav(iblock,:)=abs(fftshift(fft(fnav(iblock,:),(samp_nav*zero_pad))));
      arr=squeeze(abs(spec_nav(iblock,:)));
      [dummy pos]=max(arr);
      freq_f(iblock)=(pos-samp_nav*zero_pad/2)*pix_bw;
      freq_cor(iblock,[1:Nf])=exp(2i*pi*freq_f(iblock)*((-Nf/2:Nf/2-1)*tsample));
 end
%
%write the last measured frequency to file
% freq_shift=freq_f(n_slice);
% filename=[path,'\last_freq.txt'];
% save(filename,'freq_shift','-ascii');
%
%perform frequency correction
for izz=1:n_slice
    for izy=1:Npe
        fidc(izz,izy,[1:Nf])=squeeze(fksp(izz,izy,[1:Nf])).*freq_cor(izz,[1:Nf])';
    end
end
image=zeros(n_slice,dim,dim);
% Creating the images
image3d=fftn(fidc);
image=fftshift(abs(image3d));
 %AT THIS POINT WE NEED TO WRITE THE IMAGE INTO A TEMPORARY VARIABLE AND SAVE TO A FILE
    image_temp(:,:,:,ibval)=image(:,:,:);
    nfile=fopen(path1,'w');
    fwrite(nfile,image_temp,'float');
    fclose(nfile)
 %
 %when we have reached the last b-value, we also need to save the images
 %as the current SUM
 %read the file of existing images temp_sedwia.dat
 if ibval==n_diff
if iav>1
    nfile=fopen(path2,'r');
    exist_av=fread(nfile,'float');
    fclose(nfile)
    av_temp=reshape(exist_av,n_slice,dim,dim,n_diff);
elseif iav==1
  av_temp(n_slice,dim,dim,n_diff)=0;  
end
%
av_sum=image_temp+av_temp;
%this is the image 
%for the current average
nfile=fopen(path2,'w');
    fwrite(nfile,av_sum,'float');
    fclose(nfile)
    %xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      %normalize the images and pass the sum to recdata.raw when the last average is reached
    if iav==Nex
         morm=max(max(max(max(av_sum))))/4095;
    im_temp = av_sum/morm;
    % 
   %re-arrange matrix
   disp=n_slice*n_diff;
   im(dim,dim,disp)=0;
   idisp=0;
   for idiff=1:n_diff
   for islice=1:n_slice
       idisp=idisp+1;
       im([1:dim],[1:dim],idisp)=im_temp(islice,[1:dim],[1:dim],idiff);
   end
   end
    sf=1/morm;
path1=[path,'\recdata.dat']; 
nfile=fopen(path1,'a');
fprintf(nfile,'%d\n',sf);
fclose(nfile);
%
path=[path,'\recdata.raw']; 
    nfile=fopen(path,'w');
    fwrite(nfile,im,'float');
    fclose(nfile);
    end
    %xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 end
 %save reco_dwi
exit
