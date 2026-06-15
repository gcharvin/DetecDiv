function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% basicObjectTracking.process  Track labeled objects over time.
%
% This processor takes a labeled/segmented channel (one object per label)
% and links objects across frames using a distance-based Hungarian assignment.
%
% Inputs:
%   param   - parameter struct (see basicObjectTracking.setparam)
%   roiobj  - @roi object
%   frames  - optional vector of frames to process (default = all)
%
% Outputs:
%   paramout - parameter struct (normalized)
%   dataout  - roiobj.data (unchanged)
%   imageout - roiobj.image (with tracking output channel added)

    if nargin == 0 || isempty(param)
        paramout = basicObjectTracking.setparam();
        dataout = [];
        imageout = [];
        return;
    end

    if nargin < 3
        ctx = struct();
    elseif ~isstruct(ctx)
        % Back-compat: third argument was "frames".
        ctx = struct('frames', ctx);
    end

    if nargin == 0 || isempty(param)
        paramout = basicObjectTracking.setparam(ctx);
        dataout = [];
        imageout = [];
        return;
    end

    % Normalize/upgrade legacy parameter names.
    paramout = normalizeParam(param);

    % Ensure ROI image is loaded.
    if isempty(roiobj.image)
        roiobj.load;
    end

    dataout  = roiobj.data;
    imageout = roiobj.image;

    % Resolve input channel (ctx can override).
    inputName = readChoice(paramout.inputChannelName);
    if isfield(ctx,'channels') && ~isempty(ctx.channels)
        if isempty(inputName)
            if iscell(ctx.channels)
                inputName = char(string(ctx.channels{1}));
            else
                inputName = char(string(ctx.channels));
            end
        end
    end
    if isempty(inputName)
        error('basicObjectTracking:NoInputChannel', ...
            'No input channel selected. Please choose a labeled channel.');
    end

    channelID = roiobj.findChannelID(inputName);
    if isempty(channelID)
        error('basicObjectTracking:ChannelNotFound', ...
            'Input channel "%s" not found in ROI.', inputName);
    end
    channelID = channelID(1); % use first sub-channel if multiple

    im = roiobj.image(:,:,channelID,:);

    % Frame selection.
    T = size(im,4);
    frames = [];
    if isfield(ctx,'frames')
        frames = ctx.frames;
    elseif isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'frames')
        frames = ctx.sel.frames;
    end
    if isempty(frames) || isequal(frames, -1)
        frames = 1:T;
    else
        frames = frames(:).';
        frames = frames(frames >= 1 & frames <= T);
        if isempty(frames)
            frames = 1:T;
        end
    end

    % Prepare output label stack for all frames (unprocessed frames stay 0).
    outLabel = zeros(size(im,1), size(im,2), 1, T, 'uint16');

    % Determine input mode (auto/binary/label).
    inputMode = readChoice(paramout.inputMode);
    if isfield(ctx,'inputMode') && ~isempty(ctx.inputMode)
        inputMode = char(string(ctx.inputMode));
    end
    if isempty(inputMode)
        inputMode = 'auto';
    end

    % Estimate typical object size to normalize distances.
    area = [];
    for f = frames
        l = getLabelFrame(im(:,:,1,f), inputMode);
        stats = regionprops(l, 'Area');
        if ~isempty(stats)
            area = [area, [stats.Area]]; %#ok<AGROW>
        end
    end
    if isempty(area)
        warning('basicObjectTracking:EmptyMasks', ...
            'No objects found in selected frames. Output will be empty.');
    end

    areamean = mean(area);
    if isempty(areamean) || isnan(areamean) || areamean <= 0
        areamean = 1;
    end
    distancemean = 2 * sqrt(areamean) * 2 / pi;
    if distancemean <= 0 || isnan(distancemean)
        distancemean = 1;
    end

    % Initialize with the first frame.
    imref = im(:,:,1,frames(1));
    lref = getLabelFrame(imref, inputMode);
    outLabel(:,:,1,frames(1)) = uint16(lref);
    cellsref = getCells(lref);

    if paramout.debug
        fprintf('[basicObjectTracking] START: input="%s", output="%s", frames=%d\n', ...
            inputName, paramout.outputChannelName, numel(frames));
    end

    % Track across frames.
    for i = 2:numel(frames)
        f = frames(i);
        imtest = im(:,:,1,f);
        ltest = getLabelFrame(imtest, inputMode);
        cellstest = getCells(ltest);

        if isempty(cellstest)
            cellsref = cellstest;
            continue;
        end

        if isempty(cellsref)
            % No previous objects -> assign new ids.
            maxId = 0;
        else
            maxId = max([cellsref.n]);
        end
        cellstest = assignNewIds(cellstest, maxId);

        [cellsref, ~] = hungarianTracker(cellsref, cellstest, distancemean, paramout);

        bw = zeros(size(imref,1), size(imref,2), 'uint16');
        for j = 1:numel(cellstest)
            pix = cellstest(j).pix;
            if ~isempty(pix)
                bw(pix) = cellsref(j).n;
            end
        end
        outLabel(:,:,1,f) = bw;
    end

    % Update ROI: remove existing output channel then add the new one.
    outputName = strtrim(char(string(paramout.outputChannelName)));
    if isfield(ctx,'outputName') && ~isempty(ctx.outputName)
        if isempty(outputName)
            outputName = char(string(ctx.outputName));
        end
    end
    if isempty(outputName)
        outputName = 'track_objects';
    end
    paramout.outputChannelName = outputName;

    if ~isempty(roiobj.findChannelID(outputName))
        roiobj.removeChannel(outputName);
    end

    % Add as indexed channel (intensity = [0 0 0]).
    roiobj.addChannel(outLabel, outputName, [1 1 1], [0 0 0]);

    % Return updated ROI data/image.
    dataout  = roiobj.data;
    imageout = roiobj.image;

    % Hint for downstream partial saves.
    paramout.saveChannels = {outputName};

    if paramout.debug
        fprintf('[basicObjectTracking] DONE: output="%s"\n', outputName);
    end
end

% ===== Helpers =====

function paramout = normalizeParam(param)
    paramout = param;

    % Legacy -> new field names
    if isfield(paramout,'input_channel_name') && ~isfield(paramout,'inputChannelName')
        paramout.inputChannelName = paramout.input_channel_name;
    end
    if isfield(paramout,'output_channel_name') && ~isfield(paramout,'outputChannelName')
        paramout.outputChannelName = paramout.output_channel_name;
    end
    if isfield(paramout,'coefdist') && ~isfield(paramout,'coefDist')
        paramout.coefDist = paramout.coefdist;
    end
    if isfield(paramout,'size_weight') && ~isfield(paramout,'coefSize')
        paramout.coefSize = paramout.size_weight;
    end
    if isfield(paramout,'sizeWeight') && ~isfield(paramout,'coefSize')
        paramout.coefSize = paramout.sizeWeight;
    end
    if isfield(paramout,'max_relative_distance') && ~isfield(paramout,'maxRelativeDistance')
        paramout.maxRelativeDistance = paramout.max_relative_distance;
    end

    % Defaults if missing.
    if ~isfield(paramout,'inputChannelName')
        paramout.inputChannelName = {'none'};
    end
    if ~isfield(paramout,'outputChannelName')
        paramout.outputChannelName = 'track_objects';
    end
    if ~isfield(paramout,'coefDist')
        paramout.coefDist = 1;
    end
    if ~isfield(paramout,'coefSize')
        paramout.coefSize = 0;
    end
    if ~isfield(paramout,'coefIoU')
        paramout.coefIoU = 0;
    end
    if ~isfield(paramout,'maxRelativeDistance')
        paramout.maxRelativeDistance = 2;
    end
    if ~isfield(paramout,'debug')
        paramout.debug = false;
    end
end

function v = readChoice(val)
    if iscell(val)
        if isempty(val)
            v = '';
        else
            v = char(string(val{end}));
        end
    else
        v = char(string(val));
    end
    v = strtrim(v);
    if strcmpi(v,'none')
        v = '';
    end
end

function cells = getCells(l)
% Create a cell structure array from a labeled image.
    if isempty(l) || max(l(:)) == 0
        cells = struct('ox', {}, 'oy', {}, 'area', {}, 'n', {}, 'pix', {});
        return;
    end
    r = regionprops(l, 'Centroid', 'Area', 'PixelIdxList');
    cells = struct('ox', [], 'oy', [], 'area', [], 'n', [], 'pix', []);

    for i = 1:numel(r)
        cells(i).ox = r(i).Centroid(1);
        cells(i).oy = r(i).Centroid(2);
        cells(i).area = r(i).Area;
        cells(i).n = i;
        cells(i).pix = r(i).PixelIdxList;
    end
end

function [newcell, cost] = hungarianTracker(cell0, cell1, meancellsize, param)
% Assign objects between two frames using the Hungarian algorithm.

    newcell = [];

    if isempty(cell0)
        newcell = cell1;
        cost = [];
        return;
    end
    if isempty(cell1)
        newcell = cell1;
        cost = [];
        return;
    end

    lastObjectNumber = max([cell0.n]);
    n0 = length(find([cell0.ox] ~= 0));
    n1 = length(find([cell1.ox] ~= 0));

    M = Inf * ones(n0, n1);

    ind0 = find([cell0.ox] ~= 0);
    ind1 = find([cell1.ox] ~= 0);

    coefDist = parseScalar(param.coefDist, 1);
    coefSize = parseScalar(getfieldwithdefault(param,'coefSize',0), 0); %#ok<GFLD>
    coefIoU  = parseScalar(getfieldwithdefault(param,'coefIoU',0), 0); %#ok<GFLD>
    maxRel   = parseScalar(param.maxRelativeDistance, 2);

    for i = 1:length(ind0)
        id = ind0(i);
        for j = 1:length(ind1)
            jd = ind1(j);

            sqdist = (cell0(id).ox - cell1(jd).ox)^2 + (cell0(id).oy - cell1(jd).oy)^2;
            dist = sqrt(sqdist) / meancellsize;

            if dist > maxRel
                continue;
            end

            sizeTerm = 0;
            if coefSize > 0
                sizeTerm = abs(cell0(id).area - cell1(jd).area) / max(1, meancellsize^2);
            end

            iouTerm = 0;
            if coefIoU > 0
                iou = computeIoU(cell0(id).pix, cell1(jd).pix);
                iouTerm = 1 - iou;
            end

            M(i,j) = coefDist * dist + coefSize * sizeTerm + coefIoU * iouTerm;
        end
    end

    [Matching, ~] = Hungarian(M);
    [row, col] = find(Matching);

    row = ind0(row);
    col = ind1(col);

    % Keep only finite-cost matches.
    keep = true(size(row));
    for ii = 1:numel(row)
        i0 = find(ind0 == row(ii), 1);
        j0 = find(ind1 == col(ii), 1);
        if isempty(i0) || isempty(j0) || isinf(M(i0, j0))
            keep(ii) = false;
        end
    end
    row = row(keep);
    col = col(keep);

    ind0n = [cell0.n];
    ind1n = [cell1.n];

    row2 = ind0n(row);
    col2 = ind1n(col);

    vec2 = [row2' col2'];

    lostcells = setdiff(ind0n(find(ind0n)), row2);
    vec2 = [vec2 ; [lostcells' zeros(length(lostcells),1)]]; %#ok<AGROW>

    newcells = setdiff(ind1n(find(ind1n)), col2);
    vec2 = [vec2 ; [zeros(length(newcells),1) newcells']]; %#ok<AGROW>

    newcell = cell1;
    count = lastObjectNumber;

    for i = 1:length(newcell)
        if newcell(i).ox ~= 0
            ind = newcell(i).n;
            ind = find(vec2(:,2) == ind, 1);

            if vec2(ind,1) ~= 0
                newcell(i).n = vec2(ind,1);
            else
                newcell(i).n = count + 1;
                count = count + 1;
            end
        end
    end

    cost = M;
end

function v = parseScalar(val, default)
    v = default;
    if iscell(val)
        if ~isempty(val)
            val = val{end};
        else
            return;
        end
    end
    if isstring(val) || ischar(val)
        tmp = str2double(char(val));
        if ~isnan(tmp)
            v = tmp;
        end
    elseif isnumeric(val) && isscalar(val)
        v = double(val);
    end
end

function l = getLabelFrame(imframe, inputMode)
% Return a labeled matrix with labels 1..N (no touching merge for label mode).
    if strcmpi(inputMode, 'binary')
        l = bwlabel(imframe > 0);
        return;
    end
    if strcmpi(inputMode, 'label')
        l = relabelPreserve(imframe);
        return;
    end

    % auto detection: if non-binary values exist -> label
    hasNonBinary = any(imframe(:) ~= 0 & imframe(:) ~= 1);
    if hasNonBinary
        l = relabelPreserve(imframe);
    else
        l = bwlabel(imframe > 0);
    end
end

function l2 = relabelPreserve(l)
% Relabel a label matrix without merging touching objects.
    l = uint32(l);
    labels = unique(l(:));
    labels(labels == 0) = [];
    l2 = zeros(size(l), 'uint16');
    for i = 1:numel(labels)
        l2(l == labels(i)) = i;
    end
end

function cells = assignNewIds(cells, startId)
% Assign sequential ids starting after startId if ids are empty.
    if isempty(cells)
        return;
    end
    for i = 1:numel(cells)
        cells(i).n = startId + i;
    end
end

function iou = computeIoU(pixA, pixB)
% Compute IoU between two PixelIdxList vectors.
    if isempty(pixA) || isempty(pixB)
        iou = 0;
        return;
    end
    inter = numel(intersect(pixA, pixB));
    uni = numel(pixA) + numel(pixB) - inter;
    if uni <= 0
        iou = 0;
    else
        iou = inter / uni;
    end
end

function v = getfieldwithdefault(s, field, default)
    if isfield(s, field)
        v = s.(field);
    else
        v = default;
    end
end
