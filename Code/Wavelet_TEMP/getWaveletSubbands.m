function [subbands] = getWaveletSubbands(vol,waveletName)

% IMPORTANT: 
% - THIS FUNCTION IS TEMPORARY AND NEEDS BENCHMARKING. ALSO, IT
% ONLY WORKS WITH AXIAL SCANS FOR NOW. USING DICOM CONVENTIONS, OBVIOUSLY
% (NOT MATLAB).
% - Strategy: 2D transform for each axial slice. Then 1D transform for each
% axial line. I need to find a faster way to do that with 3D convolutions
% of wavelet filters, this is too slow now. Using GPUs would be ideal.



% INITIALIZATION
level = 1; % Always performing 1 decomposition level


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
wavNameSave = replaceCharacter(waveletName,'.','dot');
for s = 1:nSub
    names{s} = [names{s},'_',wavNameSave];
    subbands.(names{s}) = zeros(sizeV);
end

% First pass using 2D stationary wavelet transform in axial direction
for k = 1:sizeV(3)
    [LL,LH,HL,HH] = swt2(vol(:,:,k),1,waveletName); 
    subbands.(['LLL_',wavNameSave])(:,:,k) = LL; subbands.(['LLH_',wavNameSave])(:,:,k) = LL;
    subbands.(['LHL_',wavNameSave])(:,:,k) = LH; subbands.(['LHH_',wavNameSave])(:,:,k) = LH;
    subbands.(['HLL_',wavNameSave])(:,:,k) = HL; subbands.(['HLH_',wavNameSave])(:,:,k) = HL;
    subbands.(['HHL_',wavNameSave])(:,:,k) = HH; subbands.(['HHH_',wavNameSave])(:,:,k) = HH;
end

% Second pass using 1D stationary wavelet transform for all axial lines
for j = 1:sizeV(2)
    for i = 1:sizeV(1)
        vector = squeeze(subbands.(['LLL_',wavNameSave])(i,j,:)); [L,H] = swt(vector,1,waveletName);
        subbands.(['LLL_',wavNameSave])(i,j,:) = L; subbands.(['LLH_',wavNameSave])(i,j,:) = H;
        vector = squeeze(subbands.(['LHL_',wavNameSave])(i,j,:)); [L,H] = swt(vector,1,waveletName);
        subbands.(['LHL_',wavNameSave])(i,j,:) = L; subbands.(['LHH_',wavNameSave])(i,j,:) = H;
        vector = squeeze(subbands.(['HLL_',wavNameSave])(i,j,:)); [L,H] = swt(vector,1,waveletName);
        subbands.(['HLL_',wavNameSave])(i,j,:) = L; subbands.(['HLH_',wavNameSave])(i,j,:) = H;
        vector = squeeze(subbands.(['HHL_',wavNameSave])(i,j,:)); [L,H] = swt(vector,1,waveletName);
        subbands.(['HHL_',wavNameSave])(i,j,:) = L; subbands.(['HHH_',wavNameSave])(i,j,:) = H;
    end
end
% -------------------------------------------------------------------------



% *************************************************************************
% STEP 2: REMOVING UNECESSARY DATA ADDED IN STEP 1
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




% PARKED FOR TESTS --> USING AVERAGE OF 2D TRANSFORMS IN ALL 3D DIRECTIONS
% % Second pass using 2D stationary wavelet transform in coronal direction
% for i = 1:sizeV(1)
%     [LL,LH,HL,HH] = swt2(squeeze(vol(i,:,:))',1,wavelet);
%     for k = 1:sizeV(3)
%         subbands.LLL(i,:,k) = subbands.LLL(i,:,k) + LL(k,:);
%         subbands.LLH(i,:,k) = subbands.LLH(i,:,k) + LH(k,:);
%         subbands.LHL(i,:,k) = subbands.LHL(i,:,k) + LL(k,:);
%         subbands.LHH(i,:,k) = subbands.LHH(i,:,k) + LH(k,:);
%         subbands.HLL(i,:,k) = subbands.HLL(i,:,k) + HL(k,:);
%         subbands.HLH(i,:,k) = subbands.HLH(i,:,k) + HH(k,:);
%         subbands.HHL(i,:,k) = subbands.HHL(i,:,k) + HL(k,:);
%         subbands.HHH(i,:,k) = subbands.HHH(i,:,k) + HH(k,:);
%     end
% end
% 
% % Third pass using 2D stationary wavelet transform in sagittal direction
% for j = 1:sizeV(2)
%     [LL,LH,HL,HH] = swt2(squeeze(vol(:,j,:)),1,wavelet);
%     for k = 1:sizeV(3)
%         subbands.LLL(:,j,k) = subbands.LLL(:,j,k) + LL(:,k);
%         subbands.LLH(:,j,k) = subbands.LLH(:,j,k) + HL(:,k);
%         subbands.LHL(:,j,k) = subbands.LHL(:,j,k) + LH(:,k);
%         subbands.LHH(:,j,k) = subbands.LHH(:,j,k) + HH(:,k);
%         subbands.HLL(:,j,k) = subbands.HLL(:,j,k) + LL(:,k);
%         subbands.HLH(:,j,k) = subbands.HLH(:,j,k) + HL(:,k);
%         subbands.HHL(:,j,k) = subbands.HHL(:,j,k) + LH(:,k);
%         subbands.HHH(:,j,k) = subbands.HHH(:,j,k) + HH(:,k);
%     end
% end
% 
% % Dividing each subband by 3 (3 times 2D passes)
% for s = 1:nSub
%     subbands.(names{s}) = subbands.(names{s})/3; 
% end