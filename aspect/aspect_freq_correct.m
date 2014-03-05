function aspect_freq_correct(data_buffer,opt_struct)
% ASPECT_FREQ_CORRECT(data_buffer)
% data_buffer is a large_array object with a data element and an
% input_headfile element
% relefvent info should be pulled from the input_headfile.
% this function is very experimental at current. It is largly taken from
% the aspect gre3d code from peterbenel given to jamescook


irep=1;
%
res=1;
noise_box=9;

zero_pad=2;
avr_mul=2;
noise_border=4;
signal_mul=3;
nrec=1;
remove_slice=opt_struct.remove_slice;

if numel(size(data_buffer.data))>3
    warning('Frequency correction not validated for more than 3 dimensions');
end
%% load  meta(header) info
data_dims=size(data_buffer.data);
 if numel(data_dims)<3
     warning('less than 3 dimensions this will probably fail');
 end
% freps=
data_buffer.data=reshape(data_buffer.data,[data_dims(1:3),prod(data_dims(4:end))]);
for vol_num=1:size(data_buffer.data,4)
    if exist('data_buffer','var')
        recon_variables(1)=data_buffer.input_headfile.dim_X;
        recon_variables(2)=data_buffer.input_headfile.dim_Y;
        recon_variables(3)=data_buffer.input_headfile.dim_Z;
        %     recon_variables(4)=data_buffer.input_headfile.nex;
        recon_variables(5)=data_buffer.input_headfile.z_Aspect_DWEL_TIME;
        recon_variables(6)=data_buffer.input_headfile.te*1000;
        recon_variables(7)=0;
        recon_variables(8)=data_buffer.input_headfile.z_Aspect_ASIMMETRIA;
        fid=data_buffer.data(:,:,:,vol_num);
    else
        help aspect_freq_correct;
        error('DATA NOT SPECIFIED!');
        path = '/panoramaspace/A013405.work';
        recon_variables=load([path,'/recdata.dat']);
        dim_X=recon_variables(1);
        dim_Y=recon_variables(2);
        dim_Z=recon_variables(3);
        nfile=fopen([path,'/aspect_gre3d_FM_SP.tnt']);
        binary_header=fread(nfile,1056,'char');
        %%% load data
        fid=fread(nfile,dim_X*dim_Y*dim_Z*nrec*2,'float');
        fid=fid(1:2:end)+1i*fid(2:2:end);
        fclose(nfile);
        clear nfile binary_header;
    end
    
    dim_X=recon_variables(1);
    dim_Y=recon_variables(2);
    dim_Z=recon_variables(3);
    % Nex=recon_variables(4);
    
    
    %% reshape
    fid=permute(fid,[1,3,2]);
    % fid=reshape(fid, dim_X,dim_Z,dim_Y);
    
    %% caluclate frequency correction
    % pulls out the last slice of data to calculate frequency.
    tsample=recon_variables(5)*1e-6; %dwelltime ? in seconds?
    te=recon_variables(6)*1e-6;   % te in seconds
    echo_ass=recon_variables(8);%50 in usual case
    bw=1/tsample;
    pix_bw=1/tsample/(dim_X*zero_pad);
    
    fid_FM=squeeze(fid(:,dim_Z,:));%%%% this doesnt handle more than 3 dimensions! what junk!
    
    FM_mag=abs(fftshift(fft(fid_FM,dim_X*zero_pad,1),1));
    
    [dummy,pos]=max(FM_mag);
    freq_f=(pos-dim_X*zero_pad/2)*pix_bw;
    gradf=diff(freq_f);
    urf=bw*[0,cumsum((abs(gradf)>.9*bw))];
    freq_f=freq_f+urf;
    p=polyfit(0:1/(dim_Y-1):1,freq_f,4);
    freq_drift=polyval(p,0:1/(dim_Y*dim_Z-1):1);
    %   freq_drift=zeros(1,Npe*Npe2);
    
    input_fid=fid;  % preserve input_fid for later.
    fid=reshape(fid,dim_X,dim_Y*dim_Z); % put fid back into rays
    ns=fix(-dim_X/2*(1-echo_ass/100));
    nf=ns+dim_X-1;
    %% apply frequency correction
    l_errs=cell(1,dim_Y*dim_Z);
    for i=1:dim_Y*dim_Z
        freq_cor=exp(2i*pi*freq_drift(i)*((ns:nf)*tsample+te));
        fl=fid(:,i);
        fid(:,i)=fid(:,i).*freq_cor';
        fl_c=fid(:,i);
        if sum(abs(fl)-abs(fl_c))==0
            l_errs{i}=sprintf('freq_correct had no effect for ray %i\n',i);
        else 
            l_errs{i}='';
        end
    end
    
    % show any frequency lines that do not work
%     if ~strcmp(strjoin(l_errs,''),'')
%         warning('%s',strjoin(l_errs,''))
%     end
    fid=reshape(fid,dim_X,dim_Z,dim_Y);
    % if remove_slice
    %     fid(:,dim_Z,:)=[]; % delete last slice? why? that is where the frequency correction data is.
    % end
    largest_planar_dimension=max(dim_X,dim_Y);
    zf=largest_planar_dimension-dim_Y;
    zfi=floor(zf/2)+mod(zf,2);
    fid2=zeros(largest_planar_dimension,dim_Z,largest_planar_dimension);
    fid2(:,:,(zfi+1):zfi+dim_Y)=fid;
    
    fid2=permute(fid2,[1,3,2]);
    data_buffer.data(:,:,:,vol_num)=fid2;
end
data_buffer.data=reshape(data_buffer.data,data_dims);
%%% this has been commented because the main rad_mat code handles removing
%%% a zslice wether or not we run frequency correction. 
% if remove_slice
%     data_buffer.data(:,:,end,:,:,:,:)=[];
% end




