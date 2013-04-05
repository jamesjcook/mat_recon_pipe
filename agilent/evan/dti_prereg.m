function outpaths=dti_prereg(outpaths)

fixed=outpaths(1);

%matlabpool(2);
for i=2:length(outpaths)
    moving=outpaths{i};
    outpaths{i}=rigid_affine(fixed,moving,1,0,0,moving);
end
%matlabpool close