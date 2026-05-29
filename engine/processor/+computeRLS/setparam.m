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

listout = normalizeChoiceList(listout);

if isempty(listout)
    listout = {''};
end

listout{end+1} = listout{end};

tip = { ...
    'Classification data output name', ...
    'Arrest threshold in expected division periods if ExpectedDivisionPeriod is set; otherwise frames', ...
    'Death threshold frame number', ...
    'Clog threshold frame number', ...
    'Empty Threshold Discard frame number', ...
    'EmptyThresholdNext', ...
    'State decoder: off, viterbi, or median', ...
    'Expected division/budding period in frames', ...
    'Minimum division/budding interval in frames', ...
    'Minimum interval factor when using expected period', ...
    'Median decoder/filter window in frames', ...
    'Viterbi live-state switch penalty', ...
    'Viterbi terminal-state transition penalty', ...
    'Viterbi unexpected transition penalty', ...
    'Viterbi empty-to-live refill penalty', ...
    'QC low-margin frame threshold', ...
    'QC minimum mean probability margin', ...
    'QC maximum low-confidence frame fraction' ...
    };

paramout = struct();
paramout.classification_data = listout;
paramout.ArrestThreshold = 3;
paramout.DeathThreshold = 3;
paramout.ClogThreshold = 1;
paramout.EmptyThresholdDiscard = 500;
paramout.EmptyThresholdNext = 100;
paramout.StateDecoder = {'off','viterbi','median','off'};
paramout.ExpectedDivisionPeriod = 60;
paramout.MinDivisionInterval = NaN;
paramout.MinDivisionIntervalFactor = 0.5;
paramout.MedianFilterWindow = 3;
paramout.ViterbiLiveSwitchPenalty = 0.10;
paramout.ViterbiTerminalPenalty = 0.25;
paramout.ViterbiUnexpectedTransitionPenalty = 1.00;
paramout.ViterbiRefillPenalty = 0.50;
paramout.QCLowMarginThreshold = 0.05;
paramout.QCMinMeanMargin = 0.05;
paramout.QCMaxLowConfidenceFraction = 0.50;
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
