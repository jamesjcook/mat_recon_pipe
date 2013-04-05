function struct = readBrukerHeader(filename)
fid = fopen(filename, 'r', 'l');
if (fid==-1)
error('File not found in readBrukerHeader');
end
rawitems = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
rawitems = rawitems{1};
% rawdata = fread(fid, Inf, 'char=>char')';
%
% fclose(fid);
%
% temp = rawdata;
% index = 1;
%
% while ~isempty(temp)
% [thisstring temp] = strtok(temp, sprintf('\n'));
% if(strncmp(thisstring(end:-1:1), '$$', 2))
% thisstring = thisstring(1:end-2);
% end
% rawitems{index} = thisstring;
% index = index+1;
% end
index = 1;
while index<=length(rawitems)
offset = 0;
thisstring = rawitems{index};
%The next line is a hack. I'm okay with that.
%Account for comment lines and other special cases
if(strncmp(thisstring, '$$ @vis', 7))
index = index + 1;
continue
end
if(strncmp(thisstring, '##END=', 6))
break
end
%Test that we're on a variable definition lines
if(strncmp(thisstring, '##', 2))
[name value] = strtok(thisstring, '=');
%Trim off special characters
name = name(3:end);
if(name(1)=='$')
name = name(2:end);
end
if ~isvarname(name)
name = genvarname(name);
end
value = value(2:end);
%Here's the case of just one item
if(~any(value=='('))
num = str2num(value);
if ~isempty(num)
struct.(name) = num;
else
struct.(name) = value;
end
index = index+1;
continue
end
%Now, consider the case of a string
if(rawitems{index+1}(1)=='<')
struct.(name) = rawitems{index+1}(2:end-1);
index = index + 1;
continue
end
%Check for an array
if(strncmp(value, '( ', 2))
array_is_numeric = true;
%Parse the dimension description
size = str2num(value(3:end-1));
if(isscalar(size))
size = [1 size];
end
n = prod(size);
offset = 1;
data = [];
while (rawitems{index+offset}(1)~='#') && (rawitems{index+offset}(1)~='$');
data = [data rawitems{index+offset}];
offset = offset+1;
end
for index2 = 1:n
[temptemp, data] = strtok(data);
if(strncmp(temptemp((end-1):-1:1), '$$', 2))
temptemp = temptemp(1:end-2);
end
num = str2num(temptemp);
if isempty(num)
array{index2} = temptemp;
array_is_numeric = false;
else
array{index2} = num;
end
end
if(array_is_numeric)
array = cell2mat(array);
end
array = reshape(array, size);
if n==1 && iscell(array)
array = array{1};
end
struct.(name) = array;
clear array
index = index + offset;
continue
end
%Check for a cell array analogue
if(strncmp(value, '(', 1))
data = value(2:end);
while ~any(data==')')
offset = offset+1;
data = [data rawitems{index+offset}];
end
data = data(1:end-1);
index = index + offset;
struct.(name) = data;
end
%Lastly, handle XYPOINTS
if(strcmp(name, 'XYPOINTS'))
offset = 1;
ok = 1;
while(ok)
[data ok] = str2num(rawitems{index+offset});
if(ok)
struct.XYPOINTS(offset, 1:2) = data;
end
offset = offset + 1;
end
index = index + offset;
end
end
index = index+1;
end