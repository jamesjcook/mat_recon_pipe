% BrukerBatch.m

% batchnum = [8 10:26]
% 
% for k = 1:length(batchnum)
%     img{k} = getBruker(20120803,'T2FLAIR_mouse',batchnum(k));
% end

batchnum = [8 10 11 12 20 21 22 23];
img = zeros([dims(1:2) length(batchnum)]);

for k = 1:length(batchnum)
    [img(:,:,k),hdr{k}] = getBruker(20120803,'T2FLAIR_mouse',batchnum(k));
end

TI = [2500 2000 2300 2700 3000 1800 2400 2200];