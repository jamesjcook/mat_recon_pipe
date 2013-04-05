% This function generates the index needed in the name of an image for
% archiving. The output is a string.

function indx=gen_archiving_slice_indx(n, timepoints)

indx=num2str(n);
while numel(num2str(indx))<numel(num2str(timepoints))
    indx=['0' indx];
end


