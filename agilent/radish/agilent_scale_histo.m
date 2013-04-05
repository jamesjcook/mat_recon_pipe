function agilent_scale_histo(filepath,dims,histo_bins,histo_percent,maxin,outdir,histchannel)
% function scale_histo(filepath,dims,histo_bins,histo_percent,maxin,outdir,histchannel)
%   Find value to be mapped to fullscale ("scale-max") for scaling images from a complex volume.
%   The complex input file is typically the result of a 3dft reconstruction.
%   Good to provide input file max voxel value (-f) if you know it (avoids scan of volume).
%   Writes a file named convert_info_histo containing calulated scale-max. form 12345.222=any text
% Required params:
%    filepath :full path of file to reform: a floating point complex data file.
%    dims     : x dimension of the file (x dim of output image)
%               y dimension of the file (y dim of output image)
%               z dimension of the file (number of output images)
%    histo_bins : number of bins to use in creating intensity-histogram (must allow accuracy to percent chosen).
%                 Histogram is x=intensity (complex mag, i or q), y=count.
%    histo_percent: percent of total voxels to be encompassed by histogram.
%                 The intensity-bin (x) at this count percent defines "scale-max" result.
% Options:
%    maxin       : if file, Find intensity max written in this text file (typically produced by recon). Data scan for max
%                  is skipped. Avoid using with with -i, -r unless this max reflects correct channel.
%                  max text file form:1234567.89=any words
%                  OR if number, Provide known intensity max, overrides -f 
%    outdir      : Directory for output file convert_info_histo containing "scale-max" result value (default .)
%    histchannel : Either i, or q, if i, chooses histogram based on i channel intensities, vs. default mag(i,q) .
%                  Don't use this with -f unless file contains i-channel max.
%                  if q, histogram based on q channel intensities, vs. default mag(i,q) .
%                  Don't use this with -f unless file contains q-channel 
% NOTE: this doesnt really use histograms to calculate the max value to use,
% Matlab is sufficiently fast that
% img_s=sort(img(:)); 
% newmax=s_max_intensity=img_s(round(length(img_s)*histo_percent/100));
% works

%not implimented
%    -h bytes    : Header bytes, to override default 61464.

% could have this detect rolled images by saving rolled images with ro.out
% or out.ro, then save these as roimx

if exist('maxin','var')
    if exist('maxin','file')
        maxin=radish_load_info_stub(maxin);
    elseif ~isscalar(maxin)
        error('bad type for maxin, must be file path or scalar');
    end
else
    maxin='UNSET';
end

if ~exist('outdir','var')
    outdir='.';
end
if ~exist('histchannel','var')
    histchannel='mag';
end


% highest_intensity_percentage=99.9875;
% histo_percent=99.95;
CA=load_complex(filepath,dims);

if strcmp(histchannel,'mag')==1
    vol=abs(CA);
elseif strcmp(histchannel,'q')==1
    vol=real(CA);
elseif strcmp(histchannel,'i')==1
    vol=imag(CA);
end


img_s=sort(vol(:)); 
maxvol=max(vol(:));
% if strcmp(maxin,'UNSET')
% else 
%     s_max_intensity=maxin;%*histo_percent;
% end

s_max_intensity=img_s(round(length(img_s)*histo_percent/100));%throwaway highest % of data... see if that helps.




outpath=[outdir '/convert_info_histo'];
% display(['Saving vintage threeft to ' outpath '.']);
ofid=fopen(outpath,'w+');
if ofid==-1
    error('problem opening convert_info_hist file for writing file');
end
fprintf(ofid,'%f=scale_max found by agilent_scale_histo in complex file %s\n',s_max_intensity,filepath);
fprintf(ofid,'%i %i : image dimensions.\n',dims(1),dims(2));
fprintf(ofid,'%i : image set zdim.\n', dims(3));
fprintf(ofid,'%i : hito_bins, %f : histo_percent\n',histo_bins,histo_percent);
fprintf(ofid,'x : user provided max voxel value? pfovided for max= none (if file used).\n');
fprintf(ofid,'%f : max voxel value used to construct histogram\n',maxin);
fprintf(ofid,' agilent_scale_histo ma script 2012/11/28\n');
fclose(ofid);




end