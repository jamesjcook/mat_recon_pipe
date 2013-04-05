% This function parses the data acquired with repeated acquisitions using
% the radial keyhole sequences (2D or 3D) in the Bruker scanner.

function []=Bruker_parse_acquisition_data(all_data, repeat)

views_total=size(all_data, 3);
views_acq=views_total/repeat; %Number of views per acquisition
for i=1:repeat
    data_name=['acq' num2str(i) '_data'];
    d=all_data(:,:,((i-1)*views_acq+1):i*views_acq);
    eval([data_name '=d;']);
    save(data_name, data_name, '-v7.3');
end