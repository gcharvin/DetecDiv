function manifestPath = pipelineDocumentationExtractExamples(projectInput, outputDir, pipelineInput)
% pipelineDocumentationExtractExamples Extract lightweight review images.
%
% The source project is read-only. One representative ROI is sampled and
% converted into compact PNG assets that can be embedded in standalone
% Reveal.js documentation. Large ROI H5 files are never copied.

    if nargin < 2 || isempty(outputDir)
        outputDir = fullfile(tempdir, 'detecdiv_pipeline_doc_examples');
    end
    if nargin < 3
        pipelineInput = [];
    end
    pipelineSpec = normalizePipelineSpec(pipelineInput);
    outputDir = char(string(outputDir));
    if exist(outputDir, 'dir') ~= 7
        mkdir(outputDir);
    end

    if isa(projectInput, 'shallow')
        project = projectInput;
        projectLabel = 'in-memory shallow project';
    else
        projectPath = char(string(projectInput));
        if exist(projectPath, 'file') ~= 2
            error('pipelineDocumentationExtractExamples:Project', 'Project file not found: %s', projectPath);
        end
        loaded = load(projectPath, 'shallowObj');
        if ~isfield(loaded, 'shallowObj') || ~isa(loaded.shallowObj, 'shallow')
            error('pipelineDocumentationExtractExamples:Project', 'The MAT file does not contain a shallowObj project.');
        end
        project = loaded.shallowObj;
        projectLabel = projectPath;
    end
    if isempty(project.fov) || isempty(project.fov(1).roi)
        error('pipelineDocumentationExtractExamples:Empty', 'The project has no ROI to document.');
    end

    fovObj = project.fov(1);
    roiObj = chooseRepresentativeRoi(fovObj.roi);
    h5Path = fullfile(char(string(roiObj.path)), ['im_' char(string(roiObj.id)) '.h5']);
    if exist(h5Path, 'file') ~= 2
        error('pipelineDocumentationExtractExamples:H5', 'ROI image store not found: %s', h5Path);
    end
    datasets = h5info(h5Path);
    datasetNames = string({datasets.Datasets.Name});
    focusDataset = resolveFocusDataset(datasetNames, pipelineSpec);
    instanceDataset = resolveInstanceDataset(datasetNames, pipelineSpec);
    trackedDataset = resolveTrackedDataset(datasetNames, pipelineSpec);
    frameCount = datasetFrameCount(datasets, focusDataset);
    if frameCount < 1
        frameCount = datasetFrameCount(datasets, ['/' char(datasetNames(1))]);
    end
    frameIndex = max(1, round(frameCount / 2));
    [frameIndex, ~] = divisionFrame(roiObj, frameIndex, resolveDivisionSeries(pipelineSpec));

    zNames = resolveStackDatasets(datasetNames, pipelineSpec);
    if isempty(zNames)
        error('pipelineDocumentationExtractExamples:Channels', 'No DIC Z-stack channel was found in %s.', h5Path);
    end
    zIndices = unique(max(1, min(numel(zNames), round([0.2 0.5 0.8] * numel(zNames)))));
    rawPanels = cell(1, numel(zIndices));
    for i = 1:numel(zIndices)
        rawPanels{i} = readPlane(h5Path, ['/' char(zNames(zIndices(i)))], frameIndex);
    end
    rawStackFile = fullfile(outputDir, 'roi_z_stack.png');
    imwrite(panelMontage(rawPanels, 1, numel(rawPanels)), rawStackFile);

    fullFrameFile = '';
    roiDefinitionFile = '';
    selectedRoiFile = '';
    try
        fullFrameChannel = resolveFovChannelIndex(fovObj, zNames(round(numel(zNames)/2)));
        fullFrame = readFullFrame(fovObj, fullFrameChannel, frameIndex);
        if ~isempty(fullFrame)
            fullFrameFile = fullfile(outputDir, 'raw_full_frame.png');
            imwrite(limitImageSize(toUint8(fullFrame), 1400), fullFrameFile);
            roiDefinitionFile = fullfile(outputDir, 'full_frame_all_rois.png');
            imwrite(limitImageSize(overlayRoiRectangles(fullFrame, fovObj.roi, NaN), 1400), roiDefinitionFile);
            selectedRoiFile = fullfile(outputDir, 'full_frame_selected_roi.png');
            selectedIndex = find(arrayfun(@(x) strcmp(char(string(x.id)), char(string(roiObj.id))), fovObj.roi), 1);
            imwrite(limitImageSize(overlayRoiRectangles(fullFrame, fovObj.roi, selectedIndex), 1400), selectedRoiFile);
        end
    catch ME
        warning('pipelineDocumentationExtractExamples:FullFrame', 'Full-frame example unavailable: %s', ME.message);
    end

    roiTimeseriesFile = fullfile(outputDir, 'roi_timeseries.png');
    timeFrames = unique(max(1, min(frameCount, round(linspace(1, frameCount, 5)))));
    timePanels = cell(1, numel(timeFrames));
    selectedZ = ['/' char(zNames(round(numel(zNames)/2)))];
    for i = 1:numel(timeFrames)
        timePanels{i} = readPlane(h5Path, selectedZ, timeFrames(i));
    end
    imwrite(panelMontage(timePanels, 1, numel(timePanels)), roiTimeseriesFile);

    focusFile = '';
    if any(datasetNames == erase(string(focusDataset), '/'))
        focusFile = fullfile(outputDir, 'best_focus.png');
        focus = readPlane(h5Path, focusDataset, frameIndex);
        imwrite(toUint8(focus), focusFile);
    end

    segmentationInputFile = '';
    segmentationFile = '';
    segmentationFrame = frameIndex;
    if any(datasetNames == erase(string(instanceDataset), '/'))
        segmentationFrame = bestMultiCellFrame(h5Path, instanceDataset, frameCount);
        if any(datasetNames == erase(string(focusDataset), '/'))
            segmentationFocus = readPlane(h5Path, focusDataset, segmentationFrame);
        else
            segmentationFocus = readPlane(h5Path, selectedZ, segmentationFrame);
        end
        segmentationInputFile = fullfile(outputDir, 'cellpose_input.png');
        imwrite(toUint8(segmentationFocus), segmentationInputFile);
        segmentationFile = fullfile(outputDir, 'cellpose_overlay.png');
        mask = readPlane(h5Path, instanceDataset, segmentationFrame);
        imwrite(overlayLabels(segmentationFocus, mask), segmentationFile);
    end

    viterbiInputFile = segmentationFile;
    trackedFile = '';
    if any(datasetNames == erase(string(trackedDataset), '/')) && ...
            any(datasetNames == erase(string(instanceDataset), '/'))
        trackedFile = fullfile(outputDir, 'tracked_cell_overlay.png');
        trackedMask = readPlane(h5Path, trackedDataset, segmentationFrame);
        allMask = readPlane(h5Path, instanceDataset, segmentationFrame);
        imwrite(overlayViterbiSelection(segmentationFocus, allMask, trackedMask), trackedFile);
    end

    qcFiles = findQcFiles(roiObj);
    copiedQc = {};
    for i = 1:min(2, numel(qcFiles))
        [~, name, ext] = fileparts(qcFiles{i});
        target = fullfile(outputDir, [name ext]);
        copyfile(qcFiles{i}, target);
        copiedQc{end+1} = target; %#ok<AGROW>
    end

    roles = struct();
    if ~isempty(fullFrameFile)
        roles.raw = entry(fullFrameFile, 'Raw full-frame acquisition before ROI processing.', 'input');
    else
        roles.raw = entry(rawStackFile, 'Raw ROI Z-stack planes (full-frame source unavailable).', 'input');
    end
    roiEntries = struct('file',{},'caption',{},'alt',{},'kind',{});
    if ~isempty(fullFrameFile), roiEntries(end+1) = entry(fullFrameFile, 'Input: raw full frame used to define ROIs.', 'input'); end
    if ~isempty(roiDefinitionFile), roiEntries(end+1) = entry(roiDefinitionFile, sprintf('Output: all %d ROI rectangles created on the full frame.', numel(fovObj.roi)), 'output'); end
    if ~isempty(roiEntries), roles.roi_definition = roiEntries; end
    extractionEntries = struct('file',{},'caption',{},'alt',{},'kind',{});
    if ~isempty(selectedRoiFile), extractionEntries(end+1) = entry(selectedRoiFile, 'Input: one selected ROI in the source full frame.', 'input'); end
    extractionEntries(end+1) = entry(roiTimeseriesFile, sprintf('Output: ROI time series at one fixed Z plane in %s.', getLeaf(h5Path)), 'output');
    roles.roi_extraction = extractionEntries;
    bestFocusEntries = struct('file',{},'caption',{},'alt',{},'kind',{});
    bestFocusEntries(end+1) = entry(rawStackFile, 'Input: representative planes from the ROI Z stack.', 'input');
    if ~isempty(focusFile), bestFocusEntries(end+1) = entry(focusFile, 'Output: derived best-focus image.', 'output'); end
    roles.best_focus = bestFocusEntries;
    segmentationEntries = struct('file',{},'caption',{},'alt',{},'kind',{});
    if ~isempty(segmentationInputFile), segmentationEntries(end+1) = entry(segmentationInputFile, 'Input: best-focus image containing several cells.', 'input'); end
    if ~isempty(segmentationFile), segmentationEntries(end+1) = entry(segmentationFile, 'Output: instance boundaries for multiple cells.', 'output'); end
    if ~isempty(segmentationEntries), roles.segmentation = segmentationEntries; end
    divisionEntries = struct('file',{},'caption',{},'alt',{},'kind',{});
    if ~isempty(viterbiInputFile), divisionEntries(end+1) = entry(viterbiInputFile, 'Input: several segmented candidate cells.', 'input'); end
    if ~isempty(trackedFile), divisionEntries(end+1) = entry(trackedFile, 'Output: the selected target cell highlighted in green.', 'output'); end
    if ~isempty(divisionEntries), roles.division = divisionEntries; end
    finalEntries = struct('file',{},'caption',{},'alt',{},'kind',{});
    for i = 1:numel(copiedQc)
        finalEntries(end+1) = entry(copiedQc{i}, 'Quality-control output from the associated project.', 'output'); %#ok<AGROW>
    end
    if ~isempty(finalEntries), roles.final = finalEntries; end

    manifest = struct('project', projectLabel, 'fovId', char(string(fovObj.id)), ...
        'roiId', char(string(roiObj.id)), 'frame', frameIndex, 'roles', roles);
    manifestPath = fullfile(outputDir, 'examples.json');
    writeJson(manifestPath, manifest);
end

function roiObj = chooseRepresentativeRoi(rois)
    roiObj = rois(1);
    for i = 1:numel(rois)
        h5Path = fullfile(char(string(rois(i).path)), ['im_' char(string(rois(i).id)) '.h5']);
        if exist(h5Path, 'file') == 2
            roiObj = rois(i);
            return;
        end
    end
end

function count = datasetFrameCount(info, datasetPath)
    count = 0;
    name = erase(string(datasetPath), '/');
    idx = find(string({info.Datasets.Name}) == name, 1);
    if isempty(idx), return; end
    sz = info.Datasets(idx).Dataspace.Size;
    if numel(sz) >= 4, count = sz(4); else, count = 1; end
end

function image = readPlane(filename, dataset, frameIndex)
    info = h5info(filename, dataset);
    sz = info.Dataspace.Size;
    if numel(sz) < 4, sz(end+1:4) = 1; end
    frameIndex = max(1, min(frameIndex, sz(4)));
    image = squeeze(h5read(filename, dataset, [1 1 1 frameIndex], [sz(1) sz(2) 1 1]));
end

function out = toUint8(image)
    values = double(image(:));
    values = values(isfinite(values));
    if isempty(values), out = zeros(size(image), 'uint8'); return; end
    values = sort(values);
    lo = values(max(1, round(0.01 * numel(values))));
    hi = values(max(1, round(0.99 * numel(values))));
    if hi <= lo, hi = lo + 1; end
    out = uint8(255 * min(1, max(0, (double(image) - lo) / (hi - lo))));
end

function rgb = overlayLabels(image, labels)
    gray = toUint8(image);
    rgb = repmat(gray, 1, 1, 3);
    ids = unique(labels(:));
    ids = ids(ids > 0);
    palette = [236 72 87; 0 174 239; 255 185 0; 167 92 210; 46 190 120];
    for i = 1:numel(ids)
        boundary = maskBoundary(labels == ids(i));
        color = palette(mod(i-1, size(palette,1))+1, :);
        rgb = paintBoundary(rgb, boundary, color, 2);
    end
end

function rgb = overlayViterbiSelection(image, allLabels, selectedMask)
    gray = toUint8(image);
    rgb = repmat(gray, 1, 1, 3);
    allBoundary = maskBoundary(allLabels > 0);
    rgb = paintBoundary(rgb, allBoundary, [225 85 85], 1);
    selectedBoundary = maskBoundary(selectedMask > 0);
    rgb = paintBoundary(rgb, selectedBoundary, [30 220 95], 3);
end

function boundary = maskBoundary(mask)
    mask = logical(mask);
    boundary = mask & (~circshift(mask, [1 0]) | ~circshift(mask, [-1 0]) | ...
        ~circshift(mask, [0 1]) | ~circshift(mask, [0 -1]));
end

function rgb = paintBoundary(rgb, boundary, color, width)
    expanded = boundary;
    for k = 2:width
        expanded = expanded | circshift(boundary, [k-1 0]) | circshift(boundary, [-(k-1) 0]) | ...
            circshift(boundary, [0 k-1]) | circshift(boundary, [0 -(k-1)]);
    end
    for c = 1:3
        plane = rgb(:,:,c); plane(expanded) = uint8(color(c)); rgb(:,:,c) = plane;
    end
end

function frameIndex = bestMultiCellFrame(h5Path, dataset, frameCount)
    frameIndex = max(1, round(frameCount / 2));
    bestCount = -1;
    info = h5info(h5Path, dataset);
    sz = info.Dataspace.Size;
    if numel(sz) < 4, sz(end+1:4) = 1; end
    for frame = 1:min(frameCount, sz(4))
        labels = squeeze(h5read(h5Path, dataset, ...
            [1 1 1 frame], [sz(1) sz(2) 1 1]));
        count = numel(unique(labels(labels > 0)));
        if count > bestCount
            bestCount = count;
            frameIndex = frame;
        end
    end
end

function spec = normalizePipelineSpec(pipelineInput)
    spec = struct('nodes', struct([]));
    if isempty(pipelineInput), return; end
    if isa(pipelineInput, 'pipeline')
        spec.nodes = pipelineInput.nodes;
        spec.edges = pipelineInput.edges;
        return;
    end
    if isstruct(pipelineInput)
        spec = pipelineInput;
        return;
    end
    pathIn = char(string(pipelineInput));
    if exist(pathIn, 'file') == 2
        try
            spec = jsondecode(fileread(pathIn));
        catch
            spec = struct('nodes', struct([]));
        end
    end
end

function names = resolveStackDatasets(datasetNames, spec)
    nodes = getSpecNodes(spec);
    for i = 1:numel(nodes)
        params = getNodeParams(nodes(i));
        if isfield(params, 'zStackChannelNames') && ~isempty(params.zStackChannelNames)
            requested = string(params.zStackChannelNames(:));
            names = requested(ismember(requested, datasetNames));
            if ~isempty(names), return; end
        end
    end
    names = datasetNames(~cellfun(@isempty, regexp(cellstr(datasetNames), '_Z\d+$', 'once')));
    if isempty(names)
        excluded = contains(lower(datasetNames), {'mask','result','prob','focus','label'});
        names = datasetNames(~excluded);
    end
end

function dataset = resolveFocusDataset(datasetNames, spec)
    dataset = '';
    nodes = getSpecNodes(spec);
    for i = 1:numel(nodes)
        key = lower(char(string(getNodeValue(nodes(i), 'pkg', ''))));
        params = getNodeParams(nodes(i));
        if contains(key, 'bestfocus') || contains(lower(char(string(getNodeValue(nodes(i), 'func', '')))), 'bestfocus')
            dataset = firstParamValue(params, {'outputChannelName','outputName'});
            if ~isempty(dataset), break; end
        end
    end
    if isempty(dataset)
        candidates = datasetNames(contains(lower(datasetNames), 'focus') & ~contains(lower(datasetNames), {'best_z','index'}));
        if ~isempty(candidates), dataset = char(candidates(1)); end
    end
    dataset = datasetPath(dataset);
end

function dataset = resolveInstanceDataset(datasetNames, spec)
    dataset = '';
    nodes = getSpecNodes(spec);
    for i = 1:numel(nodes)
        params = getNodeParams(nodes(i));
        candidate = firstParamValue(params, {'instanceChannelName'});
        if ~isempty(candidate) && any(datasetNames == string(candidate)), dataset = candidate; break; end
    end
    if isempty(dataset)
        for i = 1:numel(nodes)
            if strcmpi(char(string(getNodeValue(nodes(i), 'type', ''))), 'classifier')
                params = getNodeParams(nodes(i));
                outputName = firstParamValue(params, {'outputName'});
                guesses = string({outputName, ['results_' outputName '_cell'], [outputName '_cell']});
                match = guesses(ismember(guesses, datasetNames));
                if ~isempty(match), dataset = char(match(1)); break; end
            end
        end
    end
    if isempty(dataset)
        candidates = datasetNames(contains(lower(datasetNames), {'cellpose','instance','segmentation'}));
        if ~isempty(candidates), dataset = char(candidates(1)); end
    end
    dataset = datasetPath(dataset);
end

function dataset = resolveTrackedDataset(datasetNames, spec)
    dataset = '';
    nodes = getSpecNodes(spec);
    for i = 1:numel(nodes)
        params = getNodeParams(nodes(i));
        candidate = firstParamValue(params, {'outputMaskChannelName','trackedMaskChannelName'});
        if ~isempty(candidate) && any(datasetNames == string(candidate)), dataset = candidate; break; end
    end
    if isempty(dataset)
        candidates = datasetNames(contains(lower(datasetNames), {'cell_of_interest','tracked','target_cell'}));
        if ~isempty(candidates), dataset = char(candidates(1)); end
    end
    dataset = datasetPath(dataset);
end

function idx = resolveFovChannelIndex(fovObj, datasetName)
    idx = 1;
    try
        names = string(fovObj.channel);
        match = find(names == string(datasetName), 1);
        if ~isempty(match), idx = match; end
    catch
    end
end

function nodes = getSpecNodes(spec)
    nodes = struct([]);
    if isstruct(spec) && isfield(spec, 'nodes'), nodes = spec.nodes; end
end

function params = getNodeParams(node)
    params = struct();
    if isstruct(node) && isfield(node, 'params') && isstruct(node.params), params = node.params; end
end

function value = getNodeValue(node, field, fallback)
    value = fallback;
    if isstruct(node) && isfield(node, field) && ~isempty(node.(field)), value = node.(field); end
    if strcmp(field, 'pkg') && isempty(value)
        params = getNodeParams(node);
        if isfield(params, 'pkg') && ~isempty(params.pkg), value = params.pkg; end
    end
end

function value = firstParamValue(params, fields)
    value = '';
    for i = 1:numel(fields)
        if isfield(params, fields{i}) && ~isempty(params.(fields{i}))
            raw = params.(fields{i});
            if iscell(raw), raw = raw{1}; end
            if isscalar(string(raw)), value = char(string(raw)); return; end
        end
    end
end

function value = datasetPath(value)
    value = char(string(value));
    if ~isempty(value) && ~startsWith(value, '/'), value = ['/' value]; end
end

function image = readFullFrame(fovObj, channelIndex, frameIndex)
    image = [];
    if isempty(fovObj.srclist) || channelIndex > numel(fovObj.srclist)
        return;
    end
    entries = fovObj.srclist{channelIndex};
    if isempty(entries), return; end
    entryIndex = max(1, min(frameIndex, numel(entries)));
    entry = entries(entryIndex);
    sourcePath = resolveSourceFile(entry);
    if isempty(sourcePath), return; end
    [~, ~, ext] = fileparts(sourcePath);
    if strcmpi(ext, '.stk')
        image = readContiguousStackPlane(sourcePath, channelIndex);
    else
        image = imread(sourcePath);
    end
    if ~isempty(fovObj.orientation) && fovObj.orientation ~= 0
        image = imrotate(image, fovObj.orientation);
    end
end

function sourcePath = resolveSourceFile(entry)
    sourcePath = '';
    name = char(string(entry.name));
    folder = '';
    if isfield(entry, 'folder'), folder = char(string(entry.folder)); end
    candidates = {name, fullfile(folder, name)};
    marker = [filesep 'SynologyDrive' filesep];
    markerIndex = strfind(lower(folder), lower(marker));
    if ~isempty(markerIndex)
        tail = folder(markerIndex(1) + numel(marker):end);
        profile = getenv('USERPROFILE');
        candidates{end+1} = fullfile(profile, 'SynologyDrive', tail, name);
        candidates{end+1} = fullfile(profile, 'SynologyDrive', 'Data', tail, name);
    end
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file') == 2
            sourcePath = candidates{i};
            return;
        end
    end
end

function image = readContiguousStackPlane(filename, planeIndex)
    warningState = warning;
    warningCleanup = onCleanup(@() warning(warningState));
    warning('off', 'all');
    tif = Tiff(filename, 'r');
    width = double(tif.getTag('ImageWidth'));
    height = double(tif.getTag('ImageLength'));
    bitDepth = double(tif.getTag('BitsPerSample'));
    offsets = tif.getTag('StripOffsets');
    tif.close();
    clear warningCleanup;
    if bitDepth ~= 16
        error('pipelineDocumentationExtractExamples:Stack', 'Only 16-bit contiguous STK files are supported.');
    end
    fidHeader = fopen(filename, 'r');
    byteOrder = fread(fidHeader, 2, '*char')';
    fclose(fidHeader);
    if strcmp(byteOrder, 'MM'), machineFormat = 'ieee-be'; else, machineFormat = 'ieee-le'; end
    bytesPerPlane = width * height * 2;
    offset = double(offsets(1)) + (double(planeIndex)-1) * bytesPerPlane;
    fid = fopen(filename, 'r', machineFormat);
    if fid < 0, error('pipelineDocumentationExtractExamples:Stack', 'Unable to open %s.', filename); end
    cleaner = onCleanup(@() fclose(fid));
    if fseek(fid, offset, 'bof') ~= 0
        error('pipelineDocumentationExtractExamples:Stack', 'Unable to seek to plane %d.', planeIndex);
    end
    raw = fread(fid, [width height], 'uint16=>uint16');
    if numel(raw) ~= width * height
        error('pipelineDocumentationExtractExamples:Stack', 'Incomplete plane %d.', planeIndex);
    end
    image = raw';
    clear cleaner;
end

function rgb = overlayRoiRectangles(image, rois, selectedIndex)
    gray = toUint8(image);
    rgb = repmat(gray, 1, 1, 3);
    for i = 1:numel(rois)
        rect = double(rois(i).value(:)');
        if numel(rect) < 4, continue; end
        if isequal(i, selectedIndex), color = [255 160 25]; width = 6; else, color = [25 220 115]; width = 3; end
        rgb = drawRectangle(rgb, rect(1:4), color, width);
    end
end

function rgb = drawRectangle(rgb, rect, color, width)
    h = size(rgb,1); w = size(rgb,2);
    x1 = max(1, min(w, round(rect(1)))); y1 = max(1, min(h, round(rect(2))));
    x2 = max(1, min(w, round(rect(1)+rect(3)))); y2 = max(1, min(h, round(rect(2)+rect(4))));
    for t = 0:width-1
        xs = max(1,x1-t):min(w,x2+t); ys = max(1,y1-t):min(h,y2+t);
        for c = 1:3
            plane = rgb(:,:,c);
            plane(max(1,y1-t),xs) = uint8(color(c)); plane(min(h,y2+t),xs) = uint8(color(c));
            plane(ys,max(1,x1-t)) = uint8(color(c)); plane(ys,min(w,x2+t)) = uint8(color(c));
            rgb(:,:,c) = plane;
        end
    end
end

function output = limitImageSize(image, maxDimension)
    step = max(1, ceil(max(size(image,1), size(image,2)) / maxDimension));
    output = image(1:step:end, 1:step:end, :);
end

function canvas = panelMontage(images, rows, cols)
    if isempty(images), canvas = uint8(255 * ones(120, 160)); return; end
    first = toUint8(images{1}); [h, w] = size(first); gutter = 8;
    canvas = uint8(255 * ones(rows*h + (rows-1)*gutter, cols*w + (cols-1)*gutter));
    for i = 1:min(numel(images), rows*cols)
        r = floor((i-1)/cols); c = mod(i-1, cols);
        y = r*(h+gutter)+1; x = c*(w+gutter)+1;
        canvas(y:y+h-1, x:x+w-1) = toUint8(images{i});
    end
end

function [frameIndex, scoreTable] = divisionFrame(roiObj, fallback, seriesName)
    frameIndex = fallback; scoreTable = table();
    if nargin < 3 || isempty(seriesName), seriesName = 'pombe_division_score'; end
    try
        roiObj.load('data');
        idx = find(arrayfun(@(x) strcmp(x.groupid, seriesName), roiObj.data), 1);
        if isempty(idx), return; end
        scoreTable = roiObj.data(idx).data;
        if any(strcmp(scoreTable.Properties.VariableNames, 'septumScore'))
            [~, row] = max(scoreTable.septumScore, [], 'omitnan');
            if any(strcmp(scoreTable.Properties.VariableNames, 'frame')), frameIndex = scoreTable.frame(row); else, frameIndex = row; end
        end
    catch
        scoreTable = table();
    end
end

function seriesName = resolveDivisionSeries(spec)
    seriesName = 'pombe_division_score';
    nodes = getSpecNodes(spec);
    for i = 1:numel(nodes)
        params = getNodeParams(nodes(i));
        candidate = firstParamValue(params, {'scoreSeriesName'});
        if ~isempty(candidate) && ~startsWith(candidate, '@resource:')
            seriesName = candidate;
            return;
        end
    end
end

function files = findQcFiles(roiObj)
    files = {};
    folder = char(string(roiObj.path));
    candidates = dir(fullfile(folder, '*qc*.png'));
    if isempty(candidates)
        candidates = dir(fullfile(folder, '*quality*control*.png'));
    end
    if isempty(candidates)
        candidates = dir(fullfile(folder, '*overlay*.png'));
    end
    [~, order] = sort(lower(string({candidates.name})));
    candidates = candidates(order);
    for i = 1:min(2, numel(candidates))
        files{end+1} = fullfile(candidates(i).folder, candidates(i).name); %#ok<AGROW>
    end
end

function value = entry(filename, caption, kind)
    if nargin < 3, kind = ''; end
    [~, name, ext] = fileparts(filename);
    value = struct('file', [name ext], 'caption', caption, 'alt', caption, 'kind', kind);
end

function out = getLeaf(filename)
    [~, name, ext] = fileparts(filename); out = [name ext];
end

function writeJson(filename, value)
    try
        text = jsonencode(value, 'PrettyPrint', true);
    catch
        text = jsonencode(value);
    end
    fid = fopen(filename, 'w');
    if fid < 0, error('pipelineDocumentationExtractExamples:IO', 'Unable to write %s.', filename); end
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, text, 'char');
    clear cleaner;
end
