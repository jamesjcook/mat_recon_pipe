% This function concatenates two structures

function s=catstruct(s1, s2)

f2=fieldnames(s2);

for i=1:length(f2);
    s1.(f2{i})=s2.(f2{i});
end

s=s1;