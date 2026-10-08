function plotRLS(datagroups, outputDir, varargin)
% plotRLS Plot generation survival curves from computeRLS event dataseries.
%
% computeRLS stores event as a categorical table variable and stores the
% terminal status separately as a string. Normalize both representations
% before identifying censored trajectories.

if nargin < 2 || isempty(outputDir)
    error('plotRLS:MissingOutputDirectory', 'An output directory is required.');
end
outputDir = char(string(outputDir));
if ~isfolder(outputDir)
    [ok, message] = mkdir(outputDir);
    if ~ok
        error('plotRLS:InvalidOutputDirectory', ...
            'Could not create output directory "%s": %s', outputDir, message);
    end
end
if isempty(datagroups)
    warning('plotRLS:NoGroups', 'No data groups were provided.');
    return;
end

colors = lines(numel(datagroups));
fig = figure('Color','w','Tag','plot_RLS','Name','RLS survival');
ax = axes(fig);
hold(ax, 'on');
legendEntries = {};
exported = 0;

for i = 1:numel(datagroups)
    if ~isfield(datagroups(i), 'Source') || ...
            ~isstruct(datagroups(i).Source) || ...
            ~isfield(datagroups(i).Source, 'nodename') || ...
            isempty(datagroups(i).Source.nodename)
        continue;
    end
    if ~isfield(datagroups(i), 'Data') || ~isfield(datagroups(i).Data, 'roiobj') || ...
            isempty(datagroups(i).Data.roiobj)
        continue;
    end

    selected = normalizeSelectedSources(datagroups(i).Source.nodename);
    eventIdx = find(strcmpi(selected(:,2), 'event'), 1, 'first');
    if isempty(eventIdx)
        continue;
    end
    groupId = selected{eventIdx,1};
    rois = datagroups(i).Data.roiobj;
    generationCount = [];
    censored = false(0,1);

    for r = 1:numel(rois)
        if isempty(rois(r).data)
            continue;
        end
        roiGroupIds = arrayfun(@(x) char(string(x.groupid)), rois(r).data, ...
            'UniformOutput', false);
        dsIdx = find(strcmp(roiGroupIds, groupId), 1, 'first');
        if isempty(dsIdx)
            continue;
        end
        ds = rois(r).data(dsIdx);
        if ~istable(ds.data) || ~ismember('event', ds.data.Properties.VariableNames)
            continue;
        end

        events = normalizeLabels(ds.getData('event'));
        events = events(~ismissing(events) & strlength(events) > 0);
        if isempty(events) || ~any(strcmpi(events, 'Birth') | strcmpi(events, 'Budding'))
            % A never-born ROI has no lifespan to include in a survival curve.
            continue;
        end

        isCensored = strcmpi(events(end), 'stillAlive');
        if ismember('status', ds.data.Properties.VariableNames)
            status = normalizeLabels(ds.getData('status'));
            status = status(~ismissing(status) & strlength(status) > 0);
            if ~isempty(status)
                isCensored = strcmpi(status(end), 'stillAlive');
            end
        end
        generationCount(end+1,1) = sum(strcmpi(events, 'Budding')); %#ok<AGROW>
        censored(end+1,1) = isCensored; %#ok<AGROW>
    end

    if isempty(generationCount)
        warning('plotRLS:NoUsableEvents', ...
            'No born trajectories with event data were found for group "%s".', ...
            char(string(datagroups(i).Name)));
        continue;
    end

    [survival, generations, lower, upper] = ecdf(generationCount, ...
        'Censoring', censored, 'Function', 'survivor');
    stairs(ax, generations, survival, 'LineWidth', 1.8, 'Color', colors(i,:));
    if numel(lower) == numel(generations) && numel(upper) == numel(generations)
        patch(ax, [generations; flipud(generations)], ...
            [lower; flipud(upper)], colors(i,:), 'FaceAlpha', 0.12, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
    end

    groupName = char(string(datagroups(i).Name));
    n = numel(generationCount);
    medianRLS = median(generationCount);
    legendEntries{end+1} = sprintf('%s (median=%g, N=%d)', ...
        groupName, medianRLS, n); %#ok<AGROW>
    exportSurvival(outputDir, groupName, groupId, generations, survival, ...
        lower, upper, generationCount, censored);
    exported = exported + 1;
end

if exported == 0
    close(fig);
    warning('plotRLS:NoEventDataseries', ...
        'Select an event dataseries from computeRLS in each group.');
    return;
end

xlabel(ax, 'Generations');
ylabel(ax, 'Survival probability');
ylim(ax, [0 1]);
grid(ax, 'on');
legend(ax, legendEntries, 'Interpreter', 'none', 'Location', 'best');
title(ax, 'Replicative lifespan', 'Interpreter', 'none');
base = fullfile(outputDir, 'RLS_survival');
exportgraphics(fig, [base '.pdf'], 'BackgroundColor', 'white');
savefig(fig, [base '.fig']);
end

function selected = normalizeSelectedSources(value)
selected = cell(0,2);
if iscell(value) && size(value,2) == 2 && all(cellfun(@(x) ischar(x) || isstring(x), value(:)))
    selected = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
elseif iscell(value)
    for k = 1:numel(value)
        item = value{k};
        if iscell(item) && numel(item) >= 2
            selected(end+1,:) = {char(string(item{1})), char(string(item{2}))}; %#ok<AGROW>
        end
    end
end
end

function labels = normalizeLabels(value)
if iscategorical(value)
    labels = string(value(:));
elseif isstring(value)
    labels = value(:);
elseif iscellstr(value)
    labels = string(value(:));
elseif ischar(value)
    labels = string(cellstr(value));
else
    labels = strings(0,1);
end
end

function exportSurvival(outputDir, groupName, groupId, generations, survival, ...
        lower, upper, generationCount, censored)
safeName = regexprep(groupName, '[^A-Za-z0-9_-]', '_');
safeId = regexprep(groupId, '[^A-Za-z0-9_-]', '_');
filename = fullfile(outputDir, sprintf('RLS_%s_%s.xlsx', safeName, safeId));
summary = table(generations(:), survival(:), lower(:), upper(:), ...
    'VariableNames', {'Generation','Survival','LowerCI','UpperCI'});
summary.N = repmat(numel(generationCount), height(summary), 1);
summary.CensoredN = repmat(sum(censored), height(summary), 1);
writetable(summary, filename, 'Sheet', 'Survival', 'WriteMode', 'overwritesheet');
end
