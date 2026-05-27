function paramout = setparam(ctx)
% trackMotherLineageViterbi.setparam  Defaults for mother/bud Viterbi tracking.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end

listChannels = {};
if isfield(ctx, 'channels') && ~isempty(ctx.channels)
    listChannels = ctx.channels;
end
if ischar(listChannels) || isstring(listChannels)
    listChannels = cellstr(listChannels);
end
if isempty(listChannels) && ~(isfield(ctx,'useProvidedChannels') && ctx.useProvidedChannels)
    try
        listChannels = listAvailableChannels;
    catch
        listChannels = {};
    end
end
if isempty(listChannels)
    listChannels = {'N/A'};
end

preferred = listChannels{end};
for k = 1:numel(listChannels)
    nm = lower(char(string(listChannels{k})));
    if contains(nm, 'cellposesam') || contains(nm, 'cpsam') || contains(nm, 'seg')
        preferred = listChannels{k};
    end
end

paramout = struct();
paramout.instanceChannelName = [{'N/A'}, listChannels(:).', {preferred}];
paramout.mode = {'mother_trap', 'daughter_trap', 'mother_trap'};
paramout.outputChannelName = 'MotherLineageViterbi';
paramout.existingPolicy = 'replace';
paramout.debug = true;

paramout.wM_center = 1.0;
paramout.wM_area = 0.5;
paramout.wM_bottom = 1.0;
paramout.wB_dist = 1.0;
paramout.wB_small = 1.0;
paramout.lambdaM_jump = 0.05;
paramout.lambdaM_area = 0.01;
paramout.lambdaM_appear = 2.0;
paramout.lambdaM_disapp = 2.0;
paramout.lambdaB_jump = 0.05;
paramout.lambdaB_area = 0.01;
paramout.lambdaB_appear = 1.0;
paramout.lambdaB_disapp = 1.0;
paramout.tempConf = 0.5;
paramout.bottomSign = 1.0;
paramout.ratioMin = 0.4;
paramout.bonusSwitch = 1.0;

paramout.tip = { ...
    'Input labeled instance channel, for example CellposeSAM output.', ...
    'Tracking mode: mother_trap favors central mother; daughter_trap favors bottom lineage with bud-to-mother switches.', ...
    'Base output name. The processor writes base_cell and base_conf channels.', ...
    'Existing output policy used by pipeline runners.', ...
    'Verbose Viterbi path logging.', ...
    'Mother center observation weight.', ...
    'Mother area observation weight.', ...
    'Mother bottom observation weight for daughter_trap.', ...
    'Bud mother-distance observation weight.', ...
    'Bud small-relative-area observation weight.', ...
    'Mother movement transition penalty.', ...
    'Mother area-change transition penalty.', ...
    'Mother appearance transition penalty.', ...
    'Mother disappearance transition penalty.', ...
    'Bud movement transition penalty.', ...
    'Bud area-change transition penalty.', ...
    'Bud appearance transition penalty.', ...
    'Bud disappearance transition penalty.', ...
    'Bud confidence sigmoid temperature.', ...
    'Bottom direction sign for daughter_trap.', ...
    'Minimum bud/mother area ratio for bud-to-mother switches.', ...
    'Bonus for a valid bud-to-mother switch.'};
end
