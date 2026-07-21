function text = detecdiv_hub_format_project_lock_summary(summary)
% detecdiv_hub_format_project_lock_summary  Human-readable Hub lock details.

    if nargin < 1 || ~isstruct(summary)
        text = 'Hub lock information is unavailable.';
        return;
    end

    projectId = localText(summary, 'project_id', '');
    lockCount = localNumber(summary, 'lock_count', 0);
    if lockCount == 0
        text = 'No active Hub lock.';
        if ~isempty(projectId)
            text = sprintf('%s\nProject: %s', text, projectId);
        end
        return;
    end

    lines = {};
    if ~isempty(projectId)
        lines{end+1} = ['Project: ' projectId]; %#ok<AGROW>
    end
    lines{end+1} = sprintf('Active lock(s): %d', lockCount); %#ok<AGROW>
    locks = summary.locks;
    for i = 1:numel(locks)
        lock = locks(i);
        lines{end+1} = sprintf('%d. %s', i, localFallback(localText(lock, 'kind', ''), 'unknown lock')); %#ok<AGROW>
        lines = localAppend(lines, '   User', localText(lock, 'holder', ''));
        lines = localAppend(lines, '   Machine', localText(lock, 'host', ''));
        lines = localAppend(lines, '   Job', localText(lock, 'job_id', ''));
        lines = localAppend(lines, '   Reason', localText(lock, 'reason', ''));
        lines = localAppend(lines, '   Last heartbeat (UTC)', localText(lock, 'heartbeat_at', ''));
        lines = localAppend(lines, '   Expires (UTC)', localText(lock, 'expires_at', ''));
        lines = localAppend(lines, '   Lock id', localText(lock, 'id', ''));
    end
    text = strjoin(lines, newline);
end

function lines = localAppend(lines, label, value)
    if ~isempty(value)
        lines{end+1} = [label ': ' value]; %#ok<AGROW>
    end
end

function value = localText(S, name, fallback)
    value = fallback;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            value = char(string(S.(name)));
        end
    catch
    end
end

function value = localNumber(S, name, fallback)
    value = fallback;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            value = double(S.(name));
        end
    catch
    end
end

function value = localFallback(value, fallback)
    if isempty(value)
        value = fallback;
    end
end
