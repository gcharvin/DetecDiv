function out = outInit(stepId, varargin)
% outInit Initialize a pipeline step output struct.

    if nargin < 1
        stepId = "";
    end

    roiPatch = struct();
    roiPatch.channels = struct('add', {{}});
    roiPatch.image = struct('write', []);
    roiPatch.dataseries = struct('upsert', {{}});
    roiPatch.tables = struct('upsert', {{}});

    projPatch = struct();
    projPatch.artifacts = struct('add', {{}});
    projPatch.registry = struct('upsert', {{}});

    out = struct( ...
        'ok',       true, ...
        'status',   "OK", ...
        'stepId',   stepId, ...
        'provides', {{}}, ...
        'requires', {{}}, ...
        'refs',     struct(), ...
        'patch',    struct('roi', roiPatch, 'project', projPatch, 'store', struct(), 'exports', struct()), ...
        'artifacts',struct(), ...
        'metrics',  struct(), ...
        'warnings', {{}}, ...
        'error',    struct('id', "", 'message', "", 'stack', []), ...
        'logs',     {{}} ...
    );

    if isempty(varargin)
        return;
    end

    % Single struct override
    if numel(varargin) == 1 && isstruct(varargin{1})
        out = mergeStruct(out, varargin{1});
        return;
    end

    if mod(numel(varargin), 2) ~= 0
        error('outInit:BadArgs', 'Name-value pairs are not balanced.');
    end

    for i = 1:2:numel(varargin)
        key = varargin{i};
        val = varargin{i+1};
        if isstring(key), key = char(key); end
        if ~ischar(key)
            error('outInit:BadKey', 'Keys must be strings.');
        end
        keyLower = lower(strtrim(key));

        if isfield(out, keyLower)
            out.(keyLower) = val;
            continue;
        end

        % Dotted path support: e.g. 'patch.roi'
        if contains(keyLower, '.')
            parts = strsplit(keyLower, '.');
            if numel(parts) == 2 && isfield(out, parts{1})
                sub = out.(parts{1});
                if isstruct(sub)
                    sub.(parts{2}) = val;
                    out.(parts{1}) = sub;
                    continue;
                end
            end
        end

        % Fallback: store under refs
        if ~isfield(out, 'refs') || ~isstruct(out.refs)
            out.refs = struct();
        end
        safeKey = matlab.lang.makeValidName(key);
        out.refs.(safeKey) = val;
    end
end

function out = mergeStruct(base, override)
    out = base;
    if isempty(override)
        return;
    end
    if ~isstruct(override)
        out = override;
        return;
    end
    f = fieldnames(override);
    for i = 1:numel(f)
        k = f{i};
        if isfield(out, k) && isstruct(out.(k)) && isstruct(override.(k))
            out.(k) = mergeStruct(out.(k), override.(k));
        else
            out.(k) = override.(k);
        end
    end
end
