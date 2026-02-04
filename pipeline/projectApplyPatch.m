function projectApplyPatch(project, patch, ctx)
% projectApplyPatch Apply project-level patch instructions.

    if nargin < 3
        ctx = struct();
    end
    if nargin < 2 || isempty(patch) || isempty(project)
        return;
    end

    if isfield(patch, 'project')
        projPatch = patch.project;
    else
        projPatch = patch;
    end

    % Ensure pipeline container
    if ~isprop(project, 'processing') || ~isstruct(project.processing)
        return;
    end
    if ~isfield(project.processing, 'pipeline') || isempty(project.processing.pipeline)
        project.processing.pipeline = struct();
    end
    if ~isstruct(project.processing.pipeline)
        project.processing.pipeline = struct();
    end

    % Artifacts add
    if isfield(projPatch, 'artifacts') && isfield(projPatch.artifacts, 'add')
        addList = projPatch.artifacts.add;
        if isstruct(addList), addList = num2cell(addList); end
        if ~isfield(project.processing.pipeline, 'artifacts') || isempty(project.processing.pipeline.artifacts)
            project.processing.pipeline.artifacts = {};
        end
        for i = 1:numel(addList)
            if isempty(addList{i}), continue; end
            project.processing.pipeline.artifacts{end+1} = addList{i}; %#ok<AGROW>
        end
    end

    % Registry upsert (simple key/value)
    if isfield(projPatch, 'registry') && isfield(projPatch.registry, 'upsert')
        upsertList = projPatch.registry.upsert;
        if isstruct(upsertList), upsertList = num2cell(upsertList); end
        if ~isfield(project.processing.pipeline, 'registry') || ~isstruct(project.processing.pipeline.registry)
            project.processing.pipeline.registry = struct();
        end
        for i = 1:numel(upsertList)
            entry = upsertList{i};
            if isempty(entry), continue; end
            if isfield(entry, 'key')
                k = matlab.lang.makeValidName(entry.key);
                if isfield(entry, 'value')
                    project.processing.pipeline.registry.(k) = entry.value;
                else
                    project.processing.pipeline.registry.(k) = entry;
                end
            end
        end
    end

    if isfield(ctx, 'log') && isstruct(ctx.log) && isfield(ctx.log, 'info')
        try
            ctx.log.info('projectApplyPatch: applied project patch');
        catch
        end
    end
end
