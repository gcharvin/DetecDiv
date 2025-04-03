function layout = score_preProcessROI(roiobj, dataidx, param)
% Prépare l'image de la ROI avant affichage et calcule la mise en page
% en intégrant les panels de données sous chaque ROI.
%
% roiobj    : liste des ROIs à afficher
% dataidx   : liste d'index pour les données à afficher
% param     : paramètres d'affichage (frames, arraySize, overlayMode, channel, levels, crop, scalingFactor, imageSize, output, etc.)

layout = [];

roitmp = roiobj(1);
if numel(roitmp.image) == 0
    roitmp.load;
end

if isempty(param.frames)
    frames = size(roitmp.image,4);
else
    frames = param.frames;
end

layout.frames = frames;
layout.dataSelectedIdx = dataidx;
layout.subData = {};

ndata = 0;
n = 0;
plotidx = {};
plotidxgroup = {};
dataidx={};

for j = 1:numel(layout.dataSelectedIdx)
    idx = layout.dataSelectedIdx(j);
    data = roitmp.data(idx);
    subDataIdx = find(cellfun(@(x) x(:, 1) == true, data.plotProperties(:, 1)));
    layout.subData(j) = {subDataIdx};
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
end


layout.plotidx = plotidx;
layout.plotidxgroup = plotidxgroup;
layout.dataidx = dataidx;
layout.ngroup = n; % nombre de panels de données par ROI

% Mise en page pour l'affichage des images
nmov = size(roitmp,2);
if ~isempty(param.arraySize)
    nRows = param.arraySize(1);
    nCols = param.arraySize(2);
    if nmov > nRows*nCols
        disp('Error: the number of ROIs exceeds the allocated space!');
        return;
    end
else
    nCols = ceil(sqrt(nmov));
    nRows = ceil(nmov / nCols);
end

layout.nCols = nCols;
layout.nRows = nRows;

% Comptage des canaux non-indexés
nChannel = 0;
nonIndexedNames = {};
for j = 1:numel(param.channel)
    if ~iscell(param.levels{j})
        nChannel = nChannel + 1;
        if iscell(param.channel)
            nonIndexedNames{end+1} = param.channel{j};
        else
            nonIndexedNames{end+1} = param.channel(j);
        end
    end
end
if nChannel == 0, nChannel = 1; end

basesize = size(roitmp.image);
if ~isempty(param.crop)
    basesize(1) = param.crop(3);
    basesize(2) = param.crop(4);
end
if param.scalingFactor ~= 1
    basesize(1) = basesize(1) * param.scalingFactor;
    basesize(2) = basesize(2) * param.scalingFactor;
end
if ~isempty(param.imageSize)
    basesize(1) = basesize(1) * param.imageSize(1);
    basesize(2) = basesize(2) * param.imageSize(2);
end

layout.tileH = basesize(1);
layout.tileW = basesize(2);

% Calcul de la mise en page en fonction du mode de sortie
switch param.output
    case 'Sequence'
        if param.overlayMode
            globalRows = nRows * (1 + layout.ngroup);
            layout.size = [basesize(1)*(1+layout.ngroup), basesize(2), 3, numel(frames)];
            layout.imagesize = [basesize(1), basesize(2), 3, numel(frames)];
        else
            globalRows = nRows * (nChannel + layout.ngroup);
            layout.size = [basesize(1)*(nChannel+layout.ngroup), basesize(2), 3, numel(frames)];
            layout.imagesize = [basesize(1)*nChannel, basesize(2), 3, numel(frames)];
        end
        globalCols = nCols * numel(frames);
        
    case 'Movie'
        globalRows = nRows * (1 + layout.ngroup);
        if param.overlayMode
            globalCols = nCols;
            layout.size = [basesize(1)*(1+layout.ngroup), basesize(2), 3, numel(frames)];
            layout.imagesize = [basesize(1), basesize(2), 3, numel(frames)];
        else
            globalCols = nCols * nChannel;
            layout.size = [basesize(1)*(1+layout.ngroup), basesize(2)*nChannel, 3, numel(frames)];
            layout.imagesize = [basesize(1), basesize(2)*nChannel, 3, numel(frames)];
        end
        
    case 'Display'
        globalRows = 1 + layout.ngroup;
        if param.overlayMode
            globalCols = 1;
            layout.size = [basesize(1)*(1+layout.ngroup), basesize(2), 3, numel(frames)];
            layout.imagesize = [basesize(1), basesize(2), 3, numel(frames)];
        else
            layout.size = [basesize(1)*(1+layout.ngroup), basesize(2)*nChannel, 3, numel(frames)];
            layout.imagesize = [basesize(1), basesize(2)*nChannel, 3, numel(frames)];
            globalCols = nChannel;
        end
end

layout.globalCols = globalCols;
layout.globalRows = globalRows;
layout.nonIndexedNames = nonIndexedNames;
end
