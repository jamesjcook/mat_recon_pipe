function [line, name, file]=get_dbline(function_name)
d=dbstack;
line=0;
name='';
file='';
for el=1:length(d)
    if strcmp(d(el).name,function_name)
        line=d(el).line;
        name=d(el).name;
        file=d(el).file;
    end
end

% loc=[{d.file}',{d.name}.',{d.line}.'];
% difiosp(loc);
