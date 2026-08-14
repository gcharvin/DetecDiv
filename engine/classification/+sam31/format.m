function out = format(classif, rois, ctx)
% sam31.format  Export DetecDiv annotations to the SAM3.1 CTC source layout.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end
out = sam31.utils.outInitSafe('sam31.format');

if isempty(classif.trainingParam)
    classif.trainingParam = sam31.utils.defaultTrainingParam();
end
if isfield(ctx,'params') && isstruct(ctx.params)
    classif.trainingParam = sam31.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end
sam31.ensureClassMetadata(classif);

if nargin < 2 || isempty(rois)
    try
        rois = classif.dataset.split.train;
    catch
        rois = classif.trainingset;
    end
end
trainrois = rois;
valrois = [];
testrois = [];
try
    if isprop(classif,'dataset') && isstruct(classif.dataset) && ...
            isfield(classif.dataset,'split') && isfield(classif.dataset.split,'val')
        valrois = classif.dataset.split.val;
        if isfield(classif.dataset.split,'test')
            testrois = classif.dataset.split.test;
        end
    end
catch
end
trainrois = normalizeRoiList(trainrois, numel(classif.roi));
valrois = normalizeRoiList(valrois, numel(classif.roi));
testrois = normalizeRoiList(testrois, numel(classif.roi));

frames = [];
if isfield(ctx, 'sel') && isstruct(ctx.sel) && isfield(ctx.sel, 'frames')
    frames = ctx.sel.frames;
elseif isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'Frames')
    frames = ctx.params.Frames;
elseif isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'frames')
    frames = ctx.params.frames;
end

if ~isempty(testrois)
    beforeTrain = trainrois;
    beforeVal = valrois;
    trainrois = setdiff(trainrois, testrois, 'stable');
    valrois = setdiff(valrois, testrois, 'stable');
    if numel(trainrois) ~= numel(beforeTrain) || numel(valrois) ~= numel(beforeVal)
        warning('sam31:TestRoisExcludedFromTrainingExport', ...
            'SAM31 format excluded test ROI(s) from the training/validation framebank: %s', ...
            strjoin(cellstr(string(testrois)), ', '));
    end
end
if isempty(valrois)
    valFraction = sam31ValidationFraction(classif.trainingParam);
    [trainrois, valrois, frames] = splitTrainValidationRois( ...
        classif,trainrois,valFraction,frames);
end

foldername = 'trainingdataset';
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'foldername')
    foldername = char(string(ctx.params.foldername));
end

internal = sam31.utils.internalDefaults();
writeLegacyCtc = logical(sam31.utils.getParam(internal, 'writeLegacyCtc', false));
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'writeLegacyCtc')
    writeLegacyCtc = logical(ctx.params.writeLegacyCtc);
end

ctcSubfolder = sam31.utils.getParam(classif.trainingParam, 'ctcSubfolder', '');
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'ctcSubfolder')
    ctcSubfolder = ctx.params.ctcSubfolder;
end
ctcSubfolder = char(string(ctcSubfolder));

framebankOut = sam31.exportFramebankDataset(classif, trainrois, valrois, ...
    'foldername', foldername, ...
    'Frames', frames, ...
    'writePreview', true);

out.status = "OK";
out.artifacts.layout = 'sam31_framebank_json';
out.artifacts.sam31DirectRoot = fullfile(classif.path, foldername);
out.artifacts.framebank = framebankOut.framebank;
out.artifacts.manTrackParentage = true;
out.metrics.framebankFrames = framebankOut.frames;
if isfield(framebankOut, 'skippedEmptyMaskFrames')
    out.metrics.skippedEmptyMaskFrames = framebankOut.skippedEmptyMaskFrames;
end
if isfield(framebankOut, 'skippedEmptyMaskDetails')
    out.metrics.skippedEmptyMaskDetails = framebankOut.skippedEmptyMaskDetails;
end

if writeLegacyCtc
    output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois, ...
        'layoutMode', "split_root", ...
        'datasetSubfolder', ctcSubfolder, ...
        'runQA', false, ...
        'qa_write_png', false, ...
        'runCocoConversion', false, ...
        'writeOverlayMovies', false);
    if isempty(strtrim(ctcSubfolder)) || strcmp(strtrim(ctcSubfolder), '.')
        out.artifacts.ctcRoot = fullfile(classif.path, foldername);
    else
        out.artifacts.ctcRoot = fullfile(classif.path, foldername, ctcSubfolder);
    end
    out.artifacts.legacyCtcWritten = true;
    if isnumeric(output)
        out.metrics.legacyCtcFrameCount = output;
    end
else
    out.artifacts.legacyCtcWritten = false;
end

function rois = normalizeRoiList(rois, nRois)
if isempty(rois)
    rois = [];
    return;
end
rois = unique(round(double(rois(:)')), 'stable');
rois = rois(isfinite(rois) & rois >= 1 & rois <= nRois);
end

function value = sam31ValidationFraction(tp)
value = 0.2;
try
    if isstruct(tp) && isfield(tp, 'validationFraction') && ~isempty(tp.validationFraction)
        raw = tp.validationFraction;
        if iscell(raw)
            raw = raw{end};
        end
        value = str2double(char(string(raw)));
    end
catch
    value = 0.2;
end
if ~isfinite(value)
    value = 0.2;
end
value = min(max(value, 0), 0.5);
end

function [trainrois, valrois, frames] = splitTrainValidationRois(classif,trainrois,valFraction,frames)
valrois = [];
if isempty(trainrois) || valFraction <= 0
    return;
end
if isscalar(trainrois)
    roiIndex = trainrois(1);
    frameCount = annotationManager.frameCount(classif.roi(roiIndex));
    selectedFrames = normalizeTrainingFrameSelection(frames,frameCount, ...
        'RoiId',roiIndex,'RoiPosition',1,'SplitName','train');
    [trainFrames, valFrames] = splitSelectedFramesForValidation( ...
        selectedFrames,valFraction);
    if isempty(trainFrames) || isempty(valFrames)
        valrois = trainrois;
        warning('sam31:ValidationSplitSingleRoi', ...
            ['Only one training ROI is available and no selected frame list could be split; ' ...
            'reusing it for SAM31 validation. Add more training ROIs for an independent validation split.']);
        return;
    end
    valrois = trainrois;
    frames = struct('train', trainFrames, 'val', valFrames);
    fprintf(['[SAM31 format] Only one training ROI is available; using disjoint selected frames ' ...
        'for internal validation (%d train, %d val). Test ROIs remain excluded.\n'], ...
        numel(trainFrames), numel(valFrames));
    return;
end
nVal = max(1, round(numel(trainrois) * valFraction));
nVal = min(nVal, numel(trainrois) - 1);
valrois = trainrois(end-nVal+1:end);
trainrois = trainrois(1:end-nVal);
fprintf('[SAM31 format] No explicit validation split; using %d/%d training ROI(s) as internal validation. Test ROIs remain excluded.\n', ...
    numel(valrois), numel([trainrois valrois]));
end

function [trainFrames, valFrames] = splitSelectedFramesForValidation(frames, valFraction)
trainFrames = [];
valFrames = [];
if isempty(frames) || isstruct(frames) || iscell(frames) || islogical(frames)
    return;
end
if ischar(frames) || isstring(frames)
    txt = strtrim(char(string(frames)));
    if isempty(txt) || any(strcmpi(txt, {'all', '0', '-1'}))
        return;
    end
    frames = str2num(strrep(txt, ',', ' ')); %#ok<ST2NM>
end
if ~isnumeric(frames)
    return;
end
frames = unique(round(double(frames(:).')), 'stable');
frames = frames(isfinite(frames) & frames >= 1);
if numel(frames) < 2
    return;
end
nVal = max(1, round(numel(frames) * valFraction));
nVal = min(nVal, numel(frames) - 1);
valFrames = frames(end-nVal+1:end);
trainFrames = frames(1:end-nVal);
end
end
