function batchSpec = detecdiv_batch_builder(selectedRefs, varargin)
% detecdiv_batch_builder  Batch builder UI for selected catalog refs.

    if nargin < 1
        selectedRefs = struct([]);
    end

    ip = inputParser;
    ip.addParameter('SourceMode', 'local', @(x)ischar(x) || isstring(x));
    ip.addParameter('EntityMode', 'projects', @(x)ischar(x) || isstring(x));
    ip.addParameter('CatalogSettings', struct(), @isstruct);
    ip.addParameter('HubSettings', struct(), @isstruct);
    ip.parse(varargin{:});
    opts = ip.Results;

    selectedRefs = localNormalizeRefs(selectedRefs);
    batchSpec = pipelineBatchNew(selectedRefs, ...
        'SourceMode', opts.SourceMode, ...
        'EntityMode', opts.EntityMode, ...
        'CreatedBy', localBatchOwner(opts), ...
        'PrototypeRuntimeConfig', struct());
    batchSpec.execution.target = 'local';

    validationReport = struct();
    runReport = struct();
    batchRootText = localDefaultBatchRoot(batchSpec);
    updatingRecentPipelineList = false;
    recentPipelinePathsCache = {};

    fig = uifigure( ...
        'Name', 'DetecDiv Batch Builder', ...
        'Position', [180 80 1340 900], ...
        'WindowStyle', 'modal', ...
        'CloseRequestFcn', @onClose);

    mainGrid = uigridlayout(fig, [4 1]);
    mainGrid.RowHeight = {150, '1x', 320, 54};
    mainGrid.Padding = [12 12 12 12];
    mainGrid.RowSpacing = 10;

    headerGrid = uigridlayout(mainGrid, [4 6]);
    headerGrid.Layout.Row = 1;
    headerGrid.ColumnWidth = {120, '1x', 120, '1x', 120, '1x'};
    headerGrid.RowHeight = {28, 28, 28, 28};
    headerGrid.Padding = [0 0 0 0];
    headerGrid.RowSpacing = 6;
    headerGrid.ColumnSpacing = 10;

    batchNameLabel = uilabel(headerGrid, 'Text', 'Batch name', 'FontWeight', 'bold');
    batchNameLabel.Layout.Row = 1;
    batchNameLabel.Layout.Column = 1;
    batchNameEdit = uieditfield(headerGrid, 'text', 'Value', batchSpec.name);
    batchNameEdit.Layout.Row = 1;
    batchNameEdit.Layout.Column = [2 3];

    executionLabel = uilabel(headerGrid, 'Text', 'Execution', 'FontWeight', 'bold');
    executionLabel.Layout.Row = 1;
    executionLabel.Layout.Column = 4;
    executionDropDown = uidropdown(headerGrid, ...
        'Items', {'Local', 'Hub'}, ...
        'ItemsData', {'local', 'hub'}, ...
        'Value', batchSpec.execution.target, ...
        'Enable', 'off');
    executionDropDown.Layout.Row = 1;
    executionDropDown.Layout.Column = [5 6];

    pipelineTitleLabel = uilabel(headerGrid, 'Text', 'Pipeline', 'FontWeight', 'bold');
    pipelineTitleLabel.Layout.Row = 2;
    pipelineTitleLabel.Layout.Column = 1;
    pipelineLabel = uilabel(headerGrid, 'Text', localPipelineText(batchSpec), 'Interpreter', 'none');
    pipelineLabel.Layout.Row = 2;
    pipelineLabel.Layout.Column = [2 5];

    prototypeTitleLabel = uilabel(headerGrid, 'Text', 'Prototype', 'FontWeight', 'bold');
    prototypeTitleLabel.Layout.Row = 3;
    prototypeTitleLabel.Layout.Column = 1;
    prototypeLabel = uilabel(headerGrid, 'Text', localPrototypeText(batchSpec), 'Interpreter', 'none');
    prototypeLabel.Layout.Row = 3;
    prototypeLabel.Layout.Column = [2 5];

    runtimeTitleLabel = uilabel(headerGrid, 'Text', 'Runtime config', 'FontWeight', 'bold');
    runtimeTitleLabel.Layout.Row = 4;
    runtimeTitleLabel.Layout.Column = 1;
    runtimeLabel = uilabel(headerGrid, 'Text', localRuntimeConfigText(batchSpec), 'Interpreter', 'none');
    runtimeLabel.Layout.Row = 4;
    runtimeLabel.Layout.Column = [2 6];

    centerGrid = uigridlayout(mainGrid, [1 2]);
    centerGrid.Layout.Row = 2;
    centerGrid.ColumnWidth = {'1.4x', '1x'};
    centerGrid.Padding = [0 0 0 0];
    centerGrid.ColumnSpacing = 10;

    itemTable = uitable(centerGrid, ...
        'Data', localItemsTable(batchSpec.items), ...
        'ColumnSortable', true, ...
        'RowStriping', 'on', ...
        'ColumnEditable', localItemTableEditable(batchSpec.items), ...
        'CellSelectionCallback', @onItemSelected, ...
        'CellEditCallback', @onItemEdited);
    itemTable.Layout.Row = 1;
    itemTable.Layout.Column = 1;

    rightGrid = uigridlayout(centerGrid, [2 1]);
    rightGrid.Layout.Row = 1;
    rightGrid.Layout.Column = 2;
    rightGrid.RowHeight = {'1x', '1x'};
    rightGrid.RowSpacing = 10;
    rightGrid.Padding = [0 0 0 0];

    detailsArea = uitextarea(rightGrid, ...
        'Editable', 'off', ...
        'FontName', 'Consolas', ...
        'Value', localItemDetails(batchSpec, batchSpec.prototypeIndex));
    detailsArea.Layout.Row = 1;

    validationTable = uitable(rightGrid, ...
        'Data', localValidationTable(validationReport), ...
        'ColumnSortable', true, ...
        'RowStriping', 'on');
    validationTable.Layout.Row = 2;

    footerGrid = uigridlayout(mainGrid, [3 6]);
    footerGrid.Layout.Row = 3;
    footerGrid.ColumnWidth = {160, 160, 160, 160, '1x', 180};
    footerGrid.RowHeight = {28, 28, 188};
    footerGrid.ColumnSpacing = 8;
    footerGrid.Padding = [0 0 0 0];

    choosePipelineButton = uibutton(footerGrid, 'push', ...
        'Text', 'Load from Disk...', ...
        'ButtonPushedFcn', @onChoosePipeline);
    choosePipelineButton.Layout.Row = 1;
    choosePipelineButton.Layout.Column = 1;

    loadPrototypeButton = uibutton(footerGrid, 'push', ...
        'Text', 'Load Prototype Run...', ...
        'ButtonPushedFcn', @onLoadPrototypeRun);
    loadPrototypeButton.Layout.Row = 1;
    loadPrototypeButton.Layout.Column = 2;

    openPrototypeButton = uibutton(footerGrid, 'push', ...
        'Text', 'Configure Prototype...', ...
        'ButtonPushedFcn', @onConfigurePrototype);
    openPrototypeButton.Layout.Row = 1;
    openPrototypeButton.Layout.Column = 3;

    validateButton = uibutton(footerGrid, 'push', ...
        'Text', 'Validate', ...
        'ButtonPushedFcn', @onValidate);
    validateButton.Layout.Row = 1;
    validateButton.Layout.Column = 4;

    runButton = uibutton(footerGrid, 'push', ...
        'Text', 'Run Batch', ...
        'ButtonPushedFcn', @onRunBatch);
    runButton.Layout.Row = 2;
    runButton.Layout.Column = 1;

    closeButton = uibutton(footerGrid, 'push', ...
        'Text', 'Close', ...
        'ButtonPushedFcn', @onClose);
    closeButton.Layout.Row = 2;
    closeButton.Layout.Column = 6;

    progressText = uilabel(footerGrid, ...
        'Text', sprintf('%d item(s) selected.', nnz([batchSpec.items.batchSelected])), ...
        'HorizontalAlignment', 'left');
    progressText.Layout.Row = 2;
    progressText.Layout.Column = [2 5];

    recentGrid = uigridlayout(footerGrid, [2 6]);
    recentGrid.Layout.Row = 3;
    recentGrid.Layout.Column = [1 6];
    recentGrid.RowHeight = {18, 164};
    recentGrid.ColumnWidth = {260, '1x', '1x', '1x', '1x', 80};
    recentGrid.RowSpacing = 4;
    recentGrid.ColumnSpacing = 8;
    recentGrid.Padding = [0 0 0 0];

    recentLabel = uilabel(recentGrid, ...
        'Text', 'Recent pipelines', ...
        'FontWeight', 'bold');
    recentLabel.Layout.Row = 1;
    recentLabel.Layout.Column = 1;

    recentInfoLabel = uilabel(recentGrid, ...
        'Text', 'Select a recent pipeline to load it.', ...
        'FontAngle', 'italic', ...
        'HorizontalAlignment', 'left');
    recentInfoLabel.Layout.Row = 1;
    recentInfoLabel.Layout.Column = [2 4];

    recentPipelineListBox = uilistbox(recentGrid, ...
        'Items', {'(No recent pipelines)'}, ...
        'Value', '(No recent pipelines)', ...
        'ValueChangedFcn', @onRecentPipelineSelected);
    recentPipelineListBox.Layout.Row = 2;
    recentPipelineListBox.Layout.Column = [1 4];

    refreshAll();

    uiwait(fig);

    if isvalid(fig)
        delete(fig);
    end

    function refreshAll()
        batchSpec.name = char(string(batchNameEdit.Value));
        batchSpec.execution.target = localExecutionTargetFromRuntime(batchSpec);
        if any(strcmp(executionDropDown.ItemsData, batchSpec.execution.target))
            executionDropDown.Value = batchSpec.execution.target;
        end
        batchSpec.itemsTable = localItemsTable(batchSpec.items);
        itemTable.Data = batchSpec.itemsTable;
        itemTable.ColumnEditable = localItemTableEditable(batchSpec.items);
        itemTable.ColumnName = batchSpec.itemsTable.Properties.VariableNames;
        pipelineLabel.Text = localPipelineText(batchSpec);
        prototypeLabel.Text = localPrototypeText(batchSpec);
        runtimeLabel.Text = localRuntimeConfigText(batchSpec);
        detailsArea.Value = localItemDetails(batchSpec, batchSpec.prototypeIndex);
        progressText.Text = localProgressSummary(batchSpec, validationReport, runReport);
        validationTable.Data = localValidationTable(validationReport);
        runButton.Text = sprintf('Run Batch (%s)', upper(batchSpec.execution.target));
        refreshRecentPipelineList();
        refreshControlStates();
    end

    function refreshRecentPipelineList()
        if updatingRecentPipelineList || ~isvalid(fig)
            return;
        end
        updatingRecentPipelineList = true;
        cleanupObj = onCleanup(@()setRecentPipelineListUpdating(false)); %#ok<NASGU>
        try
            recentPaths = localRecentPipelinePaths(true);
            recentPipelinePathsCache = recentPaths;
            if isempty(recentPaths)
                recentPipelineListBox.Items = {'(No recent pipelines)'};
                recentPipelineListBox.Value = '(No recent pipelines)';
                recentInfoLabel.Text = 'No recent pipelines are available yet.';
                return;
            end
            recentPipelineListBox.Items = [{'Select a recent pipeline...'} cellfun(@localRecentPipelineLabel, recentPaths, 'UniformOutput', false)];
            recentInfoLabel.Text = 'Select a recent pipeline to load it.';
            currentPath = localFieldText(batchSpec.pipelineRef, 'path');
            if ~isempty(currentPath)
                match = find(strcmpi(recentPipelinePathsCache, localNormalizeRecentPipelinePath(currentPath)), 1, 'first');
                if ~isempty(match)
                    recentPipelineListBox.Value = recentPipelineListBox.Items{match + 1};
                else
                    recentPipelineListBox.Value = recentPipelineListBox.Items{1};
                end
            else
                recentPipelineListBox.Value = recentPipelineListBox.Items{1};
            end
        catch
            try
                recentPipelineListBox.Items = {'(No recent pipelines)'};
                recentPipelineListBox.Value = '(No recent pipelines)';
            catch
            end
        end
    end

    function refreshControlStates()
        hasItems = localHasSelectedItems(batchSpec);
        hasPipeline = localHasPipeline(batchSpec);
        hasRuntime = localHasPrototypeRuntime(batchSpec);
        hasValidBatch = localValidationPassed(validationReport);

        choosePipelineButton.Enable = ternaryEnable(hasItems);
        loadPrototypeButton.Enable = ternaryEnable(hasItems && hasPipeline);
        openPrototypeButton.Enable = ternaryEnable(hasItems && hasPipeline);
        validateButton.Enable = ternaryEnable(hasItems && hasPipeline && hasRuntime);
        runButton.Enable = ternaryEnable(hasItems && hasPipeline && hasRuntime && hasValidBatch);
        if ~hasPipeline
            openPrototypeButton.Enable = 'off';
        end

        if ~hasItems
            progressText.Text = 'Select at least one item in the batch table.';
        elseif ~hasPipeline
            progressText.Text = 'Step 1: choose the pipeline template to apply to this batch.';
        elseif ~hasRuntime
            progressText.Text = 'Step 2: configure a prototype runtime with pipeline2, then click Use Prototype.';
        elseif ~hasValidBatch
            progressText.Text = 'Step 3: validate compatibility before launching the batch.';
        elseif isempty(fieldnames(runReport))
            progressText.Text = sprintf('Ready to run %d item(s) on %s.', nnz([batchSpec.items.batchSelected]), upper(batchSpec.execution.target));
        end
    end

    function onItemSelected(~, event)
        if isempty(event.Indices)
            return;
        end
        row = event.Indices(1, 1);
        if row < 1 || row > numel(batchSpec.items)
            return;
        end
        batchSpec.prototypeIndex = row;
        batchSpec.prototypeItemId = localFieldText(batchSpec.items(row), 'id');
        batchSpec = pipelineBatchSetPrototypeRuntime(batchSpec, batchSpec.prototypeRuntimeConfig);
        validationReport = struct();
        runReport = struct();
        refreshAll();
    end

    function onItemEdited(~, event)
        if isempty(event.Indices)
            return;
        end
        row = event.Indices(1, 1);
        if row < 1 || row > numel(batchSpec.items)
            return;
        end
        col = event.Indices(1, 2);
        if col ~= 1
            return;
        end
        batchSpec.items(row).batchSelected = logical(event.NewData);
        batchSpec.itemsTable = localItemsTable(batchSpec.items);
        if ~any([batchSpec.items.batchSelected])
            batchSpec.prototypeIndex = 0;
        elseif batchSpec.prototypeIndex < 1 || batchSpec.prototypeIndex > numel(batchSpec.items) || ~batchSpec.items(batchSpec.prototypeIndex).batchSelected
            batchSpec.prototypeIndex = find([batchSpec.items.batchSelected], 1, 'first');
        end
        validationReport = struct();
        runReport = struct();
        refreshAll();
    end

    function onChoosePipeline(~, ~)
        try
            [file, path] = uigetfile({'*.json;*.json', 'Pipeline JSON (*.json)'; '*.*', 'All files'}, ...
                'Select pipeline.json', pwd);
            if isequal(file, 0)
                return;
            end
            candidate = fullfile(path, file);
            localLoadPipelineFromPath(candidate, 'disk');
        catch ME
            uialert(fig, ME.message, 'Pipeline Load Failed');
        end
    end

    function onLoadPrototypeRun(~, ~)
        if ~localHasPipeline(batchSpec)
            uialert(fig, 'Choose a pipeline before loading prototype runtime parameters.', 'Pipeline Required');
            return;
        end
        try
            [runObj, msg] = pipelineRunLoad();
            if isempty(runObj)
                if ~isempty(msg) && ~contains(lower(char(string(msg))), 'cancel')
                    uialert(fig, msg, 'Prototype Run Load Failed');
                end
                return;
            end
            runPipelinePath = localPipelinePathFromRun(runObj);
            selectedPipelinePath = localFieldText(batchSpec.pipelineRef, 'path');
            if ~isempty(runPipelinePath) && ~isempty(selectedPipelinePath) && ...
                    ~strcmpi(localNormalizePathText(runPipelinePath), localNormalizePathText(selectedPipelinePath))
                uialert(fig, sprintf(['This prototype run belongs to a different pipeline.\n\n' ...
                    'Selected pipeline:\n%s\n\nPrototype run pipeline:\n%s'], selectedPipelinePath, runPipelinePath), ...
                    'Prototype Pipeline Mismatch');
                return;
            end
            if isprop(runObj, 'ctx') && isstruct(runObj.ctx)
                batchSpec = pipelineBatchSetPrototypeRuntime(batchSpec, runObj.ctx);
            else
                batchSpec = pipelineBatchSetPrototypeRuntime(batchSpec, struct());
            end
            if isprop(runObj, 'runId') && ~isempty(runObj.runId)
                batchSpec.prototypeItemId = char(string(runObj.runId));
            end
            validationReport = struct();
            runReport = struct();
            progressText.Text = 'Prototype runtime loaded from run.json.';
            refreshAll();
        catch ME
            uialert(fig, ME.message, 'Prototype Run Load Failed');
        end
    end

    function onRecentPipelineSelected(src, ~)
        if updatingRecentPipelineList
            return;
        end
        if isempty(src) || ~isvalid(src)
            return;
        end
        selected = char(string(src.Value));
        if isempty(selected) || strcmp(selected, '(No recent pipelines)') || strcmp(selected, 'Select a recent pipeline...')
            return;
        end
        match = find(strcmp(recentPipelineListBox.Items, selected), 1, 'first');
        if isempty(match) || match < 2 || (match - 1) > numel(recentPipelinePathsCache)
            return;
        end
        localLoadPipelineFromPath(recentPipelinePathsCache{match - 1}, 'recent');
    end

    function onConfigurePrototype(~, ~)
        if ~localHasPipeline(batchSpec)
            uialert(fig, 'Choose a pipeline before configuring the prototype runtime.', 'Pipeline Required');
            return;
        end
        if isempty(batchSpec.items) || batchSpec.prototypeIndex < 1 || batchSpec.prototypeIndex > numel(batchSpec.items)
            uialert(fig, 'Select one project row to use as the prototype.', 'Prototype Required');
            return;
        end
        item = batchSpec.items(batchSpec.prototypeIndex);
        if ~contains(lower(string(item.kind)), 'project')
            uialert(fig, 'Prototype tuning currently opens only project refs.', 'Prototype Not Ready');
            return;
        end
        if isempty(item.projectMatPath) || exist(item.projectMatPath, 'file') ~= 2
            uialert(fig, 'Prototype project MAT file is missing.', 'Prototype Not Ready');
            return;
        end
        try
            [shallowObj, msg] = shallowLoad(char(string(item.projectMatPath)));
            if isempty(shallowObj)
                uialert(fig, msg, 'Prototype Load Failed');
                return;
            end
            [~, prototypeProjectName] = fileparts(char(string(item.projectMatPath)));
            protoArgs = {shallowObj, 'ProjectVarName', matlab.lang.makeValidName(prototypeProjectName)};
            if isfield(batchSpec, 'pipelineTemplate') && ~isempty(batchSpec.pipelineTemplate) && ...
                    (isobject(batchSpec.pipelineTemplate) || (isstruct(batchSpec.pipelineTemplate) && ~isempty(fieldnames(batchSpec.pipelineTemplate))))
                protoArgs{end+1} = batchSpec.pipelineTemplate; %#ok<AGROW>
            end
            protoArgs = [protoArgs, {'BatchPrototype', true, 'Modal', true, 'UnlockRuntime', true}]; %#ok<AGROW>
            protoApp = pipeline2(protoArgs{:});
            if isempty(protoApp) || ~isvalid(protoApp) || ~protoApp.PrototypeAccepted
                try
                    delete(protoApp);
                catch
                end
                progressText.Text = 'Prototype configuration cancelled.';
                return;
            end
            batchSpec = pipelineBatchSetPrototypeRuntime(batchSpec, protoApp.PrototypeRuntimeConfig);
            if isstruct(protoApp.PrototypePipelineRef) && ~isempty(fieldnames(protoApp.PrototypePipelineRef))
                pipeObj = [];
                if isfield(protoApp.PrototypePipelineRef, 'path') && ~isempty(protoApp.PrototypePipelineRef.path)
                    [pipeObj, ~] = pipelineLoad(char(string(protoApp.PrototypePipelineRef.path)));
                end
                batchSpec = pipelineBatchSetPipeline(batchSpec, protoApp.PrototypePipelineRef, pipeObj);
            end
            batchSpec.execution.target = localExecutionTargetFromRuntime(batchSpec);
            validationReport = struct();
            runReport = struct();
            try
                delete(protoApp);
            catch
            end
            progressText.Text = sprintf('Prototype configured for %s execution.', upper(batchSpec.execution.target));
            refreshAll();
        catch ME
            uialert(fig, ME.message, 'Prototype Failed');
        end
    end

    function onValidate(~, ~)
        if ~localHasPipeline(batchSpec)
            uialert(fig, 'Choose a pipeline before validating the batch.', 'Pipeline Required');
            return;
        end
        if ~localHasPrototypeRuntime(batchSpec)
            uialert(fig, 'Configure a prototype runtime before validating the batch.', 'Runtime Required');
            return;
        end
        try
            batchSpec.name = char(string(batchNameEdit.Value));
            batchSpec.execution.target = localExecutionTargetFromRuntime(batchSpec);
            [ok, validationReport] = validatePipelineBatch(batchSpec, 'BatchRoot', batchRootText);
            batchSpec.validation = validationReport;
            if ok
                progressText.Text = 'Batch validation passed.';
            else
                progressText.Text = 'Batch validation reported errors.';
            end
            validationTable.Data = localValidationTable(validationReport);
            refreshAll();
        catch ME
            uialert(fig, ME.message, 'Validation Failed');
        end
    end

    function onRunBatch(~, ~)
        if ~localHasPipeline(batchSpec)
            uialert(fig, 'Choose a pipeline before running the batch.', 'Pipeline Required');
            return;
        end
        if ~localHasPrototypeRuntime(batchSpec)
            uialert(fig, 'Configure a prototype runtime before running the batch.', 'Runtime Required');
            return;
        end
        if ~localValidationPassed(validationReport)
            uialert(fig, 'Validate the batch successfully before launching runs.', 'Validation Required');
            return;
        end
        try
            batchSpec.name = char(string(batchNameEdit.Value));
            batchSpec.execution.target = localExecutionTargetFromRuntime(batchSpec);
            batchRootText = localDefaultBatchRoot(batchSpec);
            d = uiprogressdlg(fig, ...
                'Title', 'DetecDiv batch run', ...
                'Message', 'Validating batch...', ...
                'Indeterminate', 'on', ...
                'Cancelable', 'off');
            drawnow;
            runReport = runPipelineBatch(batchSpec, ...
                'BatchRoot', batchRootText, ...
                'ProgressCallback', @onBatchProgress, ...
                'StopOnError', false, ...
                'SaveProjects', true, ...
                'HubSettings', opts.HubSettings);
            closeProgress();
            validationReport = localGetStructField(runReport, 'validation', validationReport);
            batchSpec.validation = validationReport;
            validationTable.Data = localValidationTable(validationReport);
            progressText.Text = sprintf('Batch finished in %s.', runReport.finishedAt);
            refreshAll();
        catch ME
            closeProgress();
            uialert(fig, ME.message, 'Batch Run Failed');
        end

        function onBatchProgress(payload)
            if ~isvalid(fig)
                return;
            end
            try
                d.Indeterminate = false;
                d.Value = max(0, min(1, payload.progress));
                d.Message = localBatchProgressMessage(payload);
                progressText.Text = d.Message;
                drawnow limitrate;
            catch
            end
        end

        function closeProgress()
            try
                if exist('d', 'var') && ~isempty(d) && isvalid(d)
                    close(d);
                end
            catch
            end
        end
    end

    function onClose(~, ~)
        try
            uiresume(fig);
        catch
        end
    end

    function localLoadPipelineFromPath(pipelinePath, sourceLabel)
        pipelinePath = localNormalizeRecentPipelinePath(pipelinePath);
        if isempty(pipelinePath) || exist(pipelinePath, 'file') ~= 2
            uialert(fig, 'Pipeline file not found.', 'Pipeline Load Failed');
            return;
        end
        try
            [pipe, msg] = pipelineLoad(pipelinePath);
            if isempty(pipe)
                uialert(fig, msg, 'Pipeline Load Failed');
                return;
            end
            batchSpec = pipelineBatchSetPipeline(batchSpec, struct( ...
                'id', localPipelineId(pipe), ...
                'path', pipelinePath, ...
                'version', localPipelineVersion(pipe)), pipe);
            batchSpec = pipelineBatchSetPrototypeRuntime(batchSpec, struct());
            localAddRecentPipelinePath(pipelinePath);
            validationReport = struct();
            runReport = struct();
            progressText.Text = sprintf('Pipeline loaded from %s: %s', sourceLabel, pipelinePath);
            refreshAll();
        catch ME
            uialert(fig, ME.message, 'Pipeline Load Failed');
        end
    end

    function localAddRecentPipelinePath(pipelinePath)
        pipelinePath = localNormalizeRecentPipelinePath(pipelinePath);
        if isempty(pipelinePath)
            return;
        end
        paths = localRecentPipelinePaths(true);
        paths = paths(~strcmpi(paths, pipelinePath));
        paths = [{pipelinePath} paths];
        if numel(paths) > 10
            paths = paths(1:10);
        end
        try
            setpref('DetecDiv', 'pipeline2RecentPipelines', paths);
        catch
        end
    end

    function setRecentPipelineListUpdating(tf)
        updatingRecentPipelineList = logical(tf);
    end
end

function refs = localNormalizeRefs(refs)
    if isempty(refs)
        refs = struct([]);
        return;
    end
    if iscell(refs)
        refs = [refs{:}];
    end
    if ~isstruct(refs)
        error('detecdiv_batch_builder:InvalidRefs', 'Selected refs must be a struct array.');
    end
end

function owner = localBatchOwner(opts)
    owner = '';
    try
        if isstruct(opts.HubSettings) && isfield(opts.HubSettings, 'userKey') && ~isempty(opts.HubSettings.userKey)
            owner = char(string(opts.HubSettings.userKey));
        elseif isstruct(opts.CatalogSettings) && isfield(opts.CatalogSettings, 'userKey') && ~isempty(opts.CatalogSettings.userKey)
            owner = char(string(opts.CatalogSettings.userKey));
        end
    catch
        owner = '';
    end
end

function text = localPipelineText(batchSpec)
    if ~localHasPipeline(batchSpec)
        text = 'No pipeline selected yet.';
    else
        pipelineId = localFieldText(batchSpec.pipelineRef, 'id');
        pipelinePath = localFieldText(batchSpec.pipelineRef, 'path');
        if isempty(pipelineId)
            pipelineId = '<unnamed>';
        end
        text = sprintf('Loaded: %s | %s', pipelineId, pipelinePath);
    end
end

function text = localRecentPipelineLabel(pipelinePath)
    pipelinePath = char(string(pipelinePath));
    [folder, file, ext] = fileparts(pipelinePath);
    [parent, folderName] = fileparts(folder);
    [~, parentName] = fileparts(parent);
    text = [folderName filesep file ext];
    if ~isempty(parentName)
        text = [parentName filesep text];
    end
end

function text = localPrototypeText(batchSpec)
    if isempty(batchSpec.items) || batchSpec.prototypeIndex < 1 || batchSpec.prototypeIndex > numel(batchSpec.items)
        text = 'Select a prototype row.';
    else
        item = batchSpec.items(batchSpec.prototypeIndex);
        text = sprintf('%s | %s', localFieldText(item, 'kind'), localFieldText(item, 'displayName'));
    end
end

function text = localRuntimeConfigText(batchSpec)
    if ~localHasPrototypeRuntime(batchSpec)
        text = 'Not configured. Click Configure Prototype... and finish with Use Prototype.';
        return;
    end
    ctx = batchSpec.prototypeRuntimeConfig;
    target = upper(localExecutionTargetFromRuntime(batchSpec));
    runId = localNestedFieldText(ctx, {'runId'});
    if isempty(runId)
        runId = localNestedFieldText(ctx, {'run', 'runId'});
    end
    if isempty(runId)
        runId = '<auto>';
    end
    inputSource = localNestedFieldText(ctx, {'run', 'inputSource'});
    if isempty(inputSource)
        inputSource = '<default>';
    end
    text = sprintf('Configured: target=%s | run=%s | input=%s', target, runId, inputSource);
end

function tf = localHasPipeline(batchSpec)
    tf = false;
    try
        tf = isfield(batchSpec, 'pipelineRef') && isstruct(batchSpec.pipelineRef) && ...
            isfield(batchSpec.pipelineRef, 'path') && ~isempty(strtrim(char(string(batchSpec.pipelineRef.path))));
    catch
        tf = false;
    end
end

function tf = localHasSelectedItems(batchSpec)
    tf = false;
    try
        tf = isfield(batchSpec, 'items') && ~isempty(batchSpec.items) && ...
            isfield(batchSpec.items, 'batchSelected') && any([batchSpec.items.batchSelected]);
    catch
        tf = false;
    end
end

function tf = localHasPrototypeRuntime(batchSpec)
    tf = false;
    try
        tf = isfield(batchSpec, 'prototypeRuntimeConfig') && isstruct(batchSpec.prototypeRuntimeConfig) && ...
            ~isempty(fieldnames(batchSpec.prototypeRuntimeConfig));
    catch
        tf = false;
    end
end

function tf = localValidationPassed(report)
    tf = false;
    try
        if isempty(report) || ~isstruct(report) || ~isfield(report, 'summary') || ~isstruct(report.summary)
            return;
        end
        s = report.summary;
        if isfield(s, 'errorItems') && double(s.errorItems) > 0
            return;
        end
        if isfield(s, 'validItems') && double(s.validItems) > 0
            tf = true;
            return;
        end
        if isfield(s, 'ok')
            tf = logical(s.ok);
        end
    catch
        tf = false;
    end
end

function paths = localRecentPipelinePaths(keepMissing)
    if nargin < 1
        keepMissing = false;
    end
    paths = {};
    try
        paths = getpref('DetecDiv', 'pipeline2RecentPipelines', {});
    catch
        paths = {};
    end
    if ischar(paths) || (isstring(paths) && isscalar(paths))
        paths = {char(string(paths))};
    elseif isstring(paths)
        paths = cellstr(paths(:))';
    elseif ~iscell(paths)
        paths = {};
    end
    normalized = {};
    for i = 1:numel(paths)
        p = localNormalizeRecentPipelinePath(paths{i});
        if isempty(p)
            continue;
        end
        if keepMissing || exist(p, 'file') == 2
            normalized{end+1} = p; %#ok<AGROW>
        end
    end
    paths = unique(normalized, 'stable');
    if ~keepMissing
        try
            setpref('DetecDiv', 'pipeline2RecentPipelines', paths);
        catch
        end
    end
end

function pipelineFile = localNormalizeRecentPipelinePath(pipelineFile)
    pipelineFile = strtrim(char(string(pipelineFile)));
    if isempty(pipelineFile)
        return;
    end
    try
        if exist(pipelineFile, 'dir') == 7
            pipelineFile = fullfile(pipelineFile, 'pipeline.json');
        end
        if exist(pipelineFile, 'file') == 2
            pipelineFile = char(java.io.File(pipelineFile).getCanonicalPath());
        end
    catch
    end
end

function value = ternaryEnable(tf)
    if tf
        value = 'on';
    else
        value = 'off';
    end
end

function text = localNestedFieldText(S, path)
    text = '';
    try
        value = S;
        for i = 1:numel(path)
            key = path{i};
            if isstruct(value) && isfield(value, key)
                value = value.(key);
            else
                return;
            end
        end
        if ~isempty(value)
            text = char(string(value));
        end
    catch
        text = '';
    end
end

function text = localNormalizePathText(pathValue)
    text = strtrim(char(string(pathValue)));
    if isempty(text)
        return;
    end
    try
        text = char(java.io.File(text).getCanonicalPath());
    catch
        text = char(java.io.File(text).getAbsolutePath());
    end
end

function text = localFieldText(S, fieldName)
    text = '';
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        text = char(string(S.(fieldName)));
    end
end

function tbl = localItemsTable(items)
    if isempty(items)
        tbl = table();
        return;
    end
    n = numel(items);
    selected = false(n, 1);
    kind = strings(n, 1);
    name = strings(n, 1);
    source = strings(n, 1);
    ref = strings(n, 1);
    projectMatPath = strings(n, 1);
    datasetId = strings(n, 1);
    for i = 1:n
        selected(i) = logical(localGetStructField(items(i), 'batchSelected', false));
        kind(i) = string(localFieldText(items(i), 'kind'));
        name(i) = string(localFieldText(items(i), 'displayName'));
        source(i) = string(localFieldText(items(i), 'sourceMode'));
        ref(i) = string(localFieldText(items(i), 'catalogId'));
        projectMatPath(i) = string(localFieldText(items(i), 'projectMatPath'));
        datasetId(i) = string(localFieldText(items(i), 'datasetId'));
    end
    tbl = table(selected, kind, name, source, ref, projectMatPath, datasetId, ...
        'VariableNames', {'Selected', 'Kind', 'Name', 'Source', 'Ref', 'ProjectMatPath', 'DatasetId'});
end

function editable = localItemTableEditable(items)
    if isempty(items)
        editable = false(1, 7);
    else
        editable = [true false false false false false false];
    end
end

function rows = localValidationTable(report)
    if isempty(report) || ~isstruct(report) || ~isfield(report, 'items') || isempty(report.items)
        rows = table();
        return;
    end
    n = numel(report.items);
    item = strings(n, 1);
    kind = strings(n, 1);
    status = strings(n, 1);
    errors = strings(n, 1);
    warnings = strings(n, 1);
    for i = 1:n
        item(i) = string(localGetStructField(report.items(i), 'name', localGetStructField(report.items(i), 'displayName', '')));
        kind(i) = string(localGetStructField(report.items(i), 'kind', ''));
        status(i) = string(localGetStructField(report.items(i), 'status', ''));
        errors(i) = string(localJoinCell(localGetStructField(report.items(i), 'errors', {})));
        warnings(i) = string(localJoinCell(localGetStructField(report.items(i), 'warnings', {})));
    end
    rows = table(item, kind, status, warnings, errors, ...
        'VariableNames', {'Item', 'Kind', 'Status', 'Warnings', 'Errors'});
end

function lines = localItemDetails(batchSpec, idx)
    if isempty(batchSpec.items) || idx < 1 || idx > numel(batchSpec.items)
        lines = {'No item selected.'};
        return;
    end
    item = batchSpec.items(idx);
    lines = {
        ['Batch id     : ' localFieldText(batchSpec, 'id')]
        ['Batch name   : ' localFieldText(batchSpec, 'name')]
        ['Item kind    : ' localFieldText(item, 'kind')]
        ['Display name : ' localFieldText(item, 'displayName')]
        ['Source mode  : ' localFieldText(item, 'sourceMode')]
        ['Entity mode  : ' localFieldText(item, 'entityMode')]
        ['Catalog ref  : ' localFieldText(item, 'catalogId')]
        ['Project MAT  : ' localFieldText(item, 'projectMatPath')]
        ['Dataset id   : ' localFieldText(item, 'datasetId')]
        ['Root path    : ' localFieldText(item, 'rootPath')]
        ['Local hint   : ' localFieldText(item, 'localPathHint')]
        ['Batch sel.   : ' localBoolText(localGetStructField(item, 'batchSelected', false))]
        };
end

function text = localItemProgressLabel(item)
    if ~isstruct(item)
        text = '';
        return;
    end
    text = localFieldText(item, 'name');
    if isempty(text)
        text = localFieldText(item, 'displayName');
    end
    if isempty(text)
        text = localFieldText(item, 'kind');
    end
end

function text = localBatchProgressMessage(payload)
    idx = localGetStructField(payload, 'index', 0);
    total = localGetStructField(payload, 'total', 0);
    state = upper(char(string(localGetStructField(payload, 'state', 'running'))));
    itemText = localItemProgressLabel(localGetStructField(payload, 'item', struct()));
    if isempty(itemText)
        itemText = '<item>';
    end
    pct = round(100 * max(0, min(1, double(localGetStructField(payload, 'progress', 0)))));
    if isstruct(payload) && isfield(payload, 'node') && isstruct(payload.node)
        nodeId = localGetStructField(payload.node, 'nodeId', '');
        nodeIndex = localGetStructField(payload.node, 'nodeIndex', 0);
        totalNodes = localGetStructField(payload.node, 'totalNodes', 0);
        nodeMsg = localGetStructField(payload.node, 'message', '');
        if isempty(nodeMsg)
            nodeMsg = sprintf('Module %d/%d: %s', nodeIndex, totalNodes, char(string(nodeId)));
        end
        text = sprintf('Batch %d%% | item %d/%d: %s | %s', pct, idx, total, itemText, char(string(nodeMsg)));
        return;
    end
    text = sprintf('Batch %d%% | %s item %d/%d: %s', pct, state, idx, total, itemText);
end

function text = localProgressSummary(batchSpec, validationReport, runReport)
    parts = {};
    parts{end+1} = sprintf('%d item(s)', numel(batchSpec.items)); %#ok<AGROW>
    if nargin >= 2 && isstruct(validationReport) && isfield(validationReport, 'summary')
        s = validationReport.summary;
        if isfield(s, 'validItems')
            parts{end+1} = sprintf('valid=%d', s.validItems); %#ok<AGROW>
        end
        if isfield(s, 'errorItems')
            parts{end+1} = sprintf('errors=%d', s.errorItems); %#ok<AGROW>
        end
    end
    if nargin >= 3 && isstruct(runReport) && isfield(runReport, 'summary')
        s = runReport.summary;
        parts{end+1} = sprintf('done=%d failed=%d skipped=%d', s.doneItems, s.failedItems, s.skippedItems); %#ok<AGROW>
    end
    text = strjoin(parts, ' | ');
end

function target = localExecutionTargetFromRuntime(batchSpec)
    target = 'local';
    try
        if isstruct(batchSpec) && isfield(batchSpec, 'execution') && isstruct(batchSpec.execution) && ...
                isfield(batchSpec.execution, 'target') && ~isempty(batchSpec.execution.target)
            target = lower(char(string(batchSpec.execution.target)));
        end
        if isstruct(batchSpec) && isfield(batchSpec, 'prototypeRuntimeConfig') && ...
                isstruct(batchSpec.prototypeRuntimeConfig) && ...
                isfield(batchSpec.prototypeRuntimeConfig, 'run') && isstruct(batchSpec.prototypeRuntimeConfig.run) && ...
                isfield(batchSpec.prototypeRuntimeConfig.run, 'executionTarget') && ...
                ~isempty(batchSpec.prototypeRuntimeConfig.run.executionTarget)
            target = lower(char(string(batchSpec.prototypeRuntimeConfig.run.executionTarget)));
        end
    catch
        target = 'local';
    end
    if ~ismember(target, {'local', 'hub'})
        target = 'local';
    end
end

function text = localBoolText(value)
    if logical(value)
        text = 'true';
    else
        text = 'false';
    end
end

function val = localGetStructField(S, fieldName, defaultVal)
    val = defaultVal;
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        val = S.(fieldName);
    end
end

function text = localJoinCell(value)
    if isempty(value)
        text = '';
        return;
    end
    if iscell(value)
        parts = cell(size(value));
        for i = 1:numel(value)
            parts{i} = char(string(value{i}));
        end
        text = strjoin(parts, ' | ');
    elseif isstring(value)
        text = strjoin(cellstr(value), ' | ');
    else
        text = char(string(value));
    end
end

function text = localDefaultBatchRoot(batchSpec)
    text = fullfile(tempdir, 'detecdiv_batch_runs', localFieldText(batchSpec, 'id'));
    if isempty(strtrim(text))
        text = fullfile(tempdir, 'detecdiv_batch_runs', char(java.util.UUID.randomUUID()));
    end
end

function text = localPipelineId(pipe)
    text = '';
    try
        if isobject(pipe) && isprop(pipe, 'id') && ~isempty(pipe.id)
            text = char(string(pipe.id));
        elseif isstruct(pipe) && isfield(pipe, 'id') && ~isempty(pipe.id)
            text = char(string(pipe.id));
        elseif isobject(pipe) && isprop(pipe, 'strid') && ~isempty(pipe.strid)
            text = char(string(pipe.strid));
        end
    catch
        text = '';
    end
    if isempty(text)
        text = 'pipeline';
    end
end

function text = localPipelineVersion(pipe)
    text = '';
    try
        if isobject(pipe) && isprop(pipe, 'version') && ~isempty(pipe.version)
            text = char(string(pipe.version));
        elseif isstruct(pipe) && isfield(pipe, 'version') && ~isempty(pipe.version)
            text = char(string(pipe.version));
        end
    catch
        text = '';
    end
end

function pathText = localPipelinePathFromRun(runObj)
    pathText = '';
    try
        if isprop(runObj, 'pipelineRef') && isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'path')
            pathText = char(string(runObj.pipelineRef.path));
        end
        if isempty(pathText) && isprop(runObj, 'templatePath')
            pathText = char(string(runObj.templatePath));
        end
    catch
        pathText = '';
    end
end
