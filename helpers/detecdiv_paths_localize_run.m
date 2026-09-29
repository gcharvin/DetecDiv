function runObj = detecdiv_paths_localize_run(runObj, hub)
% Rebase reusable run references in memory; preserve execution logs/context.
    if nargin < 2, hub = detecdiv_hub_settings_get(); end
    for name = {'templatePath', 'projectPath'}
        key = name{1};
        runObj.(key) = detecdiv_paths_prefer_local(runObj.(key), hub);
    end
    if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'path')
        runObj.pipelineRef.path = detecdiv_paths_prefer_local(runObj.pipelineRef.path, hub);
    end
    if isstruct(runObj.targetRef)
        for name = {'projectPath', 'classiPath'}
            key = name{1};
            if isfield(runObj.targetRef, key)
                runObj.targetRef.(key) = detecdiv_paths_prefer_local(runObj.targetRef.(key), hub);
            end
        end
    end
end
