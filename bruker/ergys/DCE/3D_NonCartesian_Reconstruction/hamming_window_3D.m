function f=hamming_window_3D(dim)

% This function calculates the 3D Hamming window. 
% dim=dimension: The dimension of the filter will be (dim x dim x dim), ex:
% 128x128x128. 

x=0:dim-1; 
y=x; z=x;
[X,Y,Z]=meshgrid(x,y,z); 

a=2*pi/dim; 
f1=.54-.46*cos(a*X); 
f2=.54-.46*cos(a*Y); 
f3=.54-.46*cos(a*Z); 

f=f1.*f2.*f3; 
