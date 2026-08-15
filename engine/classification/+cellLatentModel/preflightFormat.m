function tp = preflightFormat(classif, rois, ctx)
%CELLLATENTMODEL.PREFLIGHTFORMAT Validate formatting configuration early.
% This function must remain read-only: classi.formatDataForTraining calls it
% before replacing an existing formatted dataset.

if nargin < 2, rois = []; end
if nargin < 3 || isempty(ctx), ctx = struct(); end
tp = cellLatentModel.utils.defaultTrainingParam();
if ~isempty(classif) && isprop(classif, 'trainingParam') && ...
        isstruct(classif.trainingParam)
    tp = cellLatentModel.utils.applyOverrides(tp, classif.trainingParam);
end
if isfield(ctx, 'params') && isstruct(ctx.params)
    tp = cellLatentModel.utils.applyOverrides(tp, ctx.params);
end

objective = configuredChoice(tp.trainingObjective, 'relation_ensemble');
if ~any(strcmp(objective, {'relation_ensemble','continuous_lineage'}))
    error('cellLatentModel:InvalidTrainingObjective', ...
        ['trainingObjective must be relation_ensemble or ' ...
         'continuous_lineage.']);
end
if strcmp(objective, 'continuous_lineage') && ...
        ~isPositiveScalar(tp.frameIntervalMinutes)
    error('cellLatentModel:MissingFrameInterval', ...
        ['Continuous-lineage formatting requires the physical acquisition ' ...
         'interval. Set training parameter "frameIntervalMinutes" to the ' ...
         'strictly positive number of minutes between two consecutive ' ...
         'frames, then format the training set again.']);
end

roiIndices = formattingRois(classif, rois);
validateChannels(classif, roiIndices, tp, objective);
end

function indices = formattingRois(classif, requested)
n = numel(classif.roi);
indices = normalizeIndices(requested, n);
validation = [];
test = [];
try
    split = classif.dataset.split;
    if isempty(indices), indices = normalizeIndices(split.train, n); end
    validation = normalizeIndices(split.val, n);
    test = normalizeIndices(split.test, n);
catch
end
if isempty(indices)
    try indices = normalizeIndices(classif.trainingset, n); catch, end
end
indices = unique([indices validation], 'stable');
indices = setdiff(indices, test, 'stable');
end

function validateChannels(classif, roiIndices, tp, objective)
trackName = strtrim(char(string(tp.trackChannelName)));
requirements = {};
if ~isempty(trackName), requirements(end+1,:) = {'tracked masks', trackName}; end %#ok<AGROW>
if strcmp(objective, 'relation_ensemble')
    gfpName = strtrim(char(string(tp.gfpChannelName)));
    if ~isempty(gfpName), requirements(end+1,:) = {'GFP', gfpName}; end %#ok<AGROW>
else
    fields = {'brightfieldChannelName','nucleusChannelName','budneckChannelName'};
    labels = {'brightfield','nucleus marker','bud-neck marker'};
    for i = 1:numel(fields)
        name = strtrim(char(string(tp.(fields{i}))));
        if ~isempty(name), requirements(end+1,:) = {labels{i}, name}; end %#ok<AGROW>
    end
end
if isempty(requirements), return; end

problems = strings(0,1);
for i = 1:numel(roiIndices)
    roiObj = classif.roi(roiIndices(i));
    missing = strings(0,1);
    for j = 1:size(requirements,1)
        if ~hasChannel(roiObj, requirements{j,2})
            missing(end+1) = sprintf('%s "%s"', ...
                requirements{j,1}, requirements{j,2}); %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        problems(end+1) = sprintf('ROI %s: missing %s', ...
            char(string(roiObj.id)), strjoin(missing, ', ')); %#ok<AGROW>
    end
end
if ~isempty(problems)
    error('cellLatentModel:TrainingInputsNotReady', ...
        ['Selected formatting ROIs do not contain every configured input:' ...
         newline '%s' newline ...
         'Unselect these ROIs or initialize and validate their GT first.'], ...
        strjoin(problems, newline));
end
end

function tf = hasChannel(roiObj, name)
tf = false;
try
    tf = ~isempty(roiObj.findChannelID(name, 'exact'));
catch
    try
        tf = any(strcmp(string(roiObj.display.channel), string(name)));
    catch
    end
end
end

function values = normalizeIndices(raw, n)
if isempty(raw), values = []; return; end
values = unique(round(double(raw(:).')), 'stable');
values = values(isfinite(values) & values >= 1 & values <= n);
end

function value = configuredChoice(raw, fallback)
while iscell(raw)
    if isempty(raw), raw = fallback; else, raw = raw{end}; end
end
value = lower(strtrim(char(string(raw))));
if isempty(value), value = fallback; end
end

function tf = isPositiveScalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0;
end
