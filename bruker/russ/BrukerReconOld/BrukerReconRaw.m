function [raw,bruker] = BrukerReconRaw
% "raw" is the raw data, "bruker" is the headfile
% Original file by Evan Calbrese, 6/8/11
% rmd - added multi-echo read, 6/8/11
% rmd - adapted for newest data and the PseriesP reconstruction, 8/6/12

% Read in Bruker parameters
bruker.acqp = readBrukerHeader('acqp');
bruker.method = readBrukerHeader('method');
raw = readBrukerFID('',bruker.method);
bruker.subject = readBrukerHeader('../subject');

if length(bruker.method.PVM_Matrix) < 3
    bruker.method.PVM_Matrix(1,3) = 1;
%     bruker.method.PVM_EncMatrix(1,3) = 1;
end

% Correct Bruker raw data with zero filling if array size is not 2^n
if prod([bruker.method.PVM_Matrix bruker.method.PVM_NEchoImages ...
         bruker.method.PVM_EncNReceivers]) ~= length(raw)
    [bruker,raw] = zerorid(bruker,raw);
    
end

if bruker.method.PVM_NEchoImages > 1 % multi-echo recon
    raw=reshape(raw,bruker.method.PVM_Matrix(1,1),  ...
        bruker.method.PVM_EncNReceivers,bruker.method.PVM_NEchoImages,  ...
        bruker.method.PVM_Matrix(1,2), bruker.method.PVM_Matrix(1,3));
    raw = permute(raw,[1 4 5 3 2]);
%     raw = raw(:,:,:,1:2:end)+raw(:,:,:,2:2:end); 
    if strcmp(bruker.method.EchoAcqMode,'allEchoes') == 1
        raw(:,:,:,2:2:end,:) = raw(end:-1:1,:,:,2:2:end,:); 
    end

    
else % works for 1-slice images only?
    if strcmp(bruker.method.Method,'RARE') % RARE sequence reconstruction
        z = bruker.method.PVM_Matrix(1,3)*bruker.acqp.NSLICES;
        rare = bruker.acqp.ACQ_rare_factor;
        
        if strcmp(bruker.method.PVM_SpatDimEnum,'2D')
        raw = reshape(raw,bruker.method.PVM_EncMatrix(1,1), ...
                          bruker.method.PVM_EncNReceivers, ...
                          rare,z,bruker.method.PVM_EncMatrix(1,2)/rare);
        raw = permute(raw,[1 5 3 4 2]); 
        raw = reshape(raw,bruker.method.PVM_EncMatrix(1,1),...
                      bruker.method.PVM_EncMatrix(1,2), ...
                      z,1,bruker.method.PVM_EncNReceivers);
        raw(:,:,bruker.acqp.ACQ_obj_order+1,:,:) = raw;
            
        elseif strcmp(bruker.method.PVM_SpatDimEnum,'3D')
        raw = reshape(raw,bruker.method.PVM_EncMatrix(1,1),...
                          bruker.method.PVM_EncNReceivers, ...
                          rare,bruker.method.PVM_EncMatrix(1,2)/rare,z);
        raw = permute(raw,[1 4 3 5 2]);
        raw = reshape(raw,bruker.method.PVM_EncMatrix(1,1),... 
                      bruker.method.PVM_EncMatrix(1,2), ...
                      z,1,bruker.method.PVM_EncNReceivers);
        end
    else % Reconstruction for presumably all normally-acquired 2- or 3-D cartesian data
        raw = reshape(raw,bruker.method.PVM_EncMatrix(1,1),bruker.method.PVM_EncNReceivers, ...
        bruker.method.PVM_EncMatrix(1,2), bruker.method.PVM_Matrix(1,3));
        raw = permute(raw,[1 3 4 5 2]);       
    end

end

end





