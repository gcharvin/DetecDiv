function paramout = setparam(ctx)
% computeLineage.setparam  Build parameters for computeLineage processor.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end

listout = {};
if isfield(ctx,'useProvidedDataSeries') && ctx.useProvidedDataSeries
    if isfield(ctx,'classification_data')
        listout = ctx.classification_data;
    elseif isfield(ctx,'classificationData')
        listout = ctx.classificationData;
    end
elseif isfield(ctx,'classification_data') && ~isempty(ctx.classification_data)
    listout = ctx.classification_data;
elseif isfield(ctx,'classificationData') && ~isempty(ctx.classificationData)
    listout = ctx.classificationData;
else
    try
        listout = listROIDataID("classification");
    catch
        listout = {};
    end
end

listout = normalizeChoiceList(listout);

if isempty(listout)
    listout = {''};
end

listout{end+1} = listout{end};

tip = { ...
    'Classification data output name', ...
    'Use post processing - data cleaning up', ...
    'Error detection', ...
    'Arrest threshold frame number', ...
    'Death threshold frame number', ...
    'Clog threshold frame number', ...
    'Empty Threshold Discard frame number', ...
    'EmptyThresholdNext' ...
    };

paramout = struct();
paramout.classification_data = listout;
paramout.postProcessing = true;
paramout.errorDetection = false;
paramout.ArrestThreshold = 175;
paramout.DeathThreshold = 3;
paramout.ClogThreshold = 1;
paramout.EmptyThresholdDiscard = 500;
paramout.EmptyThresholdNext = 100;
paramout.tip = tip;
end

function out = normalizeChoiceList(v)
    if isempty(v)
        out = {};
        return;
    end

    if ischar(v)
        v = cellstr(v);
    elseif isstring(v) || isnumeric(v) || islogical(v) || iscategorical(v)
        v = cellstr(string(v(:)));
    elseif ~iscell(v)
        v = {char(string(v))};
    end

    out = {};
    for i = 1:numel(v)
        item = v{i};
        if isempty(item)
            continue;
        end
        if ischar(item)
            out{end+1} = item; %#ok<AGROW>
        elseif isstring(item) || isnumeric(item) || islogical(item) || iscategorical(item)
            vals = cellstr(string(item(:)));
            out = [out vals(:)']; %#ok<AGROW>
        end
    end

    if isempty(out)
        out = {};
        return;
    end

    out = cellfun(@(x) char(strtrim(string(x))), out(:)', 'UniformOutput', false);
    out = out(~cellfun(@isempty, out));
    out = unique(out, 'stable');
end
