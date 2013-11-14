% [C_tracer]=calc_con_3D(TR, FAvalues, varFAstack, mat, TR_dyn, FA_dyn, S0, S_t)
%
% This function calculates the concetration of Gd-DTPA (Magnevist) on a
% pixel-by-pixel region. (More contrast agents can be added if needed.)
%
%
% =====================INPUTS================================= 
% TR = repetition time (in ms) used during the varying flip angle
% (FA) acquisition
%
% FAvalues = a vector with the flip angle values (in deg) sorted from
% lowest to highest used in the SPGR sequence. 
%
% varFAstack = a stack of the images acquired with the varying FA SPGR
% sequence. The first image in the stack corresponds to the image acquired
% with the first FA in "FAvalues" and similarly for the following images.
%
% mat=image matrix size along one dimension (assuming image matrix is
% cubic)
%
% TR_dyn = repetition time (in ms) used for acquiring the dynamic data
%
% FA_dyn = flip angle used for acquiring the dynamic data
%
% S0 = signal values before injection; a matrix of the vectorized image.
%
% S_t = signal values after injection; a matrix of the vectorized images as
% a function of time. The first column in the matrix is the first 3D image
% acquired at the first temporal point. This image must be vectorized (i.e.
% using the command im(:), where im=image).
%
% =====================OUTPUTS================================
% C_tracer = a stack of tracer concetration in each pixel. Units = mM.
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
%
%
%
% Assumptions:
% Magnet strength = 7.0 T
% FOV (3D) and pixel size are isotropic
% 
%
%Notes:
%Calculated pixel values that are equal to zero are set to that value and
%it is highly improbable that they represent a true measurement. 
%--------------------------------------------------------------------------
%Ergys Subashi, November 2011

function [C_tracer]=calc_con_3D(TR, FAvalues, varFAstack, mat, TR_dyn, FA_dyn, S0, S_t)


% ===================== Check input arguments =====================

if (nargin~=8)
disp('Not enough input arguments. Please provide eight input arguments.');
end;

% ===================== Calculate T1map, Mo_map, and E1 =====================

[T1map, Mo_map, E1]=calcT1map_3D(TR, FAvalues, varFAstack, mat);
T1map=T1map/1000; %Unit of seconds

% ===================== Calculate C_tracer =====================
r_magnevist=3.275; %mM^-1*s^-1. Magnevist (in blood plasma) relaxivity at 7T and 37 deg celcius. (Huhmann, et. al., Invest Radiol 2010;45: 554–558)

R1map_0=1./T1map; %Native R1 map (units of s^-1)
R1map_0(abs(R1map_0)==inf)=0;
TR_dyn=TR_dyn/1000; %In seconds
FA_dyn=FA_dyn*pi/180; %Convert angle to radians
s=size(S_t, 2);

S0_mat=S0*ones(1,s); %Matrix having S0 as columns needed in the calculation of R1
d1=sin(FA_dyn).*Mo_map;
d1=d1(:);
d1=d1*ones(1,s);

A=(S_t-S0_mat)./d1;
clear S_t

E1=E1(:);
B=(ones(size(E1))-E1)./(ones(size(E1))-cos(FA_dyn).*E1);
B=B*ones(1,s);
AB=A+B;
clear E1 A B S0

log_arg=(ones(size(AB))-AB)./(ones(size(AB))-cos(FA_dyn).*AB);
clear AB

log_arg(isnan(log_arg))=1; %This forces R1 at those points to be zero
ind=(log_arg <= 0) | (log_arg>1);
log_arg(ind)=1; %This forces R1 at those points to be zero
log_arg(isnan(log_arg))=1; %Discard meaningless values

R1=-(1/TR_dyn).*log(log_arg);
R1(isnan(R1)) = 0; %Discard meaningless values

R1map_0=R1map_0(:);
R1map_0=R1map_0*ones(1,s);

Con_tracer=(R1-R1map_0)/r_magnevist;
Con_tracer(Con_tracer<0)=0; %Concentration cannot be less than zero

C_vol=[];
for i=1:size(Con_tracer,2)
    v=Con_tracer(:,i);
    v=reshape(v, mat, mat, mat);
    C_vol=cat(3, C_vol, v);
end

C_tracer=C_vol;