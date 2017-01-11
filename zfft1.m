function zfft1(in_path,out_path,points,fft_max)
% zfft1 do a fft on the third of three dimensions
% data was saved as interleaved complex using this code in rad_mat. ~line 2175
%                 A=data_buffer.data;
%                 A=[imag(A(:)');real(A(:)')];
%                 A=A(:);
%                 
%                 A=typecast(A,'double');
%                 fwrite(data_buffer.chunk_out,A,'double');
% 
%
%

% we have to load multiples of points. 
% pts * 8 
%disp('fwrite  failure., must adjust.');
% return;
if ~exist(out_path,'file')
    copyfile(in_path,out_path);
end
%[A(1),A(2)]

% ans =
% 
%    1.0e-03 *
% 
%    -0.1393   -0.1179

ifid=fopen(in_path,'r','b');
f=dir(in_path);

%{
operations=f.bytes/8/points;
op_size=points*8*2;%rough memory footprint of each operation in bytes.
simultopts=1024^3/op_size; % n ops we can do at a time. (number of ops fitting in 1GB)
(f.bytes/points)
%}

skip=(f.bytes/points)-8;

if ~exist('fft_max','var')
    fft_max=f.bytes/8/points; 
end
fft_num=0;
ofid=fopen(out_path,'r+','b');% should be r+ or a+, w was wrong.
%% while we've not read the end of data
% % while ftell(ifid)<f.bytes
fprintf('%%....');
while fft_num*8<f.bytes && fft_num<fft_max
%% read data
% fprintf('\br');
% pause(0.01);
% %{
fseek(ifid,fft_num*8,'bof');
A=fread(ifid,points,'double',skip,'b');
%%% this test command correctly reads one byte from a save_complex dataset.
%%%% fseek(ifid,0,'bof');T=fread(ifid,1,'double',skip,'b');T=swapbytes(T);T=typecast(T,'single');sprintf('%d ',T)
% 
A=typecast(A,'single');
A=reshape(A,[2,numel(A)/2]);
A=complex(A(1,:),A(2,:));
A=fftshift(ifft(fftshift(A)));

%% intereleave data
% intr=[zeros(1,4);ones(1,4)];intr=intr(:);
A=[imag(A(:)');real(A(:)')];
A=A(:);

%% save data
%}
% fprintf('\bs');
% pause(0.01);
% %{
A=typecast(A,'double');
% frewind(ofid);
fseek(ofid,fft_num*8,'bof');
fwrite(ofid,A(1),'double',0,'b');
fwrite(ofid,A(2:end),'double',skip,'b');
%}
% fprintf('\b\b\b\b%03d.',floor(fft_num/points*100))
fft_num=fft_num+1;
end
fprintf('\nDone!\n');
end
%% alternate interleave
%{
function interleave=weave(dims,vol)
    interleave=zeros([2,dims]);
    interleave(1:2:end)=imag(vol);
    interleave(2:2:end)=real(vol);
end
%}