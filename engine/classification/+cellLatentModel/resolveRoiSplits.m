function [trainRois,valRois,testRois,audit] = resolveRoiSplits( ...
        classif,requested,fraction)
%CELLLATENTMODEL.RESOLVEROISPLITS Resolve an auditable whole-ROI split.
% Explicit dataset.split.val entries always win.  When validation is not
% configured, validation ROIs are selected by a stable SHA-256 ranking of
% ROI identity rather than by their position in classifierGUI.

if nargin < 2, requested = []; end
if nargin < 3 || isempty(fraction), fraction = 0.2; end
n = numel(classif.roi);
trainCandidates = normalizeIndices(requested,n);
if isempty(trainCandidates)
    try
        trainCandidates = normalizeIndices(classif.dataset.split.train,n);
    catch
    end
end
if isempty(trainCandidates)
    try
        trainCandidates = normalizeIndices(classif.trainingset,n);
    catch
    end
end
explicitVal = [];
testRois = [];
try
    explicitVal = normalizeIndices(classif.dataset.split.val,n);
    testRois = normalizeIndices(classif.dataset.split.test,n);
catch
end

% Split isolation is defined by stable ROI identity, not merely by the
% current table index.  Duplicate IDs would let the same scientific
% sequence cross train/validation/test under two indices and would make the
% approval snapshot impossible to resolve unambiguously at training time.
assertUniqueStableIdentities(classif,unique( ...
    [trainCandidates explicitVal testRois],'stable'));

% Test ROIs are never eligible for either fitting or model selection.
trainCandidates = setdiff(trainCandidates,testRois,'stable');
explicitVal = setdiff(explicitVal,testRois,'stable');
selectionPool = trainCandidates;
rankedRois = [];
rankedHashes = {};
seed = 'detecdiv-cell-latent-validation-v1';
if ~isempty(explicitVal)
    valRois = explicitVal;
    trainRois = setdiff(trainCandidates,valRois,'stable');
    mode = 'explicit';
    algorithm = 'classifier_dataset_split_val';
    targetCount = numel(valRois);
else
    valRois = [];
    trainRois = trainCandidates;
    mode = 'none';
    algorithm = 'none';
    targetCount = 0;
    if numel(trainCandidates) > 1
        fraction = validationFraction(fraction);
        targetCount = max(1,min(numel(trainCandidates)-1, ...
            round(numel(trainCandidates)*fraction)));
        [rankedRois,rankedHashes] = stableRanking( ...
            classif,trainCandidates,seed);
        chosen = rankedRois(1:targetCount);
        % Preserve classifier order for formatter readability.  Membership,
        % not table order, was decided by the stable identity ranking above.
        valRois = trainCandidates(ismember(trainCandidates,chosen));
        trainRois = setdiff(trainCandidates,valRois,'stable');
        mode = 'automatic';
        algorithm = 'sha256_ranked_stable_roi_identity_v1';
    end
end

allModelSelectionRois = unique([trainRois valRois],'stable');
audit = struct( ...
    'schema_version',1, ...
    'unit','whole_roi', ...
    'mode',mode, ...
    'algorithm',algorithm, ...
    'algorithm_seed',seed, ...
    'stable_identity_contract','roi.id', ...
    'requested_validation_fraction',double(fraction), ...
    'target_validation_roi_count',double(targetCount), ...
    'test_excluded_before_selection',true, ...
    'table_order_independent',true, ...
    'candidate_roi_indices',double(selectionPool), ...
    'candidate_roi_ids',{roiIds(classif,selectionPool)}, ...
    'ranked_candidate_roi_indices',double(rankedRois), ...
    'ranked_candidate_roi_ids',{roiIds(classif,rankedRois)}, ...
    'ranked_candidate_sha256',{rankedHashes}, ...
    'train_roi_indices',double(trainRois), ...
    'train_roi_ids',{roiIds(classif,trainRois)}, ...
    'validation_roi_indices',double(valRois), ...
    'validation_roi_ids',{roiIds(classif,valRois)}, ...
    'test_roi_indices',double(testRois), ...
    'test_roi_ids',{roiIds(classif,testRois)}, ...
    'counts',struct( ...
        'candidate_rois',double(numel(selectionPool)), ...
        'train_rois',double(numel(trainRois)), ...
        'validation_rois',double(numel(valRois)), ...
        'test_rois',double(numel(testRois))), ...
    'actual_validation_roi_fraction',safeFraction( ...
        numel(valRois),numel(allModelSelectionRois)));
end

function value = validationFraction(value)
value = double(value);
if ~isscalar(value) || ~isfinite(value) || value <= 0 || value >= 1
    error('cellLatentModel:InvalidValidationFraction', ...
        'Automatic validation fraction must be strictly between 0 and 1.');
end
end

function [ranked,hashes] = stableRanking(classif,indices,seed)
identities = cell(1,numel(indices));
hashes = cell(1,numel(indices));
for i = 1:numel(indices)
    roiobj = classif.roi(indices(i));
    roiId = objectText(roiobj,'id');
    identities{i} = roiId;
    hashes{i} = sha256Text(sprintf('%s\n%s',seed,identities{i}));
end
[~,order] = sort(string(hashes));
ranked = indices(order);
hashes = hashes(order);
end

function assertUniqueStableIdentities(classif,indices)
ids=string(roiIds(classif,indices));
uniqueIds=unique(ids,'stable');
counts=zeros(size(uniqueIds));
for index=1:numel(uniqueIds)
    counts(index)=nnz(ids==uniqueIds(index));
end
duplicates=uniqueIds(counts>1);
if isempty(duplicates),return;end
error('cellLatentModel:DuplicateStableRoiIdentity', ...
    ['ROI IDs must be unique across train, validation and test. Duplicate ' ...
     'stable identities: %s. Repair the classifier ROI table first.'], ...
    strjoin(cellstr(duplicates),', '));
end

function value = sha256Text(text)
bytes = unicode2native(char(string(text)),'UTF-8');
digest = java.security.MessageDigest.getInstance('SHA-256');
hash = typecast(digest.digest(bytes),'uint8');
value = lower(reshape(dec2hex(hash,2).',1,[]));
end

function values = roiIds(classif,indices)
indices = double(indices(:).');
values = cell(1,numel(indices));
for i = 1:numel(indices)
    values{i} = objectText(classif.roi(indices(i)),'id');
end
end

function value = objectText(obj,name)
value = '';
try value = char(string(obj.(name))); catch, end
end

function value = safeFraction(numerator,denominator)
if denominator <= 0, value = 0; else, value = numerator/denominator; end
end

function out = normalizeIndices(value,n)
if isempty(value), out = []; return; end
out = unique(round(double(value(:)')),'stable');
out = out(isfinite(out) & out >= 1 & out <= n);
end
