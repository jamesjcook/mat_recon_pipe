function [img,bruker] = BrukerRecon(dir)
% "bruker.fid" is the bruker.fid data, "bruker.acqp,method,subject are the headfile
% Original file by Evan Calbrese, 6/8/11
% rmd - added multi-echo read, 6/8/11
% rmd - adapted for newest data and the PseriesP reconstruction, 8/6/12


cd dir;
% Read in Bruker parameters
bruker.acqp = readBrukerHeader('acqp');
bruker.method = readBrukerHeader('method');
bruker.fid = readBrukerFID('',bruker.method);

if exist( '../subject','file') 
    bruker.subject = readBrukerHeader('../subject');
else
    bruker.subject = readBrukerHeader('subject');
end

if length(bruker.method.PVM_Matrix) < 3
    bruker.method.PVM_Matrix(1,3) = 1;
%     bruker.method.PVM_EncMatrix(1,3) = 1;
end

% Correct Bruker bruker.fid data with zero filling if array size is not 2^n
if prod([bruker.method.PVM_Matrix bruker.method.PVM_NEchoImages ...
         bruker.method.PVM_EncNReceivers]) ~= length(bruker.fid)
    [bruker,bruker.fid] = zerorid(bruker,bruker.fid);
    
end

if bruker.method.PVM_NEchoImages > 1 % multi-echo recon
    bruker.fid=reshape(bruker.fid,bruker.method.PVM_Matrix(1,1),  ...
        bruker.method.PVM_EncNReceivers,bruker.method.PVM_NEchoImages,  ...
        bruker.method.PVM_Matrix(1,2), bruker.method.PVM_Matrix(1,3));
    bruker.fid = permute(bruker.fid,[1 4 5 3 2]);
%     bruker.fid = bruker.fid(:,:,:,1:2:end)+bruker.fid(:,:,:,2:2:end); 
    if strcmp(bruker.method.EchoAcqMode,'allEchoes') == 1
        bruker.fid(:,:,:,2:2:end,:) = bruker.fid(end:-1:1,:,:,2:2:end,:); 
    end

    
else % works for 1-slice images only?
    if strcmp(bruker.method.Method,'RARE') % RARE sequence reconstruction
        z = bruker.method.PVM_Matrix(1,3)*bruker.acqp.NSLICES;
        rare = bruker.acqp.ACQ_rare_factor;
        
        if strcmp(bruker.method.PVM_SpatDimEnum,'2D')
        bruker.fid = reshape(bruker.fid,bruker.method.PVM_EncMatrix(1,1), ...
                          bruker.method.PVM_EncNReceivers, ...
                          rare,z,bruker.method.PVM_EncMatrix(1,2)/rare);
        bruker.fid = permute(bruker.fid,[1 5 3 4 2]); 
        bruker.fid = reshape(bruker.fid,bruker.method.PVM_EncMatrix(1,1),...
                      bruker.method.PVM_EncMatrix(1,2), ...
                      z,1,bruker.method.PVM_EncNReceivers);
        bruker.fid(:,:,bruker.acqp.ACQ_obj_order+1,:,:) = bruker.fid;
            
        elseif strcmp(bruker.method.PVM_SpatDimEnum,'3D')
        bruker.fid = reshape(bruker.fid,bruker.method.PVM_EncMatrix(1,1),...
                          bruker.method.PVM_EncNReceivers, ...
                          rare,bruker.method.PVM_EncMatrix(1,2)/rare,z);
        bruker.fid = permute(bruker.fid,[1 4 3 5 2]);
        bruker.fid = reshape(bruker.fid,bruker.method.PVM_EncMatrix(1,1),... 
                      bruker.method.PVM_EncMatrix(1,2), ...
                      z,1,bruker.method.PVM_EncNReceivers);
        end
    else % Reconstruction for presumably all normally-acquired 2- or 3-D cartesian data
        bruker.fid = reshape(bruker.fid,bruker.method.PVM_EncMatrix(1,1),bruker.method.PVM_EncNReceivers, ...
        bruker.method.PVM_EncMatrix(1,2), bruker.method.PVM_Matrix(1,3));
        bruker.fid = permute(bruker.fid,[1 3 4 5 2]);       
    end

end

end





