function f=hamming_window_2D(dim)

% This function calculates the 2D Hamming window. 
% dim=dimension: The dimension of the filter will be (dim x dim x dim), ex:
% 128x128. 

x=0:dim-1; 
y=x;
[X,Y]=meshgrid(x,y); 

a=2*pi/dim; 
f1=.54-.46*cos(a*X); 
f2=.54-.46*cos(a*Y); 

f=f1.*f2;
