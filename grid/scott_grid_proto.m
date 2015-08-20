%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% A demonstration of basic Dynamic Contrast Enhanced (DCE) reconstruction
% using radial data using a simple sliding window reconstruction.
%
% Author: Scott Haile Robertson
% Website: www.ScottHaileRobertson.com
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function scott_grid_proto()
code_path='/Users/james/Desktop/DCE_proto';
% run([code_path '/Duke-CIVM-MRI-Tools/setup.m']);
% run([code_path '/GE-MRI-Tools/setup.m']);
% run([code_path '/Non-Cartesian-Reconstruction/setup.m'])
u_dir='/Users/james/';
w_dir='/piperspace/test_RM_nemomri_ute3d_keyhole_20150312_BreathingPhantom_s16.work';
%% Fast (for quick quality control) Reconstruction parameters
scale = 0.5; % Scales the output matrix size (changes resolution)
oversampling = 1; % Use at least 2. Turn "crop" off on reconObject, then increase this until you dont see signal at the edge of FOV, then turn "crop" back on and use that oversampling
sharpness = 0.3*scale;  % This is a key parameter that tradesoff SNR and resolution (making sharpness smaller will blurr the object, but increase SNR and vice versa)
extent = 6*sharpness;
verbose = 0;
nPipeIter = 2; % Use 3-15 for option 1, lots more (~75) for iterative recon. This should scale recon time linearly(ish)
crop = 1;

% %% Slow (but decent) Reconstruction parameters
% scale = 1;
% oversampling = 2; % Use at least 2. Turn "crop" off on reconObject, then increase this until you dont see signal at the edge of FOV, then turn "crop" back on and use that oversampling
% sharpness = 0.21;  % This is a key parameter that tradesoff SNR and resolution (making sharpness smaller will blurr the object, but increase SNR and vice versa)
% extent = 9*sharpness; % 9 is a good value
% verbose = 0;
% nPipeIter = 5; % Use 3-15 for option 1, lots more (~75) for iterative recon. This should scale recon time linearly(ish)
% crop = 1;


%% Find directory containing all information
reconDir = [u_dir '/Desktop/B03180/'];

%% Read the header file to get scan info
% This could be done nicer by reading the header, etc. - I was lazy and hard-coded
nPts = 64;
nCoils = 4;
nRaysPerKey = 1980;
nKeys = 13;
nAcq = 4;%11;
samplesPerAcq = nPts*nRaysPerKey*nKeys;
unscaled_size = 2*nPts*[1 1 1];
scaled_output_size = round(scale*unscaled_size);
scale = scaled_output_size(1)/unscaled_size(1);
if(crop)
    reconMatSize = scaled_output_size;
else
    reconMatSize = scaled_output_size*oversampling;
end

%% Sliding window parameters
keysPerWindow = nPts*nRaysPerKey*13; % 10 keys of data (I like 10-15 for this dataset)
windowStep = nPts*nRaysPerKey*1; % Step by one key of data

%% Read in fid data, put in 
dataFile = [ u_dir  '/Desktop/B03180/fid'];
dataFile = [ w_dir '/fid'];
fid = fopen(dataFile);
data = fread(fid,inf,'int32');
fclose(fid);
data = complex(data(1:2:end),data(2:2:end)); % Make the data actually complex
data = reshape(data,[nPts nCoils nRaysPerKey nKeys nAcq]); % put data into matrix form
data = permute(data,[1 3 4 5 2]);% Make coil last dimmension
data = reshape(data,[nPts nRaysPerKey*nKeys nAcq nCoils]); % Vectorize all but coil dimmension

%% Read in trajectory
trajFile = [ u_dir  '/Desktop/B03180/traj'];
trajFile = '/Volumes/workstation_data/data/trajectory/bruker/nemomri/ute3d_keyhole//traj_M128_K13_U2';
fid = fopen(trajFile);
traj = fread(fid,inf,'double');
fclose(fid);
traj = reshape(traj,[3 nPts nRaysPerKey nKeys]); % put trajectory into matrix form
traj = permute(traj,[2 3 4 1]); % Put [kx,ky,kz] dimmension last
traj = reshape(traj,[nPts nRaysPerKey*nKeys 3])/scale; % vectorize keys and Acq

% % Throw away any aliased data
aliased_Pts = any(any(abs(traj)>=0.5,3),2);
nPts = sum(~aliased_Pts);
traj = traj(1:nPts,:,:);
data = data(1:nPts,:,:,:);
keysPerWindow = nPts*nRaysPerKey*13; % 13 keys of data 
windowStep = nPts*nRaysPerKey*1; % Step by one key of data
samplesPerAcq = nPts*nRaysPerKey*nKeys;

% Vectorize data and traj
traj = reshape(traj,[nPts*nRaysPerKey*nKeys 3]); % vectorize all but [kx,ky,kz] dimmension
data = reshape(data,[nPts*nRaysPerKey*nKeys*nAcq nCoils]); % Vectorize all but coil dimmension

%% Create the recon objects that dont change 
tic;
% Construct Gridding kernel
kernelObj = Recon.SysModel.Kernel.Gaussian(sharpness, extent, verbose);

% Construct Proximity object
proxObj = Recon.SysModel.Proximity.L2Proximity(kernelObj, verbose);

%% Perform sliding window Reconstruction
ptsPerCoil = nPts*nRaysPerKey*nKeys*nAcq; % all keys, acqs
windowStartIdxs = 1:windowStep:(ptsPerCoil-keysPerWindow);
nWindows = length(windowStartIdxs);
slidingWindowReconVol = zeros([reconMatSize nWindows]);

% Batch reconstructions of the same trajectories to save on DCF
% calculations and the computation of system matrices
startMod = mod(windowStartIdxs-1,samplesPerAcq)+1;
[uniqueStarts,ia,ic] = unique(startMod); % find all unique trajectories

% and yet he nevr uses either edges or counts.
try % new code 2014b and newer
[uniqueCounts, uniqueEdges] = histcounts(ic,length(uniqueStarts));
catch me % old codeb pre. 
[uniqueCounts, uniqueEdges] = histc(ic,length(uniqueStarts));
end


nSysMat = length(uniqueStarts);
tmpVol = zeros(reconMatSize);

disp(['Completed 0/' num2str(nSysMat) ' traj subsets']);
for iSysMat = 1:nSysMat % This can be done in parallel, but takes LOTS of memory
    % Make a reconObj for each window
    windowTraj = squeeze(traj(mod(uniqueStarts(iSysMat)+[0:(keysPerWindow-1)]-1,samplesPerAcq)+1,:));
    
    % Construct system model
    disp('   Creating System model');
    systemObj = Recon.SysModel.MatrixSystemModel(windowTraj, oversampling, ...
        scaled_output_size, proxObj, verbose);   
    
    % Option 1: LSQR recon + Pipe DCF (very fast because each coil uses same DCF weights)
    disp('   Calculating DCF');
    dcfObj = Recon.DCF.Iterative(systemObj, nPipeIter, verbose);
    reconObj = Recon.ReconModel.LSQGridded(systemObj, dcfObj, verbose);
    reconObj.deapodize = 1;
    
    %     % Option 2: Iterative recon (slower as it iterahappen for each
%     % coil
%     reconObj = Recon.ReconModel.ConjugateGradient(systemObj, nPipeIter, verbose);
    
    % Tell recon to crop image to prescribed FOV 
    clear systemObj dcfObj; % free up memory
    reconObj.crop = crop; 
    
    % Reconstruct all data that share this trajectory
    sameStartIdx = find(ic==iSysMat);
    nSameStart = length(sameStartIdx);
    disp(['   Reconstructed 0/' num2str(nSameStart) ' of repeated traj']);
    for iSameStart = 1:nSameStart % this can be done in parallel, but wont help as much as making the first loop parallel
        iWindow = sameStartIdx(iSameStart);
        sampleIdx = windowStartIdxs(iWindow) + [0:(keysPerWindow-1)];
        
        % Recon each coil in a SOS sense (parallel recon like SENSE/GRAPPA etc
        % would be smarter)
        for iCoil=1:nCoils
            disp(['      Reconstructed coil' num2str(iCoil) '/' num2str(nCoils)]);
            coilData = squeeze(data(sampleIdx,iCoil));
            
            % Compute SOS recon
            tmpVol = tmpVol + abs(reconObj.reconstruct(coilData, windowTraj)).^2;%;
        end
        
        % Take square root for SOS
        tmpVol = sqrt(tmpVol);
        
        % Save volume
        slidingWindowReconVol(:,:,:,iWindow) = tmpVol;
        
        % Show some progress
        disp(['   Completed ' num2str(iSameStart) '/' num2str(nSameStart) ' of repeated traj']);
    end
    clear reconObj windowTraj; % free up memory
    
    % Show some progress
    disp(['Completed ' num2str(iSysMat) '/' num2str(nSysMat) ' traj subsets']);
end
clear data traj windowStartIdxs kernelObj proxObj; % clean up
reconTime = toc/60


% Show the reconstruction
imslice(slidingWindowReconVol,'Sliding window');