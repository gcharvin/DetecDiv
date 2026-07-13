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

[height, width, nFrames] = resolveRoiGeometry(roiobj);
if height <= 0 || width <= 0 || nFrames <= 0
    error('phyloCellAnnotations:NoGeometry', ...
        'Cannot determine ROI "%s" image geometry. Run roiExtract before phyloCellAnnotations.', safeRoiId(roiobj));
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
if logical(getField(paramout, 'scrubGraphics', false))
    S.segmentation = scrubPhyloCellGraphics(S.segmentation);
end
segmentation = S.segmentation;
clear S;
deletePhyloCellFigures();

frames = resolveFrames(ctx, paramout, nFrames);
createdChannels = {};
roiRect = double(roiobj.value);
useVirtualChannels = isempty(roiobj.image);

if logical(getField(paramout, 'createCellMasks', true)) && isfield(segmentation, 'cells1')
    mask = rasterizePhyloObjects(segmentation.cells1, height, width, nFrames, frames, roiRect);
    if any(mask(:))
        roiobj = writeAnnotationChannel(roiobj, mask, paramout.cellChannelName, [1 0.35 0.05], useVirtualChannels);
        createdChannels{end+1} = paramout.cellChannelName; %#ok<AGROW>
    end
end

if logical(getField(paramout, 'createNucleusMasks', true)) && isfield(segmentation, 'nucleus')
    mask = rasterizePhyloObjects(segmentation.nucleus, height, width, nFrames, frames, roiRect);
    if any(mask(:))
        roiobj = writeAnnotationChannel(roiobj, mask, paramout.nucleusChannelName, [0.1 0.45 1], useVirtualChannels);
        createdChannels{end+1} = paramout.nucleusChannelName; %#ok<AGROW>
    end
end

if logical(getField(paramout, 'createLineage', true))
    [lineageDs, lineageTable] = buildLineageDataseries(segmentation, paramout.outputName, safeRoiId(roiobj), segFile);
    roiobj.data = replaceDataseriesGroup(roiobj.data, paramout.outputName, lineageDs);
    if logical(getField(paramout, 'createScoreLineage', true))
        roiobj = upsertScoreLineageDataseries(roiobj, lineageTable, paramout.cellChannelName, nFrames, segFile);
    end
end

if isempty(createdChannels) && ~logical(getField(paramout, 'createLineage', true))
    error('phyloCellAnnotations:NoOutput', ...
        'No phyloCell annotation output was requested for ROI "%s".', safeRoiId(roiobj));
end

paramout.saveChannels = createdChannels;
dataout = roiobj.data;
if useVirtualChannels
    imageout = [];
elseif isempty(createdChannels)
    imageout = [];
else
    imageout = roiobj.image;
end
end

function [height, width, nFrames] = resolveRoiGeometry(roiobj)
height = 0;
width = 0;
nFrames = 0;

try
    if ~isempty(roiobj.image)
        sz = size(roiobj.image);
        sz(end+1:4) = 1;
        height = sz(1);
        width = sz(2);
        nFrames = sz(4);
        return;
    end
catch
end

try
    roiRect = double(roiobj.value);
    if numel(roiRect) >= 4
        width = max(width, round(roiRect(3)));
        height = max(height, round(roiRect(4)));
    end
catch
end

h5File = '';
try
    h5File = fullfile(roiobj.path, ['im_' roiobj.id '.h5']);
catch
    h5File = '';
end
if ~isempty(h5File) && exist(h5File, 'file') == 2
    try
        info = h5info(h5File);
        if isfield(info, 'Datasets') && ~isempty(info.Datasets)
            h5Path = ['/' info.Datasets(1).Name];
            try
                bb = double(h5readatt(h5File, h5Path, 'bbox'));
                if numel(bb) >= 4
                    width = max(width, round(bb(3)));
                    height = max(height, round(bb(4)));
                end
            catch
            end
            try
                frames = h5readatt(h5File, h5Path, 'frames');
                nFrames = max(nFrames, numel(frames));
            catch
            end
            try
                absT = h5readatt(h5File, h5Path, 'abs_T');
                nFrames = max(nFrames, double(absT(1)));
            catch
            end
            if nFrames <= 0
                dims = double(info.Datasets(1).Dataspace.Size);
                if ~isempty(dims)
                    nFrames = max(dims(:));
                end
            end
        end
    catch
    end
end

try
    fovObj = roiobj.parent;
    if nFrames <= 0 && ~isempty(fovObj) && isprop(fovObj, 'frames') && ~isempty(fovObj.frames)
        nFrames = max(double(fovObj.frames(:)));
    end
catch
end
end

function roiobj = writeAnnotationChannel(roiobj, mask, channelName, rgb, useVirtualChannels)
if useVirtualChannels
    roiobj = removeVirtualChannelIfPresent(roiobj, channelName);
    display = struct('intensity', [0 0 0], 'rgb', rgb, 'indexed', uint8(1), ...
        'alpha', 0.35, 'contour', uint8(1), 'width', 1.5, 'displaylim', [0; double(max(mask(:)))]);
    roiobj.appendVirtualChannel(channelName, mask, true, 'Display', display);
else
    roiobj = replaceChannelIfPresent(roiobj, channelName);
    roiobj.addChannel(mask, channelName, rgb, [0 0 0]);
end
end

function roiobj = removeVirtualChannelIfPresent(roiobj, channelName)
names = {};
try
    if isfield(roiobj.display, 'channel') && ~isempty(roiobj.display.channel)
        names = roiobj.display.channel;
    end
catch
    names = {};
end
if ischar(names) || isstring(names)
    names = cellstr(string(names));
elseif ~iscell(names)
    names = cellstr(string(names));
end
idx = find(strcmpi(names, char(string(channelName))));
if isempty(idx)
    deleteH5DatasetIfPresent(roiobj, channelName);
    return;
end
keep = setdiff(1:numel(names), idx);
roiobj.display = keepDisplayRows(roiobj.display, keep);
try
    if ~isempty(roiobj.channelid)
        keepSub = ~ismember(double(roiobj.channelid), idx);
        old = double(roiobj.channelid(keepSub));
        for k = 1:numel(idx)
            old(old > idx(k)) = old(old > idx(k)) - 1;
        end
        roiobj.channelid = old;
    end
catch
end
deleteH5DatasetIfPresent(roiobj, channelName);
end

function display = keepDisplayRows(display, keep)
if isempty(keep)
    display.channel = {};
    return;
end
fields = {'channel','intensity','rgb','selectedchannel','indexed','alpha','contour','width','scale','log','valueTransform'};
for i = 1:numel(fields)
    fld = fields{i};
    if ~isfield(display, fld) || isempty(display.(fld))
        continue;
    end
    val = display.(fld);
    try
        if iscell(val)
            display.(fld) = val(keep);
        elseif isstruct(val)
            display.(fld) = val(keep);
        elseif size(val, 1) >= max(keep) && ~isvector(val)
            display.(fld) = val(keep, :);
        else
            val = val(:).';
            display.(fld) = val(keep);
        end
    catch
    end
end
end

function deleteH5DatasetIfPresent(roiobj, channelName)
try
    h5File = fullfile(roiobj.path, ['im_' roiobj.id '.h5']);
    if exist(h5File, 'file') ~= 2
        return;
    end
    h5Path = ['/' sanitizeDatasetNameLocal(channelName)];
    fid = H5F.open(h5File, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    cleanup = onCleanup(@()H5F.close(fid));
    if H5L.exists(fid, h5Path, 'H5P_DEFAULT') > 0
        H5L.delete(fid, h5Path, 'H5P_DEFAULT');
    end
    clear cleanup;
catch
end
end

function nameOut = sanitizeDatasetNameLocal(nameIn)
s = char(string(nameIn));
s = regexprep(s, '^\s+|\s+$', '');
s = regexprep(s, '\s+', '_');
s = regexprep(s, '[^A-Za-z0-9_\-\.]', '_');
if isempty(s), s = 'channel'; end
nameOut = s;
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
        [rows, cols] = polygonPixels(x, y, height, width);
        if isempty(rows)
            continue;
        end
        label = double(obj.n);
        if ~isfinite(label) || label <= 0
            continue;
        end
        label = uint16(min(label, double(intmax('uint16'))));
        plane = mask(:, :, 1, f);
        plane(sub2ind([height width], rows, cols)) = label;
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

function [rows, cols] = polygonPixels(x, y, height, width)
rows = [];
cols = [];
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(x) < 3 || numel(y) < 3
    return;
end
xmin = max(1, floor(min(x)));
xmax = min(width, ceil(max(x)));
ymin = max(1, floor(min(y)));
ymax = min(height, ceil(max(y)));
if xmax < xmin || ymax < ymin
    return;
end

localX = x - xmin + 1;
localY = y - ymin + 1;
boxW = xmax - xmin + 1;
boxH = ymax - ymin + 1;
try
    pixLocal = poly2mask(localX, localY, boxH, boxW);
catch
    [xx, yy] = meshgrid(1:boxW, 1:boxH);
    pixLocal = inpolygon(xx, yy, localX, localY);
end
if ~any(pixLocal(:))
    return;
end
[rr, cc] = find(pixLocal);
rows = rr + ymin - 1;
cols = cc + xmin - 1;
end

function [ds, tbl] = buildLineageDataseries(segmentation, outputName, roiId, segFile)
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

function roiobj = upsertScoreLineageDataseries(roiobj, lineageTable, cellChannelName, nFrames, segFile)
if isempty(lineageTable) || ~istable(lineageTable) || ~all(ismember({'ObjectType','ObjectID','MotherID'}, lineageTable.Properties.VariableNames))
    return;
end

ensureCellInformationDataseries(roiobj, 'nFrames', max(1, nFrames));
idx = find(arrayfun(@(x) isprop(x, 'groupid') && strcmp(char(string(x.groupid)), 'cell_information'), roiobj.data), 1, 'first');
if isempty(idx)
    return;
end

ds = roiobj.data(idx);
if ~isprop(ds, 'userData') || isempty(ds.userData) || ~isstruct(ds.userData)
    ds.userData = struct();
end
if ~isfield(ds.userData, 'lineageSources') || ~isstruct(ds.userData.lineageSources)
    ds.userData.lineageSources = struct();
end

[motherOf, birthOf, events] = scoreLineageMapsFromTable(lineageTable);
if motherOf.Count == 0
    return;
end

channelPix = resolveChannelPix(roiobj, cellChannelName);
sourceKey = 'phyloCell';
src = struct();
src.motherOf = motherOf;
src.birthOf = birthOf;
src.events = events;
src.channelName = char(string(cellChannelName));
src.channelPix = double(channelPix);
src.outputName = 'phyloCell';
src.sourceClassifierStrid = 'phyloCell';
src.displayName = 'phyloCell';
src.show = true;
src.version = 1;
src.mode = 'phylocell_import';
src.segmentationFile = segFile;
src.createdAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

ds.userData.lineageSources.(sourceKey) = src;
ds.userData.motherOf = motherOf;
ds.userData.birthOf = birthOf;
ds.userData.events = events;
ds.userData.version = 1;
ds.userData.note = "phyloCell lineage imported into cell_information.userData.lineageSources";
ds.userData.lineageChannelName = string(cellChannelName);
ds.userData.lineageChannelPix = double(channelPix);
ds.userData.motherOfSourceKey = sourceKey;
ds.userData.motherOfSourceChannelName = char(string(cellChannelName));
ds.userData.activeLineageSource = sourceKey;
ds.userData.activeLineageChannelName = char(string(cellChannelName));

try
    ds.show = false;
catch
end
roiobj.data(idx) = ds;

roiobj.display.lineage = struct( ...
    'enabled', true, ...
    'channelName', char(string(cellChannelName)), ...
    'channelPix', double(channelPix), ...
    'sourceKey', sourceKey, ...
    'showBudPairing', ~isempty(events), ...
    'showGenealogy', true, ...
    'budWindowBefore', 0, ...
    'budWindowAfter', 6);
end

function [motherOf, birthOf, events] = scoreLineageMapsFromTable(tbl)
motherOf = containers.Map('KeyType', 'int32', 'ValueType', 'double');
birthOf = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
events = struct('childId', {}, 'motherId', {}, 'startFrame', {}, 'source', {});

try
    isCell = strcmp(string(tbl.ObjectType), "cell");
catch
    isCell = true(height(tbl), 1);
end
cellTbl = tbl(isCell, :);

for i = 1:height(cellTbl)
    childId = double(cellTbl.ObjectID(i));
    motherId = double(cellTbl.MotherID(i));
    if ~isfinite(childId) || childId <= 0 || ~isfinite(motherId) || motherId <= 0 || childId == motherId
        continue;
    end
    childKey = int32(round(childId));
    motherOf(childKey) = motherId;

    birthFrame = firstPositiveFrame(cellTbl, i, {'BirthFrame','DetectionFrame'});
    if isfinite(birthFrame) && birthFrame >= 1
        birthOf(childKey) = int32(round(birthFrame));
        events(end+1) = struct( ... %#ok<AGROW>
            'childId', double(childKey), ...
            'motherId', double(motherId), ...
            'startFrame', double(birthFrame), ...
            'source', 'phyloCell');
    end
end
end

function frame = firstPositiveFrame(tbl, rowIdx, varNames)
frame = NaN;
for i = 1:numel(varNames)
    name = varNames{i};
    if ~ismember(name, tbl.Properties.VariableNames)
        continue;
    end
    try
        value = double(tbl.(name)(rowIdx));
        if isfinite(value) && value >= 1
            frame = value;
            return;
        end
    catch
    end
end
end

function pix = resolveChannelPix(roiobj, channelName)
pix = [];
try
    pix = roiobj.findChannelID(channelName, 'exact');
    if ~isempty(pix)
        pix = pix(1);
        return;
    end
catch
end
try
    names = roiobj.display.channel;
    if ischar(names) || isstring(names)
        names = cellstr(string(names));
    end
    idx = find(strcmpi(names, char(string(channelName))), 1, 'first');
    if ~isempty(idx) && ~isempty(roiobj.channelid)
        sub = find(double(roiobj.channelid) == idx, 1, 'first');
        if ~isempty(sub)
            pix = sub;
            return;
        end
    end
catch
end
if isempty(pix)
    pix = NaN;
end
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
