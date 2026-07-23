function cfg = score_getObjectDisplayConfig(roiobj, channelName)
%SCORE_GETOBJECTDISPLAYCONFIG Return the compact display config for a mask channel.

channelName = char(string(channelName));
cfg = defaultConfig(roiobj, channelName);

try
    if isempty(roiobj) || ~isprop(roiobj, 'display') || ~isstruct(roiobj.display) || ...
            ~isfield(roiobj.display, 'objectDisplay') || ...
            ~isstruct(roiobj.display.objectDisplay)
        return;
    end
    store = roiobj.display.objectDisplay;
    if ~isfield(store, 'channels') || isempty(store.channels) || ~isstruct(store.channels)
        return;
    end
    names = string({store.channels.channelName});
    hit = find(strcmpi(names, string(channelName)), 1, 'first');
    if isempty(hit)
        return;
    end
    saved = store.channels(hit);
    fields = fieldnames(cfg);
    for i = 1:numel(fields)
        name = fields{i};
        if isfield(saved, name) && ~isempty(saved.(name))
            cfg.(name) = saved.(name);
        end
    end
catch
    % A malformed optional display preset must never prevent opening a ROI.
end

cfg = normalizeConfig(cfg, roiobj, channelName);
end

function cfg = defaultConfig(roiobj, channelName)
channelColor = [1 1 1];
try
    idx = find(strcmp(cellstr(string(roiobj.display.channel)), channelName), 1, 'first');
    if ~isempty(idx) && isfield(roiobj.display, 'rgb') && size(roiobj.display.rgb, 1) >= idx
        channelColor = double(roiobj.display.rgb(idx, :));
    end
catch
end

cfg = struct( ...
    'channelName', channelName, ...
    'mode', 'normal', ...
    'criterion', 'Channel color', ...
    'objectFamily', '<auto>', ...
    'maskProvider', channelName, ...
    'lineageSource', '<family default>', ...
    'lineageMode', 'none', ...
    'familyColor', channelColor, ...
    'semanticValue', '<none>', ...
    'semanticColor', [1 0.25 0.25], ...
    'budLinkColor', [1 0.8196 0.051], ...
    'genealogyLinkColor', [0.051 0.749 1]);
end

function cfg = normalizeConfig(cfg, roiobj, channelName)
defaults = defaultConfig(roiobj, channelName);
fields = fieldnames(defaults);
for i = 1:numel(fields)
    name = fields{i};
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = defaults.(name);
    end
end

cfg.channelName = char(string(channelName));
cfg.mode = lower(char(string(cfg.mode)));
if ~any(strcmp({'normal','multicolor','semantic','edit'}, cfg.mode))
    cfg.mode = defaults.mode;
end
validCriteria = {'Channel color','Track','Frame instance','Family','New bud','Cell state'};
if ~any(strcmp(validCriteria, char(string(cfg.criterion))))
    cfg.criterion = 'Channel color';
else
    cfg.criterion = char(string(cfg.criterion));
end
cfg.lineageMode = lower(char(string(cfg.lineageMode)));
if ~any(strcmp({'none','bud','genealogy'}, cfg.lineageMode))
    cfg.lineageMode = 'none';
end
cfg.objectFamily = char(string(cfg.objectFamily));
cfg.maskProvider = char(string(cfg.maskProvider));
cfg.lineageSource = char(string(cfg.lineageSource));
cfg.semanticValue = char(string(cfg.semanticValue));
cfg.familyColor = normalizeColor(cfg.familyColor, defaults.familyColor);
cfg.semanticColor = normalizeColor(cfg.semanticColor, defaults.semanticColor);
cfg.budLinkColor = normalizeColor(cfg.budLinkColor, defaults.budLinkColor);
cfg.genealogyLinkColor = normalizeColor(cfg.genealogyLinkColor, defaults.genealogyLinkColor);
end

function color = normalizeColor(color, fallback)
if ~isnumeric(color) || numel(color) ~= 3 || any(~isfinite(color))
    color = fallback;
end
color = max(0, min(1, double(color(:).')));
end
