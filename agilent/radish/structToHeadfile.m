function structToHeadfile(dest,hf_struct,prefix,verbosity)
% saves a struct to a headfile at dest. 
% can put a prefix infront of the value names
v_pause_length=0.5;
if ~exist('prefix','var')
    prefix='';
end
if ~exist('verbosity','var')
    verbosity=0;
else
    v_pause_length=verbosity/100*v_pause_length;
end
out_hf_id=fopen(dest,'w');
if out_hf_id == -1
    error('Could not open file to write hf');
end
names=sort(fieldnames(hf_struct));
%%% insert write comment block code here

for i=1:length(names)
    name=names{i};
    value=hf_struct.(name);
    
    %%%
    % put dimensions on output data, d1:d2:d3:dn,
    %%%
    vs=size(value);
    if length(vs)>2 || vs(1) >1
        fclose(out_hf_id);
        error('ERROR: structToHeadfile array is not 1d cell array');
    end
    dim_text='';
    if max(vs) >1 
        for j=1:length(vs) 
            if j~=length(vs) % the last entry is handled  special a comment separtes the last value from the dimension string
                dim_text=sprintf('%s%s:',dim_text,num2str(vs(j)));
            else
                dim_text=sprintf('%s%s,',dim_text,num2str(vs(j)));
            end
            if verbosity>1 
                disp(dim_text);
                pause(v_pause_length);
            end
        end
    end
    %%% need to move for loop above cell, so i can better handle multi
    %%% value/type, done.

    %%%
    % put data on out_text string, data1 data2 data3 datan
    %%%
    out_text='';
    temp='';
    for j=1:vs(2) % only 2d matrix
        for k=1:vs(1)
            if iscell(value)
                temp=value{k,j};
            else
                temp=value(k,j);
            end
            if isnumeric(temp)
                temp=num2str(temp);
            elseif ischar(temp)
                temp=temp;
            else
                error('ERROR: structToHeadfile array is not single element or 2d array');
            end
            
            if j<vs(2) || k <vs(2) % only put space between elements not at end
                out_text=sprintf('%s%s ',out_text,temp);
            else
                out_text=sprintf('%s%s',out_text,temp);
            end
        end
%         if(length(value)>1)
%             temp=sprintf('%i,%s',length(value),temp);
%         end
%         if isnumeric(value{j})
%             value{j}=num2str(value{j})
%         end
%         temp=sprintf('%s %s',temp,value{j});
%         end
%         value=temp;
%         elseif isnumeric(value)
%             value=num2str(value);
%             else
    end
    
    %printf('%s=%s',names,hf.(name));
    %string=sprintf('%s=%s',name,value);
    string=sprintf('%s%s=%s%s',prefix,name,dim_text,out_text);
    if verbosity>0
        disp(string);
        pause(v_pause_length);
    %disp(string);
    end
    fprintf(out_hf_id,'%s\n',string);
end
fclose(out_hf_id);
end
