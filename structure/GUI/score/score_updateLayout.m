function layoutOut=score_updateLayout(layoutOptions,roiobj)

 roitmp = roiobj(1);
score_applyDefaultChannelSelection(roitmp);
score_loadChannelsForDisplay(roitmp, []);
score_loadChannelsForDisplay(roitmp, localObjectMaskProviders(roitmp));
if numel(roitmp.image) == 0
    try
        roitmp.load('Data', false, 'Silent');
    catch
        roitmp.load;
    end
end


fmin=1;
fmax=size(roitmp.image,4);
 isValid = all(layoutOptions.frames >= fmin & layoutOptions.frames <= fmax);


if ~isValid
  layoutOut=[];
  disp('Frames do not exist; Quitting!');
  return;
end


% if isempty(param.frames)
%     frames = size(roitmp.image,4);
% else
%     frames = layoutOptions.frames;
% end

%% channel specific parameters

dsC = roitmp.display;
% HERE
% On ne considère que les channels sélectionnés

dsC = normalizeChannelSelectionForScore(dsC);
dsC = normalizeChannelScaleForScore(dsC);

selCh = find(dsC.selectedchannel);
cmap=layoutOptions.colormap;
layoutOptions.objectDisplay = struct([]);
layoutOptions.channel = {};
layoutOptions.channelLabel = {};
layoutOptions.levels = {};
layoutOptions.displayLevels = {};
layoutOptions.RGB = {};
layoutOptions.colorMode = {};
layoutOptions.colormapName = {};
layoutOptions.weights = [];
layoutOptions.scale = false(1, 0);
layoutOptions.log = false(1, 0);

%  if size( dsC.displaylim,2)~=numel(roitmp.channelid)
% roitmp.computeDisplaylim;
%  end

if ~isfield(dsC,'displaylim') || isempty(dsC.displaylim) || size(dsC.displaylim,2) ~= numel(roitmp.channelid)
    roitmp.computeDisplaylim; % logique
    dsC = roitmp.display;
end




if ~isempty(selCh)
    % Récupérer le nom des channels (cell array de chaînes)
    channels = dsC.channel(selCh);
    channelLabels = localChannelLabels(dsC, selCh);

    % Pour chaque channel, construire un vecteur numérique [low high]
    levels = cell(1, numel(selCh));
    displayLevels = cell(1, numel(selCh));
    keepCh = true(1, numel(selCh));
    for i = 1:numel(selCh)
        idx = selCh(i);

       

        % map logical channel -> first sub-channel index
        subIdx = find(roitmp.channelid == idx, 1, 'first');
        if isempty(subIdx) || subIdx > size(roitmp.image, 3)
            try
                score_loadChannelsForDisplay(roitmp, dsC.channel(idx));
                dsC = normalizeChannelSelectionForScore(roitmp.display);
                dsC = normalizeChannelScaleForScore(dsC);
                subIdx = find(roitmp.channelid == idx, 1, 'first');
            catch
                subIdx = [];
            end
        end
        if isempty(subIdx) || subIdx > size(roitmp.image, 3)
            keepCh(i) = false;
            continue;
        end
        if ~isfield(dsC,'displaylim') || isempty(dsC.displaylim) || size(dsC.displaylim, 2) < subIdx
            try
                roitmp.computeDisplaylim('Channel', subIdx);
                dsC = roitmp.display;
            catch
            end
        end
        if ~isfield(dsC,'displaylim') || isempty(dsC.displaylim) || size(dsC.displaylim, 2) < subIdx
            lims = [0; 1];
        else
            lims = dsC.displaylim(:, subIdx);
        end
        if ~dsC.indexed(idx) && isDefaultDisplayLim(lims)
            [lowVal, highVal] = autoDisplayLevelsFromImage(roitmp, subIdx);
        else
            lowVal  = round(65535 * lims(1));
            highVal = round(65535 * lims(2));
        end

        levels{i} = [lowVal, highVal];
        displayLevels{i} = score_decodeChannelValues(roitmp, idx, [lowVal, highVal]);

        if dsC.indexed(idx)
            levels{i}={};
            displayLevels{i}={};
            levels{i}{1}='-1';
            levels{i}{2}=cmap; 
            levels{i}{3}=dsC.alpha(idx);
            levels{i}{4}=dsC.contour(idx);
            levels{i}{5}=dsC.width(idx);
        else
            levels{i} = [lowVal, highVal];
            displayLevels{i} = score_decodeChannelValues(roitmp, idx, [lowVal, highVal]);
        end
    end
    selCh = selCh(keepCh);
    levels = levels(keepCh);
    displayLevels = displayLevels(keepCh);
    channels = channels(keepCh);
    channelLabels = channelLabels(keepCh);

    % Construire pour chaque channel le vecteur RGB
    colors = cell(1, numel(selCh));
    colorMode = cell(1, numel(selCh));
    colormapName = cell(1, numel(selCh));
    for i = 1:numel(selCh)
        idx = selCh(i);
        colors{i} = dsC.rgb(idx, :);
        colorMode{i} = localDisplayCellValue(dsC, 'colorMode', idx, 'rgb');
        colormapName{i} = localDisplayCellValue(dsC, 'colormapName', idx, '');
    end

    % Construire les poids pour chaque channel en tant que vecteur numérique
    weights = dsC.alpha(selCh);  % Extraction directe sous forme numérique

    layoutOptions.channel=channels;
    layoutOptions.channelLabel=channelLabels;
    layoutOptions.levels=levels;
    layoutOptions.displayLevels=displayLevels;
    layoutOptions.RGB=colors;
    layoutOptions.colorMode=colorMode;
    layoutOptions.colormapName=colormapName;
    layoutOptions.weights=weights;
    objectDisplay = struct([]);
    for i = 1:numel(channels)
        cfg = score_getObjectDisplayConfig(roitmp, channels{i});
        if isempty(objectDisplay)
            objectDisplay = cfg;
        else
            objectDisplay(end+1) = cfg; %#ok<AGROW>
        end
    end
    layoutOptions.objectDisplay = objectDisplay;
    if ~isempty(objectDisplay)
        styleIdx = 1;
        try
            if isfield(roitmp.display, 'lineage') && ...
                    isfield(roitmp.display.lineage, 'channelName')
                hit = find(strcmpi(string({objectDisplay.channelName}), ...
                    string(roitmp.display.lineage.channelName)), 1, 'first');
                if ~isempty(hit), styleIdx = hit; end
            end
        catch
        end
        layoutOptions.BudLinkColor = objectDisplay(styleIdx).budLinkColor;
        layoutOptions.GenealogyLinkColor = objectDisplay(styleIdx).genealogyLinkColor;
    end
    try
        if isfield(roitmp.display, 'lineage')
            if isfield(roitmp.display.lineage, 'showBudPairing')
                layoutOptions.ShowBudPairingOverlay = logical(roitmp.display.lineage.showBudPairing);
            end
            if isfield(roitmp.display.lineage, 'showGenealogy')
                layoutOptions.ShowLineageOverlay = logical(roitmp.display.lineage.showGenealogy);
            end
        end
    catch
    end
    layoutOptions.scale=logical(dsC.scale(selCh));
    if isfield(dsC, 'log') && ~isempty(dsC.log)
        layoutOptions.log=logical(dsC.log(selCh));
    else
        layoutOptions.log=false(1, numel(selCh));
    end
end

%% data specfic parameters

dataidx=[];
for i=1:numel(roitmp.data)
        if roitmp.data(i).show
            dataidx=[dataidx i];
        end
end

if numel(dataidx)
layoutOptions.dataSelectedIdx = dataidx;
layoutOptions.subData = {};

ndata = 0;
n = 0;
plotidx = {};
plotidxgroup = {};
dataidx={};

for j = 1:numel(layoutOptions.dataSelectedIdx)
    idx = layoutOptions.dataSelectedIdx(j);
    data = roitmp.data(idx);
    nDataVars = localDataVariableCount(data);

    if numel( data.plotProperties)
    lineageRows = false(size(data.plotProperties, 1), 1);
    try
        if size(data.plotProperties, 2) >= 3
            lineageRows = strcmp(string(data.plotProperties(:,3)), "lineageSource");
        end
        if isprop(data, 'groupid') && strcmp(char(string(data.groupid)), 'cell_information') && ...
                size(data.plotProperties, 2) >= 2
            lineageRows = lineageRows | strcmp(string(data.plotProperties(:,2)), "lineage");
        end
    catch
        lineageRows = false(size(data.plotProperties, 1), 1);
    end
    validRows = (1:size(data.plotProperties, 1))' <= nDataVars;
    subDataIdx = find(cellfun(@(x) x(:, 1) == true, data.plotProperties(:, 1)) & ~lineageRows & validRows);
    layoutOptions.subData(j) = {subDataIdx};
    ndata = ndata + numel(subDataIdx);
    
    % Calcul du nombre de groupes à afficher (pour les panels de données)
    groups = data.plotGroup{6};
    for i = 1:numel(groups)
        pix = contains(data.plotProperties(:, end), string(groups{i}));
        pix2 = cellfun(@(x) x(:, 1) == true, data.plotProperties(:, 1)) & ~lineageRows & validRows;
        pix = find(pix & pix2);  % indices des plots à afficher
        if ~isempty(pix)
            n = n + 1;
            plotidx{n} = pix;
            plotidxgroup{n} = groups{i};
            dataidx{n} = idx;
        end
    end
    else
      plotidx={};
      plotidxgroup={};
      dataidx={};
       n=0;

    end
end

layoutOptions.plotidx = plotidx;
layoutOptions.plotidxgroup = plotidxgroup;
layoutOptions.dataidx = dataidx;
layoutOptions.ngroup = n; % nombre de panels de données par ROI
layoutOptions.Ndataseries=layoutOptions.ngroup ;
end


% Comptage des canaux non-indexés
isIndexedChannel = false(1, numel(layoutOptions.levels));
for j = 1:numel(layoutOptions.levels)
    isIndexedChannel(j) = iscell(layoutOptions.levels{j});
end
nonIndexedOrder = find(~isIndexedChannel);
indexedOrder = find(isIndexedChannel);
displayOrder = [nonIndexedOrder indexedOrder];
nChannel = numel(nonIndexedOrder);

layoutOptions.channel = localReorderDisplayField(layoutOptions.channel, displayOrder);
layoutOptions.levels = localReorderDisplayField(layoutOptions.levels, displayOrder);
if isfield(layoutOptions, 'channelLabel')
    layoutOptions.channelLabel = localReorderDisplayField(layoutOptions.channelLabel, displayOrder);
end
if isfield(layoutOptions, 'RGB')
    layoutOptions.RGB = localReorderDisplayField(layoutOptions.RGB, displayOrder);
end
if isfield(layoutOptions, 'colorMode')
    layoutOptions.colorMode = localReorderDisplayField(layoutOptions.colorMode, displayOrder);
end
if isfield(layoutOptions, 'colormapName')
    layoutOptions.colormapName = localReorderDisplayField(layoutOptions.colormapName, displayOrder);
end
if isfield(layoutOptions, 'weights')
    layoutOptions.weights = localReorderDisplayField(layoutOptions.weights, displayOrder);
end

scale = localReorderDisplayField(layoutOptions.scale, displayOrder);
layoutOptions.scale = logical(scale(1:nChannel));

if isfield(layoutOptions, 'log')
    logFlags = localReorderDisplayField(layoutOptions.log, displayOrder);
    layoutOptions.log = logical(logFlags(1:nChannel));
else
    layoutOptions.log = false(1, nChannel);
end

displayLevels = localReorderDisplayField(layoutOptions.displayLevels, displayOrder);
layoutOptions.displayLevels = displayLevels(1:nChannel);
if isfield(layoutOptions, 'channelLabel')
    layoutOptions.nonIndexedNames = layoutOptions.channelLabel(1:nChannel);
else
    layoutOptions.nonIndexedNames = layoutOptions.channel(1:nChannel);
end

%% layout parameters

basesize = size(roitmp.image);
if ~isempty(layoutOptions.crop)
    basesize(1) = layoutOptions.crop(3);
    basesize(2) = layoutOptions.crop(4);
end

if layoutOptions.scalingFactor ~= 1
    basesize(1) = basesize(1) * layoutOptions.scalingFactor;
    basesize(2) = basesize(2) * layoutOptions.scalingFactor;
end
if ~isempty(layoutOptions.imageSize)
    basesize(1) = basesize(1) * layoutOptions.imageSize(1);
    basesize(2) = basesize(2) * layoutOptions.imageSize(2);
end

layoutOptions.tileH = basesize(1);
layoutOptions.tileW = basesize(2);
layoutOptions.Nchannel=nChannel;
layoutOut=layoutOptions;
end

function value = localReorderDisplayField(value, order)
if isempty(order)
    value = value([]);
    return;
end

try
    order = order(order >= 1 & order <= numel(value));
    if iscell(value)
        value = value(order);
    elseif isstring(value)
        value = value(order);
    else
        wasColumn = iscolumn(value);
        value = value(order);
        if wasColumn
            value = value(:);
        else
            value = value(:).';
        end
    end
catch
end
end

function tf = isDefaultDisplayLim(lims)
tf = false;
try
    tf = numel(lims) >= 2 && abs(double(lims(1))) < eps && abs(double(lims(2)) - 1) < eps;
catch
    tf = false;
end
end

function [lowVal, highVal] = autoDisplayLevelsFromImage(roitmp, subIdx)
lowVal = 0;
highVal = 65535;
try
    vals = double(roitmp.image(:,:,subIdx,:));
    vals = vals(:);
    vals = vals(isfinite(vals));
    if isempty(vals)
        return;
    end
    lo = prctile(vals, 0.1);
    hi = prctile(vals, 99.9);
    if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
        lo = min(vals);
        hi = max(vals);
    end
    if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
        hi = lo + 1;
    end
    lowVal = max(0, round(lo));
    highVal = min(65535, max(lowVal + 1, round(hi)));
catch
    lowVal = 0;
    highVal = 65535;
end
end

function value = localDisplayCellValue(dsC, fieldName, idx, defaultValue)
value = defaultValue;
if ~isfield(dsC, fieldName) || isempty(dsC.(fieldName)) || idx > numel(dsC.(fieldName))
    return;
end
try
    value = char(string(dsC.(fieldName){idx}));
catch
    value = defaultValue;
end
end

function n = localDataVariableCount(data)
n = 0;
try
    if ~isprop(data, 'data') || isempty(data.data)
        return;
    end
    if istable(data.data)
        n = width(data.data);
    elseif isstruct(data.data)
        n = numel(fieldnames(data.data));
    elseif iscell(data.data)
        n = size(data.data, 2);
    else
        n = size(data.data, 2);
    end
catch
    n = 0;
end
end

function labels = localChannelLabels(dsC, selCh)
labels = dsC.channel(selCh);
if ~isfield(dsC, 'channelAlias') || isempty(dsC.channelAlias)
    return;
end
try
    for i = 1:numel(selCh)
        idx = selCh(i);
        if idx <= numel(dsC.channelAlias) && strlength(string(dsC.channelAlias{idx})) > 0
            labels{i} = char(string(dsC.channelAlias{idx}));
        end
    end
catch
    labels = dsC.channel(selCh);
end
end

function providers = localObjectMaskProviders(roiobj)
providers = {};
try
    if ~isfield(roiobj.display, 'objectDisplay') || ...
            ~isstruct(roiobj.display.objectDisplay) || ...
            ~isfield(roiobj.display.objectDisplay, 'channels')
        return;
    end
    records = roiobj.display.objectDisplay.channels;
    for i = 1:numel(records)
        if ~isfield(records, 'maskProvider')
            continue;
        end
        provider = char(string(records(i).maskProvider));
        if ~any(strcmp(provider, {'','<family default>'}))
            providers{end+1} = provider; %#ok<AGROW>
        end
    end
    providers = unique(providers, 'stable');
catch
    providers = {};
end
end

function dsC = normalizeChannelScaleForScore(dsC)
if ~isstruct(dsC) || ~isfield(dsC, 'channel') || isempty(dsC.channel)
    return;
end

nCh = numel(dsC.channel);
if ~isfield(dsC, 'scale') || isempty(dsC.scale)
    dsC.scale = false(1, nCh);
else
    scale = logical(dsC.scale(:)');
    scale = scale(1:min(numel(scale), nCh));
    if numel(scale) < nCh
        scale(end+1:nCh) = false;
    end
    dsC.scale = scale;
end
end

function dsC = normalizeChannelSelectionForScore(dsC)
if ~isstruct(dsC) || ~isfield(dsC, 'channel') || isempty(dsC.channel)
    return;
end

nCh = numel(dsC.channel);
if ~isfield(dsC, 'selectedchannel') || isempty(dsC.selectedchannel)
    dsC.selectedchannel = true(1, nCh);
else
    sel = logical(dsC.selectedchannel(:)');
    sel = sel(1:min(numel(sel), nCh));
    if numel(sel) < nCh
        sel(end+1:nCh) = true;
    end
    dsC.selectedchannel = sel;
end

end
