% This function gets the value from a specific item in the headfile
% structure

function struct_item=get_value(headfile, item_name)

%Headfile=name of headfile
%item_name=name of field (string)

struct_item=getfield(headfile, item_name);