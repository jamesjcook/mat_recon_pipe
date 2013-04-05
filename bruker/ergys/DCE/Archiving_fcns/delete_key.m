%This function deletes a given item entry from a headfile structure

function []=delete_key(headfile, item_name)

%Headfile=name of headfile
%item_name=name of field (string)

headfile=rmfield(headfile, item_name);