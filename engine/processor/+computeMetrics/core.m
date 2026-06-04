function [paramout, dataout, imageout] = core(param, roiobj, frames) %#ok<INUSD>
% computeMetrics.core  Compute mask geometry and mask-linked channel metrics.

imageout = [];

if nargin == 0
    paramout = computeMetrics.setparam(struct());
    dataout = [];
    return;
end

paramout = normalizeComputeMetricsParams(param);
disp('computeMetrics processing...');

if numel(roiobj.image) == 0
    roiobj.load;
end

dataout = roiobj.data;
if numel(dataout) == 0
    dataout = dataseries;
end

maskCount = paramout.maskChannelCount;
scoreCount = paramout.scoreChannelCount;

for i = 1:maskCount
    maskName = paramout.(sprintf('mask%d_name', i));
    if ~paramout.(sprintf('mask%d_stat', i)) || strcmp(maskName, 'N/A')
        continue;
    end

    cha = roiobj.findChannelID(maskName);
    if isempty(cha)
        warning('computeMetrics:MissingMaskChannel', ...
            'Mask channel "%s" is unavailable for ROI %s.', maskName, roiIdText(roiobj));
        continue;
    end

    dataout = computeMaskGeometry(dataout, roiobj, paramout, i, cha);
end

channelsExtract = {};
channelsName = {};
for i = 1:scoreCount
    channelName = paramout.(sprintf('channel%d_name', i));
    if strcmp(channelName, 'N/A')
        continue;
    end
    cha = roiobj.findChannelID(channelName);
    if isempty(cha)
        warning('computeMetrics:MissingScoreChannel', ...
            'Score channel "%s" is unavailable for ROI %s.', channelName, roiIdText(roiobj));
        continue;
    end
    channelsExtract{end+1} = cha; %#ok<AGROW>
    channelsName{end+1} = channelName; %#ok<AGROW>
end

if isempty(channelsExtract)
    return;
end

[dataout] = computeChannelQuantification(dataout, roiobj, paramout, channelsExtract, channelsName);
end

function paramout = normalizeComputeMetricsParams(param)
paramout = param;
if ~isstruct(paramout)
    paramout = struct();
end

paramout.maskChannelCount = countParam(paramout, {'maskChannelCount','maskCount'}, inferIndexedCount(paramout, '^mask(\d+)_name$', 2), 1, 8);
paramout.scoreChannelCount = countParam(paramout, {'scoreChannelCount','channelCount'}, inferIndexedCount(paramout, '^channel(\d+)_name$', 4), 0, 12);

for i = 1:paramout.maskChannelCount
    nameKey = sprintf('mask%d_name', i);
    statKey = sprintf('mask%d_stat', i);
    classKey = sprintf('mask%d_class', i);
    labelKey = sprintf('mask%d_label', i);
    if ~isfield(paramout, nameKey) || isempty(paramout.(nameKey))
        paramout.(nameKey) = 'N/A';
    end
    paramout.(nameKey) = selectedText(paramout.(nameKey), 'N/A');
    if ~isfield(paramout, statKey) || isempty(paramout.(statKey))
        paramout.(statKey) = true;
    end
    paramout.(statKey) = logical(paramout.(statKey));
    if ~isfield(paramout, classKey) || isempty(paramout.(classKey))
        paramout.(classKey) = 2;
    end
    paramout.(classKey) = numericScalar(paramout.(classKey), 2);
    if ~isfield(paramout, labelKey) || isempty(paramout.(labelKey))
        paramout.(labelKey) = defaultMaskLabel(i);
    end
    paramout.(labelKey) = selectedText(paramout.(labelKey), defaultMaskLabel(i));
end

for i = 1:paramout.scoreChannelCount
    key = sprintf('channel%d_name', i);
    if ~isfield(paramout, key) || isempty(paramout.(key))
        paramout.(key) = 'N/A';
    end
    paramout.(key) = selectedText(paramout.(key), 'N/A');
end

if ~isfield(paramout, 'BrightestPixels') || isempty(paramout.BrightestPixels)
    paramout.BrightestPixels = 20;
end
paramout.BrightestPixels = max(1, round(numericScalar(paramout.BrightestPixels, 20)));
end

function dataout = computeMaskGeometry(dataout, roiobj, paramout, maskIndex, cha)
maskName = paramout.(sprintf('mask%d_name', maskIndex));
maskClass = paramout.(sprintf('mask%d_class', maskIndex));
maskLabel = paramout.(sprintf('mask%d_label', maskIndex));

BW_3D = roiobj.image(:,:,cha,:);
roiobj.data = roiobj.data(isvalid(roiobj.data));
groupId = ['mask_quantification_' makeSafeVariableName(maskLabel)];
pixdata = find(arrayfun(@(x) strcmp(x.groupid, groupId), roiobj.data));
if ~isempty(pixdata)
    cc = pixdata(1);
else
    if numel(dataout) == 1 && isempty(dataout.data)
        cc = 1;
    else
        cc = numel(dataout) + 1;
    end
end

nb_temps = size(BW_3D, 4);
if maskClass == 0
    liste_valeurs = unique(BW_3D(:));
    liste_valeurs = setxor(liste_valeurs, 0);
else
    liste_valeurs = maskClass;
end

surface = zeros(length(liste_valeurs), nb_temps);
axe_majeur = zeros(length(liste_valeurs), nb_temps);
axe_mineur = zeros(length(liste_valeurs), nb_temps);
eccentricity = zeros(length(liste_valeurs), nb_temps);
cellvolume = zeros(length(liste_valeurs), nb_temps);
cellsurface = zeros(length(liste_valeurs), nb_temps);

BW_3D = permute(BW_3D, [1 2 4 3]);
BW_big = zeros(size(BW_3D));
BW_big = repmat(BW_big, [1 1 1 length(liste_valeurs)]);
for v = 1:length(liste_valeurs)
    BW_big(:,:,:,v) = BW_3D == liste_valeurs(v);
end

BWcell = mat2cell(BW_big, size(BW_big,1), size(BW_big,2), ones(1,size(BW_big,3)), ones(1,size(BW_big,4)));
stats = cellfun(@(BW) regionprops(BW, 'Area', 'MajorAxisLength', 'MinorAxisLength', 'Eccentricity'), BWcell, 'UniformOutput', false);
stats = permute(stats, [3 4 1 2]);
output = cellfun(@getra, stats, 'UniformOutput', false);
if ~isempty(output)
    output = cell2mat(output);
    output = output';
    surface = output(1:4:end,:);
    axe_majeur = output(2:4:end,:);
    axe_mineur = output(3:4:end,:);
    eccentricity = output(4:4:end,:);
end

r = axe_mineur;
h = axe_majeur - r;
cellvolume = 4*pi*r.^3/3 + pi*r.^2.*h;
cellsurface = 4*pi*r.^2 + 2*pi.*r.*h;

cell_data = [surface(1,:); axe_mineur(1,:); axe_majeur(1,:); eccentricity(1,:); cellvolume(1,:); cellsurface(1,:)];
cell_name = {'Area_Cell','LenMinAxis_Cell','LenMajAxis_Cell','Eccentric_Cell','Vol_Cell','Surf_Cell'};
plotgroup = {'Area','Length','Length','Number','Volume','Area'};
defplot = {true,true,true,true,true,true};

temp = dataseries(cell_data', cell_name, ...
    'groupid', groupId, 'parentid', roiobj.id, 'plot', defplot, 'groups', plotgroup);
dataout(cc) = temp;
dataout(cc).class = "processing";
if ~isstruct(dataout(cc).userData)
    dataout(cc).userData = struct();
end
dataout(cc).userData.mask_channel = maskName;
dataout(cc).userData.mask_label = maskLabel;
dataout(cc).userData.mask_class = maskClass;
dataout(cc).plotGroup = {[] [] [] [] [] unique(plotgroup)};

if numel(liste_valeurs) > 1
    dataout(cc).data.Area_Cell = surface';
    dataout(cc).data.LenMinAxis_Cell = axe_mineur';
    dataout(cc).data.LenMajAxis_Cell = axe_majeur';
    dataout(cc).data.Eccentric_Cell = eccentricity';
    dataout(cc).data.Vol_Cell = cellvolume';
    dataout(cc).data.Surf_Cell = cellsurface';
end
end

function dataout = computeChannelQuantification(dataout, roiobj, paramout, channelsExtract, channelsName)
im = roiobj.image;
pixels = reshape(im, [], size(im,3), size(im,4));
N = paramout.BrightestPixels;
maskCount = paramout.maskChannelCount;

name = {};
group = {};
defplot = {};
datRaw = [];

for m = 1:maskCount
    maskName = paramout.(sprintf('mask%d_name', m));
    if strcmp(maskName, 'N/A')
        continue;
    end
    maskChannel = roiobj.findChannelID(maskName);
    if isempty(maskChannel)
        continue;
    end

    metrics = computeMaskFluorescenceMetrics(im, pixels, roiobj.image(:,:,maskChannel,:), ...
        paramout.(sprintf('mask%d_class', m)), N);
    if isempty(metrics)
        continue;
    end

    maskLabel = paramout.(sprintf('mask%d_label', m));
    for i = 1:numel(channelsExtract)
        cha = channelsExtract{i};
        channelName = channelsName{i};
        metricNames = { ...
            localMetricVarName('Mean', channelName, maskLabel), ...
            localMetricVarName('Tot', channelName, maskLabel), ...
            localMetricVarName('MeanTop', channelName, maskLabel), ...
            localMetricVarName('TotTop', channelName, maskLabel), ...
            localMetricVarName('Mean_Bckg', channelName, maskLabel), ...
            localMetricVarName('MeanNoBckg', channelName, maskLabel)};
        name = [name, metricNames]; %#ok<AGROW>
        group = [group, {['Mean_' channelName], ['Total_' channelName], ['Mean_' channelName], ...
            ['Total_' channelName], ['Mean_' channelName], ['Mean_' channelName]}]; %#ok<AGROW>
        defplot = [defplot, {false,false,false,false,false,true}]; %#ok<AGROW>
        datRaw = [datRaw, ...
            mean(metrics.moyennes(1,cha,:), 2), ...
            mean(metrics.sommes(1,cha,:), 2), ...
            mean(metrics.moyenne_brillants(1,cha,:), 2), ...
            mean(metrics.somme_brillants(1,cha,:), 2), ...
            mean(metrics.moyenne_exterieur(1,cha,:), 2), ...
            mean(metrics.difference(1,cha,:), 2)]; %#ok<AGROW>
    end

    for i = 1:numel(channelsExtract)
        for j = i+1:numel(channelsExtract)
            cha_i = channelsExtract{i};
            cha_j = channelsExtract{j};
            ratioMeanNoBckg = mean(metrics.difference(1,cha_i,:), 2) ./ mean(metrics.difference(1,cha_j,:), 2);
            ratioName = localRatioMetricVarName(channelsName{i}, channelsName{j}, maskLabel);
            name = [name, ratioName]; %#ok<AGROW>
            group = [group, {ratioName}]; %#ok<AGROW>
            defplot = [defplot, {false}]; %#ok<AGROW>
            datRaw = [datRaw, ratioMeanNoBckg]; %#ok<AGROW>
        end
    end
end

if isempty(datRaw)
    return;
end

dat = permute(datRaw, [3 2 1]);
temp = dataseries(dat, name, ...
    'groupid', 'channel_quantification', 'parentid', roiobj.id, 'plot', defplot, 'groups', group);

pixdata = find(arrayfun(@(x) strcmp(x.groupid, 'channel_quantification'), dataout));
if ~isempty(pixdata)
    cc = pixdata(1);
else
    if numel(dataout) == 1 && isempty(dataout.data)
        cc = 1;
    else
        cc = numel(dataout) + 1;
    end
end

dataout(cc) = temp;
dataout(cc).class = "processing";
if ~isstruct(dataout(cc).userData)
    dataout(cc).userData = struct();
end
for m = 1:maskCount
    dataout(cc).userData.(sprintf('mask%d_class', m)) = paramout.(sprintf('mask%d_class', m));
end
dataout(cc).plotGroup = {[] [] [] [] [] unique(group)};
end

function metrics = computeMaskFluorescenceMetrics(im, pixels, maskImage, maskClass, N)
if maskClass == 0
    liste_valeurs = unique(maskImage(:));
    liste_valeurs = setxor(liste_valeurs, 0);
else
    liste_valeurs = maskClass;
end

if isempty(liste_valeurs)
    metrics = [];
    return;
end

bw = maskImage .* uint16(ismember(maskImage, liste_valeurs));
bw = repmat(bw, [1 1 1 1 size(im,3)]);
bw = permute(bw, [1 2 5 4 3]);
bw = reshape(bw, [], size(bw,3), size(bw,4));

vals = unique(bw);
matsize = max(1, length(vals) - 1);
moyennes = NaN * ones(matsize, size(bw,2), size(bw,3));
sommes = moyennes;
moyenne_brillants = moyennes;
somme_brillants = moyennes;
moyenne_exterieur = NaN * ones(1, size(bw,2), size(bw,3));

for t = 1:size(bw,3)
    for k = 1:size(bw,2)
        cc = 1;
        for j = 1:numel(vals)
            vpix = pixels(:,k,t);
            tmp = bw(:,k,t);
            pix = tmp == vals(j);
            if vals(j) == min(vals)
                moyenne_exterieur(1,k,t) = mean(vpix(pix));
            else
                moyennes(cc,k,t) = mean(vpix(pix));
                sommes(cc,k,t) = sum(vpix(pix));
                moyenne_brillants(cc,k,t) = meanTopNValues(vpix(pix), N);
                somme_brillants(cc,k,t) = sumTopNValues(vpix(pix), N);
                cc = cc + 1;
            end
        end
    end
end

metrics = struct( ...
    'moyennes', moyennes, ...
    'sommes', sommes, ...
    'moyenne_brillants', moyenne_brillants, ...
    'somme_brillants', somme_brillants, ...
    'moyenne_exterieur', moyenne_exterieur, ...
    'difference', moyennes - moyenne_exterieur);
end

function n = countParam(params, keys, defaultValue, minValue, maxValue)
n = defaultValue;
for i = 1:numel(keys)
    key = keys{i};
    if isfield(params, key) && ~isempty(params.(key))
        n = numericScalar(params.(key), defaultValue);
        break;
    end
end
n = min(maxValue, max(minValue, round(n)));
end

function n = inferIndexedCount(params, pattern, defaultValue)
n = defaultValue;
if ~isstruct(params)
    return;
end
names = fieldnames(params);
for i = 1:numel(names)
    tokens = regexp(names{i}, pattern, 'tokens', 'once');
    if ~isempty(tokens)
        n = max(n, str2double(tokens{1}));
    end
end
end

function out = selectedText(value, defaultValue)
out = defaultValue;
try
    if iscell(value)
        value = value{end};
    end
    out = char(string(value));
    out = strtrim(out);
    if isempty(out)
        out = defaultValue;
    end
catch
    out = defaultValue;
end
end

function out = numericScalar(value, defaultValue)
out = defaultValue;
try
    if iscell(value)
        value = value{end};
    end
    out = double(value);
catch
    out = defaultValue;
end
if isempty(out) || ~isscalar(out) || ~isfinite(out)
    out = defaultValue;
end
end

function label = defaultMaskLabel(i)
defaults = {'cyto','nucleus'};
if i <= numel(defaults)
    label = defaults{i};
else
    label = sprintf('mask%d', i);
end
end

function txt = roiIdText(roiobj)
txt = '<unknown>';
try
    txt = char(string(roiobj.id));
catch
end
end

function y = getra(x)
if numel(x) == 0
    y = [NaN NaN NaN NaN];
else
    y = [x.Area x.MajorAxisLength x.MinorAxisLength x.Eccentricity];
end
end

function topN = meanTopNValues(x, N)
if isempty(x)
    topN = NaN;
    return;
end
sortedX = sort(x, 'descend');
topN = mean(sortedX(1:min(N,end)));
end

function topN = sumTopNValues(x, N)
if isempty(x)
    topN = NaN;
    return;
end
sortedX = sort(x, 'descend');
topN = sum(sortedX(1:min(N,end)));
end

function out = localMetricVarName(prefix, channelName, maskLabel)
out = makeSafeVariableName(sprintf('%s_%s_%s', prefix, channelName, maskLabel));
end

function out = localRatioMetricVarName(channelName1, channelName2, maskLabel)
out = makeSafeVariableName(sprintf('Ratio_Mean_NoBckg_%s_%s_%s', channelName1, channelName2, maskLabel));
end
