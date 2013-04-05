% [T1map, Mo_map, E1]=calcT1map_3D(TR, FAvalues, varFAstack, mat)
%
% This function calculates the T1 map (R1=1/T1) and equilibrium
% longitutidal magnetization map.
%
%
% =====================INPUTS================================= 
% TR = repetition time (in ms) used during the varying flip angle
% (FA) acquisition
%
% FAvalues = a vector with the flip angle values (in deg) sorted from
% lowest to highest used in the SPGR sequence. 
%
% varFAstack = a matrix of the vectorized images acquired with the varying
% FA SPGR sequence. The first column in the matrix is the first 3D image
% acquired with the first FA in FAvalues. This image must be vectorized
% (i.e. using the command im(:), where im=image).
%
% mat=image matrix size along one dimension (assuming image matrix is
% cubic)
%
% =====================OUTPUTS================================
% T1map = T1 map (in same units as TR)
%
% Mo_map = equilibrium MR signal (note: this is not the equilibrium longitudinal magnetization) map
%
% E1=exp(-TR/T1)=slope of fitted line
%
%
%
% References:
% Li, K.-L., Zhu, X. P., Waterton, J. and Jackson, A. (2000), Improved 3D
% quantitative mapping of blood volume and endothelial permeability in
% brain tumors. Journal of Magnetic Resonance Imaging, 12: 347–357. 
%
% Deoni, S. C., Rutt, B. K. and Peters, T. M. (2003), Rapid combined T1 and
% T2 mapping using gradient recalled acquisition in the steady state.
% Magnetic Resonance in Medicine, 49: 515–526. 
%--------------------------------------------------------------------------
%Ergys Subashi, October 2011


function [T1map, Mo_map, E1]=calcT1map_3D(TR, FAvalues, varFAstack, mat)


% ===================== Check input arguments =====================
if (nargin~=4)
disp('Check the number of arguments');
end;

% ===================== Calculate T1map, Mo_map, and E1 =====================
FAvalues=FAvalues*pi/180; %Convert angle to radians
nangles=length(FAvalues);

x=zeros(size(varFAstack));
y=zeros(size(varFAstack));

for i=1:nangles
    x(:,i)=varFAstack(:,i)./tan(FAvalues(i));
    y(:,i)=varFAstack(:,i)./sin(FAvalues(i));
end

x=x'; %Now each column represents the signal as a function of alpha divided by the tan of alpha. Column 1 is for pixel 1, column 2 is for pixel 2, and so on. 
y=y';

f=zeros(2,size(x,2)); %This will contain the linear least-squares fit parameters
for i=1:size(x,2)
    f(:,i)=[x(:,i), ones(nangles, 1)]\y(:,i);
end

f1=f(1,:); %Slope
f1(f1>=1|f1<0)=inf; %f1>=1 would imply that T1 is zero or negative; f1<0 would imply that T1 is a complex number
E1=f1;

f2=f(2,:); %Intercept
f2(f2<0)=0; %f<0 would imply that f1>1 (look above for an explanation why this cannot happen)

Mo_map=f2./(1-E1);
Mo_map=reshape(Mo_map, mat, mat, mat);

T1map=-TR./log(E1); %Calculate T1 map [units same as input TR units]
T1map(T1map<0 | abs(T1map)==inf)=0;
T1map=reshape(T1map, mat, mat, mat);

E1=reshape(E1, mat, mat, mat);