function paramout = setparam(ctx)
% singleCellOscillations.setparam  Default parameters for the processor.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end

paramout = struct();

paramout.classification_data = localDefaultSelection(ctx, 'classification_data', 'div_1');
paramout.fluorescence_data = localDefaultSelection(ctx, 'fluorescence_data', 'channel_quantification');
paramout.fluorescenceVariable = localDefaultFluorescenceVariable(ctx);
paramout.cellIndex = 1;
paramout.frameStart = [];
paramout.frameEnd = [];
paramout.framePeriod = 1;
paramout.baselineMethod = 'moving_mean';
paramout.baselineWindow = 50;
paramout.baselineEndpoints = 'discard';
paramout.minCycleLength = 10;
paramout.normFrames = 100;
paramout.allowExtrapolation = true;
paramout.traceOutputName = 'osc_detrended_trace';
paramout.normalizedCyclesOutputName = 'osc_normalized_cycles';
paramout.cycleMetadataOutputName = 'osc_cycle_metadata';
paramout.writeArtifacts = false;
paramout.outputDir = localDefaultOutputDir(ctx);
paramout.workbookName = 'single_cell_oscillations.xlsx';
paramout.tip = buildTips();
end

function value = localDefaultFluorescenceVariable(ctx)
value = 'auto';
if isstruct(ctx) && isfield(ctx, 'fluorescenceVariable') && ~isempty(ctx.fluorescenceVariable)
    value = ctx.fluorescenceVariable;
elseif isstruct(ctx) && isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'fluorescenceVariable') && ~isempty(ctx.params.fluorescenceVariable)
    value = ctx.params.fluorescenceVariable;
elseif isstruct(ctx) && isfield(ctx, 'fluorescenceColumn') && ~isempty(ctx.fluorescenceColumn)
    value = ctx.fluorescenceColumn;
elseif isstruct(ctx) && isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'fluorescenceColumn') && ~isempty(ctx.params.fluorescenceColumn)
    value = ctx.params.fluorescenceColumn;
end
value = char(string(value));
end

function folder = localDefaultOutputDir(ctx)
folder = '';
if ~isstruct(ctx)
    return;
end
projectPath = localFirstText(ctx, {'projectPath'});
if isempty(projectPath) && isfield(ctx, 'run') && isstruct(ctx.run)
    projectPath = localFirstText(ctx.run, {'projectPath'});
end
if isempty(projectPath) && isfield(ctx, 'io') && isstruct(ctx.io)
    projectPath = localFirstText(ctx.io, {'projectPath'});
end
if isempty(projectPath) && isfield(ctx, 'targetRef') && isstruct(ctx.targetRef)
    projectPath = localFirstText(ctx.targetRef, {'projectPath'});
end
if isempty(projectPath)
    return;
end
if exist(projectPath, 'dir') == 7
    folder = projectPath;
else
    folder = fileparts(projectPath);
end
end

function txt = localFirstText(s, names)
txt = '';
for i = 1:numel(names)
    name = names{i};
    if isfield(s, name) && ~isempty(s.(name))
        txt = char(string(s.(name)));
        return;
    end
end
end

function value = localDefaultSelection(ctx, fieldName, fallback)
value = fallback;
if isstruct(ctx) && isfield(ctx, fieldName) && ~isempty(ctx.(fieldName))
    value = ctx.(fieldName);
elseif isstruct(ctx) && isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, fieldName) && ~isempty(ctx.params.(fieldName))
    value = ctx.params.(fieldName);
end
if isstring(value)
    value = cellstr(value);
elseif ischar(value)
    value = {value};
end
if ~iscell(value)
    value = {char(string(value))};
end
end

function tip = buildTips()
tip = { ...
    'Classification dataseries name, usually div_1', ...
    'Fluorescence dataseries name, usually channel_quantification', ...
    'Variable in the fluorescence dataseries to analyze; empty means first numeric variable', ...
    'Cell/value index to analyze when a fluorescence variable contains multiple per-frame values', ...
    'First selected frame; empty means first available', ...
    'Last selected frame; empty means last available', ...
    'Time between frames', ...
    'Baseline method: moving_mean, moving_median, none', ...
    'Moving baseline window', ...
    'Moving baseline endpoint handling: discard matches Antoine scripts, shrink keeps edge frames', ...
    'Minimum cycle length in frames', ...
    'Number of normalized points per cycle', ...
    'Allow extrapolation when normalizing short cycles', ...
    'Output dataseries name for the detrended trace', ...
    'Output dataseries name for normalized cycles', ...
    'Output dataseries name for cycle metadata', ...
    'Write run artifacts to files', ...
    'Output directory for optional artifacts', ...
    'Workbook file name for optional artifacts' ...
    };
end
