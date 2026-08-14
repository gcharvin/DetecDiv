function [pix, name, info] = resolveCorrectionProvider(roiobj, opts)
% sam31.resolveCorrectionProvider  Resolve the read-only mask source used by correction.

if nargin < 2 || ~isstruct(opts)
    opts = struct();
end

pix = [];
name = '';
info = struct('source', '', 'message', '');
annotationPix = numericField(opts, 'annotationPix', []);
ignoredRequest = '';

requestedPix = numericField(opts, 'candidateProviderPix', []);
if ~isempty(requestedPix)
    [pix, name] = validatePix(roiobj, requestedPix, annotationPix);
    if ~isempty(pix)
        info.source = 'explicit-pixel-index';
        return;
    end
end

requestedName = textField(opts, 'candidateProviderName', '');
if ~isempty(requestedName)
    [pix, name] = findNamedProvider(roiobj, requestedName, annotationPix);
    if ~isempty(pix)
        info.source = 'explicit-channel-name';
        return;
    end
    % Old UI state could contain the editable GT channel itself.  Treat an
    % unavailable or forbidden explicit name as a stale hint and continue
    % with automatic discovery instead of aborting the propagation.
    ignoredRequest = sprintf( ...
        'Ignored unavailable or annotation provider "%s" in ROI %s. ', ...
        requestedName, roiId(roiobj));
end

% The annotation contract is authoritative. For cellLatentModel this maps
% the prediction family to its real mask provider (for example
% results_cellposeSAM_cell), rather than guessing from classifier inputs.
try
    classif = [];
    if isfield(opts, 'classif') && isa(opts.classif, 'classi')
        classif = opts.classif;
    elseif isa(roiobj.parent, 'classi')
        classif = roiobj.parent;
    end
    if ~isempty(classif)
        spec = annotationManager.specForClassifier(classif);
        catalog = annotationManager.initializationCatalog(roiobj, spec);
        candidate = char(string(catalog.prediction.maskProvider));
        if ~isempty(candidate)
            [pix, name] = findNamedProvider(roiobj, candidate, annotationPix);
            if ~isempty(pix)
                info.source = 'annotation-prediction-family';
                info.message = ignoredRequest;
                return;
            end
        end
    end
catch
end

% Last-resort discovery intentionally only considers result/mask-like
% indexed channels. A raw BF channel must never silently become a provider.
names = roiChannelNames(roiobj);
lowerNames = lower(string(names));
maskLike = contains(lowerNames, 'mask') | contains(lowerNames, 'cell') | ...
    contains(lowerNames, 'seg');
priority = contains(lowerNames, 'result') * 4 + ...
    contains(lowerNames, 'track') * 2 + maskLike;
[~, order] = sort(priority, 'descend');
for i = reshape(order, 1, [])
    if priority(i) <= 0
        continue;
    end
    [candidatePix, candidateName] = findNamedProvider(roiobj, names{i}, annotationPix);
    if ~isempty(candidatePix)
        pix = candidatePix;
        name = candidateName;
        info.source = 'mask-channel-fallback';
        info.message = [ignoredRequest ...
            'Resolved heuristically because no annotation prediction provider was available.'];
        return;
    end
end

info.source = 'none';
info.message = [ignoredRequest ...
    'No separate mask candidate provider is available; SAM31 mask prompting remains the final fallback.'];
end

function [pix, name] = findNamedProvider(roiobj, requested, annotationPix)
pix = [];
name = '';
requested = char(string(requested));
try
    candidate = roiobj.findChannelID(requested);
    if ~isempty(candidate)
        [pix, name] = validatePix(roiobj, candidate(1), annotationPix);
        if ~isempty(pix)
            name = requested;
        end
    end
catch
end
end

function [pix, name] = validatePix(roiobj, candidate, annotationPix)
pix = [];
name = '';
candidate = round(double(candidate(1)));
if ~isfinite(candidate) || candidate < 1 || candidate > size(roiobj.image, 3) || ...
        (~isempty(annotationPix) && any(candidate == round(double(annotationPix(:)))))
    return;
end
pix = candidate;
names = roiChannelNames(roiobj);
logicalIndex = candidate;
try
    if numel(roiobj.channelid) >= candidate
        logicalIndex = round(double(roiobj.channelid(candidate)));
    end
catch
end
if logicalIndex >= 1 && logicalIndex <= numel(names)
    name = names{logicalIndex};
end
end

function names = roiChannelNames(roiobj)
names = {};
try
    names = cellstr(string(roiobj.display.channel));
catch
end
if isempty(names)
    try
        names = cellstr(string(roiobj.channelid));
    catch
    end
end
end

function value = numericField(s, name, fallback)
value = fallback;
try
    if isfield(s, name) && ~isempty(s.(name))
        value = double(s.(name));
    end
catch
end
end

function value = textField(s, name, fallback)
value = fallback;
try
    if isfield(s, name) && ~isempty(s.(name))
        value = char(string(s.(name)));
    end
catch
end
end

function value = roiId(roiobj)
value = '<unknown>';
try
    value = char(string(roiobj.id));
catch
end
end
