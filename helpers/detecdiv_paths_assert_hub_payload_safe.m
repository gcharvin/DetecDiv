function detecdiv_paths_assert_hub_payload_safe(value, label)
% detecdiv_paths_assert_hub_payload_safe  Reject unresolved client paths.
%
% Windows client roots are expected only in path_mappings.localRoot. Those
% values are mapping rules consumed by the worker, not resources that the
% worker tries to open directly. Client paths anywhere else in the Hub
% payload remain an error.

    if nargin < 2 || isempty(label)
        label = 'payload';
    end
    localAssertValue(value, char(string(label)));
end

function localAssertValue(value, label)
    if isstruct(value)
        for i = 1:numel(value)
            names = fieldnames(value(i));
            for j = 1:numel(names)
                childLabel = [label '.' names{j}];
                localAssertValue(value(i).(names{j}), childLabel);
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            localAssertValue(value{i}, sprintf('%s{%d}', label, i));
        end
    elseif isstring(value)
        for i = 1:numel(value)
            localAssertText(char(value(i)), sprintf('%s(%d)', label, i));
        end
    elseif ischar(value)
        localAssertText(value, label);
    end
end

function localAssertText(value, label)
    value = char(string(value));
    if isempty(value) || ~localLooksLikeClientPath(value) || ...
            localIsMappingRootLabel(label)
        return;
    end
    error('detecdiv_hub_submit_pipeline_run:LocalPathInHubPayload', ...
        ['Hub submission would send a local client path in %s: %s\n' ...
         'Move/map the resource so the worker can access it, or launch locally.'], ...
        label, value);
end

function tf = localIsMappingRootLabel(label)
    normalized = regexprep(char(string(label)), '\(\d+\)', '');
    tf = endsWith(normalized, '.path_mappings.localRoot');
end

function tf = localLooksLikeClientPath(value)
    txt = char(string(value));
    tf = ~isempty(regexp(txt, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(txt, '\\');
end
