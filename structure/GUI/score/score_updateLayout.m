function layoutOut=score_updateLayout(layoutOptions,roiobj)

 roitmp = roiobj(1);
score_applyDefaultChannelSelection(roitmp);
if numel(roitmp.image) == 0
    score_loadChannelsForDisplay(roitmp, []);
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

    % Pour chaque channel, construire un vecteur numérique [low high]
    levels = cell(1, numel(selCh));
    displayLevels = cell(1, numel(selCh));
    for i = 1:numel(selCh)
        idx = selCh(i);

       

        % map logical channel -> first sub-channel index
        subIdx = find(roitmp.channelid == idx, 1, 'first');
        if isempty(subIdx)
            subIdx = idx; % fallback
        end
        lims = dsC.displaylim(:, subIdx);
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
    layoutOptions.levels=levels;
    layoutOptions.displayLevels=displayLevels;
    layoutOptions.RGB=colors;
    layoutOptions.colorMode=colorMode;
    layoutOptions.colormapName=colormapName;
    layoutOptions.weights=weights;
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

    if numel( data.plotProperties)
    subDataIdx = find(cellfun(@(x) x(:, 1) == true, data.plotProperties(:, 1)));
    layoutOptions.subData(j) = {subDataIdx};
    ndata = ndata + numel(subDataIdx);
    
    % Calcul du nombre de groupes à afficher (pour les panels de données)
    groups = data.plotGroup{6};
    for i = 1:numel(groups)
        pix = contains(data.plotProperties(:, end), string(groups{i}));
        pix2 = cellfun(@(x) x(:, 1) == true, data.plotProperties(:, 1));
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
nChannel = 0;
nonIndexedNames = {};
nonIndexedScale = [];
nonIndexedLog = [];
nonIndexedDisplayLevels = {};
nonIndexedColorMode = {};
nonIndexedColormapName = {};
for j = 1:numel(layoutOptions.channel)
    if ~iscell(layoutOptions.levels{j})
        nChannel = nChannel + 1;
        if iscell(layoutOptions.channel)
            nonIndexedNames{end+1} = layoutOptions.channel{j};
        else
            nonIndexedNames{end+1} = layoutOptions.channel(j);
        end
        if isfield(layoutOptions, 'scale') && numel(layoutOptions.scale) >= j
            nonIndexedScale(end+1) = logical(layoutOptions.scale(j)); %#ok<AGROW>
        else
            nonIndexedScale(end+1) = false; %#ok<AGROW>
        end
        if isfield(layoutOptions, 'log') && numel(layoutOptions.log) >= j
            nonIndexedLog(end+1) = logical(layoutOptions.log(j)); %#ok<AGROW>
        else
            nonIndexedLog(end+1) = false; %#ok<AGROW>
        end
        if isfield(layoutOptions, 'displayLevels') && numel(layoutOptions.displayLevels) >= j
            nonIndexedDisplayLevels{end+1} = layoutOptions.displayLevels{j}; %#ok<AGROW>
        else
            nonIndexedDisplayLevels{end+1} = layoutOptions.levels{j}; %#ok<AGROW>
        end
        if isfield(layoutOptions, 'colorMode') && numel(layoutOptions.colorMode) >= j
            nonIndexedColorMode{end+1} = layoutOptions.colorMode{j}; %#ok<AGROW>
        else
            nonIndexedColorMode{end+1} = 'rgb'; %#ok<AGROW>
        end
        if isfield(layoutOptions, 'colormapName') && numel(layoutOptions.colormapName) >= j
            nonIndexedColormapName{end+1} = layoutOptions.colormapName{j}; %#ok<AGROW>
        else
            nonIndexedColormapName{end+1} = ''; %#ok<AGROW>
        end
    end
end
layoutOptions.scale = logical(nonIndexedScale);
layoutOptions.log = logical(nonIndexedLog);
layoutOptions.displayLevels = nonIndexedDisplayLevels;
layoutOptions.colorMode = nonIndexedColorMode;
layoutOptions.colormapName = nonIndexedColormapName;

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
