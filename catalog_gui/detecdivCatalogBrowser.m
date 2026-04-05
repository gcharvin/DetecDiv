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

    repoDir = fileparts(fileparts(mfilename('fullpath')));
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
    state.currentUser = struct();
    state.hubGroups = struct([]);
    state.hubSelectedGroupId = '';
    state.hubOwnedOnly = false;

    fig = uifigure( ...
        'Name', 'DetecDiv Catalog Browser', ...
        'Position', [100 100 1320 800], ...
        'Color', [0.98 0.98 0.98], ...
        'CloseRequestFcn', @onCloseFigure);

    mainGrid = uigridlayout(fig, [4 1]);
    mainGrid.RowHeight = {154, 28, '1x', 38};
    mainGrid.ColumnWidth = {'1x'};
    mainGrid.Padding = [14 14 14 14];
    mainGrid.RowSpacing = 10;

    controlGrid = uigridlayout(mainGrid, [4 11]);
    controlGrid.Layout.Row = 1;
    controlGrid.RowHeight = {24, 32, 32, 32};
    controlGrid.ColumnWidth = {78, 120, 65, '1x', 70, '1x', 85, 110, 95, 95, 105};
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

    userKeyLabel = uilabel(controlGrid, 'Text', 'User', 'FontWeight', 'bold');
    userKeyLabel.Layout.Row = 1;
    userKeyLabel.Layout.Column = 3;

    userKeyEdit = uieditfield(controlGrid, 'text', 'Value', state.hubSettings.userKey);
    userKeyEdit.Layout.Row = 1;
    userKeyEdit.Layout.Column = 4;

    currentUserTitleLabel = uilabel(controlGrid, 'Text', 'Current', 'FontWeight', 'bold');
    currentUserTitleLabel.Layout.Row = 1;
    currentUserTitleLabel.Layout.Column = 5;

    currentUserLabel = uilabel(controlGrid, ...
        'Text', '', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic');
    currentUserLabel.Layout.Row = 1;
    currentUserLabel.Layout.Column = [6 8];

    loginButton = uibutton(controlGrid, 'push', 'Text', 'Login...', ...
        'ButtonPushedFcn', @onHubLogin);
    loginButton.Layout.Row = 1;
    loginButton.Layout.Column = 9;

    logoutButton = uibutton(controlGrid, 'push', 'Text', 'Logout', ...
        'ButtonPushedFcn', @onHubLogout);
    logoutButton.Layout.Row = 1;
    logoutButton.Layout.Column = 10;

    backgroundCheck = uicheckbox(controlGrid, ...
        'Text', 'BG index', ...
        'Value', logical(state.catalogSettings.backgroundIndexing));
    backgroundCheck.Layout.Row = 1;
    backgroundCheck.Layout.Column = 11;

    baseUrlLabel = uilabel(controlGrid, 'Text', 'Hub URL', 'FontWeight', 'bold');
    baseUrlLabel.Layout.Row = 2;
    baseUrlLabel.Layout.Column = 1;

    baseUrlEdit = uieditfield(controlGrid, 'text', 'Value', state.hubSettings.baseUrl);
    baseUrlEdit.Layout.Row = 2;
    baseUrlEdit.Layout.Column = [2 6];

    localMountLabel = uilabel(controlGrid, 'Text', 'Local Mount', 'FontWeight', 'bold');
    localMountLabel.Layout.Row = 2;
    localMountLabel.Layout.Column = 7;

    localMountEdit = uieditfield(controlGrid, 'text', 'Value', state.hubSettings.defaultLocalProjectRoot);
    localMountEdit.Layout.Row = 2;
    localMountEdit.Layout.Column = [8 11];

    rootLabel = uilabel(controlGrid, 'Text', '', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    rootLabel.Layout.Row = 3;
    rootLabel.Layout.Column = 1;

    rootEdit = uieditfield(controlGrid, 'text');
    rootEdit.Layout.Row = 3;
    rootEdit.Layout.Column = [2 6];

    browseButton = uibutton(controlGrid, 'push', 'Text', 'Browse...', ...
        'ButtonPushedFcn', @onBrowseRoot);
    browseButton.Layout.Row = 3;
    browseButton.Layout.Column = 7;

    saveRootButton = uibutton(controlGrid, 'push', 'Text', 'Save Config', ...
        'ButtonPushedFcn', @onSaveConfiguration);
    saveRootButton.Layout.Row = 3;
    saveRootButton.Layout.Column = 8;

    indexButton = uibutton(controlGrid, 'push', 'Text', 'Index Root', ...
        'ButtonPushedFcn', @onIndexRoot);
    indexButton.Layout.Row = 3;
    indexButton.Layout.Column = 9;

    refreshButton = uibutton(controlGrid, 'push', 'Text', 'Refresh', ...
        'ButtonPushedFcn', @onRefreshProjects);
    refreshButton.Layout.Row = 3;
    refreshButton.Layout.Column = 10;

    groupLabel = uilabel(controlGrid, 'Text', 'Group', 'FontWeight', 'bold');
    groupLabel.Layout.Row = 4;
    groupLabel.Layout.Column = 1;

    groupDropDown = uidropdown(controlGrid, ...
        'Items', {'All projects'}, ...
        'ItemsData', {''}, ...
        'Value', '', ...
        'ValueChangedFcn', @onGroupFilterChanged);
    groupDropDown.Layout.Row = 4;
    groupDropDown.Layout.Column = [2 5];

    ownedOnlyCheck = uicheckbox(controlGrid, ...
        'Text', 'Owned only', ...
        'Value', false, ...
        'ValueChangedFcn', @onOwnedOnlyChanged);
    ownedOnlyCheck.Layout.Row = 4;
    ownedOnlyCheck.Layout.Column = 6;

    refreshGroupsButton = uibutton(controlGrid, 'push', 'Text', 'Groups', ...
        'ButtonPushedFcn', @onRefreshGroups);
    refreshGroupsButton.Layout.Row = 4;
    refreshGroupsButton.Layout.Column = 7;

    addToGroupButton = uibutton(controlGrid, 'push', 'Text', 'Add To Group', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onAddToGroup);
    addToGroupButton.Layout.Row = 4;
    addToGroupButton.Layout.Column = 8;

    newGroupButton = uibutton(controlGrid, 'push', 'Text', 'New Group', ...
        'ButtonPushedFcn', @onCreateGroup);
    newGroupButton.Layout.Row = 4;
    newGroupButton.Layout.Column = 9;

    sourceInfoLabel = uilabel(controlGrid, ...
        'Text', '', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic');
    sourceInfoLabel.Layout.Row = 4;
    sourceInfoLabel.Layout.Column = 10;

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
    sideGrid.RowHeight = {24, '1x', 116};
    sideGrid.RowSpacing = 8;
    sideGrid.Padding = [0 0 0 0];

    uilabel(sideGrid, 'Text', 'Project Details', 'FontWeight', 'bold');

    detailsArea = uitextarea(sideGrid, ...
        'Editable', 'off', ...
        'Value', {'No project selected.'}, ...
        'FontName', 'Consolas');
    detailsArea.Layout.Row = 2;

    actionGrid = uigridlayout(sideGrid, [3 3]);
    actionGrid.Layout.Row = 3;
    actionGrid.ColumnWidth = {'1x', '1x', '1x'};
    actionGrid.RowHeight = {32, 32, 32};
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

    runLocalButton = uibutton(actionGrid, 'push', 'Text', 'Run locally...', ...
        'Enable', 'off', 'ButtonPushedFcn', @onRunLocally);
    runLocalButton.Layout.Row = 1;
    runLocalButton.Layout.Column = 3;

    submitRunButton = uibutton(actionGrid, 'push', 'Text', 'Submit to hub...', ...
        'Enable', 'off', 'ButtonPushedFcn', @onSubmitRunToHub);
    submitRunButton.Layout.Row = 2;
    submitRunButton.Layout.Column = 1;

    notesButton = uibutton(actionGrid, 'push', 'Text', 'Notes...', ...
        'Enable', 'off', 'ButtonPushedFcn', @onManageNotes);
    notesButton.Layout.Row = 2;
    notesButton.Layout.Column = 2;

    groupButton = uibutton(actionGrid, 'push', 'Text', 'Group...', ...
        'Enable', 'off', 'ButtonPushedFcn', @onAddToGroup);
    groupButton.Layout.Row = 2;
    groupButton.Layout.Column = 3;

    aclButton = uibutton(actionGrid, 'push', 'Text', 'Share...', ...
        'Enable', 'off', 'ButtonPushedFcn', @onManageAcl);
    aclButton.Layout.Row = 3;
    aclButton.Layout.Column = 1;

    deleteButton = uibutton(actionGrid, 'push', 'Text', 'Delete...', ...
        'Enable', 'off', 'ButtonPushedFcn', @onPreviewDelete);
    deleteButton.Layout.Row = 3;
    deleteButton.Layout.Column = 2;

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

    function onHubLogin(~, ~)
        if ~strcmp(state.sourceMode, 'hub')
            return;
        end

        [userKey, password] = localPromptHubCredentials(userKeyEdit.Value);
        if isempty(userKey) || isempty(password)
            return;
        end

        state.hubSettings.baseUrl = strtrim(baseUrlEdit.Value);
        try
            [sessionInfo, state.hubSettings] = detecdiv_hub_login(userKey, password, state.hubSettings); %#ok<NASGU>
            userKeyEdit.Value = state.hubSettings.userKey;
            refreshProjectsTable();
            setStatus(sprintf('Hub session opened for %s.', state.hubSettings.userKey));
        catch ME
            uialert(fig, ME.message, 'Hub Login Failed');
            setStatus(['Hub login failed: ' ME.message]);
        end
    end

    function onHubLogout(~, ~)
        if ~strcmp(state.sourceMode, 'hub')
            return;
        end

        try
            state.hubSettings = detecdiv_hub_logout(state.hubSettings);
            state.currentUser = struct();
            syncUiFromState();
            refreshProjectsTable('PreserveStatus', true);
            setStatus('Hub session cleared.');
        catch ME
            uialert(fig, ME.message, 'Hub Logout Failed');
            setStatus(['Hub logout failed: ' ME.message]);
        end
    end

    function onGroupFilterChanged(~, ~)
        state.hubSelectedGroupId = char(string(groupDropDown.Value));
        refreshProjectsTable('PreserveStatus', true);
    end

    function onOwnedOnlyChanged(~, ~)
        state.hubOwnedOnly = logical(ownedOnlyCheck.Value);
        refreshProjectsTable('PreserveStatus', true);
    end

    function onRefreshGroups(~, ~)
        if ~strcmp(state.sourceMode, 'hub')
            return;
        end
        try
            refreshHubContext();
            setStatus(sprintf('Loaded %d project group(s) for %s.', ...
                numel(state.hubGroups), localCurrentUserLabel()));
        catch ME
            uialert(fig, ME.message, 'Group Refresh Failed');
            setStatus(['Group refresh failed: ' ME.message]);
        end
    end

    function onCreateGroup(~, ~)
        if ~strcmp(state.sourceMode, 'hub')
            return;
        end

        answer = inputdlg( ...
            {'Display name', 'Group key', 'Description'}, ...
            'Create Project Group', ...
            [1 60; 1 60; 3 60], ...
            {'', '', ''});
        if isempty(answer)
            return;
        end

        displayName = strtrim(answer{1});
        groupKey = strtrim(answer{2});
        description = strtrim(answer{3});
        if isempty(displayName)
            uialert(fig, 'The group display name cannot be empty.', 'Invalid Group');
            return;
        end
        if isempty(groupKey)
            groupKey = matlab.lang.makeValidName(lower(displayName));
        end

        try
            group = detecdiv_hub_create_project_group(groupKey, displayName, description, state.hubSettings);
            refreshHubContext();
            groupDropDown.Value = char(string(group.id));
            state.hubSelectedGroupId = groupDropDown.Value;
            refreshProjectsTable('PreserveStatus', true);
            setStatus(sprintf('Created project group "%s".', displayName));
        catch ME
            uialert(fig, ME.message, 'Create Group Failed');
        end
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
        state.hubSettings.userKey = strtrim(userKeyEdit.Value);
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
        state.hubSettings.userKey = strtrim(userKeyEdit.Value);
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

    function onRunLocally(~, ~)
        row = getSelectedProjectRow();
        if isempty(row)
            return;
        end

        try
            [shallowObj, projectMatPath] = ensureProjectLoadedForRun(row); %#ok<ASGLU>
            [pipeObj, jsonPath] = resolvePipelineForRun(shallowObj); %#ok<ASGLU>
            if isempty(pipeObj)
                uialert(fig, 'No pipeline could be resolved for this project.', 'Run Failed');
                return;
            end
            pipelineRunGUI(pipeObj, shallowObj);
            setStatus(sprintf('Opened local run builder for "%s".', char(string(row.name))));
        catch ME
            uialert(fig, ME.message, 'Run Failed');
            setStatus(['Local run failed: ' ME.message]);
        end
    end

    function onSubmitRunToHub(~, ~)
        row = getSelectedProjectRow();
        if isempty(row) || ~strcmp(state.sourceMode, 'hub')
            return;
        end

        try
            pipelines = detecdiv_hub_list_pipelines(state.hubSettings, 'IncludeObserved', true);
            if isempty(pipelines)
                uialert(fig, 'No hub pipelines are available.', 'Submit Failed');
                return;
            end

            targets = detecdiv_hub_list_execution_targets(state.hubSettings);
            runDraft = localPromptHubPipelineRun(pipelines, targets);
            if isempty(runDraft)
                return;
            end
            pipelineInfo = runDraft.pipeline;
            targetInfo = runDraft.target;
            nodeParams = runDraft.nodeParams;

            [projectDetail, projectMatPath] = resolveSelectedHubProject();
            projectRef = struct( ...
                'project_id', char(string(row.project_id)), ...
                'project_key', char(string(localStructField(projectDetail, 'project_key'))), ...
                'project_mat_path', char(string(projectMatPath)));
            pipelineRef = localPipelineRefForSubmission(pipelineInfo);

            payload = struct();
            payload.project_id = char(string(row.project_id));
            if ~isempty(pipelineInfo.id)
                payload.pipeline_id = char(string(pipelineInfo.id));
            end
            if ~isempty(targetInfo) && isstruct(targetInfo) && isfield(targetInfo, 'id') && ~isempty(targetInfo.id)
                payload.execution_target_id = char(string(targetInfo.id));
            end
            payload.requested_mode = runDraft.requestedMode;
            payload.priority = max(0, round(runDraft.priority));
            if isnan(payload.priority)
                payload.priority = 100;
            end
            payload.requested_by = char(string(state.hubSettings.userKey));
            payload.requested_from_host = localHostName();
            payload.project_ref = projectRef;
            payload.pipeline_ref = pipelineRef;
            payload.run_request = struct( ...
                'run_id', runDraft.runId, ...
                'description', runDraft.description, ...
                'selected_nodes', runDraft.selectedNodes, ...
                'node_params', nodeParams, ...
                'run_policy', runDraft.runPolicy, ...
                'existing_data_policy', runDraft.existingPolicy, ...
                'roi_cache_policy', runDraft.cachePolicy, ...
                'python', struct( ...
                    'mode', runDraft.pythonMode, ...
                    'env_name', runDraft.pythonEnv), ...
                'gpu', struct('mode', runDraft.gpuMode));
            payload.execution = struct('allow_gui', false);

            job = detecdiv_hub_create_pipeline_run(payload, state.hubSettings);
            setStatus(sprintf('Queued hub run %s for "%s".', char(string(localStructField(job, 'id'))), char(string(row.name))));
        catch ME
            uialert(fig, ME.message, 'Submit Failed');
            setStatus(['Hub submission failed: ' ME.message]);
        end
    end

    function onAddToGroup(~, ~)
        row = getSelectedProjectRow();
        if isempty(row) || ~strcmp(state.sourceMode, 'hub')
            return;
        end

        try
            if isempty(state.hubGroups)
                refreshHubContext();
            end
            if isempty(state.hubGroups)
                onCreateGroup();
                if isempty(state.hubGroups)
                    return;
                end
            end

            groupItems = cell(numel(state.hubGroups), 1);
            groupIds = cell(numel(state.hubGroups), 1);
            for i = 1:numel(state.hubGroups)
                groupItems{i} = char(string(state.hubGroups(i).display_name));
                groupIds{i} = char(string(state.hubGroups(i).id));
            end

            [selectedIdx, ok] = listdlg( ...
                'PromptString', 'Select a project group', ...
                'SelectionMode', 'single', ...
                'ListString', groupItems, ...
                'ListSize', [320 220]);
            if ~ok || isempty(selectedIdx)
                return;
            end

            detecdiv_hub_add_project_to_group(groupIds{selectedIdx}, char(string(row.project_id)), state.hubSettings);
            refreshProjectsTable('PreserveStatus', true);
            setStatus(sprintf('Added "%s" to group "%s".', ...
                char(string(row.name)), groupItems{selectedIdx}));
        catch ME
            uialert(fig, ME.message, 'Group Update Failed');
        end
    end

    function onManageNotes(~, ~)
        row = getSelectedProjectRow();
        if isempty(row) || ~strcmp(state.sourceMode, 'hub')
            return;
        end

        try
            notes = detecdiv_hub_list_project_notes(char(string(row.project_id)), state.hubSettings);
            noteSummary = localFormatNotes(notes);
            answer = inputdlg( ...
                {sprintf('Existing notes for %s', char(string(row.name))), 'New note (leave empty to only review)', 'Pin new note (0/1)'}, ...
                'Project Notes', ...
                [12 80; 6 80; 1 8], ...
                {noteSummary, '', '0'});
            if isempty(answer)
                return;
            end

            newNote = strtrim(answer{2});
            if isempty(newNote)
                setStatus(sprintf('Reviewed %d note(s) for "%s".', numel(localEnsureStructArray(notes)), char(string(row.name))));
                return;
            end

            isPinned = strcmpi(strtrim(answer{3}), '1') || strcmpi(strtrim(answer{3}), 'true');
            detecdiv_hub_create_project_note(char(string(row.project_id)), newNote, isPinned, state.hubSettings);
            updateSelectionState();
            setStatus(sprintf('Added note to "%s".', char(string(row.name))));
        catch ME
            uialert(fig, ME.message, 'Notes Failed');
        end
    end

    function onManageAcl(~, ~)
        row = getSelectedProjectRow();
        if isempty(row) || ~strcmp(state.sourceMode, 'hub')
            return;
        end

        try
            aclEntries = detecdiv_hub_list_project_acl(char(string(row.project_id)), state.hubSettings);
            aclSummary = localFormatAclEntries(aclEntries);
            answer = inputdlg( ...
                {sprintf('Existing access for %s', char(string(row.name))), 'Share with user key', 'Access level (viewer/editor)'}, ...
                'Project Access', ...
                [10 80; 1 32; 1 20], ...
                {aclSummary, '', 'viewer'});
            if isempty(answer)
                return;
            end

            targetUserKey = strtrim(answer{2});
            if isempty(targetUserKey)
                setStatus(sprintf('Reviewed ACL for "%s".', char(string(row.name))));
                return;
            end

            accessLevel = lower(strtrim(answer{3}));
            if ~ismember(accessLevel, {'viewer', 'editor'})
                uialert(fig, 'Access level must be "viewer" or "editor".', 'Invalid Access Level');
                return;
            end

            detecdiv_hub_create_project_acl(char(string(row.project_id)), targetUserKey, accessLevel, state.hubSettings);
            updateSelectionState();
            setStatus(sprintf('Granted %s access on "%s" to %s.', ...
                accessLevel, char(string(row.name)), targetUserKey));
        catch ME
            uialert(fig, ME.message, 'ACL Update Failed');
        end
    end

    function onPreviewDelete(~, ~)
        row = getSelectedProjectRow();
        if isempty(row) || ~strcmp(state.sourceMode, 'hub')
            return;
        end

        deleteChoices = {'DB Only', 'Delete Project Files', 'Cancel'};
        choice = questdlg( ...
            sprintf('How do you want to remove "%s"?', char(string(row.name))), ...
            'Delete Project', ...
            deleteChoices{:}, ...
            'Cancel');
        if isempty(choice) || strcmp(choice, 'Cancel')
            return;
        end

        deleteProjectFiles = strcmp(choice, 'Delete Project Files');

        try
            preview = detecdiv_hub_preview_project_deletion( ...
                char(string(row.project_id)), state.hubSettings, ...
                'DeleteProjectFiles', deleteProjectFiles, ...
                'DeleteLinkedRawData', false);
            previewText = localFormatDeletionPreview(preview);
            confirmChoice = questdlg( ...
                sprintf('%s\n\nContinue?', previewText), ...
                'Confirm Project Deletion', ...
                'Delete', 'Cancel', 'Cancel');
            if ~strcmp(confirmChoice, 'Delete')
                return;
            end

            detecdiv_hub_delete_project( ...
                char(string(row.project_id)), state.hubSettings, ...
                'DeleteProjectFiles', deleteProjectFiles, ...
                'DeleteLinkedRawData', false, ...
                'Confirm', true);
            refreshProjectsTable();
            setStatus(sprintf('Deleted project "%s".', char(string(row.name))));
        catch ME
            uialert(fig, ME.message, 'Delete Failed');
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
            state.hubSettings.userKey = strtrim(userKeyEdit.Value);
            detecdiv_hub_settings_set(state.hubSettings);
            refreshHubContext();
            projects = localNormalizeHubProjects(detecdiv_hub_list_projects( ...
                state.hubSettings, ...
                'GroupId', state.hubSelectedGroupId, ...
                'OwnedOnly', state.hubOwnedOnly));
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
        runLocalButton.Enable = onOff(hasRow);
        submitRunButton.Enable = onOff(hasRow && strcmp(state.sourceMode, 'hub'));
        notesButton.Enable = onOff(hasRow && strcmp(state.sourceMode, 'hub'));
        groupButton.Enable = onOff(hasRow && strcmp(state.sourceMode, 'hub'));
        aclButton.Enable = onOff(hasRow && strcmp(state.sourceMode, 'hub'));
        deleteButton.Enable = onOff(hasRow && strcmp(state.sourceMode, 'hub'));
        addToGroupButton.Enable = onOff(hasRow && strcmp(state.sourceMode, 'hub'));

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
            notes = detecdiv_hub_list_project_notes(char(string(row.project_id)), state.hubSettings);
            aclEntries = detecdiv_hub_list_project_acl(char(string(row.project_id)), state.hubSettings);
            groups = detecdiv_hub_list_project_groups_for_project(char(string(row.project_id)), state.hubSettings);
            locationCount = 0;
            if isstruct(projectDetail) && isfield(projectDetail, 'locations')
                locationCount = numel(projectDetail.locations);
            end
            ownerLabel = localOwnerLabel(projectDetail);
            detailsArea.Value = {
                'Source         : hub API'
                ['Project id     : ' char(string(row.project_id))]
                ['Name           : ' char(string(row.name))]
                ['Loaded         : ' localYesNo(localProjectLoadedPath(projectMatPath))]
                ['Owner          : ' ownerLabel]
                ['Visibility     : ' char(string(localStructField(projectDetail, 'visibility')))]
                ['Health         : ' char(string(row.health_status))]
                ['Status         : ' char(string(row.status))]
                ['Total size     : ' localHumanBytes(row.total_bytes)]
                ['Project MAT sz : ' localHumanBytes(row.project_mat_bytes)]
                ['Project Dir sz : ' localHumanBytes(row.project_dir_bytes)]
                ['Notes          : ' num2str(numel(localEnsureStructArray(notes)))]
                ['ACL entries     : ' num2str(numel(localEnsureStructArray(aclEntries)))]
                ['Groups         : ' localJoinedNames(groups, 'display_name')]
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

    function [shallowObj, projectMatPath] = ensureProjectLoadedForRun(row)
        projectMatPath = '';
        if strcmp(state.sourceMode, 'local')
            projectMatPath = char(string(row.project_mat_abs));
        else
            [~, projectMatPath] = resolveSelectedHubProject();
        end
        if isempty(projectMatPath)
            error('Could not resolve the project MAT path.');
        end

        shallowObj = localFindLoadedProjectByMatPath(projectMatPath);
        if isempty(shallowObj)
            [shallowObj, msg] = shallowLoad(projectMatPath);
            if isempty(shallowObj)
                error('%s', msg);
            end
            try
                assignin('base', matlab.lang.makeValidName(char(string(shallowObj.io.file))), shallowObj);
            catch
            end
        end
    end

    function [pipeObj, jsonPath] = resolvePipelineForRun(shallowObj)
        pipeObj = [];
        jsonPath = localProjectDefaultPipelinePath(shallowObj);
        if isempty(jsonPath)
            [fileName, folderName] = uigetfile({'*.json', 'Pipeline JSON (*.json)'}, ...
                'Select a pipeline JSON');
            if isequal(fileName, 0)
                return;
            end
            jsonPath = fullfile(folderName, fileName);
        end

        [pipeObj, msg] = pipelineLoad(jsonPath);
        if isempty(pipeObj)
            error('%s', msg);
        end
    end

    function refreshHubContext()
        if ~strcmp(state.sourceMode, 'hub')
            state.currentUser = struct();
            state.hubGroups = struct([]);
            syncGroupDropDown();
            if isvalid(fig)
                currentUserLabel.Text = localCurrentUserLabel();
            end
            return;
        end

        state.currentUser = detecdiv_hub_get_current_user(state.hubSettings);
        groups = detecdiv_hub_list_project_groups(state.hubSettings);
        state.hubGroups = localEnsureStructArray(groups);
        syncGroupDropDown();
        if isvalid(fig)
            currentUserLabel.Text = localCurrentUserLabel();
        end
    end

    function syncGroupDropDown()
        items = {'All projects'};
        itemsData = {''};
        for i = 1:numel(state.hubGroups)
            items{end + 1} = char(string(state.hubGroups(i).display_name)); %#ok<AGROW>
            itemsData{end + 1} = char(string(state.hubGroups(i).id)); %#ok<AGROW>
        end
        groupDropDown.Items = items;
        groupDropDown.ItemsData = itemsData;
        if isempty(state.hubSelectedGroupId) || ~any(strcmp(itemsData, state.hubSelectedGroupId))
            state.hubSelectedGroupId = '';
        end
        groupDropDown.Value = state.hubSelectedGroupId;
        ownedOnlyCheck.Value = logical(state.hubOwnedOnly);
    end

    function syncUiFromState()
        isLocal = strcmp(state.sourceMode, 'local');
        if isLocal
            rootLabel.Text = 'Project Root';
            rootEdit.Value = char(string(state.catalogSettings.defaultProjectRoot));
            sourceInfoLabel.Text = ['DB: ' char(string(state.catalogSettings.dbFile))];
            footerLabel.Text = 'Local SQLite mode uses only the local DB and local project paths.';
        else
            rootLabel.Text = 'Remote Root';
            rootEdit.Value = char(string(state.hubSettings.defaultRemoteProjectRoot));
            if isempty(state.hubSelectedGroupId)
                sourceInfoLabel.Text = 'Hub listing: all visible projects';
            else
                sourceInfoLabel.Text = 'Hub listing: group filter active';
            end
            footerLabel.Text = ['Hub API mode uses server paths plus local mount mapping for loading .mat files.' ...
                ' Local SQLite mode remains available in the same browser.'];
        end

        baseUrlEdit.Value = char(string(state.hubSettings.baseUrl));
        userKeyEdit.Value = char(string(state.hubSettings.userKey));
        localMountEdit.Value = char(string(state.hubSettings.defaultLocalProjectRoot));
        sourceDropDown.Value = state.sourceMode;
        backgroundCheck.Value = logical(state.catalogSettings.backgroundIndexing);
        backgroundCheck.Enable = onOff(isLocal);
        baseUrlEdit.Editable = onOff(~isLocal);
        localMountEdit.Editable = onOff(~isLocal);
        userKeyEdit.Editable = onOff(~isLocal);
        loginButton.Enable = onOff(~isLocal);
        logoutButton.Enable = onOff(~isLocal);
        groupDropDown.Enable = onOff(~isLocal);
        ownedOnlyCheck.Enable = onOff(~isLocal);
        refreshGroupsButton.Enable = onOff(~isLocal);
        newGroupButton.Enable = onOff(~isLocal);

        controlGrid.RowHeight = localHeaderRowHeights(isLocal);
        localSetVisible(baseUrlLabel, ~isLocal);
        localSetVisible(baseUrlEdit, ~isLocal);
        localSetVisible(localMountLabel, ~isLocal);
        localSetVisible(localMountEdit, ~isLocal);
        localSetVisible(userKeyLabel, ~isLocal);
        localSetVisible(userKeyEdit, ~isLocal);
        localSetVisible(currentUserTitleLabel, ~isLocal);
        localSetVisible(currentUserLabel, ~isLocal);
        localSetVisible(loginButton, ~isLocal);
        localSetVisible(logoutButton, ~isLocal);
        localSetVisible(groupLabel, ~isLocal);
        localSetVisible(groupDropDown, ~isLocal);
        localSetVisible(ownedOnlyCheck, ~isLocal);
        localSetVisible(refreshGroupsButton, ~isLocal);
        localSetVisible(addToGroupButton, ~isLocal);
        localSetVisible(newGroupButton, ~isLocal);

        browseButton.Text = ternaryText(isLocal, 'Browse...', 'Map...');
        sourceLabel.Text = 'Source';
        currentUserLabel.Text = localCurrentUserLabel();
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
        userKeyEdit.Editable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        loginButton.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        logoutButton.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        groupDropDown.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        ownedOnlyCheck.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        refreshGroupsButton.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        newGroupButton.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
    end

    function setStatus(msg)
        if isvalid(fig)
            statusLabel.Text = char(string(msg));
            drawnow limitrate;
        end
    end

    function label = localCurrentUserLabel()
        if strcmp(state.sourceMode, 'local')
            label = 'n/a';
            return;
        end

        if isempty(fieldnames(state.currentUser))
            label = '<not resolved>';
            return;
        end

        displayName = char(string(localStructField(state.currentUser, 'display_name')));
        userKey = char(string(localStructField(state.currentUser, 'user_key')));
        if isempty(displayName)
            label = localTextOr(userKey, '<unknown>');
        elseif isempty(userKey) || strcmp(displayName, userKey)
            label = displayName;
        else
            label = sprintf('%s (%s)', displayName, userKey);
        end
        authMode = char(string(state.hubSettings.authMode));
        if ~isempty(authMode)
            label = sprintf('%s [%s]', label, authMode);
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

function heights = localHeaderRowHeights(isLocal)
    if isLocal
        heights = {24, 0, 32, 0};
    else
        heights = {24, 32, 32, 32};
    end
end

function localSetVisible(component, tf)
    try
        component.Visible = onOff(tf);
    catch
    end
end

function txt = ternaryText(tf, trueText, falseText)
    if tf
        txt = trueText;
    else
        txt = falseText;
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
    visibility = strings(n, 1);
    ownerKeys = strings(n, 1);

    for i = 1:n
        item = items{i};
        metadata = struct();
        if isfield(item, 'metadata_json') && isstruct(item.metadata_json)
            metadata = item.metadata_json;
        end
        owner = struct();
        if isfield(item, 'owner') && isstruct(item.owner)
            owner = item.owner;
        end

        names(i) = string(localStructField(item, 'project_name'));
        projectIds(i) = string(localStructField(item, 'id'));
        statuses(i) = string(localStructField(item, 'status'));
        health(i) = string(localStructField(item, 'health_status'));
        visibility(i) = string(localStructField(item, 'visibility'));
        ownerKeys(i) = string(localStructField(owner, 'user_key'));
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
    projects.visibility = visibility;
    projects.owner_user_key = ownerKeys;
end

function displayTable = localBuildDisplayTable(projects, sourceMode)
    if isempty(projects)
        displayTable = table();
        return;
    end

    displayTable = table();
    displayTable.Name = string(projects.name);
    displayTable.Loaded = localLoadedLabels(projects);
    if ismember('owner_user_key', projects.Properties.VariableNames)
        displayTable.Owner = string(projects.owner_user_key);
    end
    displayTable.Health = string(projects.health_status);
    displayTable.Status = string(projects.status);
    if strcmp(sourceMode, 'local')
        displayTable.FOV = projects.fov_count;
        displayTable.ROI = projects.roi_count;
        displayTable.Runs = projects.pipeline_run_count;
        displayTable.MissingRaw = projects.missing_raw_count;
    else
        displayTable.Visibility = string(projects.visibility);
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

function value = localOwnerLabel(projectDetail)
    value = '<unknown>';
    if ~isstruct(projectDetail) || ~isfield(projectDetail, 'owner') || ~isstruct(projectDetail.owner)
        return;
    end
    owner = projectDetail.owner;
    displayName = char(string(localStructField(owner, 'display_name')));
    userKey = char(string(localStructField(owner, 'user_key')));
    if isempty(displayName)
        value = localTextOr(userKey, '<unknown>');
    elseif isempty(userKey) || strcmp(displayName, userKey)
        value = displayName;
    else
        value = sprintf('%s (%s)', displayName, userKey);
    end
end

function text = localJoinedNames(items, fieldName)
    items = localEnsureStructArray(items);
    if isempty(items)
        text = '<none>';
        return;
    end

    labels = strings(numel(items), 1);
    for i = 1:numel(items)
        labels(i) = string(localStructField(items(i), fieldName));
    end
    labels(labels == "") = [];
    if isempty(labels)
        text = '<none>';
    else
        text = strjoin(cellstr(labels), ', ');
    end
end

function out = localEnsureStructArray(in)
    if isempty(in)
        out = struct([]);
        return;
    end
    if iscell(in)
        if isempty(in)
            out = struct([]);
        else
            out = [in{:}];
        end
        return;
    end
    out = in;
end

function txt = localFormatNotes(notes)
    notes = localEnsureStructArray(notes);
    if isempty(notes)
        txt = '<no notes>';
        return;
    end

    lines = strings(numel(notes), 1);
    for i = 1:numel(notes)
        authorLabel = '<unknown>';
        if isfield(notes(i), 'author') && isstruct(notes(i).author)
            authorLabel = localOwnerLabel(struct('owner', notes(i).author));
        end
        prefix = '';
        if isfield(notes(i), 'is_pinned') && logical(notes(i).is_pinned)
            prefix = '[PIN] ';
        end
        updatedAt = char(string(localStructField(notes(i), 'updated_at')));
        noteText = char(string(localStructField(notes(i), 'note_text')));
        lines(i) = string(sprintf('%s%s | %s | %s', prefix, updatedAt, authorLabel, noteText));
    end
    txt = strjoin(cellstr(lines), newline);
end

function txt = localFormatAclEntries(aclEntries)
    aclEntries = localEnsureStructArray(aclEntries);
    if isempty(aclEntries)
        txt = '<owner only>';
        return;
    end

    lines = strings(numel(aclEntries), 1);
    for i = 1:numel(aclEntries)
        userLabel = '<unknown>';
        if isfield(aclEntries(i), 'user') && isstruct(aclEntries(i).user)
            userLabel = localOwnerLabel(struct('owner', aclEntries(i).user));
        end
        accessLevel = char(string(localStructField(aclEntries(i), 'access_level')));
        lines(i) = string(sprintf('%s | %s', userLabel, accessLevel));
    end
    txt = strjoin(cellstr(lines), newline);
end

function txt = localFormatDeletionPreview(preview)
    previewJson = struct();
    if isstruct(preview) && isfield(preview, 'preview_json') && isstruct(preview.preview_json)
        previewJson = preview.preview_json;
    end
    projectFiles = localCountStructArray(localStructField(previewJson, 'project_file_paths'));
    projectDirs = localCountStructArray(localStructField(previewJson, 'project_directories'));
    rawItems = localCountStructArray(localStructField(previewJson, 'raw_dataset_candidates'));
    txt = sprintf(['Project: %s\n' ...
        'Recoverable: %s\n' ...
        'Project files: %d\n' ...
        'Project folders: %d\n' ...
        'Raw datasets touched: %d'], ...
        char(string(localStructField(preview, 'project_name'))), ...
        localHumanBytes(localNumericField(preview, 'reclaimable_bytes')), ...
        projectFiles, projectDirs, rawItems);
end

function count = localCountStructArray(value)
    if isempty(value)
        count = 0;
        return;
    end
    if isstruct(value)
        count = numel(value);
    elseif iscell(value)
        count = numel(value);
    else
        count = 0;
    end
end

function [userKey, password] = localPromptHubCredentials(defaultUserKey)
    userKey = '';
    password = '';

    dlg = uifigure( ...
        'Name', 'Hub Login', ...
        'Position', [300 300 360 150], ...
        'WindowStyle', 'modal', ...
        'Resize', 'off');
    grid = uigridlayout(dlg, [3 2]);
    grid.RowHeight = {24, 32, 42};
    grid.ColumnWidth = {90, '1x'};
    grid.Padding = [12 12 12 12];

    uilabel(grid, 'Text', 'User key');
    userEdit = uieditfield(grid, 'text', 'Value', char(string(defaultUserKey)));
    userEdit.Layout.Row = 1;
    userEdit.Layout.Column = 2;

    passwordLabel = uilabel(grid, 'Text', 'Password');
    passwordLabel.Layout.Row = 2;
    passwordLabel.Layout.Column = 1;
    passwordEdit = uieditfield(grid, 'text');
    passwordEdit.Layout.Row = 2;
    passwordEdit.Layout.Column = 2;
    passwordEdit.Value = '';

    buttonGrid = uigridlayout(grid, [1 2]);
    buttonGrid.Layout.Row = 3;
    buttonGrid.Layout.Column = [1 2];
    buttonGrid.ColumnWidth = {'1x', '1x'};
    buttonGrid.Padding = [0 0 0 0];

    uibutton(buttonGrid, 'push', 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~, ~) delete(dlg));
    uibutton(buttonGrid, 'push', 'Text', 'Login', ...
        'ButtonPushedFcn', @onSubmit);

    uiwait(dlg);

    function onSubmit(~, ~)
        userKey = strtrim(char(string(userEdit.Value)));
        password = char(string(passwordEdit.Value));
        delete(dlg);
    end
end

function draft = localPromptHubPipelineRun(pipelines, targets)
    draft = struct([]);
    dlg = uifigure( ...
        'Name', 'Submit Pipeline Run To Hub', ...
        'Position', [280 180 760 520], ...
        'WindowStyle', 'modal', ...
        'Resize', 'off');

    grid = uigridlayout(dlg, [8 4]);
    grid.RowHeight = {22, 30, 30, 30, 30, 30, '1x', 42};
    grid.ColumnWidth = {120, '1x', 120, '1x'};
    grid.Padding = [12 12 12 12];
    grid.RowSpacing = 8;
    grid.ColumnSpacing = 10;

    pipelineLabels = cell(numel(pipelines), 1);
    pipelineValues = cell(numel(pipelines), 1);
    for i = 1:numel(pipelines)
        pipelineLabels{i} = localPipelineListLabel(pipelines(i));
        pipelineValues{i} = num2str(i);
    end

    targetLabels = {'<auto target>'};
    targetValues = {'0'};
    for i = 1:numel(targets)
        targetLabels{end + 1} = localExecutionTargetLabel(targets(i)); %#ok<AGROW>
        targetValues{end + 1} = num2str(i); %#ok<AGROW>
    end

    uilabel(grid, 'Text', 'Pipeline', 'FontWeight', 'bold');
    pipelineDropDown = uidropdown(grid, 'Items', pipelineLabels, 'ItemsData', pipelineValues, 'Value', pipelineValues{1});
    pipelineDropDown.Layout.Row = 1;
    pipelineDropDown.Layout.Column = [2 4];

    lbl = uilabel(grid, 'Text', 'Execution target', 'FontWeight', 'bold');
    lbl.Layout.Row = 2;
    lbl.Layout.Column = 1;
    targetDropDown = uidropdown(grid, 'Items', targetLabels, 'ItemsData', targetValues, 'Value', '0');
    targetDropDown.Layout.Row = 2;
    targetDropDown.Layout.Column = 2;

    lbl = uilabel(grid, 'Text', 'Requested mode', 'FontWeight', 'bold');
    lbl.Layout.Row = 2;
    lbl.Layout.Column = 3;
    requestedModeDropDown = uidropdown(grid, 'Items', {'auto', 'server', 'local'}, 'Value', 'auto');
    requestedModeDropDown.Layout.Row = 2;
    requestedModeDropDown.Layout.Column = 4;

    lbl = uilabel(grid, 'Text', 'Run ID', 'FontWeight', 'bold');
    lbl.Layout.Row = 3;
    lbl.Layout.Column = 1;
    runIdEdit = uieditfield(grid, 'text', 'Value', '');
    runIdEdit.Layout.Row = 3;
    runIdEdit.Layout.Column = 2;

    lbl = uilabel(grid, 'Text', 'Priority', 'FontWeight', 'bold');
    lbl.Layout.Row = 3;
    lbl.Layout.Column = 3;
    priorityEdit = uieditfield(grid, 'numeric', 'Value', 100, 'RoundFractionalValues', 'on');
    priorityEdit.Layout.Row = 3;
    priorityEdit.Layout.Column = 4;

    lbl = uilabel(grid, 'Text', 'Run policy', 'FontWeight', 'bold');
    lbl.Layout.Row = 4;
    lbl.Layout.Column = 1;
    runPolicyDropDown = uidropdown(grid, 'Items', {'resume', 'restart'}, 'Value', 'resume');
    runPolicyDropDown.Layout.Row = 4;
    runPolicyDropDown.Layout.Column = 2;

    lbl = uilabel(grid, 'Text', 'Existing data', 'FontWeight', 'bold');
    lbl.Layout.Row = 4;
    lbl.Layout.Column = 3;
    existingDropDown = uidropdown(grid, 'Items', {'replace', 'append', 'skip', 'error', 'upsert'}, 'Value', 'replace');
    existingDropDown.Layout.Row = 4;
    existingDropDown.Layout.Column = 4;

    lbl = uilabel(grid, 'Text', 'ROI cache', 'FontWeight', 'bold');
    lbl.Layout.Row = 5;
    lbl.Layout.Column = 1;
    cacheDropDown = uidropdown(grid, 'Items', {'auto', 'memory', 'disk'}, 'Value', 'auto');
    cacheDropDown.Layout.Row = 5;
    cacheDropDown.Layout.Column = 2;

    lbl = uilabel(grid, 'Text', 'GPU mode', 'FontWeight', 'bold');
    lbl.Layout.Row = 5;
    lbl.Layout.Column = 3;
    gpuDropDown = uidropdown(grid, 'Items', {'module_default', 'force_gpu', 'force_cpu'}, 'Value', 'module_default');
    gpuDropDown.Layout.Row = 5;
    gpuDropDown.Layout.Column = 4;

    lbl = uilabel(grid, 'Text', 'Python mode', 'FontWeight', 'bold');
    lbl.Layout.Row = 6;
    lbl.Layout.Column = 1;
    pythonModeDropDown = uidropdown(grid, 'Items', {'default', 'custom'}, 'Value', 'default');
    pythonModeDropDown.Layout.Row = 6;
    pythonModeDropDown.Layout.Column = 2;

    lbl = uilabel(grid, 'Text', 'Custom env', 'FontWeight', 'bold');
    lbl.Layout.Row = 6;
    lbl.Layout.Column = 3;
    pythonEnvEdit = uieditfield(grid, 'text', 'Value', 'detecdiv_python');
    pythonEnvEdit.Layout.Row = 6;
    pythonEnvEdit.Layout.Column = 4;

    uilabel(grid, 'Text', 'Selected nodes / description / overrides JSON', 'FontWeight', 'bold');
    notesArea = uitextarea(grid, ...
        'Value', { ...
            'Selected nodes: ', ...
            'Description: ', ...
            'Node overrides JSON: []'}, ...
        'FontName', 'Consolas');
    notesArea.Layout.Row = 7;
    notesArea.Layout.Column = [1 4];

    buttonGrid = uigridlayout(grid, [1 3]);
    buttonGrid.Layout.Row = 8;
    buttonGrid.Layout.Column = [1 4];
    buttonGrid.ColumnWidth = {'1x', '1x', '1x'};
    buttonGrid.Padding = [0 0 0 0];

    uibutton(buttonGrid, 'push', 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(dlg));
    uibutton(buttonGrid, 'push', 'Text', 'Reset', 'ButtonPushedFcn', @onReset);
    uibutton(buttonGrid, 'push', 'Text', 'Submit', 'ButtonPushedFcn', @onSubmit);

    updatePythonEnvState();
    pythonModeDropDown.ValueChangedFcn = @(~, ~) updatePythonEnvState();

    uiwait(dlg);

    function updatePythonEnvState()
        if strcmp(pythonModeDropDown.Value, 'custom')
            pythonEnvEdit.Editable = 'on';
        else
            pythonEnvEdit.Editable = 'off';
        end
    end

    function onReset(~, ~)
        targetDropDown.Value = '0';
        requestedModeDropDown.Value = 'auto';
        runIdEdit.Value = '';
        priorityEdit.Value = 100;
        runPolicyDropDown.Value = 'resume';
        existingDropDown.Value = 'replace';
        cacheDropDown.Value = 'auto';
        gpuDropDown.Value = 'module_default';
        pythonModeDropDown.Value = 'default';
        pythonEnvEdit.Value = 'detecdiv_python';
        notesArea.Value = {'Selected nodes: ', 'Description: ', 'Node overrides JSON: []'};
        updatePythonEnvState();
    end

    function onSubmit(~, ~)
        try
            selectedPipeline = pipelines(str2double(pipelineDropDown.Value));
            selectedTarget = struct([]);
            targetIdx = str2double(targetDropDown.Value);
            if targetIdx >= 1 && targetIdx <= numel(targets)
                selectedTarget = targets(targetIdx);
            end

            [selectedNodes, description, nodeParams] = localParseHubRunNotes(notesArea.Value);
            draft = struct( ...
                'pipeline', selectedPipeline, ...
                'target', selectedTarget, ...
                'requestedMode', char(string(requestedModeDropDown.Value)), ...
                'runId', strtrim(char(string(runIdEdit.Value))), ...
                'priority', double(priorityEdit.Value), ...
                'runPolicy', char(string(runPolicyDropDown.Value)), ...
                'existingPolicy', char(string(existingDropDown.Value)), ...
                'cachePolicy', char(string(cacheDropDown.Value)), ...
                'gpuMode', char(string(gpuDropDown.Value)), ...
                'pythonMode', char(string(pythonModeDropDown.Value)), ...
                'pythonEnv', strtrim(char(string(pythonEnvEdit.Value))), ...
                'selectedNodes', {selectedNodes}, ...
                'description', description, ...
                'nodeParams', nodeParams);
            delete(dlg);
        catch ME
            uialert(dlg, ME.message, 'Invalid Run Draft');
        end
    end
end

function [selectedNodes, description, nodeParams] = localParseHubRunNotes(lines)
    if ischar(lines) || isstring(lines)
        lines = cellstr(string(lines));
    end
    selectedNodes = {};
    description = '';
    nodeParams = struct('id', {}, 'params', {});

    for i = 1:numel(lines)
        lineText = char(string(lines{i}));
        parts = regexp(lineText, '^\s*([^:]+):\s*(.*)$', 'tokens', 'once');
        if isempty(parts)
            continue;
        end
        key = lower(strtrim(parts{1}));
        value = strtrim(parts{2});
        switch key
            case 'selected nodes'
                selectedNodes = localParseCommaSeparatedList(value);
            case 'description'
                description = value;
            case 'node overrides json'
                if isempty(value)
                    nodeParams = struct('id', {}, 'params', {});
                else
                    nodeParams = jsondecode(value);
                end
        end
    end
end

function shallowObj = localFindLoadedProjectByMatPath(projectMatPath)
    shallowObj = [];
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
            shallowObj = tmp;
            return;
        end
    end
end

function jsonPath = localProjectDefaultPipelinePath(shallowObj)
    jsonPath = '';
    try
        if ~isprop(shallowObj, 'runProfiles') || isempty(shallowObj.runProfiles)
            return;
        end
        if ~isfield(shallowObj.runProfiles, 'pipeline') || isempty(shallowObj.runProfiles.pipeline)
            return;
        end
        pipeInfo = shallowObj.runProfiles.pipeline;
        if isfield(pipeInfo, 'defaultTemplatePath') && ~isempty(pipeInfo.defaultTemplatePath)
            jsonPath = char(string(pipeInfo.defaultTemplatePath));
            if exist(jsonPath, 'file') ~= 2
                jsonPath = '';
            end
        end
    catch
        jsonPath = '';
    end
end

function label = localPipelineListLabel(pipelineInfo)
    source = char(string(localStructField(pipelineInfo, 'source')));
    runtimeKind = char(string(localStructField(pipelineInfo, 'runtime_kind')));
    displayName = char(string(localStructField(pipelineInfo, 'display_name')));
    key = char(string(localStructField(pipelineInfo, 'pipeline_key')));
    if isempty(displayName)
        displayName = '<unnamed pipeline>';
    end
    if isempty(key)
        label = sprintf('%s [%s | %s]', displayName, source, runtimeKind);
    else
        label = sprintf('%s (%s) [%s | %s]', displayName, key, source, runtimeKind);
    end
end

function label = localExecutionTargetLabel(targetInfo)
    displayName = char(string(localStructField(targetInfo, 'display_name')));
    kind = char(string(localStructField(targetInfo, 'target_kind')));
    hostName = char(string(localStructField(targetInfo, 'host_name')));
    gpuTxt = ternaryText(logical(localNumericField(targetInfo, 'supports_gpu')), 'GPU', 'CPU');
    if isempty(hostName)
        label = sprintf('%s [%s | %s]', displayName, kind, gpuTxt);
    else
        label = sprintf('%s [%s | %s | %s]', displayName, kind, hostName, gpuTxt);
    end
end

function values = localParseCommaSeparatedList(rawText)
    rawText = char(string(rawText));
    if isempty(strtrim(rawText))
        values = {};
        return;
    end
    pieces = regexp(rawText, '[,\n;]+', 'split');
    pieces = cellfun(@(s) strtrim(char(string(s))), pieces, 'UniformOutput', false);
    pieces = pieces(~cellfun(@isempty, pieces));
    values = pieces(:)';
end

function ref = localPipelineRefForSubmission(pipelineInfo)
    ref = struct();
    pipelineKey = char(string(localStructField(pipelineInfo, 'pipeline_key')));
    if ~isempty(pipelineKey)
        ref.pipeline_key = pipelineKey;
    end
    metadata = struct();
    if isstruct(pipelineInfo) && isfield(pipelineInfo, 'metadata_json') && isstruct(pipelineInfo.metadata_json)
        metadata = pipelineInfo.metadata_json;
    end
    observed = struct();
    if isfield(metadata, 'observed') && isstruct(metadata.observed)
        observed = metadata.observed;
    end
    pathHint = localFirstNonEmptyText({ ...
        localStructField(metadata, 'export_manifest_uri'), ...
        localStructField(metadata, 'pipeline_bundle_uri'), ...
        localStructField(metadata, 'pipeline_json_path'), ...
        localStructField(metadata, 'pipeline_path'), ...
        localStructField(observed, 'export_manifest_uri'), ...
        localStructField(observed, 'pipeline_bundle_uri'), ...
        localStructField(observed, 'pipeline_json_path'), ...
        localStructField(observed, 'pipeline_path')});
    if ~isempty(pathHint)
        if endsWith(lower(pathHint), 'export_manifest.json')
            ref.export_manifest_uri = pathHint;
        else
            ref.pipeline_json_path = pathHint;
        end
    end
end

function out = localFirstNonEmptyText(values)
    out = '';
    for i = 1:numel(values)
        txt = char(string(values{i}));
        if ~isempty(strtrim(txt))
            out = txt;
            return;
        end
    end
end

function name = localHostName()
    name = strtrim(char(string(getenv('COMPUTERNAME'))));
    if isempty(name)
        name = strtrim(char(string(getenv('HOSTNAME'))));
    end
    if isempty(name)
        name = 'catalog-client';
    end
end
