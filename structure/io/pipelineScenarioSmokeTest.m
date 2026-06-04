function results = pipelineScenarioSmokeTest(varargin)
% pipelineScenarioSmokeTest  Bounded functional checks for pipeline runs.
%
% The default test set targets the Abhilasha demo project used during the
% pipeline2 refactor. Destructive policies are validated by dry-run unless a
% temporary project is created from raw data.

    p = inputParser;
    p.addParameter('ProjectPath', defaultProjectPath(), @(x)ischar(x) || isstring(x));
    p.addParameter('PipelinePath', '', @(x)ischar(x) || isstring(x));
    p.addParameter('RawPath', defaultRawPath(), @(x)ischar(x) || isstring(x));
    p.addParameter('RunReal', true, @(x)islogical(x) || isnumeric(x));
    p.addParameter('DoRawWrite', true, @(x)islogical(x) || isnumeric(x));
    p.addParameter('Verbose', true, @(x)islogical(x) || isnumeric(x));
    p.parse(varargin{:});
    opt = p.Results;
    opt.RunReal = logical(opt.RunReal);
    opt.DoRawWrite = logical(opt.DoRawWrite);
    opt.Verbose = logical(opt.Verbose);

    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(repoRoot));
    backupPath = fullfile(repoRoot, 'backups');
    if exist(backupPath, 'dir')
        rmpath(genpath(backupPath));
    end

    projectPath = char(string(opt.ProjectPath));
    rawPath = char(string(opt.RawPath));
    [shallowObj, runObj, pipe] = loadInputs(projectPath, char(string(opt.PipelinePath)));

    rows = {};
    scenarios = buildDryScenarios(rawPath);
    for i = 1:numel(scenarios)
        sc = scenarios(i);
        ctx = makeScenarioContext(shallowObj, runObj, sc);
        [ok, detail] = executeDry(pipe, ctx);
        rows(end+1,:) = rowFor(sc, ok, detail, true); %#ok<AGROW>
        printResult(opt.Verbose, rows(end,:));
    end

    if opt.RunReal
        realScenarios = buildRealScenarios();
        for i = 1:numel(realScenarios)
            sc = realScenarios(i);
            ctx = makeScenarioContext(shallowObj, runObj, sc);
            [ok, detail] = executeReal(pipe, ctx, sc.expectError);
            rows(end+1,:) = rowFor(sc, ok, detail, ~sc.expectError); %#ok<AGROW>
            printResult(opt.Verbose, rows(end,:));
        end
    end

    if opt.DoRawWrite && exist(rawPath, 'dir')
        sc = rawWriteScenario(rawPath);
        ctx = makeRawProjectContext(sc);
        [ok, detail] = executeReal(pipe, ctx, false);
        rows(end+1,:) = rowFor(sc, ok, detail, true); %#ok<AGROW>
        printResult(opt.Verbose, rows(end,:));
    elseif opt.Verbose
        fprintf('[SKIP] real_raw_new_project_dataloader_temp - raw path missing or DoRawWrite=false.\n');
    end

    results = cell2table(rows, 'VariableNames', { ...
        'Scenario','Kind','InputMode','Nodes','FOVs','ROIs','Frames', ...
        'ExistingPolicy','GpuPolicy','ExpectedOK','OK','Detail'});
end

function scenarios = buildDryScenarios(rawPath)
    scenarios = repmat(emptyScenario(), 0, 1);
    scenarios(end+1) = scenario('dry_project_fov1_roi1_skip_cpu', 'dry', ...
        'existing dataseries', {'processor_computerls_2'}, 1, 1, 1:20, 'skip', 'force_cpu');
    scenarios(end+1) = scenario('dry_project_fov2_roi1_skip_cpu', 'dry', ...
        'existing dataseries', {'processor_computerls_2'}, 2, 1, 1:20, 'skip', 'force_cpu');
    scenarios(end+1) = scenario('dry_project_rois_1_2_replace', 'dry', ...
        'existing dataseries', {'processor_computerls_2'}, 1, [1 2], 1:20, 'replace', 'module_default');
    scenarios(end+1) = scenario('dry_project_rois_1_2_overwrite_alias', 'dry', ...
        'existing dataseries', {'processor_computerls_2'}, 1, [1 2], 1:20, 'overwrite', 'module_default');
    scenarios(end+1) = scenario('dry_project_rois_1_2_append', 'dry', ...
        'existing dataseries', {'processor_computerls_2'}, 1, [1 2], 1:20, 'append', 'module_default');
    scenarios(end+1) = scenario('dry_classifier_rls_cpu', 'dry', ...
        'existing rois', {'classifier_cnn_lstm_1','processor_computerls_2'}, 1, 1, 1:10, 'skip', 'force_cpu');
    scenarios(end+1) = scenario('dry_classifier_rls_gpu', 'dry', ...
        'existing rois', {'classifier_cnn_lstm_1','processor_computerls_2'}, 1, 1, 1:10, 'skip', 'force_gpu');
    scenarios(end+1) = scenario('dry_raw_loader_pattern', 'dry', ...
        'pipeline start (dataloader)', {'dataloader_5','roipattern_4'}, [], [], 1:20, 'replace', 'module_default', rawPath);
    scenarios(end+1) = scenario('dry_raw_full_pipeline', 'dry', ...
        'pipeline start (dataloader)', {'dataloader_5','roipattern_4','roiextract_3','classifier_cnn_lstm_1','processor_computerls_2'}, [], [], 1:20, 'skip', 'force_cpu', rawPath);
end

function scenarios = buildRealScenarios()
    scenarios = repmat(emptyScenario(), 0, 1);
    scenarios(end+1) = scenario('real_rls_skip_existing_roi1', 'real', ...
        'existing dataseries', {'processor_computerls_2'}, 1, 1, 1:20, 'skip', 'force_cpu');
    scenarios(end+1) = scenario('real_rls_error_existing_roi1', 'real', ...
        'existing dataseries', {'processor_computerls_2'}, 1, 1, 1:20, 'error', 'force_cpu');
    scenarios(end).expectError = true;
    scenarios(end+1) = scenario('real_classifier_skip_cpu', 'real', ...
        'existing rois', {'classifier_cnn_lstm_1'}, 1, 1, 1:10, 'skip', 'force_cpu');
    scenarios(end+1) = scenario('real_classifier_skip_gpu', 'real', ...
        'existing rois', {'classifier_cnn_lstm_1'}, 1, 1, 1:10, 'skip', 'force_gpu');
end

function sc = rawWriteScenario(rawPath)
    sc = scenario('real_raw_new_project_dataloader_temp', 'real', ...
        'pipeline start (dataloader)', {'dataloader_5'}, [], [], 1:20, 'replace', 'module_default', rawPath);
end

function sc = scenario(name, kind, inputMode, nodes, fovs, rois, frames, existingPolicy, gpuPolicy, rawPath)
    if nargin < 10
        rawPath = '';
    end
    sc = emptyScenario();
    sc.name = char(string(name));
    sc.kind = char(string(kind));
    sc.inputMode = char(string(inputMode));
    sc.nodes = nodes;
    sc.fovs = fovs;
    sc.rois = rois;
    sc.frames = frames;
    sc.existingPolicy = char(string(existingPolicy));
    sc.gpuPolicy = char(string(gpuPolicy));
    sc.rawPath = char(string(rawPath));
end

function sc = emptyScenario()
    sc = struct('name', '', 'kind', '', 'inputMode', '', 'nodes', {{}}, ...
        'fovs', [], 'rois', [], 'frames', [], 'existingPolicy', '', ...
        'gpuPolicy', '', 'rawPath', '', 'expectError', false);
end

function ctx = makeScenarioContext(shallowObj, runObj, sc)
    ctx = baseCtxFromRun(runObj);
    ctx.shallow = shallowObj;
    ctx.shallowObj = shallowObj;
    ctx.allowGUI = false;
    ctx.interactive = false;
    ctx.saveProgress = false;
    ctx.runId = ['pipeline_scenario_' char(java.util.UUID.randomUUID)];

    ctx.run.selectedNodes = sc.nodes;
    ctx.run.inputSource = sc.inputMode;
    ctx.run.fovIndex = sc.fovs;
    ctx.run.frames = sc.frames;
    ctx.run.rois = sc.rois;
    ctx.run.gpuPolicy = sc.gpuPolicy;
    ctx.run.runPolicy = 'restart';
    ctx.sel.fovs = sc.fovs;
    ctx.sel.frames = sc.frames;
    ctx.sel.rois = sc.rois;
    ctx.io.existingPolicy = sc.existingPolicy;
    ctx.io.globalExistingPolicy = sc.existingPolicy;

    if ~isempty(sc.fovs)
        fovIdx = sc.fovs(sc.fovs >= 1 & sc.fovs <= numel(shallowObj.fov));
        if ~isempty(fovIdx)
            ctx.fovList = shallowObj.fov(fovIdx);
            try
                ctx.channels = ctx.fovList(1).channel;
            catch
            end
        end
    end

    if contains(lower(sc.inputMode), 'existing')
        ctx.roiList = selectScenarioRois(shallowObj, sc.fovs, sc.rois);
        ctx.rois = ctx.roiList;
        ctx.dataSeries = inferScenarioDataSeries(ctx.roiList);
        ctx.dataSeriesNames = ctx.dataSeries;
    else
        ctx = rmfieldIfPresent(ctx, {'roiList','rois','dataSeries','dataSeriesNames','masks'});
        if ~isempty(sc.rawPath)
            ctx.path = sc.rawPath;
            ctx.params = struct('path', sc.rawPath, 'write', false, 'interactive', false);
        end
    end

    ctx.run.nodeParams = makeNodeOverrides(sc);
end

function ctx = makeRawProjectContext(sc)
    ctx = struct();
    tmpRoot = fullfile(tempdir, ['DetecDivPipelineSmoke_' char(java.util.UUID.randomUUID)]);
    mkdir(tmpRoot);
    shallowObj = shallow();
    shallowObj.setPath(tmpRoot, 'raw_project_smoke');
    ctx.shallow = shallowObj;
    ctx.shallowObj = shallowObj;
    ctx.allowGUI = false;
    ctx.interactive = false;
    ctx.saveProgress = false;
    ctx.runId = ['pipeline_scenario_' char(java.util.UUID.randomUUID)];
    ctx.run = struct( ...
        'selectedNodes', {sc.nodes}, ...
        'inputSource', sc.inputMode, ...
        'frames', sc.frames, ...
        'gpuPolicy', sc.gpuPolicy, ...
        'runPolicy', 'restart', ...
        'nodeParams', makeNodeOverrides(sc));
    ctx.sel = struct('frames', sc.frames);
    ctx.io = struct('existingPolicy', sc.existingPolicy, 'globalExistingPolicy', sc.existingPolicy);
    ctx.path = sc.rawPath;
    ctx.params = struct('path', sc.rawPath, 'write', true, 'interactive', false);
    ctx.store = struct('tempProjectRoot', tmpRoot);
end

function overrides = makeNodeOverrides(sc)
    overrides = struct();
    for i = 1:numel(sc.nodes)
        key = matlab.lang.makeValidName(char(string(sc.nodes{i})));
        params = struct();
        switch char(string(sc.nodes{i}))
            case 'dataloader_5'
                if ~isempty(sc.rawPath)
                    params.path = sc.rawPath;
                end
                params.interactive = false;
                params.write = ~strcmp(sc.kind, 'dry');
            case 'classifier_cnn_lstm_1'
                params.outputName = 'div_1';
                params.out_dataSeries_name = 'div_1';
            case 'processor_computerls_2'
                params.classification_data = 'div_1';
                params.outputName = 'RLS_div_1';
        end
        if ~isempty(fieldnames(params))
            overrides.(key) = params;
        end
    end
end

function [ok, detail] = executeDry(pipe, ctx)
    try
        [ok, report] = runPipelineDry(pipe, ctx, struct('allowGui', false));
        detail = summarizeReport(report);
    catch ME
        ok = false;
        detail = exceptionSummary(ME);
    end
end

function [ok, detail] = executeReal(pipe, ctx, expectError)
    try
        [ctxOut, report] = runPipeline(pipe, ctx); %#ok<ASGLU>
        ok = ~expectError;
        detail = summarizeReport(report);
    catch ME
        ok = logical(expectError);
        detail = exceptionSummary(ME);
    end
end

function rows = rowFor(sc, ok, detail, expectedOK)
    rows = {sc.name, sc.kind, sc.inputMode, strjoin(string(sc.nodes), ','), ...
        vectorText(sc.fovs), vectorText(sc.rois), vectorText(sc.frames), ...
        sc.existingPolicy, sc.gpuPolicy, logical(expectedOK), logical(ok), detail};
end

function printResult(verbose, row)
    if ~verbose
        return;
    end
    status = "FAIL";
    if row{11}
        status = "OK";
    end
    fprintf('[%s] %s - %s\n', status, row{1}, row{12});
end

function [shallowObj, runObj, pipe] = loadInputs(projectPath, pipelinePath)
    if ~exist(projectPath, 'file')
        error('pipelineScenarioSmokeTest:ProjectMissing', 'Project not found: %s', projectPath);
    end
    [shallowObj, ~] = shallowLoad(projectPath);
    runObj = [];
    try
        runs = shallowObj.processing.pipelineRun;
        if ~isempty(runs)
            runObj = runs(end);
        end
    catch
    end
    if isempty(pipelinePath)
        if ~isempty(runObj) && isprop(runObj, 'pipelineRef') && ~isempty(runObj.pipelineRef) && ...
                isfield(runObj.pipelineRef, 'path') && ~isempty(runObj.pipelineRef.path)
            pipelinePath = fullfile(runObj.pipelineRef.path, 'pipeline.json');
        else
            pipelinePath = defaultPipelinePath();
        end
    end
    if ~exist(pipelinePath, 'file')
        error('pipelineScenarioSmokeTest:PipelineMissing', 'Pipeline not found: %s', pipelinePath);
    end
    [pipe, ~] = pipelineLoad(pipelinePath);
end

function ctx = baseCtxFromRun(runObj)
    ctx = struct();
    try
        if ~isempty(runObj) && isprop(runObj, 'ctx') && isstruct(runObj.ctx)
            ctx = runObj.ctx;
        end
    catch
        ctx = struct();
    end
    if ~isfield(ctx,'run') || ~isstruct(ctx.run)
        ctx.run = struct();
    end
    if ~isfield(ctx,'io') || ~isstruct(ctx.io)
        ctx.io = struct();
    end
    if ~isfield(ctx,'sel') || ~isstruct(ctx.sel)
        ctx.sel = struct();
    end
end

function rois = selectScenarioRois(shallowObj, fovs, roiIdx)
    rois = [];
    if isempty(fovs)
        fovs = 1:numel(shallowObj.fov);
    end
    fovs = fovs(fovs >= 1 & fovs <= numel(shallowObj.fov));
    for i = 1:numel(fovs)
        r = shallowObj.fov(fovs(i)).roi;
        if isempty(r)
            continue;
        end
        idx = roiIdx;
        if isempty(idx)
            idx = 1:numel(r);
        end
        idx = idx(idx >= 1 & idx <= numel(r));
        if isempty(idx)
            continue;
        end
        if isempty(rois)
            rois = r(idx);
        else
            rois = [rois r(idx)]; %#ok<AGROW>
        end
    end
end

function names = inferScenarioDataSeries(rois)
    names = {};
    if isempty(rois)
        return;
    end
    try
        rois(1).load('data');
    catch
    end
    try
        data = rois(1).data;
        for i = 1:numel(data)
            ds = data(i);
            if isprop(ds, 'groupid') && ~isempty(ds.groupid)
                names{end+1} = char(string(ds.groupid)); %#ok<AGROW>
            elseif isprop(ds, 'id') && ~isempty(ds.id)
                names{end+1} = char(string(ds.id)); %#ok<AGROW>
            end
        end
        names = unique(names, 'stable');
    catch
        names = {};
    end
end

function detail = summarizeReport(report)
    detail = '';
    try
        if isfield(report, 'summary') && isstruct(report.summary) && ~isempty(fieldnames(report.summary))
            s = report.summary;
            detail = sprintf('nodes total=%d done=%d skipped=%d failed=%d', ...
                getNumField(s,'totalNodes'), getNumField(s,'doneNodes'), ...
                getNumField(s,'skippedNodes'), getNumField(s,'failedNodes'));
        end
        if isfield(report, 'errors') && ~isempty(report.errors)
            err = strjoin(string(report.errors), ' | ');
            if isempty(detail)
                detail = char(err);
            else
                detail = [detail '; errors=' char(err)];
            end
        end
        if isempty(detail) && isfield(report, 'ok')
            detail = ['validation ok=' char(string(report.ok))];
        end
    catch
        detail = 'report available';
    end
end

function n = getNumField(s, name)
    n = 0;
    if isfield(s, name) && ~isempty(s.(name))
        n = double(s.(name));
    end
end

function detail = exceptionSummary(ME)
    detail = ME.message;
    try
        if ~isempty(ME.stack)
            detail = sprintf('%s [%s:%d]', detail, ME.stack(1).name, ME.stack(1).line);
        end
    catch
    end
end

function ctx = rmfieldIfPresent(ctx, names)
    for i = 1:numel(names)
        if isfield(ctx, names{i})
            ctx = rmfield(ctx, names{i});
        end
    end
end

function txt = vectorText(v)
    if isempty(v)
        txt = '';
        return;
    end
    if iscell(v)
        txt = char(strjoin(string(v), ','));
        return;
    end
    try
        if isnumeric(v) && numel(v) > 8
            txt = sprintf('%g:%g', v(1), v(end));
        else
            txt = strtrim(sprintf('%g ', v));
        end
    catch
        txt = char(string(v));
    end
end

function path = defaultProjectPath()
    path = 'C:\Users\Gilles Charvin\SynologyDrive\abhilasha\Abhilasha_Analysis_April2026.mat';
end

function path = defaultRawPath()
    path = 'C:\Users\Gilles Charvin\SynologyDrive\abhilasha\raw\2026_04_09Yam740Yak108_18_004.ome.zarr';
end

function path = defaultPipelinePath()
    path = 'C:\Users\Gilles Charvin\SynologyDrive\abhilasha\pipeline\pipeline.json';
end
