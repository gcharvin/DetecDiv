classdef ProjectRuns
    % Project run metadata and frozen templates; no images or model runtimes.
    methods (Static)
        function runs = cached(project)
            runs = pipelineRun.empty;
            if isempty(project) || ~isfield(project.processing,'pipelineRun'), return; end
            values = project.processing.pipelineRun;
            if isa(values,'pipelineRun'), runs = values(isvalid(values)); end
        end
        function [added,issues] = discover(project)
            added = 0; issues = {};
            if isempty(project) || isempty(project.io.path) || isempty(project.io.file), return; end
            root = fullfile(project.io.path,project.io.file,'pipeline');
            if ~isfolder(root), return; end
            folders = dir(root); folders = folders([folders.isdir] & ~ismember({folders.name},{'.','..'}));
            runs = detecdivui.ProjectRuns.cached(project);
            for k = 1:numel(folders)
                path = fullfile(root,folders(k).name);
                if ~isfile(fullfile(path,'run.json')), continue; end
                if ~isempty(runs) && any(strcmpi(strrep({runs.path},'\','/'),strrep(path,'\','/'))), continue; end
                try
                    [run,message] = pipelineRunLoad(path);
                    assert(~isempty(run),'detecdivui:RunLoad','%s',message);
                    if ~isempty(runs) && any(strcmp({runs.runId},run.runId)), continue; end
                    runs(end+1) = run; added = added+1; %#ok<AGROW>
                catch err
                    issues{end+1} = [folders(k).name ': ' err.message]; %#ok<AGROW>
                end
            end
            project.processing.pipelineRun = runs;
        end
        function name = pipelineName(run)
            name = run.templateId;
            if isstruct(run.pipelineRef) && isfield(run.pipelineRef,'id') && ~isempty(run.pipelineRef.id), name = run.pipelineRef.id; end
            if isempty(name) && isfield(run.ctx,'pipelineSpec') && isfield(run.ctx.pipelineSpec,'name'), name = run.ctx.pipelineSpec.name; end
            if isempty(name), name = 'Unknown pipeline'; end
            name = char(string(name));
        end
        function template = snapshot(run)
            assert(isfield(run.ctx,'pipelineSpec') && isstruct(run.ctx.pipelineSpec) && ...
                isfield(run.ctx.pipelineSpec,'nodes'),'detecdivui:RunSnapshot', ...
                'This run has no saved pipeline definition. Open its source pipeline explicitly.');
            spec = run.ctx.pipelineSpec; template = pipeline();
            template.strid = detecdivui.ProjectRuns.pipelineName(run);
            template.nodes = pipelineNormalizeNodes(spec.nodes,'persist');
            for key = {'edges','branches','version','runProfiles','description'}
                if isfield(spec,key{1}), template.(key{1}) = spec.(key{1}); end
            end
            if ~isfield(spec,'version') && isfield(run.pipelineRef,'version') && ~isempty(run.pipelineRef.version)
                template.version = run.pipelineRef.version;
            end
            % Remote job/template paths are provenance, never a save destination.
            template.path = '';
        end
    end
end
