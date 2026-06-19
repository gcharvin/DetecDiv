function migrated = migrateAnnotationChannels(roiObj, classif, varargin)
% migrateAnnotationChannels  Convert legacy per-class GT channels to one semantic channel.
%
% DeepLab semantic pixel classifiers use one indexed annotation channel named
% classif.strid. Older/instance-style imports may contain one channel per class
% named <strid>_<class>. This helper consolidates those channels into the single
% semantic channel expected by formatPixelTrainingSet and classifierGUI.

migrated = false;
removeLegacy = false;

for i = 1:2:numel(varargin)
    key = lower(char(string(varargin{i})));
    if i + 1 > numel(varargin)
        break;
    end
    switch key
        case 'removelegacy'
            removeLegacy = logical(varargin{i+1});
    end
end

if isempty(roiObj) || isempty(classif)
    return;
end

try
    deeplab_pixel_classification.ensureClassMetadata(classif);
catch
end

annName = deeplab_pixel_classification.annotationChannelName(classif);
if isempty(annName)
    return;
end

try
    if isempty(roiObj.image)
        roiObj.load;
    end
catch
end
if isempty(roiObj.image)
    return;
end

pixAnn = roiObj.findChannelID(annName);
if iscell(pixAnn)
    pixAnn = cell2mat(pixAnn);
end

[legacyNames, legacyPix] = legacyClassChannels(roiObj, classif);
hasLegacy = ~isempty(legacyPix);

if isempty(pixAnn) && hasLegacy
    label = uint16(zeros(size(roiObj.image, 1), size(roiObj.image, 2), 1, size(roiObj.image, 4)));
    for k = 1:numel(legacyPix)
        pix = legacyPix(k);
        classIndex = legacyClassIndex(legacyNames{k}, classif);
        if isempty(classIndex)
            continue;
        end
        mask = roiObj.image(:, :, pix, :) > 0;
        if classIndex <= 1
            % Background is the implicit zero/default class for semantic masks.
            continue;
        end
        label(mask) = uint16(classIndex);
    end

    roiObj.addChannel(label, annName, [1 1 1], [0 0 0]);
    pixAnn = roiObj.findChannelID(annName);
    if iscell(pixAnn)
        pixAnn = cell2mat(pixAnn);
    end
    migrated = true;
end

if ~isempty(pixAnn)
    configureSemanticDisplay(roiObj, pixAnn(1));
end

if removeLegacy && hasLegacy
    for k = 1:numel(legacyNames)
        try
            roiObj.removeChannel(legacyNames{k});
            migrated = true;
        catch
        end
    end
end
end

function [names, pix] = legacyClassChannels(roiObj, classif)
names = {};
pix = [];
try
    classes = cellstr(string(classif.classes(:)));
catch
    classes = {};
end
for i = 1:numel(classes)
    name = [char(string(classif.strid)) '_' classes{i}];
    p = roiObj.findChannelID(name);
    if iscell(p)
        p = cell2mat(p);
    end
    if ~isempty(p)
        names{end+1} = name; %#ok<AGROW>
        pix(end+1) = p(1); %#ok<AGROW>
    end
end
end

function idx = legacyClassIndex(channelName, classif)
idx = [];
prefix = [char(string(classif.strid)) '_'];
if ~startsWith(channelName, prefix)
    return;
end
className = extractAfter(string(channelName), strlength(prefix));
classes = string(classif.classes(:));
hit = find(strcmp(classes, className), 1);
if ~isempty(hit)
    idx = hit;
end
end

function configureSemanticDisplay(roiObj, pix)
try
    logIdx = roiObj.channelid(pix);
    nLog = max(double(logIdx), numel(roiObj.display.channel));
    roiObj.display = ensureDisplayVector(roiObj.display, 'selectedchannel', nLog, 0);
    roiObj.display = ensureDisplayVector(roiObj.display, 'indexed', nLog, 0);
    roiObj.display = ensureDisplayVector(roiObj.display, 'alpha', nLog, 1);
    roiObj.display = ensureDisplayVector(roiObj.display, 'contour', nLog, 0);
    roiObj.display = ensureDisplayVector(roiObj.display, 'width', nLog, 0);
    roiObj.display = ensureDisplayMatrix(roiObj.display, 'rgb', nLog, [1 1 1]);
    roiObj.display = ensureDisplayMatrix(roiObj.display, 'intensity', nLog, [1 1 1]);
    roiObj.display.selectedchannel(logIdx) = true;
    roiObj.display.indexed(logIdx) = true;
    roiObj.display.rgb(logIdx, :) = [1 1 1];
    roiObj.display.intensity(logIdx, :) = [0 0 0];
    roiObj.display.contour(logIdx) = 1;
    roiObj.display.alpha(logIdx) = 0.35;
    roiObj.display.width(logIdx) = 1.5;
catch
end
end

function display = ensureDisplayVector(display, fieldName, nRows, defaultValue)
if ~isfield(display, fieldName) || isempty(display.(fieldName))
    display.(fieldName) = repmat(defaultValue, 1, nRows);
else
    value = display.(fieldName);
    value = value(:).';
    if numel(value) < nRows
        value(end+1:nRows) = defaultValue;
    end
    display.(fieldName) = value;
end
end

function display = ensureDisplayMatrix(display, fieldName, nRows, defaultRow)
if ~isfield(display, fieldName) || isempty(display.(fieldName))
    display.(fieldName) = repmat(defaultRow, nRows, 1);
else
    value = double(display.(fieldName));
    if size(value, 1) < nRows
        value(end+1:nRows, :) = repmat(defaultRow, nRows - size(value, 1), 1);
    end
    display.(fieldName) = value;
end
end
