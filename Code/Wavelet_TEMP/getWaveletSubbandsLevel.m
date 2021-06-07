function [subbands] = getWaveletSubbandsLevel(vol,level,wavelet_name,L_filt,H_filt)

% IMPORTANT: 
% - THIS FUNCTION IS TEMPORARY AND NEEDS BENCHMARKING. ALSO, IT
% ONLY WORKS WITH AXIAL SCANS FOR NOW. USING DICOM CONVENTIONS, OBVIOUSLY
% (NOT MATLAB).
% - Strategy: 2D transform for each axial slice. Then 1D transform for each
% axial line. I need to find a faster way to do that with 3D convolutions
% of wavelet filters, this is too slow now. Using GPUs would be ideal.


% INPUTS
% - vol: 3D array to filter
% - wavelet_name: Char array defining the 'waveletname'
% - level: level of decomposition
% - L_filt: Low-pass decomposition filter (optional)
% - H_filt: High-pass decomposition filter (optional)


% INITIALIZATION
if nargin < 4
    wav1 = wavelet_name; 
    wav2 = []; % This works with swt2, but not with swt
    wav2_hack = ''; % Will use this with the eval function to solve the problem with swt.
else
    wav1 = L_filt;
    wav2 = H_filt;
    wav2_hack = ',H_filt'; % Will use this with the eval function to solve the problem with swt.
end

% *************************************************************************
% STEP 1: MAKING SURE THE VOLUME HAS EVEN SIZE (necessary for swt2)
% Adding a layer identical to the last one of the volume. This should not
% create problems for sufficiently large bounding boxes. Is box10 ok?
remove = zeros(1,3);
sizeV = size(vol);
if mod(sizeV(1),2)
    volTemp = zeros(sizeV(1)+1,sizeV(2),sizeV(3));
    volTemp(1:end-1,:,:) = vol;
    volTemp(end,:,:) = squeeze(vol(end,:,:));
    vol = volTemp;
    remove(1) = true;
end
sizeV = size(vol);
if mod(sizeV(2),2)
    volTemp = zeros(sizeV(1),sizeV(2)+1,sizeV(3));
    volTemp(:,1:end-1,:) = vol;
    volTemp(:,end,:) = squeeze(vol(:,end,:));
    vol = volTemp;
    remove(2) = true;
end
sizeV = size(vol);
if mod(sizeV(3),2)
    volTemp = zeros(sizeV(1),sizeV(2),sizeV(3)+1);
    volTemp(:,:,1:end-1) = vol;
    volTemp(:,:,end) = squeeze(vol(:,:,end));
    vol = volTemp;
    remove(3) = true;
end
% -------------------------------------------------------------------------



% *************************************************************************
% STEP 2: COMPUTE ALL SUB-BANDS

% Initialization
sizeV = size(vol);
subbands = struct; names = {'LLL','LLH','LHL','LHH','HLL','HLH','HHL','HHH'}; nSub = numel(names);
wavNameSave = replaceCharacter(wavelet_name,'.','dot');
for s = 1:nSub
    names{s} = [names{s},'_',wavNameSave];
    subbands.(names{s}) = zeros(sizeV);
end

% First pass using 2D stationary wavelet transform in axial direction
for k = 1:sizeV(3)
    [LL,LH,HL,HH] = swt2(vol(:,:,k),level,wav1,wav2); 
    subbands.(['LLL_',wavNameSave])(:,:,k) = LL(:,:,level); subbands.(['LLH_',wavNameSave])(:,:,k) = LL(:,:,level);
    subbands.(['LHL_',wavNameSave])(:,:,k) = LH(:,:,level); subbands.(['LHH_',wavNameSave])(:,:,k) = LH(:,:,level);
    subbands.(['HLL_',wavNameSave])(:,:,k) = HL(:,:,level); subbands.(['HLH_',wavNameSave])(:,:,k) = HL(:,:,level);
    subbands.(['HHL_',wavNameSave])(:,:,k) = HH(:,:,level); subbands.(['HHH_',wavNameSave])(:,:,k) = HH(:,:,level);
end

% Second pass using 1D stationary wavelet transform for all axial lines
for j = 1:sizeV(2)
    for i = 1:sizeV(1)
        vector = squeeze(subbands.(['LLL_',wavNameSave])(i,j,:)); 
        eval(['[L,H] = swt(vector,level,wav1',wav2_hack,');']);
        subbands.(['LLL_',wavNameSave])(i,j,:) = L(level,:); subbands.(['LLH_',wavNameSave])(i,j,:) = H(level,:);
        vector = squeeze(subbands.(['LHL_',wavNameSave])(i,j,:)); 
        eval(['[L,H] = swt(vector,level,wav1',wav2_hack,');']);
        subbands.(['LHL_',wavNameSave])(i,j,:) = L(level,:); subbands.(['LHH_',wavNameSave])(i,j,:) = H(level,:);
        vector = squeeze(subbands.(['HLL_',wavNameSave])(i,j,:)); 
        eval(['[L,H] = swt(vector,level,wav1',wav2_hack,');']);
        subbands.(['HLL_',wavNameSave])(i,j,:) = L(level,:); subbands.(['HLH_',wavNameSave])(i,j,:) = H(level,:);
        vector = squeeze(subbands.(['HHL_',wavNameSave])(i,j,:)); 
        eval(['[L,H] = swt(vector,level,wav1',wav2_hack,');']);
        subbands.(['HHL_',wavNameSave])(i,j,:) = L(level,:); subbands.(['HHH_',wavNameSave])(i,j,:) = H(level,:);
    end
end
% -------------------------------------------------------------------------



% *************************************************************************
% STEP 3: REMOVING UNECESSARY DATA ADDED IN STEP 1
if remove(1)
    for s = 1:nSub
        subbands.(names{s}) = subbands.(names{s})(1:end-1,:,:);
    end
end
if remove(2)
    for s = 1:nSub
        subbands.(names{s}) = subbands.(names{s})(:,1:end-1,:);
    end
end
if remove(3)
    for s = 1:nSub
        subbands.(names{s}) = subbands.(names{s})(:,:,1:end-1);
    end
end
% -------------------------------------------------------------------------

end
