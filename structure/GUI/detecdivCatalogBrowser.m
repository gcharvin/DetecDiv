function fig = detecdivCatalogBrowser(varargin)
% detecdivCatalogBrowser  Browse indexed DetecDiv projects and launch indexing jobs.

    ip = inputParser;
    ip.addParameter('RootPath', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('DbFile', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    settings = detecdiv_catalog_settings_get();
    if strlength(string(opts.RootPath)) > 0
        settings.defaultProjectRoot = char(string(opts.RootPath));
    end
    if strlength(string(opts.DbFile)) > 0
        settings.dbFile = char(string(opts.DbFile));
    end

    repoDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    detecdiv_catalog_init(settings.dbFile);

    state = struct();
    state.settings = settings;
    state.projects = table();
    state.selectedRow = [];
    state.job = [];
    state.pollTimer = [];
    state.lastVisibleProjectCount = 0;

    fig = uifigure( ...
        'Name', 'DetecDiv Catalog Browser', ...
        'Position', [100 100 1280 760], ...
        'Color', [0.98 0.98 0.98], ...
        'CloseRequestFcn', @onCloseFigure);

    mainGrid = uigridlayout(fig, [4 1]);
    mainGrid.RowHeight = {76, 28, '1x', 38};
    mainGrid.ColumnWidth = {'1x'};
    mainGrid.Padding = [14 14 14 14];
    mainGrid.RowSpacing = 10;

    controlGrid = uigridlayout(mainGrid, [2 7]);
    controlGrid.Layout.Row = 1;
    controlGrid.RowHeight = {24, 32};
    controlGrid.ColumnWidth = {90, '1x', 96, 116, 130, 110, 110};
    controlGrid.ColumnSpacing = 8;
    controlGrid.Padding = [0 0 0 0];

    rootLabel = uilabel(controlGrid, 'Text', 'Project Root', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
    rootLabel.Layout.Row = 1;
    rootLabel.Layout.Column = 1;

    dbLabel = uilabel(controlGrid, ...
        'Text', ['DB: ' state.settings.dbFile], ...
        'FontAngle', 'italic', ...
        'HorizontalAlignment', 'left');
    dbLabel.Layout.Row = 1;
    dbLabel.Layout.Column = [2 7];

    rootEdit = uieditfield(controlGrid, 'text', 'Value', state.settings.defaultProjectRoot);
    rootEdit.Layout.Row = 2;
    rootEdit.Layout.Column = 2;

    browseButton = uibutton(controlGrid, 'push', 'Text', 'Browse...', ...
        'ButtonPushedFcn', @onBrowseRoot);
    browseButton.Layout.Row = 2;
    browseButton.Layout.Column = 3;

    saveRootButton = uibutton(controlGrid, 'push', 'Text', 'Save Default', ...
        'ButtonPushedFcn', @onSaveDefaultRoot);
    saveRootButton.Layout.Row = 2;
    saveRootButton.Layout.Column = 4;

    backgroundCheck = uicheckbox(controlGrid, ...
        'Text', 'Background indexing', ...
        'Value', logical(state.settings.backgroundIndexing));
    backgroundCheck.Layout.Row = 2;
    backgroundCheck.Layout.Column = 5;

    indexButton = uibutton(controlGrid, 'push', 'Text', 'Index Root', ...
        'ButtonPushedFcn', @onIndexRoot);
    indexButton.Layout.Row = 2;
    indexButton.Layout.Column = 6;

    refreshButton = uibutton(controlGrid, 'push', 'Text', 'Refresh', ...
        'ButtonPushedFcn', @onRefreshProjects);
    refreshButton.Layout.Row = 2;
    refreshButton.Layout.Column = 7;

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

    actionGrid = uigridlayout(sideGrid, [1 3]);
    actionGrid.Layout.Row = 3;
    actionGrid.ColumnWidth = {'1x', '1x', '1x'};
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

    openMatButton = uibutton(actionGrid, 'push', 'Text', 'Open MAT', ...
        'Enable', 'off', 'ButtonPushedFcn', @onOpenMatFile);
    openMatButton.Layout.Row = 1;
    openMatButton.Layout.Column = 3;

    footerLabel = uilabel(mainGrid, ...
        'Text', 'Indexation on demand. Background mode uses a separate MATLAB batch job.', ...
        'HorizontalAlignment', 'left', ...
        'FontAngle', 'italic', ...
        'FontColor', [0.35 0.35 0.35]);
    footerLabel.Layout.Row = 4;

    refreshProjectsTable();

    function onBrowseRoot(~, ~)
        currentRoot = strtrim(rootEdit.Value);
        if isempty(currentRoot) || ~isfolder(currentRoot)
            currentRoot = pwd;
        end
        selectedRoot = uigetdir(currentRoot, 'Select DetecDiv project root');
        if isequal(selectedRoot, 0)
            return;
        end
        rootEdit.Value = char(selectedRoot);
    end

    function onSaveDefaultRoot(~, ~)
        rootPath = sanitizeRoot(rootEdit.Value);
        if isempty(rootPath)
            uialert(fig, 'Please choose a valid project root folder first.', ...
                'Invalid Folder');
            return;
        end

        state.settings.defaultProjectRoot = rootPath;
        state.settings.recentProjectRoots = updateRecentRoots(state.settings.recentProjectRoots, rootPath);
        state.settings.backgroundIndexing = logical(backgroundCheck.Value);
        detecdiv_catalog_settings_set(state.settings);
        setStatus(['Default project root saved: ' rootPath]);
    end

    function onIndexRoot(~, ~)
        rootPath = sanitizeRoot(rootEdit.Value);
        if isempty(rootPath)
            uialert(fig, 'Please choose a valid project root folder.', 'Invalid Folder');
            return;
        end

        state.settings.defaultProjectRoot = rootPath;
        state.settings.recentProjectRoots = updateRecentRoots(state.settings.recentProjectRoots, rootPath);
        state.settings.backgroundIndexing = logical(backgroundCheck.Value);
        detecdiv_catalog_settings_set(state.settings);

        if logical(backgroundCheck.Value)
            launchBackgroundIndex(rootPath);
        else
            runSynchronousIndex(rootPath);
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
        if height(state.projects) >= state.selectedRow
            state.settings.lastSelectedProjectMat = char(string(state.projects.project_mat_abs(state.selectedRow)));
            detecdiv_catalog_settings_set(state.settings);
        end
        updateSelectionState();
    end

    function onLoadProject(~, ~)
        row = getSelectedProjectRow();
        if isempty(row)
            return;
        end

        matPath = char(string(row.project_mat_abs));
        try
            [shallowObj, msg] = shallowLoad(matPath);
            if isempty(shallowObj)
                setStatus(msg);
                return;
            end

            varName = matlab.lang.makeValidName(['proj_' char(string(row.name))]);
            assignin('base', varName, shallowObj);
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
        openPath(char(string(row.project_dir_abs)));
    end

    function onOpenMatFile(~, ~)
        row = getSelectedProjectRow();
        if isempty(row)
            return;
        end
        openPath(char(string(row.project_mat_abs)));
    end

    function launchBackgroundIndex(rootPath)
        if ~isempty(state.job) && isvalidJob(state.job) && ~strcmpi(state.job.State, 'finished')
            uialert(fig, 'An indexing job is already running.', 'Indexing In Progress');
            return;
        end

        try
            cluster = parcluster('local');
            job = batch(cluster, @detecdiv_catalog_run_index_job, 1, ...
                {rootPath, state.settings.dbFile}, ...
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
            detecdiv_catalog_run_index_job(rootPath, state.settings.dbFile);
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

        projects = detecdiv_catalog_list_projects(state.settings.dbFile);
        state.projects = projects;
        state.lastVisibleProjectCount = height(projects);

        if isempty(projects)
            projectTable.Data = table();
            projectTable.ColumnName = {};
            state.selectedRow = [];
            updateSelectionState();
            if ~preserveStatus
                setStatus('No indexed projects found in the local catalog DB.');
            end
            return;
        end

        displayTable = table();
        displayTable.Name = string(projects.name);
        displayTable.Health = string(projects.health_status);
        displayTable.Raw = string(projects.raw_status);
        displayTable.FOV = projects.fov_count;
        displayTable.ROI = projects.roi_count;
        displayTable.Runs = projects.pipeline_run_count;
        displayTable.MissingRaw = projects.missing_raw_count;
        displayTable.RelativePath = string(projects.project_rel_from_root);

        projectTable.Data = displayTable;
        projectTable.ColumnName = displayTable.Properties.VariableNames;

        restorePreviousSelection();
        updateSelectionState();

        if ~preserveStatus
            setStatus(sprintf('%d indexed project(s) loaded from %s.', height(projects), state.settings.dbFile));
        end
    end

    function restorePreviousSelection()
        state.selectedRow = [];
        if isempty(state.projects) || height(state.projects) == 0
            return;
        end

        wantedMat = char(string(state.settings.lastSelectedProjectMat));
        if isempty(wantedMat)
            return;
        end

        matchIdx = find(strcmp(string(state.projects.project_mat_abs), string(wantedMat)), 1, 'first');
        if ~isempty(matchIdx)
            state.selectedRow = matchIdx;
        end
    end

    function updateSelectionState()
        row = getSelectedProjectRow();
        hasRow = ~isempty(row);

        loadButton.Enable = onOff(hasRow);
        openFolderButton.Enable = onOff(hasRow);
        openMatButton.Enable = onOff(hasRow);

        if ~hasRow
            detailsArea.Value = {'No project selected.'};
            return;
        end

        detailsArea.Value = {
            ['Name           : ' char(string(row.name))]
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

    function setBusyState(tf)
        indexButton.Enable = onOff(~tf);
        refreshButton.Enable = 'on';
        browseButton.Enable = onOff(~tf);
        saveRootButton.Enable = onOff(~tf);
        backgroundCheck.Enable = onOff(~tf);
        rootEdit.Editable = onOff(~tf);
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

    function rootPath = sanitizeRoot(rootValue)
        rootPath = strtrim(char(string(rootValue)));
        if isempty(rootPath)
            rootPath = '';
            return;
        end
        try
            rootPath = char(java.io.File(rootPath).getCanonicalPath());
        catch
        end
        if ~isfolder(rootPath)
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
