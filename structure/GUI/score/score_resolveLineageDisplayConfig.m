function [binding, key] = score_resolveLineageDisplayConfig(roiobj, channelName, channelPix, cfg, showBud, showGenealogy, allowActiveFallback)
%SCORE_RESOLVELINEAGEDISPLAYCONFIG Resolve existing lineage without modifying a ROI.
% Comparison rows disable the legacy active-source fallback so an unrelated
% mask cannot inherit the currently selected channel's mother map.

if nargin < 7, allowActiveFallback = true; end
binding = struct('enabled',false,'channelName','','channelPix',[], ...
    'sourceKey','','modelFamilyId',0,'showBudPairing',false, ...
    'showGenealogy',false,'budWindowBefore',0,'budWindowAfter',6);
key = '';
if isempty(roiobj) || (~showBud && ~showGenealogy) || strcmp(string(cfg.lineageSource),"<none>")
    return;
end

try
    [model, modelStatus] = score_getCellModel(roiobj);
    if strcmp(modelStatus, 'ok')
        [familyIndex, familyId, ~, provider] = ...
            score_resolveCellModelFamily(model, cfg, channelName);
        if ~isempty(familyIndex)
            key = sprintf('cell_model:%u', familyId);
            providerPix = [];
            try providerPix = roiobj.findChannelID(provider); catch, end
            if isempty(providerPix)
                providerPix = channelPix;
                provider = channelName;
            end
            hasRelations = any(model.relations.family_id == familyId);
            binding = struct( ...
                'enabled', logical(hasRelations), ...
                'channelName', char(string(provider)), ...
                'channelPix', double(providerPix), ...
                'sourceKey', key, ...
                'modelFamilyId', double(familyId), ...
                'showBudPairing', logical(showBud && hasRelations), ...
                'showGenealogy', logical(showGenealogy && hasRelations), ...
                'budWindowBefore', 0, ...
                'budWindowAfter', 6);
            return;
        end
    end

    idx = find(arrayfun(@(x) isprop(x,'groupid') && ...
        strcmp(char(string(x.groupid)), 'cell_information'), roiobj.data), 1, 'first');
    if isempty(idx) || ~isstruct(roiobj.data(idx).userData)
        return;
    end
    ud = roiobj.data(idx).userData;
    preferred = char(string(cfg.lineageSource));
    source = [];

    if isfield(ud, 'lineageSources') && isstruct(ud.lineageSources)
        fields = fieldnames(ud.lineageSources);
        if ~any(strcmp(preferred, {'','<family default>','<none>'})) && ...
                isfield(ud.lineageSources, preferred)
            key = preferred;
            source = ud.lineageSources.(key);
        end
        if isempty(source)
            for i = 1:numel(fields)
                candidate = ud.lineageSources.(fields{i});
                if isfield(candidate, 'channelName') && ...
                        strcmp(string(candidate.channelName), string(channelName))
                    key = fields{i};
                    source = candidate;
                    break;
                end
            end
        end
        if allowActiveFallback && isempty(source) && isfield(ud, 'activeLineageSource') && ...
                isfield(ud.lineageSources, char(string(ud.activeLineageSource)))
            key = char(string(ud.activeLineageSource));
            source = ud.lineageSources.(key);
        end
    end

    legacyMatches = allowActiveFallback;
    for field = {"motherOfSourceChannelName","lineageChannelName","activeLineageChannelName"}
        name = char(field{1});
        if isfield(ud,name) && strcmp(string(ud.(name)),string(channelName))
            legacyMatches = true;
        end
    end
    if isfield(roiobj.display,'lineage') && isfield(roiobj.display.lineage,'channelName')
        legacyMatches = legacyMatches || strcmp(string(roiobj.display.lineage.channelName),string(channelName));
    end
    if isempty(source) && legacyMatches && isfield(ud, 'motherOf') && isa(ud.motherOf, 'containers.Map')
        key = 'legacy';
        source = struct('motherOf', ud.motherOf);
        if isfield(ud, 'events'), source.events = ud.events; end
        if isfield(ud, 'lineageChannelName'), source.channelName = ud.lineageChannelName; end
        if isfield(ud, 'lineageChannelPix'), source.channelPix = ud.lineageChannelPix; end
    end
    if isempty(source)
        key = '';
        return;
    end

    hasMap = isfield(source, 'motherOf') && isa(source.motherOf, 'containers.Map') && ...
        source.motherOf.Count > 0;
    hasEvents = isfield(source, 'events') && ~isempty(source.events);
    if (showGenealogy && hasMap) || (showBud && hasEvents)
        sourceChannel = char(string(channelName));
        sourcePix = double(channelPix);
        if isfield(source, 'channelName') && ~isempty(source.channelName)
            sourceChannel = char(string(source.channelName));
        end
        if isfield(source, 'channelPix') && ~isempty(source.channelPix)
            sourcePix = double(source.channelPix);
        else
            try sourcePix = double(roiobj.findChannelID(sourceChannel)); catch, end
        end
        if isempty(sourcePix) || numel(sourcePix) ~= 1 || sourcePix < 1
            key = '';
            return;
        end
        binding = struct( ...
            'enabled', true, ...
            'channelName', sourceChannel, ...
            'channelPix', sourcePix, ...
            'sourceKey', key, ...
            'showBudPairing', logical(showBud && hasEvents), ...
            'showGenealogy', logical(showGenealogy && hasMap), ...
            'budWindowBefore', 0, ...
            'budWindowAfter', 6);
    else
        key = '';
    end
catch
    binding.enabled = false;
    key = '';
end
end
