function mappings = detecdiv_paths_run_payload_mappings(ctx)
% detecdiv_paths_run_payload_mappings  Mapping rules sent to execution workers.
%
% Preserve both sides of every client-to-server mapping. Pipeline modules can
% contain absolute paths originating on different Windows clients (for
% example X:\ or Z:\). The Linux worker needs the original localRoot in order
% to resolve those modulePath values to their server-visible remoteRoot.

    if nargin < 1 || isempty(ctx) || ~isstruct(ctx)
        ctx = struct();
    end

    raw = detecdiv_paths_module_mappings(ctx);
    mappings = struct('localRoot', {}, 'remoteRoot', {});
    for i = 1:numel(raw)
        try
            localRoot = char(string(raw(i).localRoot));
            remoteRoot = regexprep( ...
                strrep(char(string(raw(i).remoteRoot)), '\', '/'), ...
                '[\/]+$', '');
            if isempty(strtrim(localRoot)) || isempty(remoteRoot) || ...
                    ~startsWith(remoteRoot, '/')
                continue;
            end
            mappings(end+1).localRoot = localRoot; %#ok<AGROW>
            mappings(end).remoteRoot = remoteRoot;
        catch
        end
    end
end
