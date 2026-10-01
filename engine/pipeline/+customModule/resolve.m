function [fun, info, cleanup] = resolve(cfg, ctx)
% Resolve on the executing machine; temporary path changes are scoped.
cleanup = [];
if isempty(cfg.entryPoint)
    error('customModule:EntryPoint', 'Set entryPoint to a MATLAB function name.');
end
folder = cfg.codeFolder;
if ~isempty(folder)
    isAbsolute = startsWith(folder, {'/','\'}) || ~isempty(regexp(folder, '^[A-Za-z]:[/\\]', 'once'));
    if ~isAbsolute
        roots = {};
        if isfield(ctx, 'pipelineTemplatePath'), roots{end+1} = ctx.pipelineTemplatePath; end
        if isfield(ctx, 'pipelineRef') && isstruct(ctx.pipelineRef) && isfield(ctx.pipelineRef, 'path')
            roots{end+1} = ctx.pipelineRef.path;
        end
        roots{end+1} = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
        roots = roots(~cellfun(@isempty, roots));
        for i = 1:numel(roots)
            [~, ~, ext] = fileparts(char(roots{i}));
            if strcmpi(ext, '.json'), roots{i} = fileparts(char(roots{i})); end
        end
        candidates = cellfun(@(root) fullfile(char(root), folder), roots, 'UniformOutput', false);
        idx = find(cellfun(@isfolder, candidates), 1);
        if isempty(idx)
            error('customModule:CodeFolder', 'Relative codeFolder "%s" was not found under the pipeline folder or DetecDiv root.', folder);
        end
        folder = candidates{idx};
    end
    if ~isfolder(folder)
        error('customModule:CodeFolder', 'codeFolder does not exist on this machine: %s.', folder);
    end
    oldPath = path;
    cleanup = onCleanup(@()path(oldPath));
    addpath(folder, '-begin');
end
file = which(cfg.entryPoint);
if isempty(file) || ~isfile(file)
    error('customModule:EntryPoint', 'Function "%s" was not found on this machine. Set codeFolder or add it to the MATLAB path.', cfg.entryPoint);
end
if ~isempty(folder)
    resolvedFolder = char(java.io.File(folder).getCanonicalPath());
    resolvedFile = char(java.io.File(file).getCanonicalPath());
    if ~startsWith([resolvedFile filesep], [resolvedFolder filesep], 'IgnoreCase', ispc)
        error('customModule:EntryPoint', 'Function "%s" resolves outside codeFolder (%s).', cfg.entryPoint, file);
    end
end
fun = str2func(cfg.entryPoint);
try
    nIn = nargin(fun);
    nOut = nargout(fun);
catch ME
    error('customModule:FunctionRequired', 'entryPoint must be a callable MATLAB function. Wrap scripts in function ctx = myFunction(ctx). Details: %s', ME.message);
end
if strcmp(cfg.callMode, 'context')
    supplied = 1;
    requested = 1;
else
    supplied = numel(cfg.args);
    requested = numel(cfg.out);
end
if nIn >= 0 && supplied > nIn
    error('customModule:Signature', '%s accepts at most %d input(s); %d are configured.', cfg.entryPoint, nIn, supplied);
end
if nOut >= 0 && requested > nOut
    error('customModule:Signature', '%s returns at most %d output(s); %d are required.', cfg.entryPoint, nOut, requested);
end
info = struct('entryPoint', cfg.entryPoint, 'file', file, 'callMode', cfg.callMode);
end
