function [pipelinePath, pipelineId] = detecdiv_project_cached_pipeline_ref(shallowObj)
% detecdiv_project_cached_pipeline_ref  Read a project's known pipeline reference.
%
% This helper intentionally performs no filesystem or network access. It is
% safe to call from UI selection and paint callbacks.

    pipelinePath = '';
    pipelineId = '';

    if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        return;
    end

    try
        if isprop(shallowObj, 'runProfiles') && isstruct(shallowObj.runProfiles) && ...
                isfield(shallowObj.runProfiles, 'pipeline') && ...
                isstruct(shallowObj.runProfiles.pipeline)
            pipelineInfo = shallowObj.runProfiles.pipeline;
            if isfield(pipelineInfo, 'defaultTemplatePath') && ...
                    ~isempty(pipelineInfo.defaultTemplatePath)
                pipelinePath = char(string(pipelineInfo.defaultTemplatePath));
            end
            if isfield(pipelineInfo, 'defaultTemplateId') && ...
                    ~isempty(pipelineInfo.defaultTemplateId)
                pipelineId = char(string(pipelineInfo.defaultTemplateId));
            end
        end
    catch
        pipelinePath = '';
        pipelineId = '';
    end

    if ~isempty(pipelinePath) && ~isempty(pipelineId)
        return;
    end

    try
        if ~isprop(shallowObj, 'processing') || ~isstruct(shallowObj.processing) || ...
                ~isfield(shallowObj.processing, 'pipelineRun') || ...
                isempty(shallowObj.processing.pipelineRun)
            return;
        end

        runs = shallowObj.processing.pipelineRun;
        for runIndex = numel(runs):-1:1
            pipelineRef = struct();
            if isprop(runs(runIndex), 'pipelineRef') && ...
                    isstruct(runs(runIndex).pipelineRef)
                pipelineRef = runs(runIndex).pipelineRef;
            end

            if isempty(pipelinePath) && isfield(pipelineRef, 'path') && ...
                    ~isempty(pipelineRef.path)
                pipelinePath = char(string(pipelineRef.path));
            end
            if isempty(pipelineId) && isfield(pipelineRef, 'id') && ...
                    ~isempty(pipelineRef.id)
                pipelineId = char(string(pipelineRef.id));
            end
            if ~isempty(pipelinePath) && ~isempty(pipelineId)
                return;
            end
        end
    catch
        % Cached metadata is optional; leave any value already recovered.
    end
end
