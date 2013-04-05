function max_bval=agilent_bval_calc(procpar)

%gamma is always the same for proton imaging
gamma=267.513e6; % for H1, in rad/(s*T)

%get deltas and gradient amp from procpar
delta=procpar.tdelta;
DELTA=procpar.tDELTA;
G=procpar.gdiff*1e-5; %convert G/cm to T/mm

%check diffusion scheme and multiply gradient amp by root2 if a double
%gradient scheme is being used
if any(strcmp('diffscheme',fieldnames(procpar)))
    if strcmp(procpar.diffscheme{1},'diff_jiang6')
        G=G*sqrt(2);
    end
else
    G=0;
end
max_bval=((gamma^2)*(G^2)*(delta^2)*((4*DELTA)-delta))/(pi^2);
