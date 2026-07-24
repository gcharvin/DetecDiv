function out = classify(roiobj, classif, ctx)
% trackastra.classify  Link an indexed instance-mask movie into tracklets.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end
out = trackastra.utils.outInitSafe('trackastra.classify');
trackastra.ensureClassMetadata(classif);
detecdiv_check_cancel(ctx, 'trackastra classify start');

p = trackastra.utils.defaultExecutionParam();
try
    if isprop(classif,'executionParam') && isstruct(classif.executionParam)
        p = trackastra.utils.applyParamOverrides(p, classif.executionParam);
    end
catch
end
if isfield(ctx,'params') && isstruct(ctx.params)
    runtimeParams = ctx.params;
    artifactKeys = {'modelSource','customModelPath','checkpointPath','pythonExecutable'};
    present = artifactKeys(isfield(runtimeParams,artifactKeys));
    if ~isempty(present), runtimeParams = rmfield(runtimeParams,present); end
    p = trackastra.utils.applyParamOverrides(p, runtimeParams);
end

if isempty(roiobj.image)
    roiobj.load;
end
if isempty(roiobj.image)
    error('trackastra:EmptyROI', 'ROI image data is empty.');
end

frames = resolveFrames(ctx, size(roiobj.image,4));
if numel(frames) > 1 && any(diff(frames) ~= 1)
    error('trackastra:NonContiguousFrames', ...
        'Trackastra requires a contiguous temporal selection. Got frames %s.', mat2str(frames));
end

imageName = scalarText(p.imageChannelName);
maskName = scalarText(p.instanceChannelName);
selected = selectedChannels(ctx);
if isempty(imageName) && ~isempty(selected)
    imageName = selected{1};
end
if isempty(maskName) && numel(selected) >= 2
    maskName = selected{2};
end
if isempty(imageName)
    error('trackastra:MissingImageBinding', ...
        'imageChannelName is required and must identify an intensity channel.');
end
if isempty(maskName)
    error('trackastra:MissingMaskBinding', ...
        'instanceChannelName is required and must identify an indexed instance-mask channel.');
end

imageIdx = firstChannelIndex(roiobj, imageName, 'image');
maskIdx = firstChannelIndex(roiobj, maskName, 'instance mask');
rawImages = squeeze(roiobj.image(:,:,imageIdx,frames));
instanceMasks = squeeze(roiobj.image(:,:,maskIdx,frames));
if numel(frames) == 1
    rawImages = reshape(rawImages, size(rawImages,1), size(rawImages,2), 1);
    instanceMasks = reshape(instanceMasks, size(instanceMasks,1), size(instanceMasks,2), 1);
end
validateInstanceMasks(instanceMasks, maskName);

outputName = scalarText(p.outputName);
if isfield(ctx,'names') && isstruct(ctx.names) && isfield(ctx.names,'outputName') && ~isempty(ctx.names.outputName)
    outputName = scalarText(ctx.names.outputName);
end
if isempty(outputName)
    outputName = 'trackastra';
end
channelName = outputChannelName(outputName);

workDir = resolveWorkDir(ctx, classif, roiobj);
inputPath = fullfile(workDir, 'trackastra_input.mat');
resultPath = fullfile(workDir, 'trackastra_results.mat');
configPath = fullfile(workDir, 'trackastra_config.json');
save(inputPath, 'rawImages', 'instanceMasks', 'frames', '-v7');

cfg = struct();
cfg.input_mat_path = slashPath(inputPath);
cfg.output_mat_path = slashPath(resultPath);
cfg.edge_csv_path = slashPath(fullfile(workDir, 'trackastra_edges.csv'));
cfg.candidate_edge_csv_path = slashPath(fullfile(workDir, 'trackastra_candidate_edges.csv'));
cfg.model_source = normalizedChoice(p.modelSource, {'pretrained','custom'}, 'pretrained');
cfg.pretrained_model = scalarText(p.pretrainedModel);
cfg.custom_model_path = slashPath(resolveArtifactPath(classif, p.customModelPath));
cfg.checkpoint_path = slashPath(resolveArtifactPath(classif, p.checkpointPath));
cfg.tracking_mode = normalizedChoice(p.trackingMode, {'greedy','greedy_nodiv','ilp'}, 'greedy');
cfg.device = normalizedChoice(p.device, {'automatic','cuda','cpu','mps'}, 'automatic');
cfg.batch_size = nonnegativeInteger(p.batchSize, 0, 'batchSize');
cfg.n_workers = nonnegativeInteger(p.nWorkers, 0, 'nWorkers');
cfg.max_distance = nonnegativeScalar(p.maxDistance, 0, 'maxDistance');
cfg.max_frame_gap = nonnegativeInteger(p.maxFrameGap, 1, 'maxFrameGap');
cfg.division_identity_mode = normalizedChoice(p.divisionIdentityMode, ...
    {'continuing_parent','symmetric'}, 'continuing_parent');
cfg.normalize_images = logicalScalar(p.normalizeImages, true);
cfg.cancel_path = cancelTokenFile(ctx);
cfg.progress_base = 0;
cfg.progress_span = 1;
cfg.progress_enabled = isfield(ctx, 'progressCallback') && ...
    isa(ctx.progressCallback, 'function_handle');
try
    if exist('detecdiv_progress_bounds', 'file') == 2
        [cfg.progress_base, cfg.progress_span] = ...
            detecdiv_progress_bounds(ctx);
        cfg.progress_span = 0.95 * cfg.progress_span;
    end
catch
    cfg.progress_base = 0;
    cfg.progress_span = 1;
end
writeJson(configPath, cfg);

pythonExe = trackastra.utils.resolvePythonExecutable(p.pythonExecutable, ctx);
scriptPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'classify_trackastra.py');
cmd = sprintf('"%s" "%s" "%s"', pythonExe, scriptPath, configPath);
fprintf('[Trackastra] input image=%s mask=%s frames=%d:%d model=%s mode=%s device=%s\n', ...
    imageName, maskName, frames(1), frames(end), modelDescription(cfg), cfg.tracking_mode, cfg.device);
[status, msg] = system(cmd, '-echo');
if status ~= 0
    error('trackastra:PythonFailed', 'Trackastra Python runner failed (%d):\n%s', status, msg);
end
detecdiv_check_cancel(ctx, 'trackastra classify after Python');
if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 0.95, ...
        'Trackastra inference complete; integrating tracks...', ...
        'Scope', 'integration');
end

if exist(resultPath,'file') ~= 2
    error('trackastra:MissingResults', 'Python runner did not write %s.', resultPath);
end
res = load(resultPath);
if ~isfield(res,'masks_tracked')
    error('trackastra:MissingTrackedMasks', 'Result file has no masks_tracked array.');
end
tracked = uint32(res.masks_tracked);
if ndims(tracked) == 2
    tracked = reshape(tracked, size(tracked,1), size(tracked,2), 1);
end
if size(tracked,1) ~= size(roiobj.image,1) || size(tracked,2) ~= size(roiobj.image,2) || size(tracked,3) ~= numel(frames)
    error('trackastra:ResultShapeMismatch', ...
        'Tracked mask shape %s does not match ROI selection [%d %d %d].', ...
        mat2str(size(tracked)), size(roiobj.image,1), size(roiobj.image,2), numel(frames));
end
if max(tracked(:)) > intmax('uint16')
    error('trackastra:TooManyTracklets', ...
        'Trackastra produced ID %u, above the uint16 ROI channel limit.', max(tracked(:)));
end

outImage = roiobj.image;
outIdx = roiobj.findChannelID(channelName);
if isempty(outIdx)
    emptyStack = zeros(size(outImage,1), size(outImage,2), 1, size(outImage,4), 'uint16');
    roiobj.addChannel(emptyStack, channelName, [1 1 1], [0 0 0]);
    outImage = roiobj.image;
    outIdx = roiobj.findChannelID(channelName);
end
outIdx = outIdx(1);
outImage(:,:,outIdx,frames) = reshape(uint16(tracked), size(tracked,1), size(tracked,2), 1, size(tracked,3));

out.data = roiobj.data;
out.image = outImage;
out.patch = [];
out.status = "OK";
out.artifacts.workDir = workDir;
out.artifacts.edges = fullfile(workDir, 'trackastra_edges.csv');
out.artifacts.candidateEdges = fullfile(workDir, 'trackastra_candidate_edges.csv');
out.metrics.trackletCount = double(max(tracked(:)));
out.metrics.frameCount = numel(frames);
out.metrics.gapClosingEdges = 0;
try, out.metrics.gapClosingEdges = double(res.n_gap_edges); catch, end
if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 1, ...
        sprintf('Integrated %d Trackastra frames.', numel(frames)), ...
        'Scope', 'integration');
end
end

function frames = resolveFrames(ctx, nFrames)
frames = [];
if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'frames')
    frames = ctx.sel.frames;
elseif isfield(ctx,'frames')
    frames = ctx.frames;
end
if isempty(frames) || isequal(frames,-1)
    frames = 1:nFrames;
else
    frames = unique(round(double(frames(:)')), 'stable');
    frames = frames(isfinite(frames) & frames >= 1 & frames <= nFrames);
end
if isempty(frames)
    error('trackastra:EmptyFrameSelection', 'No valid frame is selected.');
end
end

function channels = selectedChannels(ctx)
channels = {};
if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'channels')
    value = ctx.sel.channels;
    if ischar(value) || isstring(value)
        channels = cellstr(string(value(:)));
    elseif iscell(value)
        channels = cellfun(@(x) char(string(x)), value(:)', 'UniformOutput', false);
    end
end
channels = channels(~cellfun(@isempty, channels));
end

function idx = firstChannelIndex(roiobj, name, role)
idx = roiobj.findChannelID(name);
if iscell(idx), idx = cell2mat(idx); end
if isempty(idx)
    error('trackastra:ChannelNotFound', 'Trackastra %s channel "%s" was not found in the ROI.', role, name);
end
idx = idx(1);
end

function validateInstanceMasks(masks, name)
values = double(masks(:));
if any(~isfinite(values)) || any(values < 0) || any(abs(values-round(values)) > 1e-6)
    error('trackastra:InvalidInstanceMasks', ...
        'Channel "%s" must contain finite, non-negative integer instance labels.', name);
end
end

function name = outputChannelName(outputName)
if startsWith(outputName, 'results_', 'IgnoreCase', true)
    name = outputName;
else
    name = ['results_' outputName];
end
end

function workDir = resolveWorkDir(ctx, classif, roiobj)
base = '';
if isfield(ctx,'workDir') && ~isempty(ctx.workDir)
    base = char(string(ctx.workDir));
end
if isempty(base)
    try
        base = fullfile(classif.path, 'work', 'trackastra');
    catch
        base = fullfile(tempdir, 'detecdiv_trackastra');
    end
end
roiId = 'roi';
try, roiId = char(string(roiobj.id)); catch, end
roiId = regexprep(roiId, '[^A-Za-z0-9_.-]', '_');
workDir = fullfile(base, roiId);
if exist(workDir,'dir') ~= 7, mkdir(workDir); end
end

function writeJson(pathValue, value)
fid = fopen(pathValue,'w');
if fid < 0, error('trackastra:ConfigWriteFailed','Unable to write %s.',pathValue); end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(value, 'PrettyPrint', true), 'char');
end

function txt = scalarText(value)
while iscell(value)
    value = value(~cellfun(@isempty,value));
    if isempty(value), txt = ''; return; end
    value = value{end};
end
txt = strtrim(char(string(value)));
end

function out = normalizedChoice(value, allowed, fallback)
out = lower(strrep(strrep(scalarText(value),'-','_'),' ','_'));
if ~any(strcmp(out,allowed)), out = fallback; end
end

function value = nonnegativeInteger(raw, fallback, name)
value = round(nonnegativeScalar(raw, fallback, name));
end

function value = nonnegativeScalar(raw, fallback, name)
if iscell(raw) && ~isempty(raw), raw = raw{end}; end
value = double(raw);
if isempty(value), value = fallback; end
if ~isscalar(value) || ~isfinite(value) || value < 0
    error('trackastra:InvalidParameter', '%s must be a non-negative scalar.', name);
end
end

function value = logicalScalar(raw, fallback)
if iscell(raw) && ~isempty(raw), raw = raw{end}; end
if isempty(raw), value = fallback; return; end
if ischar(raw) || isstring(raw)
    value = any(strcmpi(strtrim(char(string(raw))), {'true','yes','on','1'}));
else
    value = logical(raw(1));
end
end

function pathValue = slashPath(pathValue)
pathValue = strrep(char(string(pathValue)), '\', '/');
end

function pathValue = resolveArtifactPath(classif, pathValue)
pathValue = scalarText(pathValue);
if isempty(pathValue) || isAbsolutePath(pathValue), return; end
try
    if isprop(classif,'path') && ~isempty(classif.path)
        pathValue = fullfile(char(string(classif.path)),pathValue);
    end
catch
end
end

function tf = isAbsolutePath(pathValue)
tf = ~isempty(regexp(pathValue,'^[A-Za-z]:[\\/]', 'once')) || ...
    startsWith(pathValue,'\\') || startsWith(pathValue,'/');
end

function value = cancelTokenFile(ctx)
value = '';
if isfield(ctx,'cancel') && isstruct(ctx.cancel) && isfield(ctx.cancel,'tokenFile')
    value = slashPath(ctx.cancel.tokenFile);
end
end

function txt = modelDescription(cfg)
if strcmp(cfg.model_source,'custom')
    txt = cfg.custom_model_path;
else
    txt = cfg.pretrained_model;
end
end
