function summary = detecdiv_hub_project_lock_summary(project, hub)
% detecdiv_hub_project_lock_summary  Read and display Hub project lock state.

    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end

    ref = localProjectRef(project, hub);
    if isempty(ref.project_id)
        error('detecdiv_hub_project_lock_summary:MissingProjectId', ...
            'Hub project id is required.');
    end

    status = detecdiv_hub_project_locks(ref, hub);
    locks = localAsStructArray(localField(status, 'locks', struct([])));
    summary = struct();
    summary.project_id = char(string(ref.project_id));
    summary.editable = localLogicalField(status, 'editable', isempty(locks));
    summary.reason = localTextField(status, 'reason', '');
    summary.lock_count = numel(locks);
    summary.locks = localNormalizeLocks(locks);
    summary.checked_at = char(datetime('now'));

    if nargout == 0
        localPrintSummary(summary);
        clear summary
    end
end

function locks = localNormalizeLocks(rawLocks)
    locks = repmat(struct('id', '', 'kind', '', 'holder', '', 'host', '', ...
        'job_id', '', 'status', '', 'scope', '', 'expires_at', '', 'reason', ''), numel(rawLocks), 1);
    for i = 1:numel(rawLocks)
        lock = rawLocks(i);
        locks(i) = struct( ...
            'id', localFirstText(lock, {'id','lock_id'}), ...
            'kind', localFirstText(lock, {'lock_kind','kind','type'}), ...
            'holder', localFirstText(lock, {'holder_key','holder','owner','requested_by'}), ...
            'host', localFirstText(lock, {'holder_host','host','requested_from_host'}), ...
            'job_id', localFirstText(lock, {'job_id','hub_job_id','pipeline_run_id'}), ...
            'status', localFirstText(lock, {'status','state'}), ...
            'scope', localFirstText(lock, {'write_scope','scope'}), ...
            'expires_at', localFirstText(lock, {'expires_at','expiresAt','expires','ttl_expires_at'}), ...
            'reason', localFirstText(lock, {'reason','message','detail'}));
    end
end

function localPrintSummary(summary)
    if summary.editable
        state = 'editable';
    else
        state = 'locked/read-only';
    end
    fprintf('Hub project %s: %s', summary.project_id, state);
    if ~isempty(summary.reason)
        fprintf(' - %s', summary.reason);
    end
    fprintf('\nLocks: %d\n', summary.lock_count);

    for i = 1:numel(summary.locks)
        lock = summary.locks(i);
        fprintf('  %d. %s %s', i, localFallback(lock.kind, '<unknown-kind>'), ...
            localFallback(lock.id, '<no-id>'));
        details = {};
        details = localAppendDetail(details, 'holder', lock.holder);
        details = localAppendDetail(details, 'host', lock.host);
        details = localAppendDetail(details, 'job', lock.job_id);
        details = localAppendDetail(details, 'status', lock.status);
        details = localAppendDetail(details, 'scope', lock.scope);
        details = localAppendDetail(details, 'expires', lock.expires_at);
        if ~isempty(details)
            fprintf(' (%s)', strjoin(details, ', '));
        end
        if ~isempty(lock.reason)
            fprintf(' - %s', lock.reason);
        end
        fprintf('\n');
    end
end

function details = localAppendDetail(details, name, value)
    if ~isempty(value)
        details{end+1} = [name '=' value];
    end
end

function value = localFallback(value, fallback)
    if isempty(value)
        value = fallback;
    end
end

function value = localField(S, name, fallback)
    value = fallback;
    try
        if isstruct(S) && isfield(S, name)
            value = S.(name);
        end
    catch
    end
end

function value = localTextField(S, name, fallback)
    value = fallback;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            value = char(string(S.(name)));
        end
    catch
    end
end

function value = localFirstText(S, names)
    value = '';
    for i = 1:numel(names)
        value = localTextField(S, names{i}, '');
        if ~isempty(value)
            return;
        end
    end
end

function value = localLogicalField(S, name, fallback)
    value = fallback;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            raw = S.(name);
            if islogical(raw) || isnumeric(raw)
                value = logical(raw(1));
            else
                txt = strtrim(char(string(raw)));
                value = any(strcmpi(txt, {'1','true','yes','on'}));
            end
        end
    catch
    end
end

function rows = localAsStructArray(value)
    if isempty(value)
        rows = struct([]);
    elseif isstruct(value)
        rows = value(:);
    elseif iscell(value)
        rows = struct([]);
        for i = 1:numel(value)
            item = localAsStructArray(value{i});
            if ~isempty(item)
                rows = [rows; item(:)]; %#ok<AGROW>
            end
        end
    else
        rows = struct([]);
    end
end
