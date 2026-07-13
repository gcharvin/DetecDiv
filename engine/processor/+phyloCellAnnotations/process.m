function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% phyloCellAnnotations.process  Convert phyloCell contours to ROI channels.

if nargin < 3 || isempty(ctx) || ~isstruct(ctx)
    ctx = struct();
end
if nargin == 0 || isempty(param)
    paramout = phyloCellAnnotations.setparam(ctx);
    dataout = [];
    imageout = [];
    return;
end

paramout = phyloCellAnnotations.setparam(ctx);
if isstruct(param)
    paramout = mergeStructOverride(paramout, param);
end

if isempty(roiobj.image)
    roiobj.load;
end
if isempty(roiobj.image)
    error('phyloCellAnnotations:NoImage', ...
        'ROI "%s" has no extracted image. Run roiExtract before phyloCellAnnotations.', safeRoiId(roiobj));
end

segFile = resolveSegmentationFile(roiobj, paramout);
if isempty(segFile) || exist(segFile, 'file') ~= 2
    error('phyloCellAnnotations:NoSegmentation', ...
        'No phyloCell segmentation file found for ROI "%s".', safeRoiId(roiobj));
end

S = load(segFile, 'segmentation');
deletePhyloCellFigures();
if ~isfield(S, 'segmentation')
    error('phyloCellAnnotations:NoSegmentationVariable', ...
        'File "%s" does not contain a segmentation variable.', segFile);
end
S.segmentation = scrubPhyloCellGraphics(S.segmentation);
segmentation = S.segmentation;
clear S;
deletePhyloCellFigures();

frames = resolveFrames(ctx, paramout, size(roiobj.image, 4));
createdChannels = {};
roiRect = double(roiobj.value);

if logical(getField(paramout, 'createCellMasks', true)) && isfield(segmentation, 'cells1')
    mask = rasterizePhyloObjects(segmentation.cells1, size(roiobj.image, 1), size(roiobj.image, 2), ...
        size(roiobj.image, 4), frames, roiRect);
    if any(mask(:))
        roiobj = replaceChannelIfPresent(roiobj, paramout.cellChannelName);
        roiobj.addChannel(mask, paramout.cellChannelName, [1 0.35 0.05], [0 0 0]);
        createdChannels{end+1} = paramout.cellChannelName; %#ok<AGROW>
    end
end

if logical(getField(paramout, 'createNucleusMasks', true)) && isfield(segmentation, 'nucleus')
    mask = rasterizePhyloObjects(segmentation.nucleus, size(roiobj.image, 1), size(roiobj.image, 2), ...
        size(roiobj.image, 4), frames, roiRect);
    if any(mask(:))
        roiobj = replaceChannelIfPresent(roiobj, paramout.nucleusChannelName);
        roiobj.addChannel(mask, paramout.nucleusChannelName, [0.1 0.45 1], [0 0 0]);
        createdChannels{end+1} = paramout.nucleusChannelName; %#ok<AGROW>
    end
end

if logical(getField(paramout, 'createLineage', true))
    lineageDs = buildLineageDataseries(segmentation, paramout.outputName, safeRoiId(roiobj), segFile);
    roiobj.data = replaceDataseriesGroup(roiobj.data, paramout.outputName, lineageDs);
end

if isempty(createdChannels) && ~logical(getField(paramout, 'createLineage', true))
    error('phyloCellAnnotations:NoOutput', ...
        'No phyloCell annotation output was requested for ROI "%s".', safeRoiId(roiobj));
end

paramout.saveChannels = createdChannels;
dataout = roiobj.data;
if isempty(createdChannels)
    imageout = [];
else
    imageout = roiobj.image;
end
end

function deletePhyloCellFigures()
try
    h = findall(0, 'Type', 'figure', 'Name', 'phyloCell_mainGUI');
    delete(h);
catch
end
try
    h = findobj('Name', 'phyloCell_mainGUI');
    delete(h);
catch
end
try
    figs = findall(0, 'Type', 'figure');
    for i = 1:numel(figs)
        if figureReferencesPhyloCell(figs(i))
            delete(figs(i));
        end
    end
catch
end
end

function tf = figureReferencesPhyloCell(figHandle)
tf = false;
try
    objs = findall(figHandle);
    for i = 1:numel(objs)
        props = {'CreateFcn','Callback','ButtonDownFcn','DeleteFcn','CloseRequestFcn'};
        for p = 1:numel(props)
            try
                val = get(objs(i), props{p});
                if callbackMentionsPhyloCell(val)
                    tf = true;
                    return;
                end
            catch
            end
        end
    end
catch
    tf = false;
end
end

function tf = callbackMentionsPhyloCell(val)
tf = false;
try
    if isa(val, 'function_handle')
        txt = func2str(val);
    elseif iscell(val)
        txt = strjoin(cellfun(@(x) char(string(x)), val, 'UniformOutput', false), ' ');
    else
        txt = char(string(val));
    end
    tf = contains(txt, 'phyloCell_mainGUI');
catch
    tf = false;
end
end

function segmentation = scrubPhyloCellGraphics(segmentation)
if ~isstruct(segmentation)
    return;
end
directFields = {'cells1','nucleus'};
for k = 1:numel(directFields)
    fld = directFields{k};
    if isfield(segmentation, fld)
        segmentation.(fld) = scrubObjectArrayGraphics(segmentation.(fld));
    end
end
trackFields = {'tcells1','tnucleus'};
for k = 1:numel(trackFields)
    fld = trackFields{k};
    if isfield(segmentation, fld)
        segmentation.(fld) = scrubTrackObjectArrayGraphics(segmentation.(fld));
    end
end
end

function arr = scrubTrackObjectArrayGraphics(arr)
if isempty(arr) || ~isobject(arr)
    return;
end
for i = 1:numel(arr)
    try
        if isprop(arr(i), 'Obj') && ~isempty(arr(i).Obj)
            arr(i).Obj = scrubObjectArrayGraphics(arr(i).Obj);
        end
    catch
    end
end
end

function arr = scrubObjectArrayGraphics(arr)
if isempty(arr) || ~isobject(arr)
    return;
end
for i = 1:numel(arr)
    try
        if isprop(arr(i), 'htext')
            arr(i).htext = [];
        end
    catch
    end
    try
        if isprop(arr(i), 'hcontour')
            arr(i).hcontour = [];
        end
    catch
    end
end
end

function mask = rasterizePhyloObjects(objects, height, width, nFrames, frames, roiRect)
mask = zeros(height, width, 1, nFrames, 'uint16');
if isempty(objects) || ~isobject(objects)
    return;
end

frameSet = frames(:)';
for f = frameSet
    if f < 1 || f > nFrames
        continue;
    end
    objs = objectsForFrame(objects, f);
    for i = 1:numel(objs)
        obj = objs(i);
        if ~isLivePhyloObject(obj)
            continue;
        end
        x = double(obj.x(:)) - roiRect(1) + 1;
        y = double(obj.y(:)) - roiRect(2) + 1;
        if numel(x) < 3 || numel(y) < 3
            continue;
        end
        pix = polygonMask(x, y, height, width);
        if ~any(pix(:))
            continue;
        end
        label = double(obj.n);
        if ~isfinite(label) || label <= 0
            continue;
        end
        label = uint16(min(label, double(intmax('uint16'))));
        plane = mask(:, :, 1, f);
        plane(pix) = label;
        mask(:, :, 1, f) = plane;
    end
end
end

function objs = objectsForFrame(objects, frame)
objs = objects([]);
try
    if ndims(objects) >= 2 && size(objects, 1) >= frame
        row = objects(frame, :);
        keep = arrayfun(@isLivePhyloObject, row);
        objs = row(keep);
        return;
    end
catch
end

try
    keep = false(size(objects));
    for i = 1:numel(objects)
        keep(i) = isLivePhyloObject(objects(i)) && getNumericProp(objects(i), 'image', frame) == frame;
    end
    objs = objects(keep);
catch
    objs = objects([]);
end
end

function tf = isLivePhyloObject(obj)
tf = false;
try
    tf = isobject(obj) && isprop(obj, 'n') && ~isempty(obj.n) && double(obj.n) > 0 && ...
        isprop(obj, 'x') && isprop(obj, 'y') && numel(obj.x) >= 3 && numel(obj.y) >= 3;
catch
    tf = false;
end
end

function pix = polygonMask(x, y, height, width)
try
    pix = poly2mask(x, y, height, width);
catch
    [xx, yy] = meshgrid(1:width, 1:height);
    pix = inpolygon(xx, yy, x, y);
end
end

function ds = buildLineageDataseries(segmentation, outputName, roiId, segFile)
rows = {};
rows = [rows; lineageRows(getField(segmentation, 'tcells1', []), 'cell')]; %#ok<AGROW>
rows = [rows; lineageRows(getField(segmentation, 'tnucleus', []), 'nucleus')]; %#ok<AGROW>

if isempty(rows)
    tbl = table(string.empty(0,1), zeros(0,1), zeros(0,1), cell(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), cell(0,1), cell(0,1), 'VariableNames', ...
        {'ObjectType','ObjectID','MotherID','DaughterIDs','BirthFrame','DetectionFrame','LastFrame','DivisionFrames','BudFrames'});
else
    tbl = cell2table(rows, 'VariableNames', ...
        {'ObjectType','ObjectID','MotherID','DaughterIDs','BirthFrame','DetectionFrame','LastFrame','DivisionFrames','BudFrames'});
end

groups = repmat({'lineage'}, 1, width(tbl));
plots = repmat({false}, 1, width(tbl));
ds = dataseries(tbl, tbl.Properties.VariableNames, ...
    'groupid', outputName, 'parentid', roiId, 'plot', plots, 'groups', groups, ...
    'class', 'processing', 'type', 'other');
ds.description = 'Imported phyloCell lineage/object metadata.';
ds.userData = struct('source', 'phyloCell', 'segmentationFile', segFile, ...
    'lineage_semantics', 'ObjectID values match the indexed mask labels when phyloCell provided matching object ids.');
end

function rows = lineageRows(trackObjects, objectType)
rows = {};
if isempty(trackObjects) || ~isobject(trackObjects)
    return;
end

for i = 1:numel(trackObjects)
    tr = trackObjects(i);
    objectId = getNumericProp(tr, 'N', i);
    if objectId <= 0
        objectId = i;
    end
    motherId = getNumericProp(tr, 'mother', NaN);
    if isnan(motherId) || motherId == 0
        motherId = firstNumeric(getField(tr, 'mothers', NaN), NaN);
    end
    daughters = numericVector(getField(tr, 'daughterList', []));
    birthFrame = getNumericProp(tr, 'birthFrame', NaN);
    detectionFrame = getNumericProp(tr, 'detectionFrame', NaN);
    lastFrame = getNumericProp(tr, 'lastFrame', NaN);
    divisionFrames = numericVector(getField(tr, 'divisionTimes', []));
    budFrames = numericVector(getField(tr, 'budTimes', []));

    rows(end+1, :) = {string(objectType), double(objectId), double(motherId), daughters, ...
        double(birthFrame), double(detectionFrame), double(lastFrame), divisionFrames, budFrames}; %#ok<AGROW>
end
end

function data = replaceDataseriesGroup(data, groupid, ds)
if isempty(data) || (isa(data, 'dataseries') && numel(data) == 1 && isempty(data(1).groupid))
    data = ds;
    return;
end
try
    keep = ~arrayfun(@(x) strcmp(char(string(x.groupid)), char(string(groupid))), data);
    data = data(keep);
catch
end
data(end+1) = ds;
end

function roiobj = replaceChannelIfPresent(roiobj, channelName)
try
    if isfield(roiobj.display, 'channel') && any(strcmpi(roiobj.display.channel, channelName))
        roiobj.removeChannel(channelName);
    end
catch
end
end

function segFile = resolveSegmentationFile(roiobj, paramout)
segFile = '';
if isfield(paramout, 'segmentationFile') && ~isempty(paramout.segmentationFile)
    segFile = char(string(paramout.segmentationFile));
    return;
end
try
    fovObj = roiobj.parent;
    if ~isempty(fovObj) && isprop(fovObj, 'contours') && isstruct(fovObj.contours) && ...
            isfield(fovObj.contours, 'phyloCell') && isstruct(fovObj.contours.phyloCell) && ...
            isfield(fovObj.contours.phyloCell, 'segmentationFile')
        segFile = char(string(fovObj.contours.phyloCell.segmentationFile));
    end
catch
    segFile = '';
end
end

function frames = resolveFrames(ctx, paramout, nFrames)
frames = [];
if isfield(paramout, 'frames') && ~isempty(paramout.frames)
    frames = paramout.frames;
elseif isfield(ctx, 'frames') && ~isempty(ctx.frames)
    frames = ctx.frames;
end
if isempty(frames) || (isnumeric(frames) && isscalar(frames) && frames == -1)
    frames = 1:nFrames;
else
    frames = unique(double(frames(:)'));
    frames = frames(frames >= 1 & frames <= nFrames);
end
end

function value = getField(s, fieldName, defaultValue)
if nargin < 3
    defaultValue = [];
end
value = defaultValue;
try
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    elseif isobject(s) && isprop(s, fieldName)
        value = s.(fieldName);
    end
catch
    value = defaultValue;
end
end

function value = getNumericProp(s, fieldName, defaultValue)
value = defaultValue;
try
    raw = getField(s, fieldName, defaultValue);
    if ~isempty(raw)
        value = double(raw(1));
    end
catch
    value = defaultValue;
end
end

function out = numericVector(v)
out = [];
try
    if isempty(v)
        return;
    end
    out = double(v(:)');
    out = out(isfinite(out) & out ~= 0);
catch
    out = [];
end
end

function value = firstNumeric(v, defaultValue)
value = defaultValue;
try
    vv = numericVector(v);
    if ~isempty(vv)
        value = vv(1);
    end
catch
    value = defaultValue;
end
end

function out = mergeStructOverride(base, patch)
out = base;
if nargin < 2 || ~isstruct(patch) || isempty(patch)
    return;
end
fn = fieldnames(patch);
for i = 1:numel(fn)
    out.(fn{i}) = patch.(fn{i});
end
end

function roiId = safeRoiId(roiobj)
roiId = '<unknown>';
try
    roiId = char(string(roiobj.id));
catch
end
end
