%This function creates the tag file needed for archiving

function []=write_tagfile_DCE(runno, mat, projectcode, civmid, Filtering_method, img_format)

tag_file{1,1}=[runno ',' 'androsspace,' num2str(mat) ',' projectcode ',' '.' img_format];
tag_file{end+1, 1}=['# recon_person=' civmid];
tag_file{end+1, 1}=['# tag_file_creator=' 'Ergys_James'];
tag_file{end+1, 1}=['# Filtering_method= ' Filtering_method];
dlmcell(['/androsspace/Archive_Tags/' 'READY_' runno], tag_file);