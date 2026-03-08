function fig = detecdivCatalogBrowser(varargin)
% detecdivCatalogBrowser  Browse indexed DetecDiv projects from local DB or hub API.

    ip = inputParser;
    ip.addParameter('RootPath', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('DbFile', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    catalogSettings = detecdiv_catalog_settings_get();
    hubSettings = detecdiv_hub_settings_get();
    if strlength(string(opts.RootPath)) > 0
        catalogSettings.defaultProjectRoot = char(string(opts.RootPath));
    end
    if strlength(string(opts.DbFile)) > 0
        catalogSettings.dbFile = char(string(opts.DbFile));
    end

    repoDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    detecdiv_catalog_init(catalogSettings.dbFile);

    state = struct();
    state.catalogSettings = catalogSettings;
    state.hubSettings = hubSettings;
    state.sourceMode = localNormalizeSourceMode(hubSettings.sourceMode);
    state.projects = table();
    state.selectedRow = [];
    state.job = [];
    state.pollTimer = [];
    state.lastVisibleProjectCount = 0;

    fig = uifigure( ...
        'Name', 'DetecDiv Catalog Browser', ...
        'Position', [100 100 1320 800], ...
        'Color', [0.98 0.98 0.98], ...
        'CloseRequestFcn', @onCloseFigure);

    mainGrid = uigridlayout(fig, [4 1]);
    mainGrid.RowHeight = {122, 28, '1x', 38};
    mainGrid.ColumnWidth = {'1x'};
    mainGrid.Padding = [14 14 14 14];
    mainGrid.RowSpacing = 10;

    controlGrid = uigridlayout(mainGrid, [3 8]);
    controlGrid.Layout.Row = 1;
    controlGrid.RowHeight = {24, 32, 32};
    controlGrid.ColumnWidth = {78, 120, '1x', 90, '1x', 110, 110, 110};
    controlGrid.ColumnSpacing = 8;
    controlGrid.Padding = [0 0 0 0];

    sourceLabel = uilabel(controlGrid, 'Text', 'Source', 'FontWeight', 'bold');
    sourceLabel.Layout.Row = 1;
    sourceLabel.Layout.Column = 1;

    sourceDropDown = uidropdown(controlGrid, ...
        'Items', {'Local SQLite', 'Hub API'}, ...
        'ItemsData', {'local', 'hub'}, ...
        'Value', state.sourceMode, ...
        'ValueChangedFcn', @onSourceModeChanged);
    sourceDropDown.Layout.Row = 1;
    sourceDropDown.Layout.Column = 2;

    sourceInfoLabel = uilabel(controlGrid, ...
        'Text', '', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic');
    sourceInfoLabel.Layout.Row = 1;
    sourceInfoLabel.Layout.Column = [3 5];

    backgroundCheck = uicheckbox(controlGrid, ...
        'Text', 'Background indexing', ...
        'Value', logical(state.catalogSettings.backgroundIndexing));
    backgroundCheck.Layout.Row = 1;
    backgroundCheck.Layout.Column = [6 8];

    baseUrlLabel = uilabel(controlGrid, 'Text', 'Hub URL', 'FontWeight', 'bold');
    baseUrlLabel.Layout.Row = 2;
    baseUrlLabel.Layout.Column = 1;

    baseUrlEdit = uieditfield(controlGrid, 'text', 'Value', state.hubSettings.baseUrl);
    baseUrlEdit.Layout.Row = 2;
    baseUrlEdit.Layout.Column = [2 5];

    localMountLabel = uilabel(controlGrid, 'Text', 'Local Mount', 'FontWeight', 'bold');
    localMountLabel.Layout.Row = 2;
    localMountLabel.Layout.Column = 6;

    localMountEdit = uieditfield(controlGrid, 'text', 'Value', state.hubSettings.defaultLocalProjectRoot);
    localMountEdit.Layout.Row = 2;
    localMountEdit.Layout.Column = [7 8];

    rootLabel = uilabel(controlGrid, 'Text', '', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    rootLabel.Layout.Row = 3;
    rootLabel.Layout.Column = 1;

    rootEdit = uieditfield(controlGrid, 'text');
    rootEdit.Layout.Row = 3;
    rootEdit.Layout.Column = [2 4];

    browseButton = uibutton(controlGrid, 'push', 'Text', 'Browse...', ...
        'ButtonPushedFcn', @onBrowseRoot);
    browseButton.Layout.Row = 3;
    browseButton.Layout.Column = 5;

    saveRootButton = uibutton(controlGrid, 'push', 'Text', 'Save Config', ...
        'ButtonPushedFcn', @onSaveConfiguration);
    saveRootButton.Layout.Row = 3;
    saveRootButton.Layout.Column = 6;

    indexButton = uibutton(controlGrid, 'push', 'Text', 'Index Root', ...
        'ButtonPushedFcn', @onIndexRoot);
    indexButton.Layout.Row = 3;
    indexButton.Layout.Column = 7;

    refreshButton = uibutton(controlGrid, 'push', 'Text', 'Refresh', ...
        'ButtonPushedFcn', @onRefreshProjects);
    refreshButton.Layout.Row = 3;
    refreshButton.Layout.Column = 8;

    statusLabel = uilabel(mainGrid, ...
        'Text', 'Ready.', ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.15 0.15 0.15]);
    statusLabel.Layout.Row = 2;

    bodyGrid = uigridlayout(mainGrid, [1 2]);
    bodyGrid.Layout.Row = 3;
    bodyGrid.ColumnWidth = {'2.6x', '1x'};
    bodyGrid.ColumnSpacing = 12;
    bodyGrid.Padding = [0 0 0 0];

    projectTable = uitable(bodyGrid, ...
        'Data', table(), ...
        'ColumnSortable', true, ...
        'RowStriping', 'on', ...
        'CellSelectionCallback', @onProjectSelected);
    projectTable.Layout.Row = 1;
    projectTable.Layout.Column = 1;

    sideGrid = uigridlayout(bodyGrid, [3 1]);
    sideGrid.Layout.Row = 1;
    sideGrid.Layout.Column = 2;
    sideGrid.RowHeight = {24, '1x', 40};
    sideGrid.RowSpacing = 8;
    sideGrid.Padding = [0 0 0 0];

    uilabel(sideGrid, 'Text', 'Project Details', 'FontWeight', 'bold');

    detailsArea = uitextarea(sideGrid, ...
        'Editable', 'off', ...
        'Value', {'No project selected.'}, ...
        'FontName', 'Consolas');
    detailsArea.Layout.Row = 2;

    actionGrid = uigridlayout(sideGrid, [1 2]);
    actionGrid.Layout.Row = 3;
    actionGrid.ColumnWidth = {'1x', '1x'};
    actionGrid.ColumnSpacing = 8;
    actionGrid.Padding = [0 0 0 0];

    loadButton = uibutton(actionGrid, 'push', 'Text', 'Load Project', ...
        'Enable', 'off', 'ButtonPushedFcn', @onLoadProject);
    loadButton.Layout.Row = 1;
    loadButton.Layout.Column = 1;

    openFolderButton = uibutton(actionGrid, 'push', 'Text', 'Open Folder', ...
        'Enable', 'off', 'ButtonPushedFcn', @onOpenFolder);
    openFolderButton.Layout.Row = 1;
    openFolderButton.Layout.Column = 2;

    footerLabel = uilabel(mainGrid, ...
        'Text', 'Local mode uses SQLite. Hub mode uses the API and maps server roots to local mounts when needed.', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic', ...
        'FontColor', [0.35 0.35 0.35]);
    footerLabel.Layout.Row = 4;

    syncUiFromState();
    refreshProjectsTable();

    function onSourceModeChanged(~, ~)
        state.sourceMode = localNormalizeSourceMode(sourceDropDown.Value);
        state.hubSettings.sourceMode = state.sourceMode;
        detecdiv_hub_settings_set(state.hubSettings);
        syncUiFromState();
        refreshProjectsTable();
    end

    function onBrowseRoot(~, ~)
        currentRoot = strtrim(rootEdit.Value);
        if isempty(currentRoot) || ~isfolder(currentRoot)
            if strcmp(state.sourceMode, 'local')
                currentRoot = pwd;
            else
                currentRoot = localMountEdit.Value;
                if isempty(currentRoot) || ~isfolder(currentRoot)
                    currentRoot = pwd;
                end
            end
        end
        selectedRoot = uigetdir(currentRoot, 'Select project root');
        if isequal(selectedRoot, 0)
            return;
        end
        rootEdit.Value = char(selectedRoot);
    end

    function onSaveConfiguration(~, ~)
        if strcmp(state.sourceMode, 'local')
            rootPath = sanitizeRoot(rootEdit.Value, 'RequireExisting', true);
            if isempty(rootPath)
                uialert(fig, 'Please choose a valid local project root folder first.', ...
                    'Invalid Folder');
                return;
            end

            state.catalogSettings.defaultProjectRoot = rootPath;
            state.catalogSettings.recentProjectRoots = updateRecentRoots( ...
                state.catalogSettings.recentProjectRoots, rootPath);
            state.catalogSettings.backgroundIndexing = logical(backgroundCheck.Value);
            detecdiv_catalog_settings_set(state.catalogSettings);
            setStatus(['Local catalog configuration saved: ' rootPath]);
            syncUiFromState();
            return;
        end

        hubRoot = sanitizeRoot(rootEdit.Value, 'RequireExisting', false);
        localMount = sanitizeRoot(localMountEdit.Value, 'RequireExisting', false);

        state.hubSettings.baseUrl = strtrim(baseUrlEdit.Value);
        state.hubSettings.defaultRemoteProjectRoot = hubRoot;
        state.hubSettings.defaultLocalProjectRoot = localMount;
        state.hubSettings.sourceMode = state.sourceMode;
        if ~isempty(hubRoot) && ~isempty(localMount)
            state.hubSettings = detecdiv_hub_upsert_path_mapping(state.hubSettings, hubRoot, localMount);
        end
        detecdiv_hub_settings_set(state.hubSettings);
        setStatus('Hub configuration saved.');
        syncUiFromState();
    end

    function onIndexRoot(~, ~)
        if strcmp(state.sourceMode, 'local')
            rootPath = sanitizeRoot(rootEdit.Value, 'RequireExisting', true);
            if isempty(rootPath)
                uialert(fig, 'Please choose a valid project root folder.', 'Invalid Folder');
                return;
            end

            state.catalogSettings.defaultProjectRoot = rootPath;
            state.catalogSettings.recentProjectRoots = updateRecentRoots( ...
                state.catalogSettings.recentProjectRoots, rootPath);
            state.catalogSettings.backgroundIndexing = logical(backgroundCheck.Value);
            detecdiv_catalog_settings_set(state.catalogSettings);

            if logical(backgroundCheck.Value)
                launchBackgroundIndex(rootPath);
            else
                runSynchronousIndex(rootPath);
            end
            return;
        end

        hubRoot = sanitizeRoot(rootEdit.Value, 'RequireExisting', false);
        localMount = sanitizeRoot(localMountEdit.Value, 'RequireExisting', false);
        if isempty(hubRoot)
            uialert(fig, 'Please enter the remote project root to index on the hub.', 'Invalid Root');
            return;
        end

        state.hubSettings.baseUrl = strtrim(baseUrlEdit.Value);
        state.hubSettings.defaultRemoteProjectRoot = hubRoot;
        state.hubSettings.defaultLocalProjectRoot = localMount;
        state.hubSettings.sourceMode = state.sourceMode;
        if ~isempty(hubRoot) && ~isempty(localMount)
            state.hubSettings = detecdiv_hub_upsert_path_mapping(state.hubSettings, hubRoot, localMount);
        end
        detecdiv_hub_settings_set(state.hubSettings);

        setBusyState(true);
        cleanupObj = onCleanup(@() setBusyState(false)); %#ok<NASGU>
        drawnow;

        try
            response = detecdiv_hub_request_index(hubRoot, state.hubSettings, ...
                'HostScope', 'server', 'ClearExistingForRoot', false);
            refreshProjectsTable();
            setStatus(sprintf('Hub indexed %d project(s) from %s.', ...
                response.indexed_projects, char(string(response.source_path))));
        catch ME
            uialert(fig, ME.message, 'Hub Indexing Failed');
            setStatus(['Hub indexing failed: ' ME.message]);
        end
    end

    function onRefreshProjects(~, ~)
        refreshProjectsTable();
    end

    function onProjectSelected(~, event)
        if isempty(event.Indices)
            state.selectedRow = [];
            updateSelectionState();
            return;
        end

        state.selectedRow = event.Indices(1, 1);
        if isempty(state.projects) || height(state.projects) < state.selectedRow
            updateSelectionState();
            return;
        end

        if strcmp(state.sourceMode, 'local')
            state.catalogSettings.lastSelectedProjectMat = char(string(state.projects.project_mat_abs(state.selectedRow)));
            detecdiv_catalog_settings_set(state.catalogSettings);
        else
            state.hubSettings.lastProjectId = char(string(state.projects.project_id(state.selectedRow)));
            detecdiv_hub_settings_set(state.hubSettings);
        end
        updateSelectionState();
    end

    function onLoadProject(~, ~)
        row = getSelectedProjectRow();
        if isempty(row)
            return;
        end

        try
            if strcmp(state.sourceMode, 'local')
                [shallowObj, msg] = shallowLoad(char(string(row.project_mat_abs)));
            else
                [shallowObj, msg] = detecdiv_hub_load_project(char(string(row.project_id)), state.hubSettings);
            end
            if isempty(shallowObj)
                setStatus(msg);
                return;
            end

            varName = matlab.lang.makeValidName(['proj_' char(string(row.name))]);
            assignin('base', varName, shallowObj);
            refreshProjectsTable('PreserveStatus', true);
            setStatus(sprintf('Project loaded into workspace as "%s".', varName));
        catch ME
            uialert(fig, ME.message, 'Load Project Failed');
        end
    end

    function onOpenFolder(~, ~)
        row = getSelectedProjectRow();
        if isempty(row)
            return;
        end

        if strcmp(state.sourceMode, 'local')
            openPath(char(string(row.project_dir_abs)));
            return;
        end

        [projectDetail, projectMatPath] = resolveSelectedHubProject();
        if ~isempty(projectMatPath)
            openPath(fileparts(projectMatPath));
            return;
        end

        projectDir = localHubMetadataField(projectDetail, 'project_dir_abs');
        if ~isempty(projectDir)
            openPath(projectDir);
        else
            uialert(fig, 'Could not resolve a local folder for this hub project.', 'Open Failed');
        end
    end

    function launchBackgroundIndex(rootPath)
        if ~isempty(state.job) && isvalidJob(state.job) && ~strcmpi(state.job.State, 'finished')
            uialert(fig, 'An indexing job is already running.', 'Indexing In Progress');
            return;
        end

        try
            cluster = parcluster('local');
            job = batch(cluster, @detecdiv_catalog_run_index_job, 1, ...
                {rootPath, state.catalogSettings.dbFile}, ...
                'CurrentFolder', repoDir, ...
                'AutoAddClientPath', true, ...
                'Pool', 0);
        catch ME
            setStatus(['Background launch failed, running synchronously: ' ME.message]);
            runSynchronousIndex(rootPath);
            return;
        end

        state.job = job;
        stopPollingTimer();
        state.pollTimer = timer( ...
            'ExecutionMode', 'fixedSpacing', ...
            'Period', 0.75, ...
            'BusyMode', 'drop', ...
            'TimerFcn', @(~, ~)pollFutureState());
        start(state.pollTimer);

        setBusyState(true);
        setStatus(['Background indexing started for: ' rootPath]);
    end

    function runSynchronousIndex(rootPath)
        setBusyState(true);
        cleanupObj = onCleanup(@() setBusyState(false)); %#ok<NASGU>
        drawnow;

        try
            detecdiv_catalog_run_index_job(rootPath, state.catalogSettings.dbFile);
            refreshProjectsTable();
            setStatus(['Indexing completed for: ' rootPath]);
        catch ME
            uialert(fig, ME.message, 'Indexing Failed');
            setStatus(['Indexing failed: ' ME.message]);
        end
    end

    function pollFutureState()
        if ~isvalid(fig)
            stopPollingTimer();
            return;
        end

        if isempty(state.job) || ~isvalidJob(state.job)
            stopPollingTimer();
            setBusyState(false);
            return;
        end

        switch lower(string(state.job.State))
            case "finished"
                stopPollingTimer();
                try
                    fetchOutputs(state.job);
                    refreshProjectsTable();
                    setStatus('Background indexing completed.');
                catch ME
                    uialert(fig, ME.message, 'Background Indexing Failed');
                    setStatus(['Background indexing failed: ' ME.message]);
                end
                setBusyState(false);
                cleanupFinishedJob();
            case "failed"
                stopPollingTimer();
                try
                    fetchOutputs(state.job);
                catch ME
                    uialert(fig, ME.message, 'Background Indexing Failed');
                    setStatus(['Background indexing failed: ' ME.message]);
                end
                setBusyState(false);
                cleanupFinishedJob();
            otherwise
                refreshProjectsTable('PreserveStatus', true);
                setStatus(sprintf('Background indexing running... %d visible project(s).', ...
                    state.lastVisibleProjectCount));
        end
    end

    function refreshProjectsTable(varargin)
        ipLocal = inputParser;
        ipLocal.addParameter('PreserveStatus', false, @(x)islogical(x) || isnumeric(x));
        ipLocal.parse(varargin{:});
        preserveStatus = logical(ipLocal.Results.PreserveStatus);

        try
            if strcmp(state.sourceMode, 'local')
                projects = localNormalizeLocalProjects( ...
                    detecdiv_catalog_list_projects(state.catalogSettings.dbFile));
                state.projects = projects;
                state.lastVisibleProjectCount = height(projects);
                projectTable.Data = localBuildDisplayTable(projects, 'local');
                restorePreviousSelection();
                updateSelectionState();
                if ~preserveStatus
                    if isempty(projects)
                        setStatus('No indexed projects found in the local catalog DB.');
                    else
                        setStatus(sprintf('%d indexed project(s) loaded from %s.', ...
                            height(projects), state.catalogSettings.dbFile));
                    end
                end
                return;
            end

            state.hubSettings.baseUrl = strtrim(baseUrlEdit.Value);
            detecdiv_hub_settings_set(state.hubSettings);
            projects = localNormalizeHubProjects(detecdiv_hub_list_projects(state.hubSettings));
            state.projects = projects;
            state.lastVisibleProjectCount = height(projects);
            projectTable.Data = localBuildDisplayTable(projects, 'hub');
            restorePreviousSelection();
            updateSelectionState();
            if ~preserveStatus
                if isempty(projects)
                    setStatus(sprintf('No projects returned by %s.', state.hubSettings.baseUrl));
                else
                    setStatus(sprintf('%d hub project(s) loaded from %s.', ...
                        height(projects), state.hubSettings.baseUrl));
                end
            end
        catch ME
            state.projects = table();
            projectTable.Data = table();
            state.selectedRow = [];
            updateSelectionState();
            if ~preserveStatus
                setStatus(['Refresh failed: ' ME.message]);
            end
        end
    end

    function restorePreviousSelection()
        state.selectedRow = [];
        if isempty(state.projects) || height(state.projects) == 0
            return;
        end

        if strcmp(state.sourceMode, 'local')
            wantedKey = char(string(state.catalogSettings.lastSelectedProjectMat));
            if isempty(wantedKey)
                return;
            end
            matchIdx = find(strcmp(string(state.projects.project_mat_abs), string(wantedKey)), 1, 'first');
        else
            wantedKey = char(string(state.hubSettings.lastProjectId));
            if isempty(wantedKey)
                return;
            end
            matchIdx = find(strcmp(string(state.projects.project_id), string(wantedKey)), 1, 'first');
        end
        if ~isempty(matchIdx)
            state.selectedRow = matchIdx;
        end
    end

    function updateSelectionState()
        row = getSelectedProjectRow();
        hasRow = ~isempty(row);

        loadButton.Enable = onOff(hasRow);
        openFolderButton.Enable = onOff(hasRow);

        if ~hasRow
            detailsArea.Value = {'No project selected.'};
            return;
        end

        if strcmp(state.sourceMode, 'local')
            detailsArea.Value = {
                'Source         : local SQLite'
                ['Name           : ' char(string(row.name))]
                ['Loaded         : ' localYesNo(localProjectLoadedPath(char(string(row.project_mat_abs))))]
                ['Health         : ' char(string(row.health_status))]
                ['Raw status     : ' char(string(row.raw_status))]
                ['FOV count      : ' num2str(row.fov_count)]
                ['ROI count      : ' num2str(row.roi_count)]
                ['Classifier cnt : ' num2str(row.classifier_count)]
                ['Processor cnt  : ' num2str(row.processor_count)]
                ['Pipeline runs  : ' num2str(row.pipeline_run_count)]
                ['Missing raw    : ' num2str(row.missing_raw_count)]
                ['Last scan      : ' char(string(row.last_scan_at))]
                ' '
                ['Project MAT    : ' char(string(row.project_mat_abs))]
                ['Project folder : ' char(string(row.project_dir_abs))]
                ['Root folder    : ' char(string(row.root_abs_path))]
                ['Relative path  : ' char(string(row.project_rel_from_root))]
                };
            return;
        end

        try
            [projectDetail, projectMatPath, resolutionInfo] = resolveSelectedHubProject();
            locationCount = 0;
            if isstruct(projectDetail) && isfield(projectDetail, 'locations')
                locationCount = numel(projectDetail.locations);
            end
            detailsArea.Value = {
                'Source         : hub API'
                ['Project id     : ' char(string(row.project_id))]
                ['Name           : ' char(string(row.name))]
                ['Loaded         : ' localYesNo(localProjectLoadedPath(projectMatPath))]
                ['Health         : ' char(string(row.health_status))]
                ['Status         : ' char(string(row.status))]
                ['Total size     : ' localHumanBytes(row.total_bytes)]
                ['Locations      : ' num2str(locationCount)]
                ['Resolved MAT   : ' localTextOr(projectMatPath, '<not resolved>')]
                ['Resolution     : ' localTextOr(localStructField(resolutionInfo, 'resolutionMethod'), '<none>')]
                ' '
                ['Metadata MAT   : ' localTextOr(localHubMetadataField(projectDetail, 'project_mat_abs'), '<none>')]
                ['Metadata Dir   : ' localTextOr(localHubMetadataField(projectDetail, 'project_dir_abs'), '<none>')]
                };
        catch ME
            detailsArea.Value = {
                'Source         : hub API'
                ['Project id     : ' char(string(row.project_id))]
                ['Name           : ' char(string(row.name))]
                ['Health         : ' char(string(row.health_status))]
                ' '
                ['Detail fetch failed: ' ME.message]
                };
        end
    end

    function row = getSelectedProjectRow()
        row = [];
        if isempty(state.selectedRow)
            return;
        end
        if isempty(state.projects) || height(state.projects) < state.selectedRow
            return;
        end
        row = state.projects(state.selectedRow, :);
    end

    function [projectDetail, projectMatPath, resolutionInfo] = resolveSelectedHubProject()
        row = getSelectedProjectRow();
        if isempty(row)
            error('No project selected.');
        end
        projectDetail = detecdiv_hub_get_project(char(string(row.project_id)), state.hubSettings);
        [projectMatPath, resolutionInfo] = detecdiv_hub_resolve_project_location(projectDetail, state.hubSettings);
    end

    function syncUiFromState()
        if strcmp(state.sourceMode, 'local')
            rootLabel.Text = 'Project Root';
            rootEdit.Value = char(string(state.catalogSettings.defaultProjectRoot));
            sourceInfoLabel.Text = ['DB: ' char(string(state.catalogSettings.dbFile))];
        else
            rootLabel.Text = 'Hub Root';
            rootEdit.Value = char(string(state.hubSettings.defaultRemoteProjectRoot));
            sourceInfoLabel.Text = ['Hub: ' char(string(state.hubSettings.baseUrl))];
        end

        baseUrlEdit.Value = char(string(state.hubSettings.baseUrl));
        localMountEdit.Value = char(string(state.hubSettings.defaultLocalProjectRoot));
        sourceDropDown.Value = state.sourceMode;
        backgroundCheck.Value = logical(state.catalogSettings.backgroundIndexing);
        backgroundCheck.Enable = onOff(strcmp(state.sourceMode, 'local'));
        baseUrlEdit.Editable = onOff(strcmp(state.sourceMode, 'hub'));
        localMountEdit.Editable = onOff(strcmp(state.sourceMode, 'hub'));
    end

    function setBusyState(tf)
        indexButton.Enable = onOff(~tf);
        refreshButton.Enable = 'on';
        browseButton.Enable = onOff(~tf);
        saveRootButton.Enable = onOff(~tf);
        backgroundCheck.Enable = onOff(strcmp(state.sourceMode, 'local') && ~tf);
        sourceDropDown.Enable = onOff(~tf);
        rootEdit.Editable = onOff(~tf);
        baseUrlEdit.Editable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        localMountEdit.Editable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
    end

    function setStatus(msg)
        if isvalid(fig)
            statusLabel.Text = char(string(msg));
            drawnow limitrate;
        end
    end

    function onCloseFigure(~, ~)
        stopPollingTimer();
        if ~isempty(state.job) && isvalidJob(state.job)
            try
                cancel(state.job);
            catch
            end
            cleanupFinishedJob();
        end
        delete(fig);
    end

    function stopPollingTimer()
        if isempty(state.pollTimer)
            return;
        end
        try
            stop(state.pollTimer);
        catch
        end
        try
            delete(state.pollTimer);
        catch
        end
        state.pollTimer = [];
    end

    function rootPath = sanitizeRoot(rootValue, varargin)
        ipRoot = inputParser;
        ipRoot.addParameter('RequireExisting', true, @(x)islogical(x) || isnumeric(x));
        ipRoot.parse(varargin{:});

        rootPath = strtrim(char(string(rootValue)));
        if isempty(rootPath)
            rootPath = '';
            return;
        end
        try
            if logical(ipRoot.Results.RequireExisting) || isfolder(rootPath)
                rootPath = char(java.io.File(rootPath).getCanonicalPath());
            end
        catch
        end
        if logical(ipRoot.Results.RequireExisting) && ~isfolder(rootPath)
            rootPath = '';
        end
    end

    function roots = updateRecentRoots(roots, newRoot)
        roots = cellstr(string(roots));
        newRoot = char(string(newRoot));
        roots = roots(~strcmpi(roots, newRoot));
        roots = [{newRoot} roots(:)'];
        if numel(roots) > 10
            roots = roots(1:10);
        end
    end

    function cleanupFinishedJob()
        if isempty(state.job)
            return;
        end
        try
            delete(state.job);
        catch
        end
        state.job = [];
    end

    function flag = isvalidJob(job)
        flag = false;
        try
            flag = ~isempty(job) && isvalid(job);
        catch
            flag = ~isempty(job);
        end
    end

    function openPath(targetPath)
        if ~exist(targetPath, 'file') && ~exist(targetPath, 'dir')
            uialert(fig, ['Path not found: ' targetPath], 'Open Failed');
            return;
        end

        try
            if ispc
                winopen(targetPath);
            elseif ismac
                system(['open "' targetPath '"']);
            else
                system(['xdg-open "' targetPath '" &']);
            end
        catch ME
            uialert(fig, ME.message, 'Open Failed');
        end
    end

    function value = onOff(tf)
        if tf
            value = 'on';
        else
            value = 'off';
        end
    end
end

function mode = localNormalizeSourceMode(mode)
    mode = lower(strtrim(char(string(mode))));
    if ~ismember(mode, {'local', 'hub'})
        mode = 'local';
    end
end

function projects = localNormalizeLocalProjects(projects)
    if isempty(projects)
        projects = table();
        return;
    end
    projects.project_id = repmat("", height(projects), 1);
    projects.status = repmat("indexed", height(projects), 1);
end

function projects = localNormalizeHubProjects(items)
    if isempty(items)
        projects = table();
        return;
    end

    if isstruct(items)
        items = num2cell(items);
    end

    n = numel(items);
    names = strings(n, 1);
    projectIds = strings(n, 1);
    statuses = strings(n, 1);
    health = strings(n, 1);
    mats = strings(n, 1);
    dirs = strings(n, 1);
    relPaths = strings(n, 1);
    matBytes = zeros(n, 1);
    dirBytes = zeros(n, 1);
    totalBytes = zeros(n, 1);

    for i = 1:n
        item = items{i};
        metadata = struct();
        if isfield(item, 'metadata_json') && isstruct(item.metadata_json)
            metadata = item.metadata_json;
        end

        names(i) = string(localStructField(item, 'project_name'));
        projectIds(i) = string(localStructField(item, 'id'));
        statuses(i) = string(localStructField(item, 'status'));
        health(i) = string(localStructField(item, 'health_status'));
        mats(i) = string(localStructField(metadata, 'project_mat_abs'));
        dirs(i) = string(localStructField(metadata, 'project_dir_abs'));
        relPaths(i) = string(localStructField(metadata, 'project_rel_from_root'));
        matBytes(i) = localNumericField(item, 'project_mat_bytes');
        dirBytes(i) = localNumericField(item, 'project_dir_bytes');
        totalBytes(i) = localNumericField(item, 'total_bytes');
    end

    projects = table();
    projects.project_id = projectIds;
    projects.name = names;
    projects.status = statuses;
    projects.health_status = health;
    projects.raw_status = repmat("unknown", n, 1);
    projects.fov_count = nan(n, 1);
    projects.roi_count = nan(n, 1);
    projects.classifier_count = nan(n, 1);
    projects.processor_count = nan(n, 1);
    projects.pipeline_run_count = nan(n, 1);
    projects.missing_raw_count = nan(n, 1);
    projects.last_scan_at = repmat("", n, 1);
    projects.project_mat_abs = mats;
    projects.project_dir_abs = dirs;
    projects.root_abs_path = repmat("", n, 1);
    projects.project_rel_from_root = relPaths;
    projects.project_mat_bytes = matBytes;
    projects.project_dir_bytes = dirBytes;
    projects.total_bytes = totalBytes;
end

function displayTable = localBuildDisplayTable(projects, sourceMode)
    if isempty(projects)
        displayTable = table();
        return;
    end

    displayTable = table();
    displayTable.Name = string(projects.name);
    displayTable.Loaded = localLoadedLabels(projects);
    displayTable.Health = string(projects.health_status);
    displayTable.Status = string(projects.status);
    if strcmp(sourceMode, 'local')
        displayTable.FOV = projects.fov_count;
        displayTable.ROI = projects.roi_count;
        displayTable.Runs = projects.pipeline_run_count;
        displayTable.MissingRaw = projects.missing_raw_count;
    else
        displayTable.SizeGB = round(double(projects.total_bytes) ./ 1e9, 2);
    end
    displayTable.RelativePath = string(projects.project_rel_from_root);
end

function value = localStructField(in, fieldName)
    value = '';
    if isstruct(in) && isfield(in, fieldName)
        value = in.(fieldName);
    end
end

function value = localNumericField(in, fieldName)
    value = 0;
    if isstruct(in) && isfield(in, fieldName) && ~isempty(in.(fieldName))
        value = double(in.(fieldName));
    end
end

function value = localHubMetadataField(projectDetail, fieldName)
    value = '';
    if ~isstruct(projectDetail) || ~isfield(projectDetail, 'metadata_json') || ...
            ~isstruct(projectDetail.metadata_json)
        return;
    end
    value = localStructField(projectDetail.metadata_json, fieldName);
end

function out = localTextOr(in, fallback)
    txt = char(string(in));
    if isempty(txt)
        out = fallback;
    else
        out = txt;
    end
end

function out = localHumanBytes(value)
    value = double(value);
    units = {'B', 'KB', 'MB', 'GB', 'TB'};
    idx = 1;
    while value >= 1024 && idx < numel(units)
        value = value / 1024;
        idx = idx + 1;
    end
    out = sprintf('%.2f %s', value, units{idx});
end

function labels = localLoadedLabels(projects)
    if isempty(projects)
        labels = strings(0, 1);
        return;
    end

    labels = strings(height(projects), 1);
    for i = 1:height(projects)
        labels(i) = string(localYesNo(localProjectLoadedPath(char(string(projects.project_mat_abs(i))))));
    end
end

function txt = localYesNo(tf)
    if tf
        txt = 'loaded';
    else
        txt = '';
    end
end

function tf = localProjectLoadedPath(projectMatPath)
    tf = false;
    projectMatPath = char(string(projectMatPath));
    if isempty(projectMatPath)
        return;
    end

    [pathstr, namestr, ext] = fileparts(projectMatPath);
    if isempty(ext)
        ext = '.mat';
    end
    expectedPath = localNormalizeLoadedPath(pathstr);
    expectedFile = lower([namestr ext]);

    try
        varlist = evalin('base', 'who');
    catch
        return;
    end

    for i = 1:numel(varlist)
        varName = varlist{i};
        if strcmp(varName, 'ans')
            continue;
        end

        try
            tmp = evalin('base', varName);
        catch
            continue;
        end

        if ~isa(tmp, 'shallow') || ~isprop(tmp, 'io') || ~isfield(tmp.io, 'path') || ~isfield(tmp.io, 'file')
            continue;
        end

        loadedPath = localNormalizeLoadedPath(tmp.io.path);
        loadedFile = lower([char(string(tmp.io.file)) '.mat']);
        if strcmp(loadedPath, expectedPath) && strcmp(loadedFile, expectedFile)
            tf = true;
            return;
        end
    end
end

function out = localNormalizeLoadedPath(pathIn)
    out = regexprep(lower(strrep(char(string(pathIn)), '\', '/')), '/+$', '');
end
