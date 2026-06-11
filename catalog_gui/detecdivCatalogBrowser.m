function varargout = detecdivCatalogBrowser(varargin)
% detecdivCatalogBrowser  Browse indexed DetecDiv projects from local DB or hub API.

    ip = inputParser;
    ip.addParameter('RootPath', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('DbFile', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    catalogSettings = detecdiv_catalog_settings_get();
    hubSettings = localCompleteHubSettings(detecdiv_hub_settings_get());
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
    state.entityMode = 'projects';
    state.projects = table();
    state.visibleProjects = table();
    state.displayProjects = table();
    state.searchText = '';
    state.pageSize = 100;
    state.currentPage = 1;
    state.sortVariable = 'name';
    state.sortAscending = true;
    state.selectedRow = [];
    state.job = [];
    state.pollTimer = [];
    state.lastVisibleProjectCount = 0;
    state.currentUser = struct();
    state.hubGroups = struct([]);
    state.hubUsers = struct([]);
    state.hubSelectedGroupId = '';
    state.hubSelectedOwnerKey = '';
    state.hubOwnedOnly = false;

    fig = uifigure( ...
        'Name', 'DetecDiv Catalog Browser', ...
        'Position', [60 60 1640 900], ...
        'Color', [0.98 0.98 0.98], ...
        'CloseRequestFcn', @onCloseFigure);

    fileMenu = uimenu(fig, 'Text', 'File');
    uimenu(fileMenu, 'Text', 'New Project...', 'MenuSelectedFcn', @onNewProjectInPipeline2);
    uimenu(fileMenu, 'Text', 'Batch New...', 'MenuSelectedFcn', @onBatchNewProjects);
    uimenu(fileMenu, 'Text', 'Connection Settings...', 'Separator', 'on', ...
        'MenuSelectedFcn', @onOpenConnectionSettings);
    uimenu(fileMenu, 'Text', 'Index Projects...', 'MenuSelectedFcn', @onOpenIndexDialog);
    uimenu(fileMenu, 'Text', 'Refresh', 'MenuSelectedFcn', @onRefreshProjects);
    uimenu(fileMenu, 'Text', 'Close', 'Separator', 'on', ...
        'MenuSelectedFcn', @(src, event) onCloseFigure(src, event));

    mainGrid = uigridlayout(fig, [4 1]);
    mainGrid.RowHeight = {116, 28, '1x', 38};
    mainGrid.ColumnWidth = {'1x'};
    mainGrid.Padding = [14 14 14 14];
    mainGrid.RowSpacing = 10;

    controlGrid = uigridlayout(mainGrid, [5 11]);
    controlGrid.Layout.Row = 1;
    controlGrid.RowHeight = {32, 32, 32, 0, 0};
    controlGrid.ColumnWidth = {78, 140, 110, 110, '1x', 110, 110, 150, 95, 120, 90};
    controlGrid.ColumnSpacing = 8;
    controlGrid.Padding = [0 0 0 0];

    backingPanel = uipanel(fig, 'Visible', 'off', 'Position', [0 0 1 1]);
    backingGrid = uigridlayout(backingPanel, [5 11]);
    backingGrid.RowHeight = {24, 32, 32, 32, 32};
    backingGrid.ColumnWidth = {78, 120, 65, '1x', 72, '1x', 70, '1x', 95, 95, 105};
    backingGrid.Padding = [0 0 0 0];

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

    entityLabel = uilabel(controlGrid, 'Text', 'View', 'FontWeight', 'bold');
    entityLabel.Layout.Row = 1;
    entityLabel.Layout.Column = 3;

    entityDropDown = uidropdown(controlGrid, ...
        'Items', {'Projects', 'Raw datasets'}, ...
        'ItemsData', {'projects', 'raw_datasets'}, ...
        'Value', state.entityMode, ...
        'ValueChangedFcn', @onEntityModeChanged);
    entityDropDown.Layout.Row = 1;
    entityDropDown.Layout.Column = [4 5];

    connectionSettingsButton = uibutton(controlGrid, 'push', ...
        'Text', 'Connection Settings...', ...
        'ButtonPushedFcn', @onOpenConnectionSettings);
    connectionSettingsButton.Layout.Row = 1;
    connectionSettingsButton.Layout.Column = [8 10];

    userKeyLabel = uilabel(backingGrid, 'Text', 'User', 'FontWeight', 'bold');
    userKeyLabel.Layout.Row = 1;
    userKeyLabel.Layout.Column = 3;

    userKeyEdit = uieditfield(backingGrid, 'text', 'Value', state.hubSettings.userKey);
    userKeyEdit.Layout.Row = 1;
    userKeyEdit.Layout.Column = 4;

    passwordLabel = uilabel(backingGrid, 'Text', 'Password', 'FontWeight', 'bold');
    passwordLabel.Layout.Row = 1;
    passwordLabel.Layout.Column = 5;

    try
        passwordEdit = uieditfield(backingGrid, 'password');
    catch
        passwordEdit = uieditfield(backingGrid, 'text');
    end
    passwordEdit.Value = '';
    passwordEdit.Layout.Row = 1;
    passwordEdit.Layout.Column = 6;

    currentUserTitleLabel = uilabel(backingGrid, 'Text', 'Current', 'FontWeight', 'bold');
    currentUserTitleLabel.Layout.Row = 1;
    currentUserTitleLabel.Layout.Column = 7;

    currentUserLabel = uilabel(backingGrid, ...
        'Text', '', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic');
    currentUserLabel.Layout.Row = 1;
    currentUserLabel.Layout.Column = 8;

    loginButton = uibutton(backingGrid, 'push', 'Text', 'Login...', ...
        'ButtonPushedFcn', @onHubLogin);
    loginButton.Layout.Row = 1;
    loginButton.Layout.Column = 9;

    logoutButton = uibutton(backingGrid, 'push', 'Text', 'Logout', ...
        'ButtonPushedFcn', @onHubLogout);
    logoutButton.Layout.Row = 1;
    logoutButton.Layout.Column = 10;

    backgroundCheck = uicheckbox(backingGrid, ...
        'Text', 'BG index', ...
        'Value', logical(state.catalogSettings.backgroundIndexing));
    backgroundCheck.Layout.Row = 1;
    backgroundCheck.Layout.Column = 11;

    baseUrlLabel = uilabel(backingGrid, 'Text', 'Hub URL', 'FontWeight', 'bold');
    baseUrlLabel.Layout.Row = 2;
    baseUrlLabel.Layout.Column = 1;

    baseUrlEdit = uieditfield(backingGrid, 'text', 'Value', state.hubSettings.baseUrl);
    baseUrlEdit.Layout.Row = 2;
    baseUrlEdit.Layout.Column = [2 6];

    localMountLabel = uilabel(backingGrid, 'Text', 'Local Mount', 'FontWeight', 'bold');
    localMountLabel.Layout.Row = 2;
    localMountLabel.Layout.Column = 7;

    localMountEdit = uieditfield(backingGrid, 'text', 'Value', state.hubSettings.defaultLocalProjectRoot);
    localMountEdit.Layout.Row = 2;
    localMountEdit.Layout.Column = [8 11];

    rootLabel = uilabel(backingGrid, 'Text', '', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    rootLabel.Layout.Row = 3;
    rootLabel.Layout.Column = 1;

    rootEdit = uieditfield(backingGrid, 'text');
    rootEdit.Layout.Row = 3;
    rootEdit.Layout.Column = [2 6];

    browseButton = uibutton(backingGrid, 'push', 'Text', 'Browse...', ...
        'ButtonPushedFcn', @onBrowseRoot);
    browseButton.Layout.Row = 3;
    browseButton.Layout.Column = 7;

    saveRootButton = uibutton(backingGrid, 'push', 'Text', 'Save Config', ...
        'ButtonPushedFcn', @onSaveConfiguration);
    saveRootButton.Layout.Row = 3;
    saveRootButton.Layout.Column = 8;

    indexButton = uibutton(backingGrid, 'push', 'Text', 'Index Root', ...
        'ButtonPushedFcn', @onIndexRoot);
    indexButton.Layout.Row = 3;
    indexButton.Layout.Column = 9;

    refreshButton = uibutton(controlGrid, 'push', 'Text', 'Refresh', ...
        'ButtonPushedFcn', @onRefreshProjects);
    refreshButton.Layout.Row = 1;
    refreshButton.Layout.Column = 11;

    groupLabel = uilabel(controlGrid, 'Text', 'Owner/Group', 'FontWeight', 'bold');
    groupLabel.Layout.Row = 2;
    groupLabel.Layout.Column = 1;

    groupDropDown = uidropdown(controlGrid, ...
        'Items', {'All projects'}, ...
        'ItemsData', {''}, ...
        'Value', '', ...
        'ValueChangedFcn', @onGroupFilterChanged);
    groupDropDown.Layout.Row = 2;
    groupDropDown.Layout.Column = [2 5];

    ownedOnlyCheck = uicheckbox(controlGrid, ...
        'Text', 'Owned only', ...
        'Value', false, ...
        'ValueChangedFcn', @onOwnedOnlyChanged);
    ownedOnlyCheck.Layout.Row = 2;
    ownedOnlyCheck.Layout.Column = 6;

    refreshGroupsButton = uibutton(controlGrid, 'push', 'Text', 'Refresh', ...
        'ButtonPushedFcn', @onRefreshGroups);
    refreshGroupsButton.Layout.Row = 2;
    refreshGroupsButton.Layout.Column = 7;

    addToGroupButton = uibutton(controlGrid, 'push', 'Text', 'Add To Group', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onAddToGroup);
    addToGroupButton.Layout.Row = 2;
    addToGroupButton.Layout.Column = 8;

    newGroupButton = uibutton(controlGrid, 'push', 'Text', 'New Group', ...
        'ButtonPushedFcn', @onCreateGroup);
    newGroupButton.Layout.Row = 2;
    newGroupButton.Layout.Column = 9;

    sourceInfoLabel = uilabel(controlGrid, ...
        'Text', '', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic', ...
        'WordWrap', 'on');
    sourceInfoLabel.Layout.Row = 1;
    sourceInfoLabel.Layout.Column = [6 7];

    searchLabel = uilabel(controlGrid, 'Text', 'Search', 'FontWeight', 'bold');
    searchLabel.Layout.Row = 3;
    searchLabel.Layout.Column = 1;

    searchEdit = uieditfield(controlGrid, 'text', ...
        'Value', state.searchText, ...
        'ValueChangedFcn', @onSearchChanged);
    try
        searchEdit.ValueChangingFcn = @onSearchChanging;
    catch
    end
    searchEdit.Layout.Row = 3;
    searchEdit.Layout.Column = [2 8];

    clearSearchButton = uibutton(controlGrid, 'push', ...
        'Text', 'Clear', ...
        'ButtonPushedFcn', @onClearSearch);
    clearSearchButton.Layout.Row = 3;
    clearSearchButton.Layout.Column = 9;

    sortDropDown = uidropdown(controlGrid, ...
        'Items', {'Name', 'Modified Date', 'Imported Date', 'Health', 'FOV', 'ROI', 'Runs', 'Missing Raw'}, ...
        'ItemsData', {'name', 'project_mtime', 'created_at', 'health_status', 'fov_count', 'roi_count', 'pipeline_run_count', 'missing_raw_count'}, ...
        'Value', state.sortVariable, ...
        'ValueChangedFcn', @onSortChanged);
    sortDropDown.Layout.Row = 3;
    sortDropDown.Layout.Column = 10;

    sortDirectionButton = uibutton(controlGrid, 'push', ...
        'Text', 'Asc', ...
        'ButtonPushedFcn', @onSortDirectionToggled);
    sortDirectionButton.Layout.Row = 3;
    sortDirectionButton.Layout.Column = 11;

    statusLabel = uilabel(mainGrid, ...
        'Text', 'Ready.', ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.15 0.15 0.15]);
    statusLabel.Layout.Row = 2;

    bodyGrid = uigridlayout(mainGrid, [1 2]);
    bodyGrid.Layout.Row = 3;
    bodyGrid.ColumnWidth = {'3.3x', '1x'};
    bodyGrid.ColumnSpacing = 12;
    bodyGrid.Padding = [0 0 0 0];

    projectTable = uitable(bodyGrid, ...
        'Data', table(), ...
        'ColumnSortable', false, ...
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

    detailsTitleLabel = uilabel(sideGrid, 'Text', 'Project Details', 'FontWeight', 'bold');

    detailsArea = uitextarea(sideGrid, ...
        'Editable', 'off', ...
        'Value', {'No project selected.'}, ...
        'FontName', 'Consolas');
    detailsArea.Layout.Row = 2;

    actionGrid = uigridlayout(sideGrid, [3 3]);
    actionGrid.Layout.Row = 3;
    actionGrid.ColumnWidth = {'1x', '1x', '1x'};
    actionGrid.RowHeight = {32, 32, 0};
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

    pipeline2Button = uibutton(actionGrid, 'push', 'Text', 'Run Pipeline...', ...
        'Enable', 'off', 'ButtonPushedFcn', @onOpenPipeline2);
    pipeline2Button.Layout.Row = 1;
    pipeline2Button.Layout.Column = 3;

    newProjectButton = uibutton(actionGrid, 'push', 'Text', 'New Project...', ...
        'ButtonPushedFcn', @onNewProjectInPipeline2);
    newProjectButton.Layout.Row = 2;
    newProjectButton.Layout.Column = 1;

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
    aclButton.Layout.Row = 2;
    aclButton.Layout.Column = 1;

    batchNewButton = uibutton(actionGrid, 'push', 'Text', 'Batch New...', ...
        'ButtonPushedFcn', @onBatchNewProjects);
    batchNewButton.Layout.Row = 3;
    batchNewButton.Layout.Column = 2;

    footerGrid = uigridlayout(mainGrid, [1 5]);
    footerGrid.Layout.Row = 4;
    footerGrid.ColumnWidth = {'1x', 90, 180, 90, 100};
    footerGrid.ColumnSpacing = 8;
    footerGrid.Padding = [0 0 0 0];

    footerLabel = uilabel(footerGrid, ...
        'Text', 'Local mode uses SQLite. Hub mode uses the API and maps server roots to local mounts when needed.', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic', ...
        'FontColor', [0.35 0.35 0.35]);
    footerLabel.Layout.Row = 1;
    footerLabel.Layout.Column = 1;

    prevPageButton = uibutton(footerGrid, 'push', ...
        'Text', 'Previous', ...
        'ButtonPushedFcn', @onPreviousPage);
    prevPageButton.Layout.Row = 1;
    prevPageButton.Layout.Column = 2;

    pageLabel = uilabel(footerGrid, ...
        'Text', 'Page 0 / 0', ...
        'HorizontalAlignment', 'center');
    pageLabel.Layout.Row = 1;
    pageLabel.Layout.Column = 3;

    nextPageButton = uibutton(footerGrid, 'push', ...
        'Text', 'Next', ...
        'ButtonPushedFcn', @onNextPage);
    nextPageButton.Layout.Row = 1;
    nextPageButton.Layout.Column = 4;

    pageSizeDropDown = uidropdown(footerGrid, ...
        'Items', {'50', '100', '200'}, ...
        'ItemsData', [50 100 200], ...
        'Value', state.pageSize, ...
        'ValueChangedFcn', @onPageSizeChanged);
    pageSizeDropDown.Layout.Row = 1;
    pageSizeDropDown.Layout.Column = 5;

    syncUiFromState();
    refreshProjectsTable();

    function onSourceModeChanged(~, ~)
        state.sourceMode = localNormalizeSourceMode(sourceDropDown.Value);
        state.hubSettings.sourceMode = state.sourceMode;
        if strcmp(state.sourceMode, 'local') && strcmp(state.entityMode, 'raw_datasets')
            state.entityMode = 'raw_datasets';
        end
        state.currentPage = 1;
        state.selectedRow = [];
        detecdiv_hub_settings_set(state.hubSettings);
        syncUiFromState();
        refreshProjectsTable();
    end

    function onEntityModeChanged(~, ~)
        state.entityMode = localNormalizeEntityMode(entityDropDown.Value);
        state.currentPage = 1;
        state.selectedRow = [];
        syncUiFromState();
        refreshProjectsTable();
    end

    function onHubLogin(~, ~)
        if ~strcmp(state.sourceMode, 'hub')
            return;
        end

        if isempty(strtrim(char(string(state.hubSettings.baseUrl))))
            uialert(fig, 'Configure the Hub URL first in Connection Settings.', 'Missing Hub Settings');
            return;
        end

        [userKey, password] = localPromptHubCredentials(state.hubSettings.userKey);
        if isempty(userKey) || isempty(password)
            return;
        end

        try
            [sessionInfo, state.hubSettings] = detecdiv_hub_login(userKey, password, state.hubSettings); %#ok<NASGU>
            passwordEdit.Value = '';
            syncUiFromState();
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
            passwordEdit.Value = '';
            syncUiFromState();
            refreshProjectsTable('PreserveStatus', true);
            setStatus('Hub session cleared.');
        catch ME
            uialert(fig, ME.message, 'Hub Logout Failed');
            setStatus(['Hub logout failed: ' ME.message]);
        end
    end

    function onGroupFilterChanged(~, ~)
        [state.hubSelectedGroupId, state.hubSelectedOwnerKey] = localParseHubFilterValue(groupDropDown.Value);
        state.currentPage = 1;
        state.selectedRow = [];
        refreshProjectsTable('PreserveStatus', true);
    end

    function onOwnedOnlyChanged(~, ~)
        state.hubOwnedOnly = logical(ownedOnlyCheck.Value);
        state.currentPage = 1;
        state.selectedRow = [];
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
            state.hubSelectedGroupId = char(string(group.id));
            state.hubSelectedOwnerKey = '';
            groupDropDown.Value = localGroupFilterValue(state.hubSelectedGroupId);
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
        if strcmp(state.sourceMode, 'hub')
            localMountEdit.Value = char(selectedRoot);
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
            syncUiFromState();
            refreshProjectsTable();
            setStatus(['Local catalog configuration saved: ' rootPath]);
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
        syncUiFromState();
        refreshProjectsTable();
        setStatus('Hub configuration saved.');
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
        cleanupObj = onCleanup(@() setBusyState(false));
        drawnow;

        try
            response = detecdiv_hub_request_index(hubRoot, state.hubSettings, ...
                'HostScope', 'server', 'ClearExistingForRoot', false);
            refreshProjectsTable();
            if isstruct(response) && isfield(response, 'job') && isstruct(response.job)
                setStatus(sprintf('Queued hub indexing job %s for %s.', ...
                    char(string(localStructField(response.job, 'id'))), ...
                    char(string(localStructField(response.job, 'source_path')))));
            else
                setStatus(sprintf('Hub indexed %d project(s) from %s.', ...
                    response.indexed_projects, char(string(response.source_path))));
            end
        catch ME
            uialert(fig, ME.message, 'Hub Indexing Failed');
            setStatus(['Hub indexing failed: ' ME.message]);
        end
    end

    function onRefreshProjects(~, ~)
        refreshProjectsTable();
    end

    function onOpenConnectionSettings(~, ~)
        dlg = uifigure( ...
            'Name', 'Connection Settings', ...
            'Position', [180 180 760 340], ...
            'WindowStyle', 'modal', ...
            'Resize', 'off');

        isLocalDialog = strcmp(state.sourceMode, 'local');
        grid = uigridlayout(dlg, [8 4]);
        grid.ColumnWidth = {120, '1x', 120, '1x'};
        grid.RowHeight = {24, 24, 30, 30, 30, 30, '1x', 40};
        grid.Padding = [12 12 12 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 10;

        connectionStatusLabel = uilabel(grid, 'Text', '', 'FontAngle', 'italic');
        connectionStatusLabel.Layout.Row = 1;
        connectionStatusLabel.Layout.Column = [1 4];

        tokenLabel = uilabel(grid, 'Text', '', 'FontName', 'Consolas');
        tokenLabel.Layout.Row = 2;
        tokenLabel.Layout.Column = [1 4];

        localRootLabel = uilabel(grid, 'Text', 'Projects Root', 'FontWeight', 'bold');
        localRootLabel.Layout.Row = 3;
        localRootLabel.Layout.Column = 1;
        localRootEdit = uieditfield(grid, 'text', ...
            'Value', char(string(state.catalogSettings.defaultProjectRoot)));
        localRootEdit.Layout.Row = 3;
        localRootEdit.Layout.Column = [2 3];
        localBrowseButton = uibutton(grid, 'push', 'Text', 'Browse...', ...
            'ButtonPushedFcn', @onDialogBrowseLocalRoot);
        localBrowseButton.Layout.Row = 3;
        localBrowseButton.Layout.Column = 4;

        backgroundDialogCheck = uicheckbox(grid, ...
            'Text', 'Background indexing', ...
            'Value', logical(state.catalogSettings.backgroundIndexing));
        backgroundDialogCheck.Layout.Row = 4;
        backgroundDialogCheck.Layout.Column = [2 4];

        baseUrlDialogLabel = uilabel(grid, 'Text', 'Hub URL', 'FontWeight', 'bold');
        baseUrlDialogLabel.Layout.Row = 3;
        baseUrlDialogLabel.Layout.Column = 1;
        baseUrlDialogEdit = uieditfield(grid, 'text', ...
            'Value', char(string(state.hubSettings.baseUrl)));
        baseUrlDialogEdit.Layout.Row = 3;
        baseUrlDialogEdit.Layout.Column = [2 4];

        userDialogLabel = uilabel(grid, 'Text', 'User', 'FontWeight', 'bold');
        userDialogLabel.Layout.Row = 4;
        userDialogLabel.Layout.Column = 1;
        userDialogEdit = uieditfield(grid, 'text', ...
            'Value', char(string(state.hubSettings.userKey)));
        userDialogEdit.Layout.Row = 4;
        userDialogEdit.Layout.Column = 2;

        passwordDialogLabel = uilabel(grid, 'Text', 'Password', 'FontWeight', 'bold');
        passwordDialogLabel.Layout.Row = 4;
        passwordDialogLabel.Layout.Column = 3;
        try
            passwordDialogEdit = uieditfield(grid, 'password');
        catch
            passwordDialogEdit = uieditfield(grid, 'text');
        end
        passwordDialogEdit.Layout.Row = 4;
        passwordDialogEdit.Layout.Column = 4;
        passwordDialogEdit.Value = '';

        remoteRootDialogLabel = uilabel(grid, 'Text', 'Remote Root', 'FontWeight', 'bold');
        remoteRootDialogLabel.Layout.Row = 5;
        remoteRootDialogLabel.Layout.Column = 1;
        remoteRootDialogEdit = uieditfield(grid, 'text', ...
            'Value', char(string(state.hubSettings.defaultRemoteProjectRoot)));
        remoteRootDialogEdit.Layout.Row = 5;
        remoteRootDialogEdit.Layout.Column = [2 4];

        localMountDialogLabel = uilabel(grid, 'Text', 'Local Mount', 'FontWeight', 'bold');
        localMountDialogLabel.Layout.Row = 6;
        localMountDialogLabel.Layout.Column = 1;
        localMountDialogEdit = uieditfield(grid, 'text', ...
            'Value', char(string(state.hubSettings.defaultLocalProjectRoot)));
        localMountDialogEdit.Layout.Row = 6;
        localMountDialogEdit.Layout.Column = [2 3];
        localMountBrowseButton = uibutton(grid, 'push', 'Text', 'Browse...', ...
            'ButtonPushedFcn', @onDialogBrowseLocalMount);
        localMountBrowseButton.Layout.Row = 6;
        localMountBrowseButton.Layout.Column = 4;

        buttonGrid = uigridlayout(grid, [1 5]);
        buttonGrid.Layout.Row = 8;
        buttonGrid.Layout.Column = [1 4];
        buttonGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
        buttonGrid.Padding = [0 0 0 0];
        buttonGrid.ColumnSpacing = 8;

        saveDialogButton = uibutton(buttonGrid, 'push', 'Text', 'Save', ...
            'ButtonPushedFcn', @onDialogSave);
        sessionButton = uibutton(buttonGrid, 'push', 'Text', 'Login', ...
            'ButtonPushedFcn', @onDialogSessionToggle);
        spacer2 = uilabel(buttonGrid, 'Text', '');
        spacer3 = uilabel(buttonGrid, 'Text', '');
        closeDialogButton = uibutton(buttonGrid, 'push', 'Text', 'Close', ...
            'ButtonPushedFcn', @(~, ~) delete(dlg));

        saveDialogButton.Layout.Row = 1;
        saveDialogButton.Layout.Column = 1;
        sessionButton.Layout.Row = 1;
        sessionButton.Layout.Column = 2;
        spacer2.Layout.Row = 1;
        spacer2.Layout.Column = 3;
        spacer3.Layout.Row = 1;
        spacer3.Layout.Column = 4;
        closeDialogButton.Layout.Row = 1;
        closeDialogButton.Layout.Column = 5;

        pullDialogValuesFromState();

        function syncDialogMode()
            localSetVisible(localRootLabel, isLocalDialog);
            localSetVisible(localRootEdit, isLocalDialog);
            localSetVisible(localBrowseButton, isLocalDialog);
            localSetVisible(backgroundDialogCheck, isLocalDialog);

            localSetVisible(baseUrlDialogLabel, ~isLocalDialog);
            localSetVisible(baseUrlDialogEdit, ~isLocalDialog);
            localSetVisible(userDialogLabel, ~isLocalDialog);
            localSetVisible(userDialogEdit, ~isLocalDialog);
            localSetVisible(passwordDialogLabel, ~isLocalDialog);
            localSetVisible(passwordDialogEdit, ~isLocalDialog);
            localSetVisible(remoteRootDialogLabel, ~isLocalDialog);
            localSetVisible(remoteRootDialogEdit, ~isLocalDialog);
            localSetVisible(localMountDialogLabel, ~isLocalDialog);
            localSetVisible(localMountDialogEdit, ~isLocalDialog);
            localSetVisible(localMountBrowseButton, ~isLocalDialog);
            localSetVisible(sessionButton, ~isLocalDialog);

            if isLocalDialog
                connectionStatusLabel.Text = 'Local catalog mode. No Hub session is used.';
                tokenLabel.Text = ['DB: ' char(string(state.catalogSettings.dbFile))];
            else
                connectionStatusLabel.Text = ['Hub status: ' localCurrentUserLabel()];
                tokenText = localTokenLabel(state.hubSettings);
                if isempty(tokenText)
                    tokenLabel.Text = 'Token: <none>';
                    sessionButton.Text = 'Login';
                else
                    tokenLabel.Text = ['Token: ' tokenText];
                    sessionButton.Text = 'Logout';
                end
            end
        end

        function ok = applyDialogValues()
            ok = false;
            if isLocalDialog
                rootPath = sanitizeRoot(localRootEdit.Value, 'RequireExisting', true);
                if isempty(rootPath)
                    uialert(dlg, 'Please choose a valid local project root folder.', 'Invalid Folder');
                    return;
                end
                state.catalogSettings.defaultProjectRoot = rootPath;
                state.catalogSettings.recentProjectRoots = updateRecentRoots( ...
                    state.catalogSettings.recentProjectRoots, rootPath);
                state.catalogSettings.backgroundIndexing = logical(backgroundDialogCheck.Value);
                rootEdit.Value = rootPath;
                backgroundCheck.Value = logical(backgroundDialogCheck.Value);
                detecdiv_catalog_settings_set(state.catalogSettings);
                ok = true;
                return;
            end

            hubRoot = sanitizeRoot(remoteRootDialogEdit.Value, 'RequireExisting', false);
            localMount = sanitizeRoot(localMountDialogEdit.Value, 'RequireExisting', false);
            state.hubSettings.baseUrl = strtrim(char(string(baseUrlDialogEdit.Value)));
            state.hubSettings.userKey = strtrim(char(string(userDialogEdit.Value)));
            state.hubSettings.defaultRemoteProjectRoot = hubRoot;
            state.hubSettings.defaultLocalProjectRoot = localMount;
            state.hubSettings.sourceMode = state.sourceMode;
            if ~isempty(hubRoot) && ~isempty(localMount)
                state.hubSettings = detecdiv_hub_upsert_path_mapping(state.hubSettings, hubRoot, localMount);
            end
            baseUrlEdit.Value = char(string(state.hubSettings.baseUrl));
            userKeyEdit.Value = char(string(state.hubSettings.userKey));
            rootEdit.Value = char(string(state.hubSettings.defaultRemoteProjectRoot));
            localMountEdit.Value = char(string(state.hubSettings.defaultLocalProjectRoot));
            detecdiv_hub_settings_set(state.hubSettings);
            ok = true;
        end

        function pullDialogValuesFromState()
            localRootEdit.Value = char(string(state.catalogSettings.defaultProjectRoot));
            backgroundDialogCheck.Value = logical(state.catalogSettings.backgroundIndexing);
            baseUrlDialogEdit.Value = char(string(state.hubSettings.baseUrl));
            userDialogEdit.Value = char(string(state.hubSettings.userKey));
            remoteRootDialogEdit.Value = char(string(state.hubSettings.defaultRemoteProjectRoot));
            localMountDialogEdit.Value = char(string(state.hubSettings.defaultLocalProjectRoot));
            passwordDialogEdit.Value = '';
            syncDialogMode();
        end

        function onDialogBrowseLocalRoot(~, ~)
            currentRoot = char(string(localRootEdit.Value));
            if isempty(currentRoot) || ~isfolder(currentRoot)
                currentRoot = pwd;
            end
            selectedRoot = uigetdir(currentRoot, 'Select project root');
            if isequal(selectedRoot, 0)
                return;
            end
            localRootEdit.Value = char(selectedRoot);
        end

        function onDialogBrowseLocalMount(~, ~)
            currentRoot = char(string(localMountDialogEdit.Value));
            if isempty(currentRoot) || ~isfolder(currentRoot)
                currentRoot = pwd;
            end
            selectedRoot = uigetdir(currentRoot, 'Select local mount');
            if isequal(selectedRoot, 0)
                return;
            end
            localMountDialogEdit.Value = char(selectedRoot);
        end

        function onDialogSave(~, ~)
            if ~applyDialogValues()
                return;
            end
            pullDialogValuesFromState();
            syncUiFromState();
            refreshProjectsTable();
            setStatus('Connection settings saved.');
        end

        function onDialogSessionToggle(~, ~)
            if isLocalDialog
                return;
            end
            if ~applyDialogValues()
                return;
            end

            if isempty(localTokenLabel(state.hubSettings))
                userKey = strtrim(char(string(userDialogEdit.Value)));
                password = char(string(passwordDialogEdit.Value));
                if isempty(userKey) || isempty(password)
                    uialert(dlg, 'User and password are required to open a Hub session.', 'Missing Hub Credentials');
                    return;
                end
                try
                    [~, state.hubSettings] = detecdiv_hub_login(userKey, password, state.hubSettings);
                    passwordDialogEdit.Value = '';
                    passwordEdit.Value = '';
                    refreshProjectsTable('PreserveStatus', true);
                    setStatus(sprintf('Hub session opened for %s.', state.hubSettings.userKey));
                catch ME
                    uialert(dlg, ME.message, 'Hub Login Failed');
                    setStatus(['Hub login failed: ' ME.message]);
                end
            else
                try
                    state.hubSettings = detecdiv_hub_logout(state.hubSettings);
                    state.currentUser = struct();
                    passwordDialogEdit.Value = '';
                    passwordEdit.Value = '';
                    refreshProjectsTable('PreserveStatus', true);
                    setStatus('Hub session cleared.');
                catch ME
                    uialert(dlg, ME.message, 'Hub Logout Failed');
                    setStatus(['Hub logout failed: ' ME.message]);
                end
            end
            detecdiv_hub_settings_set(state.hubSettings);
            pullDialogValuesFromState();
            syncUiFromState();
        end
    end

    function onOpenIndexDialog(~, ~)
        dlg = uifigure( ...
            'Name', 'Index Projects', ...
            'Position', [220 220 760 220], ...
            'WindowStyle', 'modal', ...
            'Resize', 'off');

        grid = uigridlayout(dlg, [4 4]);
        grid.ColumnWidth = {110, '1x', 110, 110};
        grid.RowHeight = {30, 30, '1x', 40};
        grid.Padding = [12 12 12 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 10;

        pathLabel = uilabel(grid, 'Text', ternaryText(strcmp(state.sourceMode, 'local'), 'Projects Root', 'Remote Root'), ...
            'FontWeight', 'bold');
        pathLabel.Layout.Row = 1;
        pathLabel.Layout.Column = 1;

        defaultPath = char(string(ternaryText(strcmp(state.sourceMode, 'local'), ...
            state.catalogSettings.defaultProjectRoot, state.hubSettings.defaultRemoteProjectRoot)));
        pathEdit = uieditfield(grid, 'text', 'Value', defaultPath);
        pathEdit.Layout.Row = 1;
        pathEdit.Layout.Column = 2;

        browseIndexButton = uibutton(grid, 'push', 'Text', 'Browse...', ...
            'ButtonPushedFcn', @onDialogBrowseIndexPath);
        browseIndexButton.Layout.Row = 1;
        browseIndexButton.Layout.Column = 3;

        runIndexButton = uibutton(grid, 'push', 'Text', 'Run Index', ...
            'ButtonPushedFcn', @onDialogRunIndex);
        runIndexButton.Layout.Row = 1;
        runIndexButton.Layout.Column = 4;

        bgIndexDialogCheck = uicheckbox(grid, ...
            'Text', 'Background indexing', ...
            'Value', logical(state.catalogSettings.backgroundIndexing), ...
            'Visible', onOff(strcmp(state.sourceMode, 'local')));
        bgIndexDialogCheck.Layout.Row = 2;
        bgIndexDialogCheck.Layout.Column = [2 4];

        statusArea = uitextarea(grid, ...
            'Editable', 'off', ...
            'Value', {char(string(statusLabel.Text))});
        statusArea.Layout.Row = 3;
        statusArea.Layout.Column = [1 4];

        closeButton = uibutton(grid, 'push', 'Text', 'Close', ...
            'ButtonPushedFcn', @(~, ~) delete(dlg));
        closeButton.Layout.Row = 4;
        closeButton.Layout.Column = 4;

        mirrorTimer = timer( ...
            'ExecutionMode', 'fixedSpacing', ...
            'Period', 0.5, ...
            'BusyMode', 'drop', ...
            'TimerFcn', @(~, ~) syncIndexStatus());
        start(mirrorTimer);
        dlg.CloseRequestFcn = @onCloseIndexDialog;

        function onDialogBrowseIndexPath(~, ~)
            currentRoot = char(string(pathEdit.Value));
            if isempty(currentRoot) || ~isfolder(currentRoot)
                currentRoot = pwd;
            end
            selectedRoot = uigetdir(currentRoot, 'Select project root to index');
            if isequal(selectedRoot, 0)
                return;
            end
            pathEdit.Value = char(selectedRoot);
        end

        function onDialogRunIndex(~, ~)
            if strcmp(state.sourceMode, 'local')
                rootEdit.Value = char(string(pathEdit.Value));
                backgroundCheck.Value = logical(bgIndexDialogCheck.Value);
            else
                rootEdit.Value = char(string(pathEdit.Value));
            end
            onIndexRoot([], []);
            syncIndexStatus();
        end

        function syncIndexStatus()
            if ~isvalid(dlg) || ~isvalid(statusArea) || ~isvalid(fig)
                return;
            end
            msg = char(string(statusLabel.Text));
            if isempty(msg)
                msg = 'Ready.';
            end
            statusArea.Value = {msg};
        end

        function onCloseIndexDialog(~, ~)
            try
                stop(mirrorTimer);
            catch
            end
            try
                delete(mirrorTimer);
            catch
            end
            delete(dlg);
        end
    end

    function onSearchChanged(~, ~)
        state.searchText = char(string(searchEdit.Value));
        state.currentPage = 1;
        if strcmp(state.sourceMode, 'hub')
            refreshProjectsTable();
            return;
        end
        updateProjectTableFromState();
        restorePreviousSelection();
        updateSelectionState();
    end

    function onSearchChanging(~, event)
        state.searchText = char(string(event.Value));
        state.currentPage = 1;
        if strcmp(state.sourceMode, 'hub')
            return;
        end
        updateProjectTableFromState();
        restorePreviousSelection();
        updateSelectionState();
    end

    function onClearSearch(~, ~)
        state.searchText = '';
        searchEdit.Value = '';
        state.currentPage = 1;
        if strcmp(state.sourceMode, 'hub')
            refreshProjectsTable();
            return;
        end
        updateProjectTableFromState();
        restorePreviousSelection();
        updateSelectionState();
    end

    function onSortChanged(~, ~)
        state.sortVariable = char(string(sortDropDown.Value));
        state.currentPage = 1;
        updateProjectTableFromState();
        restorePreviousSelection();
        updateSelectionState();
    end

    function onSortDirectionToggled(~, ~)
        state.sortAscending = ~state.sortAscending;
        syncSortControls();
        state.currentPage = 1;
        updateProjectTableFromState();
        restorePreviousSelection();
        updateSelectionState();
    end

    function onPreviousPage(~, ~)
        if state.currentPage <= 1
            return;
        end
        state.currentPage = state.currentPage - 1;
        updateProjectDisplayPage();
        applyProjectTableStyles();
        updateSelectionState();
    end

    function onNextPage(~, ~)
        totalPages = max(1, ceil(height(state.visibleProjects) / state.pageSize));
        if state.currentPage >= totalPages
            return;
        end
        state.currentPage = state.currentPage + 1;
        updateProjectDisplayPage();
        applyProjectTableStyles();
        updateSelectionState();
    end

    function onPageSizeChanged(~, ~)
        state.pageSize = double(pageSizeDropDown.Value);
        syncPageToSelection();
        updateProjectDisplayPage();
        applyProjectTableStyles();
        updateSelectionState();
    end

    function onProjectSelected(~, event)
        if isempty(event.Indices)
            state.selectedRow = [];
            updateSelectionState();
            return;
        end

        state.selectedRow = localPageStartIndex() + event.Indices(1, 1) - 1;
        if isempty(state.visibleProjects) || height(state.visibleProjects) < state.selectedRow
            updateSelectionState();
            return;
        end

        if strcmp(state.entityMode, 'projects') && strcmp(state.sourceMode, 'local')
            state.catalogSettings.lastSelectedProjectMat = char(string(state.visibleProjects.project_mat_abs(state.selectedRow)));
            detecdiv_catalog_settings_set(state.catalogSettings);
        elseif strcmp(state.entityMode, 'projects')
            state.hubSettings.lastProjectId = char(string(state.visibleProjects.project_id(state.selectedRow)));
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
                projectMatPath = char(string(row.project_mat_abs));
            else
                [~, projectMatPath, resolutionInfo] = resolveSelectedHubProject();
            end

            if isempty(projectMatPath)
                if strcmp(state.sourceMode, 'hub')
                    error('%s', localHubResolutionMessage(char(string(row.name)), resolutionInfo));
                else
                    error('Could not resolve the project MAT path.');
                end
            end

            [shallowObj, loadedVarName] = localFindLoadedProjectByMatPath(projectMatPath);
            if ~isempty(shallowObj)
                refreshLoadedIndicators();
                setStatus(sprintf('Project already loaded in workspace as "%s".', loadedVarName));
                return;
            end

            progressDlg = showLoadProgress(projectMatPath);
            cleanupProgress = onCleanup(@() closeProgressDialog(progressDlg)); %#ok<NASGU>
            if strcmp(state.sourceMode, 'hub')
                [shallowObj, msg] = localShallowLoadResolved(projectMatPath, resolutionInfo);
            else
                [shallowObj, msg] = shallowLoad(projectMatPath);
            end
            if isempty(msg)
                msg = 'shallowLoad returned an empty project.';
            end
            if isempty(shallowObj)
                setStatus(msg);
                return;
            end
            if strcmp(state.sourceMode, 'hub')
                shallowObj = localApplyHubLoadMetadata(shallowObj, row, projectMatPath, resolutionInfo);
                shallowObj = detecdiv_hub_prepare_project_open(shallowObj, 'Hub', state.hubSettings);
            end

            varName = matlab.lang.makeValidName(char(string(row.name)));
            if isempty(varName)
                varName = 'project';
            end
            assignin('base', varName, shallowObj);
            localEmitWorkspaceChanged('projectLoaded', struct( ...
                'projectVar', varName, ...
                'projectMatPath', projectMatPath, ...
                'sourceMode', state.sourceMode));
            refreshLoadedIndicators();
            setStatus(sprintf('Project loaded into workspace as "%s".', varName));
        catch ME
            message = localErrorMessage(ME);
            uialert(fig, message, 'Load Project Failed');
            setStatus(['Load failed: ' message]);
        end
    end

    function refreshLoadedIndicators()
        try
            if isempty(state.projects)
                return;
            end
            updateProjectTableFromState();
            applyProjectTableStyles();
            updateSelectionState();
        catch
        end
    end

    function progressDlg = showLoadProgress(projectMatPath)
        progressDlg = [];
        try
            progressDlg = uiprogressdlg(fig, ...
                'Title', 'Loading Project', ...
                'Message', ['Loading ' char(string(projectMatPath))], ...
                'Indeterminate', 'on');
            drawnow;
        catch
            progressDlg = [];
        end
    end

    function closeProgressDialog(progressDlg)
        if isempty(progressDlg)
            return;
        end
        try
            if isvalid(progressDlg)
                close(progressDlg);
            end
        catch
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
            [mappedProjectDir, ~] = detecdiv_hub_apply_path_mapping(projectDir, state.hubSettings);
            if ~isempty(mappedProjectDir)
                projectDir = mappedProjectDir;
            end
            openPath(projectDir);
        else
            uialert(fig, 'Could not resolve a local folder for this hub project.', 'Open Failed');
        end
    end

    function onOpenPipeline2(~, ~)
        row = getSelectedProjectRow();
        if isempty(row)
            return;
        end

        try
            [shallowObj, ~] = ensureProjectLoadedForRun(row);
            pipeline2(shallowObj);
            setStatus(sprintf('Opened Run Pipeline for "%s" in existing project mode.', char(string(row.name))));
        catch ME
            uialert(fig, ME.message, 'Run Pipeline Failed');
            setStatus(['Run Pipeline failed: ' ME.message]);
        end
    end

    function onNewProjectInPipeline2(~, ~)
        try
            pipeline2();
            setStatus('Opened pipeline2 for a new project / raw data run.');
        catch ME
            uialert(fig, ME.message, 'Pipeline2 Failed');
            setStatus(['Pipeline2 failed: ' ME.message]);
        end
    end

    function onBatchNewProjects(~, ~)
        try
            syncHubSettingsFromControls();
            spec = localPromptBatchNewProjects(fig, state.sourceMode, state.catalogSettings, state.hubSettings);
            if isempty(spec)
                return;
            end

            setBusyState(true);
            cleanupBusy = onCleanup(@() setBusyState(false)); %#ok<NASGU>
            progressDlg = uiprogressdlg(fig, ...
                'Title', 'Creating Catalog Projects', ...
                'Message', 'Preparing projects...', ...
                'Indeterminate', 'off', ...
                'Value', 0);
            cleanupProgress = onCleanup(@() closeProgressDialog(progressDlg)); %#ok<NASGU>
            drawnow;

            created = repmat(struct('project', [], 'matPath', '', 'varName', ''), 0, 1);
            for i = 1:numel(spec.rawPaths)
                progressDlg.Value = (i - 1) / max(1, numel(spec.rawPaths));
                progressDlg.Message = sprintf('Creating project %d / %d...', i, numel(spec.rawPaths));
                drawnow;

                [shallowObj, matPath] = localCreateCatalogProjectFromRaw( ...
                    spec.outputDir, spec.projectNames{i}, spec.rawPaths{i}, spec.pipelineTemplatePath);
                varName = matlab.lang.makeValidName(char(string(shallowObj.io.file)));
                assignin('base', varName, shallowObj);
                created(end + 1) = struct('project', shallowObj, 'matPath', matPath, 'varName', varName); %#ok<AGROW>
            end
            localEmitWorkspaceChanged('projectsCreated', struct( ...
                'projectVars', {cellstr(string({created.varName}))}, ...
                'projectMatPaths', {cellstr(string({created.matPath}))}, ...
                'sourceMode', state.sourceMode));

            if strcmp(state.sourceMode, 'local')
                progressDlg.Message = 'Indexing local catalog...';
                progressDlg.Value = 0.92;
                drawnow;
                detecdiv_catalog_index_projects(spec.outputDir, state.catalogSettings.dbFile, 'Verbose', false);
                refreshProjectsTable();
                setStatus(sprintf('Created, loaded, and indexed %d local project(s).', numel(created)));
            else
                progressDlg.Message = 'Queueing Hub indexing...';
                progressDlg.Value = 0.92;
                drawnow;
                serverOutputDir = localMapCatalogOutputDirForHub(spec.outputDir, state.hubSettings);
                detecdiv_hub_request_index(serverOutputDir, state.hubSettings, ...
                    'HostScope', 'server', 'ClearExistingForRoot', false);
                refreshProjectsTable('PreserveStatus', true);
                setStatus(sprintf(['Created and loaded %d project(s). Hub indexing queued for %s; ' ...
                    'refresh after the worker completes.'], numel(created), serverOutputDir));
            end

            refreshLoadedIndicators();
        catch ME
            uialert(fig, localErrorMessage(ME), 'Batch Project Creation Failed');
            setStatus(['Batch project creation failed: ' localErrorMessage(ME)]);
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
        ipLocal.addParameter('ShowProgress', [], @(x)islogical(x) || isnumeric(x) || isempty(x));
        ipLocal.addParameter('ProgressMessage', '', @(x)ischar(x) || isstring(x));
        ipLocal.parse(varargin{:});
        preserveStatus = logical(ipLocal.Results.PreserveStatus);
        showProgress = ipLocal.Results.ShowProgress;
        if isempty(showProgress)
            showProgress = ~preserveStatus;
        else
            showProgress = logical(showProgress);
        end

        progressDlg = [];
        if showProgress
            progressDlg = showCatalogProgress(ipLocal.Results.ProgressMessage);
        end
        cleanupProgress = onCleanup(@() closeProgressDialog(progressDlg)); %#ok<NASGU>

        try
            if strcmp(state.sourceMode, 'local')
                if strcmp(state.entityMode, 'raw_datasets')
                    state.projects = localNormalizeLocalRawDatasets(table());
                    updateProjectTableFromState();
                    applyProjectTableStyles();
                    restorePreviousSelection();
                    updateSelectionState();
                    if ~preserveStatus
                        setStatus('Local raw dataset catalog is not implemented yet.');
                    end
                    return;
                end

                projects = localNormalizeLocalProjects( ...
                    detecdiv_catalog_list_projects(state.catalogSettings.dbFile));
                state.projects = projects;
                updateProjectTableFromState();
                applyProjectTableStyles();
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

            syncHubSettingsFromControls();
            detecdiv_hub_settings_set(state.hubSettings);
            refreshHubContext();
            if strcmp(state.entityMode, 'raw_datasets')
                projects = localNormalizeHubRawDatasets(detecdiv_hub_list_raw_datasets( ...
                    state.hubSettings, ...
                    'OwnerKey', state.hubSelectedOwnerKey, ...
                    'OwnedOnly', state.hubOwnedOnly, ...
                    'Search', state.searchText));
            else
                projects = localNormalizeHubProjects(detecdiv_hub_list_projects( ...
                    state.hubSettings, ...
                    'GroupId', state.hubSelectedGroupId, ...
                    'OwnerKey', state.hubSelectedOwnerKey, ...
                    'OwnedOnly', state.hubOwnedOnly, ...
                    'Search', state.searchText));
            end
            state.projects = projects;
            updateProjectTableFromState();
            applyProjectTableStyles();
            restorePreviousSelection();
            updateSelectionState();
            if ~preserveStatus
                if isempty(projects)
                    setStatus(sprintf('No %s returned by %s.', localEntityPluralLabel(state.entityMode), state.hubSettings.baseUrl));
                else
                    setStatus(sprintf('%d hub %s loaded from %s.', ...
                        height(projects), localEntityPluralLabel(state.entityMode), state.hubSettings.baseUrl));
                end
            end
        catch ME
            state.projects = table();
            state.visibleProjects = table();
            state.displayProjects = table();
            projectTable.Data = table();
            applyProjectTableStyles();
            state.selectedRow = [];
            updateSelectionState();
            if ~preserveStatus
                setStatus(['Refresh failed: ' ME.message]);
            end
        end
    end

    function progressDlg = showCatalogProgress(message)
        progressDlg = [];
        message = char(string(message));
        if isempty(strtrim(message))
            if strcmp(state.sourceMode, 'hub')
                if strcmp(state.entityMode, 'raw_datasets')
                    message = 'Loading Hub raw dataset catalog database...';
                else
                    message = 'Loading Hub project catalog database...';
                end
            elseif strcmp(state.entityMode, 'raw_datasets')
                message = 'Loading local raw dataset catalog database...';
            else
                message = 'Loading local project catalog database...';
            end
        end
        try
            progressDlg = uiprogressdlg(fig, ...
                'Title', 'Loading catalog', ...
                'Message', message, ...
                'Indeterminate', 'on', ...
                'Cancelable', 'off');
            drawnow;
        catch
            progressDlg = [];
        end
    end

    function updateProjectTableFromState()
        filteredProjects = localFilterProjects(state.projects, state.searchText);
        state.visibleProjects = localSortProjects(filteredProjects, state.sortVariable, state.sortAscending);
        state.lastVisibleProjectCount = height(state.visibleProjects);
        clampCurrentPage();
        updateProjectDisplayPage();
        syncSortControls();
    end

    function updateProjectDisplayPage()
        if isempty(state.visibleProjects) || height(state.visibleProjects) == 0
            state.displayProjects = table();
        else
            startIdx = localPageStartIndex();
            endIdx = min(height(state.visibleProjects), startIdx + state.pageSize - 1);
            state.displayProjects = state.visibleProjects(startIdx:endIdx, :);
        end
        displayTable = localBuildDisplayTable(state.displayProjects, state.sourceMode, state.hubSettings, state.entityMode);
        projectTable.Data = displayTable;
        projectTable.ColumnName = localDisplayColumnNames(displayTable);
        syncPageControls();
    end

    function applyProjectTableStyles()
        try
            removeStyle(projectTable);
            if ~strcmp(state.entityMode, 'projects')
                return;
            end
            loadedRows = localLoadedRows(state.displayProjects, state.sourceMode, state.hubSettings);
            if ~isempty(loadedRows)
                loadedStyle = uistyle('BackgroundColor', [0.83 0.94 0.86]);
                addStyle(projectTable, loadedStyle, 'row', loadedRows);
            end
        catch
        end
    end

    function restorePreviousSelection()
        state.selectedRow = [];
        if isempty(state.visibleProjects) || height(state.visibleProjects) == 0
            return;
        end

        if ~strcmp(state.entityMode, 'projects')
            return;
        elseif strcmp(state.sourceMode, 'local')
            wantedKey = char(string(state.catalogSettings.lastSelectedProjectMat));
            if isempty(wantedKey)
                return;
            end
            matchIdx = find(strcmp(string(state.visibleProjects.project_mat_abs), string(wantedKey)), 1, 'first');
        else
            wantedKey = char(string(state.hubSettings.lastProjectId));
            if isempty(wantedKey)
                return;
            end
            matchIdx = find(strcmp(string(state.visibleProjects.project_id), string(wantedKey)), 1, 'first');
        end
        if ~isempty(matchIdx)
            state.selectedRow = matchIdx;
            syncPageToSelection();
            updateProjectDisplayPage();
            applyProjectTableStyles();
        end
    end

    function clampCurrentPage()
        totalPages = max(1, ceil(height(state.visibleProjects) / state.pageSize));
        state.currentPage = max(1, min(state.currentPage, totalPages));
    end

    function syncPageToSelection()
        if isempty(state.selectedRow) || state.selectedRow < 1
            clampCurrentPage();
            return;
        end
        state.currentPage = max(1, ceil(double(state.selectedRow) / state.pageSize));
        clampCurrentPage();
    end

    function startIdx = localPageStartIndex()
        clampCurrentPage();
        startIdx = (state.currentPage - 1) * state.pageSize + 1;
    end

    function syncPageControls()
        totalRows = height(state.visibleProjects);
        totalPages = max(1, ceil(totalRows / state.pageSize));
        if totalRows == 0
            pageLabel.Text = ['Page 0 / 0 - 0 ' localEntityPluralLabel(state.entityMode)];
        else
            startIdx = localPageStartIndex();
            endIdx = min(totalRows, startIdx + state.pageSize - 1);
            pageLabel.Text = sprintf('Page %d / %d - %d-%d of %d', ...
                state.currentPage, totalPages, startIdx, endIdx, totalRows);
        end
        prevPageButton.Enable = onOff(totalRows > 0 && state.currentPage > 1);
        nextPageButton.Enable = onOff(totalRows > 0 && state.currentPage < totalPages);
        pageSizeDropDown.Value = state.pageSize;
    end

    function syncSortControls()
        syncEntitySortOptions();
        if ~strcmp(char(string(sortDropDown.Value)), state.sortVariable)
            sortDropDown.Value = state.sortVariable;
        end
        if state.sortAscending
            sortDirectionButton.Text = 'Asc';
        else
            sortDirectionButton.Text = 'Desc';
        end
    end

    function syncEntitySortOptions()
        if strcmp(state.entityMode, 'raw_datasets')
            sortDropDown.Items = {'Name', 'Created Date', 'Updated Date', 'Status', 'Completeness', 'Kind', 'Positions', 'Size', 'Owner'};
            sortDropDown.ItemsData = {'name', 'created_at', 'updated_at', 'status', 'completeness_status', 'dataset_kind', 'position_count', 'total_bytes', 'owner_user_key'};
            if ~ismember(state.sortVariable, sortDropDown.ItemsData)
                state.sortVariable = 'name';
            end
            return;
        end

        sortDropDown.Items = {'Name', 'Modified Date', 'Imported Date', 'Health', 'FOV', 'ROI', 'Runs', 'Missing Raw'};
        sortDropDown.ItemsData = {'name', 'project_mtime', 'created_at', 'health_status', 'fov_count', 'roi_count', 'pipeline_run_count', 'missing_raw_count'};
        if ~ismember(state.sortVariable, sortDropDown.ItemsData)
            state.sortVariable = 'name';
        end
    end

    function updateSelectionState()
        row = getSelectedProjectRow();
        hasRow = ~isempty(row);
        isProjectView = strcmp(state.entityMode, 'projects');

        loadButton.Enable = onOff(hasRow && isProjectView);
        openFolderButton.Enable = onOff(hasRow && isProjectView);
        pipeline2Button.Enable = onOff(hasRow && isProjectView);
        notesButton.Enable = onOff(hasRow && isProjectView && strcmp(state.sourceMode, 'hub'));
        groupButton.Enable = onOff(hasRow && isProjectView && strcmp(state.sourceMode, 'hub'));
        aclButton.Enable = onOff(hasRow && isProjectView && strcmp(state.sourceMode, 'hub'));
        addToGroupButton.Enable = onOff(hasRow && isProjectView && strcmp(state.sourceMode, 'hub'));

        if ~hasRow
            detailsArea.Value = {['No ' localEntitySingularLabel(state.entityMode) ' selected.']};
            return;
        end

        if ~isProjectView
            detailsArea.Value = localRawDatasetDetails(row, state.sourceMode);
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
                ['Modified date  : ' localTextOr(localDisplayDate(row.project_mtime), '<unknown>')]
                ['Imported date  : ' localTextOr(localDisplayDate(row.created_at), '<unknown>')]
                ['Last scan      : ' char(string(row.last_scan_at))]
                ' '
                ['Project MAT    : ' char(string(row.project_mat_abs))]
                ['Project folder : ' char(string(row.project_dir_abs))]
                ['Root folder    : ' char(string(row.root_abs_path))]
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
                ['Project dir    : ' localTextOr(localStructField(resolutionInfo, 'projectDirPath'), '<not resolved>')]
                ['Resolution     : ' localTextOr(localStructField(resolutionInfo, 'resolutionMethod'), '<none>')]
                ['Missing folder : ' localTextOr(localJoinTextList(localStructField(resolutionInfo, 'missingProjectFolders')), '<none>')]
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
        if isempty(state.visibleProjects) || height(state.visibleProjects) < state.selectedRow
            return;
        end
        row = state.visibleProjects(state.selectedRow, :);
    end

    function [projectDetail, projectMatPath, resolutionInfo] = resolveSelectedHubProject()
        row = getSelectedProjectRow();
        if isempty(row)
            error('No project selected.');
        end
        syncHubSettingsFromControls();
        projectDetail = detecdiv_hub_get_project(char(string(row.project_id)), state.hubSettings);
        [projectMatPath, resolutionInfo] = detecdiv_hub_resolve_project_location(projectDetail, state.hubSettings);
    end

    function syncHubSettingsFromControls()
        if ~strcmp(state.sourceMode, 'hub')
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
    end

    function [shallowObj, projectMatPath] = ensureProjectLoadedForRun(row)
        projectMatPath = '';
        if strcmp(state.sourceMode, 'local')
            projectMatPath = char(string(row.project_mat_abs));
        else
            [~, projectMatPath, resolutionInfo] = resolveSelectedHubProject();
        end
        if isempty(projectMatPath)
            if strcmp(state.sourceMode, 'hub')
                error('%s', localHubResolutionMessage(char(string(row.name)), resolutionInfo));
            else
                error('Could not resolve the project MAT path.');
            end
        end

        shallowObj = localFindLoadedProjectByMatPath(projectMatPath);
        if isempty(shallowObj)
            if strcmp(state.sourceMode, 'hub')
                [shallowObj, msg] = localShallowLoadResolved(projectMatPath, resolutionInfo);
            else
                [shallowObj, msg] = shallowLoad(projectMatPath);
            end
            if isempty(shallowObj)
                error('%s', msg);
            end
            if strcmp(state.sourceMode, 'hub')
                shallowObj = localApplyHubLoadMetadata(shallowObj, row, projectMatPath, resolutionInfo);
                shallowObj = detecdiv_hub_prepare_project_open(shallowObj, 'Hub', state.hubSettings);
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

    function [shallowObj, msg] = localShallowLoadResolved(projectMatPath, resolutionInfo)
        projectDirPath = char(string(localStructField(resolutionInfo, 'projectDirPath')));
        if ~isempty(projectDirPath)
            [shallowObj, msg] = shallowLoad(projectMatPath, 'ProjectDir', projectDirPath);
        else
            [shallowObj, msg] = shallowLoad(projectMatPath);
        end
    end

    function shallowObj = localApplyHubLoadMetadata(shallowObj, row, projectMatPath, resolutionInfo)
        if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
            return;
        end
        if ~isprop(shallowObj, 'runProfiles') || ~isstruct(shallowObj.runProfiles)
            shallowObj.runProfiles = struct();
        end
        if ~isfield(shallowObj.runProfiles, 'hub') || ~isstruct(shallowObj.runProfiles.hub)
            shallowObj.runProfiles.hub = struct();
        end
        shallowObj.runProfiles.hub.hubManaged = true;
        shallowObj.runProfiles.hub.hub_project_id = char(string(row.project_id));
        shallowObj.runProfiles.hub.project_id = char(string(row.project_id));
        shallowObj.runProfiles.hub.project_name = char(string(row.name));
        shallowObj.runProfiles.hub.project_mat_path = char(string(projectMatPath));
        shallowObj.runProfiles.hub.local_project_mat_path = char(string(projectMatPath));
        shallowObj.runProfiles.hub.project_dir_path = char(string(localStructField(resolutionInfo, 'projectDirPath')));
        shallowObj.runProfiles.hub.local_project_dir_path = shallowObj.runProfiles.hub.project_dir_path;
        shallowObj.runProfiles.hub.storage_is_shared_with_raw_dataset = true;
        shallowObj.runProfiles.hub.loaded_from_catalog_at = char(datetime('now'));
    end

    function launchSpec = choosePipeline2LaunchSpec(shallowObj, projectMatPath)
        launchSpec = struct();
        runs = localProjectPipelineRuns(shallowObj);
        hasRuns = ~isempty(runs);
        defaultPipelinePath = localProjectDefaultPipelinePath(shallowObj);
        hasDefaultPipeline = ~isempty(defaultPipelinePath);

        choices = {'Open project in pipeline2'};
        choiceKeys = {'project'};
        if hasDefaultPipeline
            choices{end + 1} = 'Open project with default pipeline template'; %#ok<AGROW>
            choiceKeys{end + 1} = 'defaultTemplate'; %#ok<AGROW>
        end
        choices{end + 1} = 'Choose pipeline template...';
        choiceKeys{end + 1} = 'chooseTemplate';
        if hasRuns
            choices{end + 1} = 'Reproduce existing run...'; %#ok<AGROW>
            choiceKeys{end + 1} = 'existingRun'; %#ok<AGROW>
        end

        [selectedIdx, ok] = listdlg( ...
            'PromptString', localPipeline2Prompt(projectMatPath), ...
            'SelectionMode', 'single', ...
            'ListString', choices, ...
            'ListSize', [430 180]);
        if ~ok || isempty(selectedIdx)
            launchSpec = [];
            return;
        end

        switch choiceKeys{selectedIdx}
            case 'project'
                return;
            case 'defaultTemplate'
                [pipeObj, jsonPath] = localLoadPipelineTemplate(defaultPipelinePath);
                launchSpec.pipeObj = pipeObj;
                launchSpec.pipelinePath = jsonPath;
            case 'chooseTemplate'
                [pipeObj, jsonPath] = choosePipelineTemplateForPipeline2(projectMatPath);
                if isempty(pipeObj)
                    launchSpec = [];
                    return;
                end
                launchSpec.pipeObj = pipeObj;
                launchSpec.pipelinePath = jsonPath;
            case 'existingRun'
                runObj = choosePipelineRunForPipeline2(runs);
                if isempty(runObj)
                    launchSpec = [];
                    return;
                end
                launchSpec.runObj = runObj;
        end
    end

    function [pipeObj, jsonPath] = choosePipelineTemplateForPipeline2(projectMatPath)
        pipeObj = [];
        jsonPath = '';
        startDir = fileparts(char(string(projectMatPath)));
        if isempty(startDir) || ~isfolder(startDir)
            startDir = pwd;
        end
        [fileName, folderName] = uigetfile({'*.json', 'Pipeline JSON (*.json)'}, ...
            'Select a pipeline template for pipeline2', startDir);
        if isequal(fileName, 0)
            return;
        end
        [pipeObj, jsonPath] = localLoadPipelineTemplate(fullfile(folderName, fileName));
    end

    function runObj = choosePipelineRunForPipeline2(runs)
        runObj = [];
        labels = localPipelineRunLabels(runs);
        [selectedIdx, ok] = listdlg( ...
            'PromptString', 'Select the existing run to use as a pipeline2 seed', ...
            'SelectionMode', 'single', ...
            'ListString', labels, ...
            'ListSize', [560 260]);
        if ~ok || isempty(selectedIdx)
            return;
        end
        runObj = runs(selectedIdx);
    end

    function refreshHubContext()
        if ~strcmp(state.sourceMode, 'hub')
            state.currentUser = struct();
            state.hubGroups = struct([]);
            state.hubUsers = struct([]);
            syncGroupDropDown();
            if isvalid(fig)
                currentUserLabel.Text = localCurrentUserLabel();
            end
            return;
        end

        state.currentUser = detecdiv_hub_get_current_user(state.hubSettings);
        groups = detecdiv_hub_list_project_groups(state.hubSettings);
        state.hubGroups = localEnsureStructArray(groups);
        users = detecdiv_hub_list_users(state.hubSettings);
        state.hubUsers = localEnsureStructArray(users);
        syncGroupDropDown();
        if isvalid(fig)
            currentUserLabel.Text = localCurrentUserLabel();
        end
    end

    function syncGroupDropDown()
        if strcmp(state.entityMode, 'raw_datasets')
            items = {'All raw datasets'};
        else
            items = {'All projects'};
        end
        itemsData = {''};
        for i = 1:numel(state.hubUsers)
            userKey = char(string(localStructField(state.hubUsers(i), 'user_key')));
            if isempty(userKey)
                continue;
            end
            items{end + 1} = ['Owner: ' localUserOptionLabel(state.hubUsers(i))]; %#ok<AGROW>
            itemsData{end + 1} = localOwnerFilterValue(userKey); %#ok<AGROW>
        end
        if strcmp(state.entityMode, 'projects')
            for i = 1:numel(state.hubGroups)
                items{end + 1} = ['Group: ' char(string(state.hubGroups(i).display_name))]; %#ok<AGROW>
                itemsData{end + 1} = localGroupFilterValue(state.hubGroups(i).id); %#ok<AGROW>
            end
        end
        groupDropDown.Items = items;
        groupDropDown.ItemsData = itemsData;
        selectedValue = localHubFilterValue(state.hubSelectedGroupId, state.hubSelectedOwnerKey);
        if isempty(selectedValue) || ~any(strcmp(itemsData, selectedValue))
            state.hubSelectedGroupId = '';
            state.hubSelectedOwnerKey = '';
            selectedValue = '';
        end
        groupDropDown.Value = selectedValue;
        ownedOnlyCheck.Value = logical(state.hubOwnedOnly);
    end

    function syncUiFromState()
        isLocal = strcmp(state.sourceMode, 'local');
        isProjectView = strcmp(state.entityMode, 'projects');
        if isLocal
            rootLabel.Text = 'Projects Root';
            rootEdit.Value = char(string(state.catalogSettings.defaultProjectRoot));
            if isProjectView
                sourceInfoLabel.Text = ['Local catalog. DB: ' char(string(state.catalogSettings.dbFile))];
                footerLabel.Text = 'Local SQLite mode uses only the local DB and local project paths.';
            else
                sourceInfoLabel.Text = 'Local raw dataset catalog is not implemented yet.';
                footerLabel.Text = 'Raw dataset browsing currently uses Hub data; local indexing will be added later.';
            end
        else
            rootLabel.Text = 'Remote Root';
            rootEdit.Value = char(string(state.hubSettings.defaultRemoteProjectRoot));
            sourceInfoLabel.Text = ['Hub connection: ' localCurrentUserLabel()];
            if isProjectView
                footerLabel.Text = ['Hub API mode uses server paths plus local mount mapping for loading .mat files.' ...
                    ' Local SQLite mode remains available in the same browser.'];
            else
                footerLabel.Text = 'Hub raw dataset mode lists catalogued raw datasets. Project creation and local dataset indexing will be added later.';
            end
        end

        baseUrlEdit.Value = char(string(state.hubSettings.baseUrl));
        userKeyEdit.Value = char(string(state.hubSettings.userKey));
        localMountEdit.Value = char(string(state.hubSettings.defaultLocalProjectRoot));
        sourceDropDown.Value = state.sourceMode;
        entityDropDown.Value = state.entityMode;
        searchEdit.Value = state.searchText;
        backgroundCheck.Value = logical(state.catalogSettings.backgroundIndexing);
        backgroundCheck.Enable = onOff(isLocal);
        baseUrlEdit.Editable = onOff(~isLocal);
        localMountEdit.Editable = onOff(~isLocal);
        userKeyEdit.Editable = onOff(~isLocal);
        passwordEdit.Editable = onOff(~isLocal);
        loginButton.Enable = onOff(~isLocal);
        logoutButton.Enable = onOff(~isLocal);
        groupDropDown.Enable = onOff(~isLocal);
        ownedOnlyCheck.Enable = onOff(~isLocal);
        refreshGroupsButton.Enable = onOff(~isLocal);
        newGroupButton.Enable = onOff(~isLocal);

        controlGrid.RowHeight = localHeaderRowHeights(isLocal);
        newProjectButton.Visible = 'off';
        batchNewButton.Visible = 'off';
        localSetVisible(baseUrlLabel, false);
        localSetVisible(baseUrlEdit, false);
        localSetVisible(localMountLabel, false);
        localSetVisible(localMountEdit, false);
        localSetVisible(userKeyLabel, false);
        localSetVisible(userKeyEdit, false);
        localSetVisible(passwordLabel, false);
        localSetVisible(passwordEdit, false);
        localSetVisible(currentUserTitleLabel, false);
        localSetVisible(currentUserLabel, false);
        localSetVisible(loginButton, false);
        localSetVisible(logoutButton, false);
        localSetVisible(groupLabel, ~isLocal);
        localSetVisible(groupDropDown, ~isLocal);
        localSetVisible(ownedOnlyCheck, ~isLocal);
        localSetVisible(refreshGroupsButton, ~isLocal);
        localSetVisible(addToGroupButton, ~isLocal);
        localSetVisible(newGroupButton, ~isLocal);
        localSetVisible(backgroundCheck, false);
        localSetVisible(indexButton, false);
        localSetVisible(rootLabel, false);
        localSetVisible(rootEdit, false);
        localSetVisible(browseButton, false);
        localSetVisible(saveRootButton, false);
        localSetVisible(sourceInfoLabel, true);
        localSetVisible(connectionSettingsButton, true);
        localSetVisible(refreshButton, true);

        browseButton.Text = ternaryText(isLocal, 'Browse...', 'Map...');
        sourceLabel.Text = 'Source';
        groupLabel.Text = ternaryText(isProjectView, 'Owner/Group', 'Owner');
        detailsTitleLabel.Text = [localEntityTitleLabel(state.entityMode) ' Details'];
        syncEntitySortOptions();
        currentUserLabel.Text = localCurrentUserLabel();
    end

    function setBusyState(tf)
        indexButton.Enable = onOff(~tf && strcmp(state.sourceMode, 'local'));
        refreshButton.Enable = 'on';
        browseButton.Enable = onOff(~tf);
        saveRootButton.Enable = onOff(~tf);
        backgroundCheck.Enable = onOff(strcmp(state.sourceMode, 'local') && ~tf);
        sourceDropDown.Enable = onOff(~tf);
        rootEdit.Editable = onOff(~tf);
        baseUrlEdit.Editable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        localMountEdit.Editable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        userKeyEdit.Editable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        passwordEdit.Editable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        loginButton.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        logoutButton.Enable = onOff(~tf && strcmp(state.sourceMode, 'hub'));
        entityDropDown.Enable = onOff(~tf);
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

        tokenLabel = localTokenLabel(state.hubSettings);
        if isempty(fieldnames(state.currentUser))
            if isempty(tokenLabel)
                label = 'Disconnected';
            else
                label = ['Connected, token ' tokenLabel];
            end
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
        if isempty(tokenLabel)
            label = [label ' - no token'];
        else
            label = [label ' - token ' tokenLabel];
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

    if nargout > 0
        varargout{1} = fig;
    end
end

function heights = localHeaderRowHeights(isLocal)
    if isLocal
        heights = {32, 0, 32, 0, 0};
    else
        heights = {32, 32, 32, 0, 0};
    end
end

function localSetVisible(component, tf)
    try
        if tf
            component.Visible = 'on';
        else
            component.Visible = 'off';
        end
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

function label = localTokenLabel(hubSettings)
    label = '';
    if ~isstruct(hubSettings) || ~isfield(hubSettings, 'sessionToken')
        return;
    end

    token = strtrim(char(string(hubSettings.sessionToken)));
    if isempty(token)
        return;
    end

    if numel(token) <= 18
        label = token;
    else
        label = [token(1:10) '...' token(end-5:end)];
    end
end

function hubSettings = localCompleteHubSettings(hubSettings)
    defaults = struct( ...
        'sourceMode', 'local', ...
        'baseUrl', 'http://detecdiv-hub.detecdiv.internal', ...
        'timeoutSeconds', 15, ...
        'userKey', '', ...
        'sessionToken', '', ...
        'authMode', '', ...
        'defaultRemoteProjectRoot', '', ...
        'defaultLocalProjectRoot', '', ...
        'storageRootMap', struct(), ...
        'pathPrefixMap', struct(), ...
        'lastProjectId', '');

    if ~isstruct(hubSettings)
        hubSettings = defaults;
        return;
    end

    if isfield(hubSettings, 'timeout') && ~isfield(hubSettings, 'timeoutSeconds')
        hubSettings.timeoutSeconds = hubSettings.timeout;
    end
    if isfield(hubSettings, 'pathMappings') && ~isfield(hubSettings, 'pathPrefixMap')
        hubSettings.pathPrefixMap = localPathMappingsToPrefixMap(hubSettings.pathMappings);
    end

    fields = fieldnames(defaults);
    for i = 1:numel(fields)
        key = fields{i};
        if ~isfield(hubSettings, key) || isempty(hubSettings.(key))
            hubSettings.(key) = defaults.(key);
        end
    end
end

function pathPrefixMap = localPathMappingsToPrefixMap(pathMappings)
    pathPrefixMap = struct();
    if ~isstruct(pathMappings)
        return;
    end
    for i = 1:numel(pathMappings)
        if ~isfield(pathMappings(i), 'remoteRoot') || ~isfield(pathMappings(i), 'localRoot')
            continue;
        end
        remotePrefix = char(string(pathMappings(i).remoteRoot));
        localPrefix = char(string(pathMappings(i).localRoot));
        if isempty(remotePrefix) || isempty(localPrefix)
            continue;
        end
        key = matlab.lang.makeValidName(['map_' num2str(i)]);
        pathPrefixMap.(key) = struct( ...
            'remotePrefix', remotePrefix, ...
            'localPrefix', localPrefix);
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

function datasets = localNormalizeLocalRawDatasets(items)
    %#ok<INUSD>
    datasets = table();
end

function datasets = localNormalizeHubRawDatasets(items)
    if isempty(items)
        datasets = table();
        return;
    end

    items = localUnwrapHubRawDatasetList(items);
    if isstruct(items)
        items = num2cell(items);
    end

    n = numel(items);
    datasetIds = strings(n, 1);
    externalKeys = strings(n, 1);
    names = strings(n, 1);
    statuses = strings(n, 1);
    completeness = strings(n, 1);
    kinds = strings(n, 1);
    microscopes = strings(n, 1);
    rawRoots = strings(n, 1);
    storageUris = strings(n, 1);
    localHints = strings(n, 1);
    projectCounts = nan(n, 1);
    positionCounts = nan(n, 1);
    totalBytes = zeros(n, 1);
    visibility = strings(n, 1);
    ownerKeys = strings(n, 1);
    createdAt = strings(n, 1);
    updatedAt = strings(n, 1);

    for i = 1:n
        item = items{i};
        metadata = struct();
        if isfield(item, 'metadata_json') && isstruct(item.metadata_json)
            metadata = item.metadata_json;
        elseif isfield(item, 'metadata') && isstruct(item.metadata)
            metadata = item.metadata;
        end
        owner = struct();
        if isfield(item, 'owner') && isstruct(item.owner)
            owner = item.owner;
        end

        datasetIds(i) = string(localStructFirstField(item, {'id', 'dataset_id', 'raw_dataset_id'}));
        externalKeys(i) = string(localStructFirstField(item, {'external_key', 'key'}));
        names(i) = string(localFirstNonEmpty( ...
            localStructFirstField(item, {'dataset_name', 'name', 'display_name', 'acquisition_label', 'external_key'}), ...
            localStructFirstField(metadata, {'dataset_name', 'name', 'display_name'})));
        statuses(i) = string(localStructFirstField(item, {'status', 'health_status'}));
        completeness(i) = string(localStructFirstField(item, {'completeness_status'}));
        kinds(i) = string(localFirstNonEmpty( ...
            localStructFirstField(item, {'dataset_kind', 'kind', 'type', 'modality', 'data_format'}), ...
            localStructFirstField(metadata, {'dataset_kind', 'kind', 'type', 'modality'})));
        microscopes(i) = string(localStructFirstField(item, {'microscope_name'}));
        rawRoots(i) = string(localFirstNonEmpty( ...
            localStructFirstField(item, {'raw_root', 'root_path', 'path', 'dataset_path'}), ...
            localStructFirstField(metadata, {'raw_root', 'root_path', 'path', 'dataset_path'})));
        storageUris(i) = string(localFirstNonEmpty( ...
            localStructFirstField(item, {'storage_uri', 'uri', 'archive_uri'}), ...
            localStructFirstField(metadata, {'storage_uri', 'uri'})));
        localHints(i) = string(localFirstNonEmpty( ...
            localStructFirstField(item, {'local_path_hint'}), ...
            localStructFirstField(metadata, {'local_path_hint', 'local_path'})));
        projectCounts(i) = localNumericFirstField(item, {'project_count', 'linked_project_count', 'projects_count'});
        positionCounts(i) = localNumericFirstField(item, {'position_count', 'positions_count'});
        totalBytes(i) = localNumericFirstField(item, {'total_bytes', 'size_bytes', 'bytes'});
        visibility(i) = string(localStructFirstField(item, {'visibility'}));
        ownerKeys(i) = string(localFirstNonEmpty( ...
            localStructFirstField(owner, {'user_key'}), ...
            localStructFirstField(item, {'owner_user_key', 'user_key'})));
        createdAt(i) = string(localStructFirstField(item, {'created_at', 'imported_at'}));
        updatedAt(i) = string(localStructFirstField(item, {'updated_at', 'last_scan_at'}));

        if strlength(names(i)) == 0
            [~, leaf] = fileparts(char(rawRoots(i)));
            names(i) = string(localTextOr(leaf, char(datasetIds(i))));
        end
    end

    datasets = table();
    datasets.dataset_id = datasetIds;
    datasets.external_key = externalKeys;
    datasets.name = names;
    datasets.status = statuses;
    datasets.completeness_status = completeness;
    datasets.dataset_kind = kinds;
    datasets.microscope_name = microscopes;
    datasets.raw_root = rawRoots;
    datasets.storage_uri = storageUris;
    datasets.local_path_hint = localHints;
    datasets.project_count = projectCounts;
    datasets.position_count = positionCounts;
    datasets.total_bytes = totalBytes;
    datasets.visibility = visibility;
    datasets.owner_user_key = ownerKeys;
    datasets.created_at = createdAt;
    datasets.updated_at = updatedAt;
end

function items = localUnwrapHubRawDatasetList(items)
    if ~isstruct(items) || numel(items) ~= 1
        return;
    end

    candidateFields = {'raw_datasets', 'datasets', 'items', 'results', 'data'};
    for i = 1:numel(candidateFields)
        fieldName = candidateFields{i};
        if isfield(items, fieldName) && ~isempty(items.(fieldName))
            items = items.(fieldName);
            return;
        end
    end
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
    fovCounts = nan(n, 1);
    roiCounts = nan(n, 1);
    classifierCounts = nan(n, 1);
    processorCounts = nan(n, 1);
    pipelineRunCounts = nan(n, 1);
    missingRawCounts = nan(n, 1);
    createdAt = strings(n, 1);
    updatedAt = strings(n, 1);

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
        fovCounts(i) = localNumericField(item, 'fov_count');
        roiCounts(i) = localNumericField(item, 'roi_count');
        classifierCounts(i) = localNumericField(item, 'classifier_count');
        processorCounts(i) = localNumericField(item, 'processor_count');
        pipelineRunCounts(i) = localNumericField(item, 'pipeline_run_count');
        missingRawCounts(i) = localNumericField(item, 'missing_raw_count');
        createdAt(i) = string(localStructField(item, 'created_at'));
        updatedAt(i) = string(localStructField(item, 'updated_at'));
    end

    projects = table();
    projects.project_id = projectIds;
    projects.name = names;
    projects.status = statuses;
    projects.health_status = health;
    projects.raw_status = repmat("unknown", n, 1);
    projects.fov_count = fovCounts;
    projects.roi_count = roiCounts;
    projects.classifier_count = classifierCounts;
    projects.processor_count = processorCounts;
    projects.pipeline_run_count = pipelineRunCounts;
    projects.missing_raw_count = missingRawCounts;
    projects.last_scan_at = updatedAt;
    projects.project_mtime = updatedAt;
    projects.created_at = createdAt;
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

function displayTable = localBuildDisplayTable(projects, sourceMode, hubSettings, entityMode)
    if isempty(projects)
        displayTable = table();
        return;
    end
    if nargin < 3
        hubSettings = struct();
    end
    if nargin < 4
        entityMode = 'projects';
    end

    if strcmp(entityMode, 'raw_datasets')
        displayTable = table();
        displayTable.Name = string(projects.name);
        displayTable.Status = string(projects.status);
        displayTable.Completeness = string(projects.completeness_status);
        displayTable.Kind = string(projects.dataset_kind);
        displayTable.Microscope = string(projects.microscope_name);
        displayTable.Positions = projects.position_count;
        displayTable.LinkedProjects = projects.project_count;
        displayTable.Size = localHumanBytesColumn(projects.total_bytes);
        displayTable.Owner = string(projects.owner_user_key);
        displayTable.UpdatedDate = localDisplayDateColumn(projects.updated_at);
        displayTable.ExternalKey = string(projects.external_key);
        return;
    end

    displayTable = table();
    displayTable.Name = string(projects.name);
    displayTable.Loaded = localLoadedLabels(projects, sourceMode, hubSettings);
    displayTable.Health = string(projects.health_status);
    displayTable.FOV = projects.fov_count;
    displayTable.ROI = projects.roi_count;
    displayTable.Runs = projects.pipeline_run_count;
    displayTable.MissingRaw = projects.missing_raw_count;
    displayTable.ModifiedDate = localDisplayDateColumn(projects.project_mtime);
    displayTable.ImportedDate = localDisplayDateColumn(projects.created_at);
end

function names = localDisplayColumnNames(displayTable)
    if isempty(displayTable) || ~istable(displayTable)
        names = {};
        return;
    end
    names = displayTable.Properties.VariableNames;
end

function out = localHumanBytesColumn(values)
    out = strings(size(values));
    for i = 1:numel(values)
        out(i) = string(localHumanBytes(values(i)));
    end
end

function out = localDisplayDateColumn(values)
    values = string(values);
    out = strings(size(values));
    for i = 1:numel(values)
        out(i) = string(localDisplayDate(values(i)));
    end
end

function txt = localDisplayDate(value)
    txt = '';
    raw = strtrim(char(string(value)));
    if isempty(raw)
        return;
    end

    try
        dt = datetime(raw, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    catch
        try
            dt = datetime(raw, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        catch
            try
                dt = datetime(raw);
            catch
                txt = raw;
                return;
            end
        end
    end

    txt = char(string(dt, 'yyyy-MM-dd HH:mm'));
end

function out = localFilterProjects(projects, searchText)
    out = projects;
    if isempty(projects) || height(projects) == 0
        return;
    end

    query = lower(strtrim(char(string(searchText))));
    if isempty(query)
        return;
    end

    keep = false(height(projects), 1);
    varNames = projects.Properties.VariableNames;
    for i = 1:height(projects)
        rowText = "";
        for j = 1:numel(varNames)
            value = projects.(varNames{j});
            try
                rowText = rowText + " " + string(value(i));
            catch
                try
                    rowText = rowText + " " + string(value{i});
                catch
                end
            end
        end
        keep(i) = contains(lower(rowText), query);
    end

    out = projects(keep, :);
end

function out = localSortProjects(projects, sortVariable, sortAscending)
    out = projects;
    if isempty(projects) || height(projects) == 0
        return;
    end

    sortVariable = char(string(sortVariable));
    if isempty(sortVariable) || ~ismember(sortVariable, projects.Properties.VariableNames)
        sortVariable = 'name';
    end
    if ~ismember(sortVariable, projects.Properties.VariableNames)
        return;
    end

    direction = 'ascend';
    if ~logical(sortAscending)
        direction = 'descend';
    end

    values = projects.(sortVariable);
    tempName = '__detecdiv_sort_key__';
    while ismember(tempName, projects.Properties.VariableNames)
        tempName = [tempName '_'];
    end

    try
        if iscell(values)
            values = string(values);
        end
        if isstring(values) || ischar(values) || iscategorical(values)
            sortValues = lower(string(values));
        elseif isdatetime(values) || isnumeric(values) || islogical(values)
            sortValues = values;
        else
            sortValues = string(values);
        end
        out = projects;
        out.(tempName) = sortValues;
        out = sortrows(out, tempName, direction);
        out.(tempName) = [];
    catch
        try
            out = sortrows(projects, sortVariable, direction);
        catch
            out = projects;
        end
    end
end

function value = localStructField(in, fieldName)
    value = '';
    if isstruct(in) && isfield(in, fieldName)
        value = in.(fieldName);
    end
end

function value = localStructFirstField(in, fieldNames)
    value = '';
    if ~isstruct(in)
        return;
    end
    for i = 1:numel(fieldNames)
        fieldName = char(string(fieldNames{i}));
        if isfield(in, fieldName) && ~isempty(in.(fieldName))
            value = in.(fieldName);
            return;
        end
    end
end

function value = localFirstNonEmpty(varargin)
    value = '';
    for i = 1:nargin
        candidate = varargin{i};
        if isempty(candidate)
            continue;
        end
        if strlength(string(candidate)) > 0
            value = candidate;
            return;
        end
    end
end

function value = localNumericField(in, fieldName)
    value = 0;
    if isstruct(in) && isfield(in, fieldName) && ~isempty(in.(fieldName))
        value = double(in.(fieldName));
    end
end

function value = localNumericFirstField(in, fieldNames)
    value = 0;
    if ~isstruct(in)
        return;
    end
    for i = 1:numel(fieldNames)
        fieldName = char(string(fieldNames{i}));
        if isfield(in, fieldName) && ~isempty(in.(fieldName))
            try
                value = double(in.(fieldName));
                return;
            catch
            end
        end
    end
end

function mode = localNormalizeEntityMode(mode)
    mode = char(lower(strtrim(string(mode))));
    switch mode
        case {'raw_datasets', 'raw-datasets', 'datasets', 'dataset', 'raw dataset', 'raw datasets'}
            mode = 'raw_datasets';
        otherwise
            mode = 'projects';
    end
end

function label = localEntityPluralLabel(entityMode)
    if strcmp(localNormalizeEntityMode(entityMode), 'raw_datasets')
        label = 'raw dataset(s)';
    else
        label = 'project(s)';
    end
end

function label = localEntitySingularLabel(entityMode)
    if strcmp(localNormalizeEntityMode(entityMode), 'raw_datasets')
        label = 'raw dataset';
    else
        label = 'project';
    end
end

function label = localEntityTitleLabel(entityMode)
    if strcmp(localNormalizeEntityMode(entityMode), 'raw_datasets')
        label = 'Raw Dataset';
    else
        label = 'Project';
    end
end

function lines = localRawDatasetDetails(row, sourceMode)
    sourceLabel = 'local catalog';
    if strcmp(sourceMode, 'hub')
        sourceLabel = 'hub API';
    end
    lines = {
        ['Source         : ' sourceLabel]
        ['Dataset id     : ' char(string(localTableField(row, 'dataset_id')))]
        ['Name           : ' char(string(localTableField(row, 'name')))]
        ['External key   : ' char(string(localTableField(row, 'external_key')))]
        ['Status         : ' char(string(localTableField(row, 'status')))]
        ['Completeness   : ' char(string(localTableField(row, 'completeness_status')))]
        ['Kind           : ' char(string(localTableField(row, 'dataset_kind')))]
        ['Microscope     : ' char(string(localTableField(row, 'microscope_name')))]
        ['Visibility     : ' char(string(localTableField(row, 'visibility')))]
        ['Owner          : ' char(string(localTableField(row, 'owner_user_key')))]
        ['Positions      : ' char(string(localTableField(row, 'position_count')))]
        ['Linked projects: ' char(string(localTableField(row, 'project_count')))]
        ['Total size     : ' localHumanBytes(localTableNumericField(row, 'total_bytes'))]
        ['Created date   : ' localTextOr(localDisplayDate(localTableField(row, 'created_at')), '<unknown>')]
        ['Updated date   : ' localTextOr(localDisplayDate(localTableField(row, 'updated_at')), '<unknown>')]
        ' '
        ['Raw root       : ' char(string(localTableField(row, 'raw_root')))]
        ['Storage URI    : ' char(string(localTableField(row, 'storage_uri')))]
        ['Local hint     : ' char(string(localTableField(row, 'local_path_hint')))]
        };
end

function value = localTableField(row, fieldName)
    value = '';
    fieldName = char(string(fieldName));
    if istable(row) && ismember(fieldName, row.Properties.VariableNames)
        column = row.(fieldName);
        try
            value = column(1);
        catch
            try
                value = column{1};
            catch
            end
        end
    end
end

function value = localTableNumericField(row, fieldName)
    value = 0;
    raw = localTableField(row, fieldName);
    try
        value = double(raw);
    catch
        value = 0;
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

function msg = localHubResolutionMessage(projectLabel, resolutionInfo)
    projectLabel = char(string(projectLabel));
    if isempty(projectLabel)
        projectLabel = 'selected hub project';
    end
    msg = sprintf('Could not resolve a complete local project for "%s".', projectLabel);
    candidates = localJoinTextList(localStructField(resolutionInfo, 'candidatePaths'));
    missingFolders = localJoinTextList(localStructField(resolutionInfo, 'missingProjectFolders'));
    if ~isempty(missingFolders)
        msg = sprintf('%s Found .mat file(s), but missing project folder(s): %s', msg, missingFolders);
    elseif ~isempty(candidates)
        msg = sprintf('%s Candidate .mat path(s): %s', msg, candidates);
    end
end

function out = localJoinTextList(values)
    out = '';
    if isempty(values)
        return;
    end
    try
        if iscell(values)
            values = string(values);
        else
            values = string(values);
        end
        values = values(:);
        values(values == "") = [];
        if isempty(values)
            return;
        end
        out = strjoin(cellstr(values), ' | ');
    catch
        out = char(string(values));
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

function message = localErrorMessage(ME)
    message = char(string(ME.message));
    if isempty(message)
        message = getReport(ME, 'basic', 'hyperlinks', 'off');
    end
    if isempty(strtrim(message))
        message = 'MATLAB raised an error without a message.';
    end
end

function labels = localLoadedLabels(projects, sourceMode, hubSettings)
    if isempty(projects)
        labels = strings(0, 1);
        return;
    end
    if nargin < 2
        sourceMode = 'local';
    end
    if nargin < 3
        hubSettings = struct();
    end

    labels = strings(height(projects), 1);
    for i = 1:height(projects)
        labels(i) = string(localYesNo(localProjectLoadedPath( ...
            localLoadedComparableMatPath(projects(i, :), sourceMode, hubSettings))));
    end
end

function rows = localLoadedRows(projects, sourceMode, hubSettings)
    rows = [];
    if isempty(projects)
        return;
    end
    if nargin < 3
        hubSettings = struct();
    end

    for i = 1:height(projects)
        if localProjectLoadedPath(localLoadedComparableMatPath(projects(i, :), sourceMode, hubSettings))
            rows(end+1) = i; %#ok<AGROW>
        end
    end
end

function projectMatPath = localLoadedComparableMatPath(projectRow, sourceMode, hubSettings)
    projectMatPath = char(string(projectRow.project_mat_abs));
    if strcmp(sourceMode, 'hub') && ~isempty(projectMatPath)
        [mappedPath, ~] = detecdiv_hub_apply_path_mapping(projectMatPath, hubSettings);
        if ~isempty(mappedPath)
            projectMatPath = mappedPath;
        end
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
        loadedFile = localNormalizeLoadedFileName(tmp.io.file);
        if strcmp(loadedPath, expectedPath) && strcmp(loadedFile, expectedFile)
            tf = true;
            return;
        end
    end
end

function fileName = localNormalizeLoadedFileName(fileIn)
    fileName = lower(char(string(fileIn)));
    [~, ~, ext] = fileparts(fileName);
    if isempty(ext)
        fileName = [fileName '.mat'];
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

function label = localUserOptionLabel(userInfo)
    displayName = char(string(localStructField(userInfo, 'display_name')));
    userKey = char(string(localStructField(userInfo, 'user_key')));
    if isempty(displayName)
        label = localTextOr(userKey, '<unknown>');
    elseif isempty(userKey) || strcmp(displayName, userKey)
        label = displayName;
    else
        label = sprintf('%s (%s)', displayName, userKey);
    end
end

function value = localOwnerFilterValue(userKey)
    value = ['owner:' char(string(userKey))];
end

function value = localGroupFilterValue(groupId)
    value = ['group:' char(string(groupId))];
end

function value = localHubFilterValue(groupId, ownerKey)
    groupId = char(string(groupId));
    ownerKey = char(string(ownerKey));
    if ~isempty(ownerKey)
        value = localOwnerFilterValue(ownerKey);
    elseif ~isempty(groupId)
        value = localGroupFilterValue(groupId);
    else
        value = '';
    end
end

function [groupId, ownerKey] = localParseHubFilterValue(rawValue)
    groupId = '';
    ownerKey = '';
    rawValue = char(string(rawValue));
    if startsWith(rawValue, 'owner:')
        ownerKey = extractAfter(rawValue, strlength('owner:'));
        ownerKey = char(string(ownerKey));
    elseif startsWith(rawValue, 'group:')
        groupId = extractAfter(rawValue, strlength('group:'));
        groupId = char(string(groupId));
    elseif ~isempty(rawValue)
        groupId = rawValue;
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

function [shallowObj, loadedVarName] = localFindLoadedProjectByMatPath(projectMatPath)
    shallowObj = [];
    loadedVarName = '';
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
        loadedFile = localNormalizeLoadedFileName(tmp.io.file);
        if strcmp(loadedPath, expectedPath) && strcmp(loadedFile, expectedFile)
            shallowObj = tmp;
            loadedVarName = varName;
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

function prompt = localPipeline2Prompt(projectMatPath)
    projectMatPath = char(string(projectMatPath));
    if isempty(projectMatPath)
        prompt = 'Choose how pipeline2 should open this catalog project';
    else
        prompt = sprintf('Choose how pipeline2 should open this catalog project:\n%s', projectMatPath);
    end
end

function [pipeObj, jsonPath] = localLoadPipelineTemplate(jsonPath)
    pipeObj = [];
    jsonPath = char(string(jsonPath));
    if isempty(jsonPath) || exist(jsonPath, 'file') ~= 2
        error('detecdivCatalogBrowser:MissingPipelineTemplate', ...
            'Pipeline template not found: %s', jsonPath);
    end

    [pipeObj, msg] = pipelineLoad(jsonPath);
    if isempty(pipeObj)
        error('detecdivCatalogBrowser:PipelineLoadFailed', '%s', msg);
    end
end

function localEmitWorkspaceChanged(action, payload)
    if nargin < 2 || isempty(payload) || ~isstruct(payload)
        payload = struct();
    end
    payload.source = 'catalog';
    payload.action = char(string(action));
    payload.timestamp = char(datetime('now'));
    try
        detecdiv_event('emit', 'workspaceChanged', payload);
    catch ME
        warning('detecdivCatalogBrowser:WorkspaceEventFailed', ...
            'Could not emit workspaceChanged event: %s', ME.message);
    end
end

function spec = localPromptBatchNewProjects(parentFig, sourceMode, catalogSettings, hubSettings)
    spec = [];
    outputDefault = '';
    if strcmp(sourceMode, 'hub')
        outputDefault = char(string(hubSettings.defaultLocalProjectRoot));
    end
    if isempty(outputDefault)
        outputDefault = char(string(catalogSettings.defaultProjectRoot));
    end
    if isempty(outputDefault) || ~isfolder(outputDefault)
        outputDefault = pwd;
    end

    pipelineChoices = localCatalogPipelineTemplateChoices();

    dlg = uifigure( ...
        'Name', 'Create Catalog Projects', ...
        'Position', [220 180 900 520], ...
        'WindowStyle', 'modal', ...
        'Color', [0.98 0.98 0.98]);
    dlg.UserData = [];
    if ~isempty(parentFig)
        try
            dlg.Icon = parentFig.Icon;
        catch
        end
    end

    grid = uigridlayout(dlg, [6 4]);
    grid.RowHeight = {26, 32, 32, '1x', 34, 38};
    grid.ColumnWidth = {105, '1x', 110, 110};
    grid.Padding = [14 14 14 14];
    grid.RowSpacing = 8;
    grid.ColumnSpacing = 8;

    modeLabel = uilabel(grid, ...
        'Text', ['Mode: ' upper(char(string(sourceMode)))], ...
        'FontWeight', 'bold');
    modeLabel.Layout.Row = 1;
    modeLabel.Layout.Column = [1 4];

    outputLabel = uilabel(grid, 'Text', 'Output dir', 'FontWeight', 'bold');
    outputLabel.Layout.Row = 2;
    outputLabel.Layout.Column = 1;

    outputEdit = uieditfield(grid, 'text', 'Value', outputDefault);
    outputEdit.Layout.Row = 2;
    outputEdit.Layout.Column = 2;

    browseOutputButton = uibutton(grid, 'push', 'Text', 'Browse...', ...
        'ButtonPushedFcn', @browseOutput);
    browseOutputButton.Layout.Row = 2;
    browseOutputButton.Layout.Column = 3;

    pipelineLabel = uilabel(grid, 'Text', 'Template', 'FontWeight', 'bold');
    pipelineLabel.Layout.Row = 3;
    pipelineLabel.Layout.Column = 1;

    pipelineDrop = uidropdown(grid, ...
        'Items', pipelineChoices.labels, ...
        'ItemsData', pipelineChoices.paths, ...
        'Value', pipelineChoices.paths{1}, ...
        'ValueChangedFcn', @onPipelineChoiceChanged);
    pipelineDrop.Layout.Row = 3;
    pipelineDrop.Layout.Column = [2 3];

    browsePipelineButton = uibutton(grid, 'push', 'Text', 'Browse...', ...
        'ButtonPushedFcn', @browsePipeline);
    browsePipelineButton.Layout.Row = 3;
    browsePipelineButton.Layout.Column = 4;

    data = cell(0, 2);
    rawTable = uitable(grid, ...
        'Data', data, ...
        'ColumnName', {'Raw dataset path', 'Project name'}, ...
        'ColumnEditable', [true true], ...
        'ColumnWidth', {560, 210});
    rawTable.Layout.Row = 4;
    rawTable.Layout.Column = [1 4];

    addRowButton = uibutton(grid, 'push', 'Text', 'Add Row', ...
        'ButtonPushedFcn', @addRow);
    addRowButton.Layout.Row = 5;
    addRowButton.Layout.Column = 1;

    addPathButton = uibutton(grid, 'push', 'Text', 'Add Path...', ...
        'ButtonPushedFcn', @addPath);
    addPathButton.Layout.Row = 5;
    addPathButton.Layout.Column = 2;

    removeRowButton = uibutton(grid, 'push', 'Text', 'Remove Empty', ...
        'ButtonPushedFcn', @removeEmptyRows);
    removeRowButton.Layout.Row = 5;
    removeRowButton.Layout.Column = 3;

    cancelButton = uibutton(grid, 'push', 'Text', 'Cancel', ...
        'ButtonPushedFcn', @cancelDialog);
    cancelButton.Layout.Row = 6;
    cancelButton.Layout.Column = 3;

    okButton = uibutton(grid, 'push', 'Text', 'OK', ...
        'ButtonPushedFcn', @okDialog);
    okButton.Layout.Row = 6;
    okButton.Layout.Column = 4;

    waitfor(dlg, 'UserData');
    if isvalid(dlg)
        spec = dlg.UserData;
        if isstruct(spec) && isfield(spec, 'cancelled') && spec.cancelled
            spec = [];
        end
        delete(dlg);
    end

    function browseOutput(varargin)
        startDir = char(string(outputEdit.Value));
        if isempty(startDir) || ~isfolder(startDir)
            startDir = pwd;
        end
        picked = uigetdir(startDir, 'Select project output folder');
        if isequal(picked, 0)
            return;
        end
        outputEdit.Value = picked;
    end

    function browsePipeline(varargin)
        [fileName, folderName] = uigetfile({'*.json', 'Pipeline JSON (*.json)'}, ...
            'Select pipeline template', pwd);
        if isequal(fileName, 0)
            return;
        end
        jsonPath = fullfile(folderName, fileName);
        pipelineDrop.Items = [{'None'}, {localPipelineChoiceLabel(jsonPath)}];
        pipelineDrop.ItemsData = {'', jsonPath};
        pipelineDrop.Value = jsonPath;
    end

    function onPipelineChoiceChanged(~, ~)
        if strcmp(char(string(pipelineDrop.Value)), '__browse__')
            browsePipeline();
        end
    end

    function addRow(~, ~)
        dataNow = rawTable.Data;
        dataNow(end + 1, :) = {'', ''};
        rawTable.Data = dataNow;
    end

    function addPath(~, ~)
        startDir = char(string(outputEdit.Value));
        if isempty(startDir) || ~isfolder(startDir)
            startDir = pwd;
        end
        picked = uigetdir(startDir, 'Select raw dataset folder');
        if isequal(picked, 0)
            return;
        end
        dataNow = rawTable.Data;
        dataNow(end + 1, :) = {picked, localProjectNameFromRawPath(picked)};
        rawTable.Data = dataNow;
    end

    function removeEmptyRows(~, ~)
        dataNow = rawTable.Data;
        if isempty(dataNow)
            return;
        end
        keep = false(size(dataNow, 1), 1);
        for ii = 1:size(dataNow, 1)
            keep(ii) = ~isempty(strtrim(char(string(dataNow{ii, 1})))) || ...
                ~isempty(strtrim(char(string(dataNow{ii, 2}))));
        end
        rawTable.Data = dataNow(keep, :);
    end

    function cancelDialog(~, ~)
        dlg.UserData = struct('cancelled', true);
    end

    function okDialog(~, ~)
        try
            outDir = strtrim(char(string(outputEdit.Value)));
            if isempty(outDir)
                error('Output dir is required.');
            end
            if ~isfolder(outDir)
                mkdir(outDir);
            end

            dataNow = rawTable.Data;
            rawPaths = {};
            projectNames = {};
            for ii = 1:size(dataNow, 1)
                rawPath = strtrim(char(string(dataNow{ii, 1})));
                projectName = strtrim(char(string(dataNow{ii, 2})));
                if isempty(rawPath)
                    continue;
                end
                if ~isfolder(rawPath) && ~isfile(rawPath)
                    error('Raw dataset path does not exist: %s', rawPath);
                end
                if isempty(projectName)
                    projectName = localProjectNameFromRawPath(rawPath);
                end
                rawPaths{end + 1} = rawPath; %#ok<AGROW>
                projectNames{end + 1} = matlab.lang.makeValidName(projectName); %#ok<AGROW>
            end
            if isempty(rawPaths)
                error('Add at least one raw dataset path.');
            end
            if numel(unique(string(projectNames))) ~= numel(projectNames)
                error('Project names must be unique within the batch.');
            end

            templatePath = char(string(pipelineDrop.Value));
            if strcmp(templatePath, '__browse__')
                templatePath = '';
            end
            dlg.UserData = struct( ...
                'outputDir', outDir, ...
                'rawPaths', {rawPaths}, ...
                'projectNames', {projectNames}, ...
                'pipelineTemplatePath', templatePath);
        catch ME
            uialert(dlg, ME.message, 'Invalid Batch Project Definition');
        end
    end
end

function choices = localCatalogPipelineTemplateChoices()
    labels = {'None'};
    paths = {''};

    repoDir = fileparts(fileparts(mfilename('fullpath')));
    candidates = {};
    recentFile = fullfile(repoDir, 'recentPipelines.mat');
    if exist(recentFile, 'file') == 2
        try
            S = load(recentFile);
            names = fieldnames(S);
            for i = 1:numel(names)
                value = S.(names{i});
                if iscell(value) || isstring(value)
                    candidates = [candidates; cellstr(string(value(:)))]; %#ok<AGROW>
                end
            end
        catch
        end
    end
    candidates = [candidates; cellstr(string(localFindPipelineJsonCandidates(repoDir)))]; %#ok<AGROW>
    candidates = unique(string(candidates), 'stable');
    candidates(candidates == "") = [];

    for i = 1:numel(candidates)
        p = char(candidates(i));
        if exist(p, 'file') ~= 2
            continue;
        end
        labels{end + 1} = localPipelineChoiceLabel(p); %#ok<AGROW>
        paths{end + 1} = p; %#ok<AGROW>
        if numel(paths) >= 12
            break;
        end
    end
    labels{end + 1} = 'Browse...';
    paths{end + 1} = '__browse__';
    choices = struct('labels', {labels}, 'paths', {paths});
end

function paths = localFindPipelineJsonCandidates(repoDir)
    paths = strings(0, 1);
    roots = [ ...
        string(fullfile(repoDir, 'pipeline_templates'))
        string(fullfile(repoDir, 'pipelines'))
        string(fullfile(repoDir, 'catalog'))];
    for i = 1:numel(roots)
        if ~isfolder(roots(i))
            continue;
        end
        listing = dir(fullfile(char(roots(i)), '**', 'pipeline.json'));
        for j = 1:numel(listing)
            paths(end + 1, 1) = string(fullfile(listing(j).folder, listing(j).name)); %#ok<AGROW>
        end
    end
end

function label = localPipelineChoiceLabel(jsonPath)
    [folderName, fileName, ext] = fileparts(char(string(jsonPath)));
    [~, parentName] = fileparts(folderName);
    if isempty(parentName)
        label = [fileName ext];
    else
        label = sprintf('%s/%s%s', parentName, fileName, ext);
    end
end

function [shallowObj, matPath] = localCreateCatalogProjectFromRaw(outputDir, projectName, rawPath, pipelineTemplatePath)
    outputDir = char(string(outputDir));
    projectName = matlab.lang.makeValidName(char(string(projectName)));
    rawPath = char(string(rawPath));
    if isempty(projectName)
        projectName = localProjectNameFromRawPath(rawPath);
    end

    matPath = fullfile(outputDir, [projectName '.mat']);
    if exist(matPath, 'file') == 2
        error('Project MAT already exists: %s', matPath);
    end

    projectDir = fullfile(outputDir, projectName);
    if ~isfolder(projectDir)
        mkdir(projectDir);
    end

    shallowObj = shallow();
    shallowObj.setPath(outputDir, projectName);
    shallowObj.tag = 'shallow project';
    shallowObj.runProfiles.catalog = struct( ...
        'createdFromCatalog', true, ...
        'rawDataPath', rawPath, ...
        'createdAt', char(datetime('now')));
    shallowObj.addData(rawPath);
    if localProjectHasNoParsedFov(shallowObj)
        error('Raw dataset could not be parsed into any FOV: %s', rawPath);
    end

    if ~isempty(pipelineTemplatePath)
        [pipeObj, jsonPath] = localLoadPipelineTemplate(pipelineTemplatePath);
        shallowObj.runProfiles.pipeline = struct( ...
            'defaultTemplatePath', jsonPath, ...
            'defaultTemplateId', char(string(pipeObj.strid)), ...
            'assignedFromCatalog', true, ...
            'assignedAt', char(datetime('now')));
    end

    shallowSave(shallowObj, 'shallowObj');
    matPath = fullfile(outputDir, [projectName '.mat']);
end

function tf = localProjectHasNoParsedFov(shallowObj)
    tf = true;
    try
        if isempty(shallowObj) || ~isa(shallowObj, 'shallow') || isempty(shallowObj.fov)
            return;
        end
        if numel(shallowObj.fov) == 1
            f = shallowObj.fov(1);
            hasSrcList = isprop(f, 'srclist') && ~isempty(f.srclist);
            hasSrcPath = isprop(f, 'srcpath') && ~isempty(f.srcpath);
            if ~hasSrcList && ~hasSrcPath
                return;
            end
        end
        tf = false;
    catch
        tf = true;
    end
end

function projectName = localProjectNameFromRawPath(rawPath)
    rawPath = regexprep(char(string(rawPath)), '[\\\/]+$', '');
    [~, projectName] = fileparts(rawPath);
    if isempty(projectName)
        projectName = 'project';
    end
    projectName = matlab.lang.makeValidName(projectName);
end

function serverOutputDir = localMapCatalogOutputDirForHub(outputDir, hubSettings)
    ctx = struct('hub', hubSettings);
    [serverOutputDir, mapped] = detecdiv_paths_map_module_path(outputDir, ctx, 'server');
    if ~mapped
        error('detecdivCatalogBrowser:HubOutputNotMapped', ...
            ['Could not map output dir to a server path for Hub indexing: %s\n' ...
             'Set Remote Root / Local Mount in the catalog header first.'], char(string(outputDir)));
    end
end

function runs = localProjectPipelineRuns(shallowObj)
    runs = [];
    try
        if isempty(shallowObj) || ~isa(shallowObj, 'shallow') || ...
                ~isprop(shallowObj, 'processing') || ~isstruct(shallowObj.processing) || ...
                ~isfield(shallowObj.processing, 'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
            return;
        end

        rawRuns = shallowObj.processing.pipelineRun;
        if isa(rawRuns, 'pipelineRun')
            runs = rawRuns;
            return;
        end
        if iscell(rawRuns)
            keep = cellfun(@(x) isa(x, 'pipelineRun'), rawRuns);
            rawRuns = rawRuns(keep);
            if isempty(rawRuns)
                return;
            end
            runs = [rawRuns{:}];
        end
    catch
        runs = [];
    end
end

function labels = localPipelineRunLabels(runs)
    if isempty(runs)
        labels = {};
        return;
    end

    labels = cell(numel(runs), 1);
    for i = 1:numel(runs)
        runObj = runs(i);
        runId = localObjectTextProperty(runObj, 'runId', sprintf('run_%d', i));
        status = localObjectTextProperty(runObj, 'status', '');
        createdAt = localObjectTextProperty(runObj, 'createdAt', '');
        templateId = localObjectTextProperty(runObj, 'templateId', '');
        if isempty(templateId)
            try
                if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'id')
                    templateId = char(string(runObj.pipelineRef.id));
                end
            catch
            end
        end

        parts = {runId};
        if ~isempty(status)
            parts{end + 1} = ['status=' status]; %#ok<AGROW>
        end
        if ~isempty(templateId)
            parts{end + 1} = ['template=' templateId]; %#ok<AGROW>
        end
        if ~isempty(createdAt)
            parts{end + 1} = ['created=' createdAt]; %#ok<AGROW>
        end
        labels{i} = strjoin(parts, ' | ');
    end
end

function value = localObjectTextProperty(obj, propName, defaultValue)
    value = defaultValue;
    try
        if isprop(obj, propName)
            raw = obj.(propName);
            if ~isempty(raw)
                value = char(string(raw));
            end
        end
    catch
        value = defaultValue;
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
