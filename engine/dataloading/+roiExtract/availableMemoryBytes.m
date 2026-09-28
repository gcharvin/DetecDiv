function [bytes, note] = availableMemoryBytes(procRoot, cgroupRoot)
%AVAILABLEMEMORYBYTES Remaining RAM in this process's worker and ancestors.
% Optional roots allow verification with proc/cgroup fixtures. Swap is not
% counted as batch RAM. MATLAB pool processes share their service's cgroup.
fixture = nargin > 0;
if nargin < 1, procRoot = '/proc'; end
if nargin < 2, cgroupRoot = '/sys/fs/cgroup'; end
values = []; notes = {};
if ispc && ~fixture
    m = memory;
    values = double(m.MaxPossibleArrayBytes);
    notes = {'Windows MaxPossibleArrayBytes'};
else
    txt = readText(fullfile(procRoot, 'meminfo'));
    tok = regexp(txt, '(?m)^MemAvailable:\s+(\d+)\s+kB', 'tokens', 'once');
    if isempty(tok)
        tok = regexp(txt, '(?m)^MemFree:\s+(\d+)\s+kB', 'tokens', 'once');
    end
    if ~isempty(tok)
        values(end+1) = str2double(tok{1}) * 1024;
        notes{end+1} = sprintf('host available %.2f GiB', values(end)/2^30);
    end
    membership = readText(fullfile(procRoot, 'self', 'cgroup'));
    tok = regexp(membership, '(?m)^0::([^\r\n]*)', 'tokens', 'once');
    mountPoint = cgroupRoot;
    relative = '';
    if ~isempty(tok)
        relative = tok{1};
        % Account for a cgroup namespace or a nonstandard cgroup2 mount.
        if ~fixture
            mounts = regexp(readText(fullfile(procRoot, 'self', 'mountinfo')), '\r?\n', 'split');
            for i = 1:numel(mounts)
                fields = regexp(mounts{i}, ' ', 'split');
                if numel(fields) < 7 || ~contains(mounts{i}, ' - cgroup2 '), continue; end
                root = strrep(fields{4}, '\040', ' ');
                mountPoint = strrep(fields{5}, '\040', ' ');
                if strcmp(root, relative)
                    relative = '';
                elseif ~strcmp(root, '/') && startsWith(relative, [root '/'])
                    relative = relative(numel(root)+1:end);
                end
                break;
            end
        end
        leaf = fullfile(mountPoint, regexprep(relative, '^/+', ''));
        limitName = 'memory.max'; usageName = 'memory.current';
    else
        tok = regexp(membership, '(?m)^\d+:(?:[^:\r\n]*,)?memory(?:,[^:\r\n]*)?:([^\r\n]*)', 'tokens', 'once');
        mountPoint = fullfile(cgroupRoot, 'memory');
        if ~isempty(tok), relative = tok{1}; end
        leaf = fullfile(mountPoint, regexprep(relative, '^/+', ''));
        limitName = 'memory.limit_in_bytes'; usageName = 'memory.usage_in_bytes';
    end
    directory = leaf;
    while isfolder(directory)
        used = numericFile(fullfile(directory, usageName));
        limits = {limitName};
        if strcmp(limitName, 'memory.max'), limits{end+1} = 'memory.high'; end
        for i = 1:numel(limits)
            limit = numericFile(fullfile(directory, limits{i}));
            if isfinite(limit) && limit >= 0 && limit < 1e18 && isfinite(used) && used >= 0
                values(end+1) = max(0, limit - used);
                notes{end+1} = sprintf('%s/%s remaining %.2f GiB', ...
                    directory, limits{i}, values(end)/2^30);
            end
        end
        if strcmp(directory, mountPoint), break; end
        parent = fileparts(directory);
        if strcmp(parent, directory) || ~startsWith(parent, mountPoint), break; end
        directory = parent;
    end
end
% The inherited budget also caps fallback estimates when cgroups are absent.
if ~fixture
    limitMB = str2double(getenv('DETECDIV_HUB_WORKER_MEMORY_LIMIT_MB'));
    if isfinite(limitMB) && limitMB > 0
        values(end+1) = limitMB * 2^20;
        notes{end+1} = sprintf('worker environment cap %.2f GiB', limitMB/1024);
    end
end
if isempty(values)
    values = 2e9;
    notes = {'memory unavailable: conservative 2 GB fallback'};
end
% Preserve zero headroom; never replace an exhausted worker with host RAM.
bytes = 0.8 * min(values);
note = sprintf('%s; usable %.2f GiB (20%% reserve, swap excluded)', ...
    strjoin(notes, '; '), bytes/2^30);
end

function txt = readText(path)
txt = '';
try, txt = fileread(path); catch, end
end

function value = numericFile(path)
value = str2double(strtrim(readText(path)));
end
