function ctx = process(ctx)
%movieExport.process  Render a Score or raw-FOV export without a GUI.
%
% This is deliberately an exporter node, rather than a processor: a Score
% mosaic needs the whole ROI selection at once and must not run ROI-by-ROI.

if nargin < 1 || ~isstruct(ctx)
    error('movieExport:MissingContext', 'A pipeline execution context is required.');
end
params = localParams(ctx);
sourceType = lower(strtrim(char(string(localField(params, 'sourceType', 'score_roi')))));

switch sourceType
    case {'score_roi','score_classifier'}
        [outputPath, kind] = localRenderScore(ctx, params);
    case 'raw_fov'
        [outputPath, kind] = localRenderRawFov(ctx, params);
    otherwise
        error('movieExport:UnknownSource', 'Unsupported movie source type: %s', sourceType);
end

ctx = localAddArtifact(ctx, kind, outputPath);
end

function [outputPath, kind] = localRenderScore(ctx, params)
rois = localSelectedRois(ctx, params);
if isempty(rois)
    error('movieExport:NoROI', 'The movie export has no selected ROI.');
end
opts = localField(params, 'layoutOptions', struct());
if ~isstruct(opts) || isempty(fieldnames(opts))
    error('movieExport:MissingRecipe', 'Score movie layout options are required.');
end
mode = localOutputMode(params, opts);
opts.mode = lower(mode);
opts.name = localResolveOutputPath(ctx, params, mode);

% score_createDisplayHandles historically creates its own figure in movie
% mode. It now honours this invisible canvas, which makes the same renderer
% usable locally and on a headless Hub MATLAB worker.
fig = figure('Visible', 'off', 'Color', localField(opts, 'background', [0 0 0]), ...
    'IntegerHandle', 'off', 'HandleVisibility', 'callback');
cleaner = onCleanup(@()localCloseFigure(fig)); %#ok<NASGU>
handles = score_createDisplayHandles(opts, fig);
score_renderFinalFrame(handles, rois, opts);
outputPath = localFinalOutputPath(opts.name, mode);
kind = localArtifactKind(mode);
end

function [outputPath, kind] = localRenderRawFov(ctx, params)
shallowObj = localShallow(ctx);
if isempty(shallowObj)
    error('movieExport:NoProject', 'Raw-FOV movie export requires a shallow project.');
end
raw = localField(params, 'raw', struct());
fovIndex = localPositiveInteger(localField(raw, 'fovIndex', 1), 1);
if fovIndex > numel(shallowObj.fov)
    error('movieExport:BadFov', 'Selected raw FOV %d does not exist.', fovIndex);
end
fovObj = shallowObj.fov(fovIndex);
cfg = localField(raw, 'channelCfg', struct([]));
if isempty(cfg)
    error('movieExport:NoChannel', 'Select at least one raw display channel.');
end
frames = localFrames(localField(raw, 'frames', []), fovObj);
if isempty(frames)
    error('movieExport:NoFrame', 'No raw frame is available for this export.');
end
mode = localOutputMode(params, struct());
outputPath = localResolveOutputPath(ctx, params, mode);
fig = figure('Visible', 'off', 'Color', 'black', 'IntegerHandle', 'off', ...
    'HandleVisibility', 'callback');
cleaner = onCleanup(@()localCloseFigure(fig)); %#ok<NASGU>
ax = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off');
titleText = char(string(localField(raw, 'title', '')));

if strcmpi(mode, 'Sequence')
    outputPath = localWithExtension(outputPath, '.pdf');
    for i = 1:numel(frames)
        rgb = localRawBlend(fovObj, frames(i), cfg);
        image(ax, rgb); axis(ax, 'image'); ax.Visible = 'off';
        if ~isempty(titleText), title(ax, sprintf('%s | frame %d', titleText, frames(i)), 'Color', 'w', 'Interpreter', 'none'); end
        drawnow;
        if i == 1
            exportgraphics(fig, outputPath, 'ContentType', 'image');
        else
            exportgraphics(fig, outputPath, 'ContentType', 'image', 'Append', true);
        end
    end
    kind = 'movie_sequence_pdf';
    return;
end

[writer, outputPath] = localOpenVideoWriter(outputPath, localField(raw, 'framesPerSecond', 10));
writerCleanup = onCleanup(@()localCloseWriter(writer)); %#ok<NASGU>
for i = 1:numel(frames)
    rgb = localRawBlend(fovObj, frames(i), cfg);
    image(ax, rgb); axis(ax, 'image'); ax.Visible = 'off';
    if ~isempty(titleText), title(ax, sprintf('%s | frame %d', titleText, frames(i)), 'Color', 'w', 'Interpreter', 'none'); end
    drawnow;
    writeVideo(writer, im2uint8(rgb));
end
close(writer);
kind = 'movie_mp4';
end

function rgb = localRawBlend(fovObj, frame, cfg)
images = cell(1, numel(cfg));
for i = 1:numel(cfg)
    if ~logical(localField(cfg(i), 'enabled', true))
        continue;
    end
    images{i} = readImage(fovObj, frame, i);
end
rgb = workflowui.composeBlendImage(images, cfg);
if isempty(rgb)
    error('movieExport:RawFrame', 'Could not compose raw frame %d.', frame);
end
end

function [writer, pathOut] = localOpenVideoWriter(pathIn, fps)
profiles = VideoWriter.getProfiles;
names = {profiles.Name};
profile = 'MPEG-4';
if ~ismember(profile, names)
    preferred = {'MPEG-4','Motion JPEG AVI','Uncompressed AVI'};
    profile = preferred{find(ismember(preferred, names), 1, 'first')};
end
if isempty(profile), profile = names{1}; end
if strcmp(profile, 'MPEG-4')
    pathOut = localWithExtension(pathIn, '.mp4');
else
    pathOut = localWithExtension(pathIn, '.avi');
end
writer = VideoWriter(pathOut, profile);
fps = double(fps);
if ~isscalar(fps) || ~isfinite(fps) || fps <= 0, fps = 10; end
writer.FrameRate = fps;
open(writer);
end

function rois = localSelectedRois(ctx, params)
rois = roi.empty;
refs = localField(params, 'roiRefs', struct('fovIndex', {}, 'roiIndex', {}, 'id', {}));
shallowObj = localShallow(ctx);
if isempty(shallowObj)
    % Classifier-scoped Hub jobs attach the selected classifier snapshot
    % ROI inventory directly to ctx; no shallow project exists in that mode.
    rois = localField(ctx, 'roiList', localField(ctx, 'rois', roi.empty));
    return;
end
if isempty(refs)
    for f = 1:numel(shallowObj.fov)
        rois = [rois shallowObj.fov(f).roi]; %#ok<AGROW>
    end
    return;
end
for i = 1:numel(refs)
    f = localPositiveInteger(localField(refs(i), 'fovIndex', 0), 0);
    r = localPositiveInteger(localField(refs(i), 'roiIndex', 0), 0);
    if f >= 1 && f <= numel(shallowObj.fov) && r >= 1 && r <= numel(shallowObj.fov(f).roi)
        rois(end+1) = shallowObj.fov(f).roi(r); %#ok<AGROW>
    end
end
end

function pathOut = localResolveOutputPath(ctx, params, mode)
requested = char(string(localField(params, 'outputPath', '')));
useArtifacts = logical(localField(params, 'useRunArtifactFolder', false));
if useArtifacts || isempty(requested)
    runPath = '';
    try, runPath = char(string(ctx.run.path)); catch, end
    if isempty(runPath)
        try, runPath = char(string(ctx.store.runPath)); catch, end
    end
    if isempty(runPath), runPath = pwd; end
    folder = fullfile(runPath, 'artifacts', 'movies');
    if exist(folder, 'dir') ~= 7, mkdir(folder); end
    requested = fullfile(folder, 'movie_export');
end
if strcmpi(mode, 'Sequence')
    pathOut = localWithExtension(requested, '.pdf');
else
    pathOut = localWithExtension(requested, '.mp4');
end
end

function mode = localOutputMode(params, opts)
mode = char(string(localField(params, 'outputMode', localField(opts, 'mode', 'Movie'))));
if any(strcmpi(mode, {'movie','mp4'})), mode = 'Movie'; else, mode = 'Sequence'; end
end

function out = localFinalOutputPath(pathIn, mode)
if strcmpi(mode, 'Sequence')
    out = localWithExtension(pathIn, '.pdf');
else
    % score_renderFinalFrame selects an AVI fallback when MPEG-4 is not
    % supported by the worker.  Report the file that was actually written.
    candidates = {localWithExtension(pathIn, '.mp4'), ...
        localWithExtension(pathIn, '.avi'), localWithExtension(pathIn, '.mj2')};
    present = candidates(cellfun(@(p) exist(p, 'file') == 2, candidates));
    if isempty(present)
        out = candidates{1};
    else
        out = present{1};
    end
end
end

function out = localWithExtension(pathIn, ext)
[folder, name] = fileparts(char(string(pathIn)));
out = fullfile(folder, [name ext]);
end

function kind = localArtifactKind(mode)
if strcmpi(mode, 'Sequence'), kind = 'movie_sequence_pdf'; else, kind = 'movie_mp4'; end
end

function ctx = localAddArtifact(ctx, kind, pathOut)
item = struct('kind', kind, 'path', char(string(pathOut)));
if ~isfield(ctx, 'artifacts') || isempty(ctx.artifacts), ctx.artifacts = item; else, ctx.artifacts(end+1) = item; end
if ~isfield(ctx, 'files') || isempty(ctx.files), ctx.files = {item.path}; else, ctx.files{end+1} = item.path; end
end

function params = localParams(ctx)
params = localField(ctx, 'params', struct());
if ~isstruct(params), params = struct(); end
end

function shallowObj = localShallow(ctx)
shallowObj = localField(ctx, 'shallow', localField(ctx, 'shallowObj', []));
end

function frames = localFrames(value, fovObj)
frames = double(value(:)');
if isempty(frames)
    try, frames = 1:max(double(fovObj.frames)); catch, frames = []; end
end
frames = unique(round(frames(isfinite(frames) & frames >= 1)), 'stable');
end

function v = localPositiveInteger(value, fallback)
v = fallback;
try
    n = round(double(value(1))); if isfinite(n) && n >= 0, v = n; end
catch
end
end

function value = localField(S, name, defaultValue)
value = defaultValue;
try
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name)), value = S.(name); end
catch
end
end

function localCloseFigure(fig)
try, if isgraphics(fig), close(fig); end, catch, end
end

function localCloseWriter(writer)
try, if isvalid(writer), close(writer); end, catch, end
end
