if ~exist('ute_buffer','var');
    load('uteload.mat');
end
if ~exist('scott_buffer','var');
    load('scottload.mat');
end

%%{
%%% display first 1%'
range_offset=0;
fig_base=0;
db=ute_buffer;
range=1:round(0.01*db.headfile.rays_per_volume); t=db.trajectory;
fprintf('plot first %i endpoints',range(end));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
range=1:round(0.01*db.headfile.rays_per_volume); t=db.trajectory;
fprintf('plot first %i endpoints',range(end));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display first 1000
range_offset=0;
db=ute_buffer;
fig_base=2;
range=1:1000; t=db.trajectory;
range=range+range_offset;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
range=1:1000; t=db.trajectory;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display second 1000
range_offset=1000;
db=ute_buffer;
fig_base=4;
range=1:1000; t=db.trajectory;
range=range+range_offset;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
% range=1:round(0.01*db.headfile.rays_per_volume); 
t=db.trajectory;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display third 1000
range_offset=2000;
db=ute_buffer;
fig_base=6;
range=1:1000; t=db.trajectory;
range=range+range_offset;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
%range=1:round(0.01*db.headfile.rays_per_volume);
t=db.trajectory;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display first 4k
range_offset=0;
db=ute_buffer;
fig_base=8;
range=1:4000; t=db.trajectory;
range=range+range_offset;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
%range=1:round(0.01*db.headfile.rays_per_volume);
t=db.trajectory;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display 1% dispersed through array.
pctfraction=0.01;
range_offset=0;
db=ute_buffer;
fig_base=10;
printcount=pctfraction*db.headfile.rays_per_volume;
ptskip=round(db.headfile.rays_per_volume/printcount);
range=1:ptskip:db.headfile.rays_per_volume;
t=db.trajectory;
range=range+range_offset;
fprintf('plot %i endpoints\n',round(printcount));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
printcount=pctfraction*db.headfile.rays_per_volume;
ptskip=round(db.headfile.rays_per_volume/printcount);
range=1:ptskip:db.headfile.rays_per_volume;
t=db.trajectory;
fprintf('plot %i endpoints\n',round(printcount));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display 10% dispersed through array.
pctfraction=0.1;
range_offset=0;
db=ute_buffer;
fig_base=12;
printcount=pctfraction*db.headfile.rays_per_volume;
ptskip=round(db.headfile.rays_per_volume/printcount);
range=1:ptskip:db.headfile.rays_per_volume;
t=db.trajectory;
range=range+range_offset;
fprintf('plot %i endpoints\n',round(printcount));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
printcount=pctfraction*db.headfile.rays_per_volume;
ptskip=round(db.headfile.rays_per_volume/printcount);
range=1:ptskip:db.headfile.rays_per_volume;
t=db.trajectory;
fprintf('plot %i endpoints\n',round(printcount));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display 30% dispersed through array.
pctfraction=0.3;
range_offset=0;
db=ute_buffer;
fig_base=14;
printcount=pctfraction*db.headfile.rays_per_volume;
ptskip=round(db.headfile.rays_per_volume/printcount);
range=1:ptskip:db.headfile.rays_per_volume;
t=db.trajectory;
range=range+range_offset;
fprintf('plot %i endpoints\n',round(printcount));
figure(fig_base+1);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
db=scott_buffer;
printcount=pctfraction*db.headfile.rays_per_volume;
ptskip=round(db.headfile.rays_per_volume/printcount);
range=1:ptskip:db.headfile.rays_per_volume;
t=db.trajectory;
fprintf('plot %i endpoints\n',round(printcount));
figure(fig_base+2);plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'o');
pause(1);

%%% display scan progression 5% at a time
range_offset=0;
fig_base=16;
%%% init figure with first 40 points of scott data to get a good scale on graph
db=scott_buffer;
range=1:40; t=db.trajectory;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+1);hold off;
plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'.');

db=ute_buffer;
t=db.trajectory;
hold on;
rmin=1;
for i=1:5:101; s=tic;
rmax=round(size(t,3)*min(i,100)/100);
range=rmin:rmax;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'.');
e=toc(s); if(e>1); break; else pause(0.15); end
rmin=rmax+1;
end
hold off;


db=scott_buffer;
range=1:40; t=db.trajectory;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
figure(fig_base+2);hold off;
plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'.');
hold on;
rmin=1;
for i=1:5:101; s=tic;
rmax=round(size(t,3)*min(i,100)/100);
range=rmin:rmax;
fprintf('plot %i-%i endpoints\n',range(1),range(end));
plot3(squeeze(t(1,end,range)),squeeze(t(2,end,range)),squeeze(t(3,end,range)),'.');
e=toc(s); if(e>1); break; else pause(0.15); end
rmin=rmax+1;
end
hold off;
pause(1);


% plotting tools?
% plot many rays
% plot real and imag separate


%}