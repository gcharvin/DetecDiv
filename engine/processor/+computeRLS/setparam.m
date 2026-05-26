function paramout = setparam(ctx)
% computeRLS.setparam  Build parameters for computeRLS processor.

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

if ischar(listout) || isstring(listout)
    listout = cellstr(listout);
end

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
