function fovOut = extractFovTask(fovIn, projectIo, projectId, args, matlabThreads, progressQueue, taskInfo)
% roiExtract.extractFovTask  Isolated worker task for one FOV extraction.
%
% The task owns one FOV and therefore one output directory.  It deliberately
% does not save the project: the client process merges all completed FOVs and
% persists the project once, avoiding concurrent project-file writes.

    if nargin < 4 || isempty(args)
        args = {};
    end
    if nargin < 5 || isempty(matlabThreads)
        matlabThreads = [];
    end
    if nargin < 6
        progressQueue = [];
    end
    if nargin < 7 || ~isstruct(taskInfo)
        taskInfo = struct();
    end

    if ~isempty(matlabThreads)
        try
            maxNumCompThreads(max(1, floor(double(matlabThreads(1)))));
        catch
        end
    end

    taskProject = shallow();
    if nargin >= 2 && isstruct(projectIo)
        taskProject.io = projectIo;
    end
    if nargin >= 3 && ~isempty(projectId)
        taskProject.projectId = projectId;
    end
    taskProject.fov = fovIn;

    try
        rois = taskProject.fov(1).roi;
        for i = 1:numel(rois)
            rois(i).parent = taskProject.fov(1);
        end
    catch
    end

    progressCallback = [];
    if ~isempty(progressQueue)
        progressCallback = @(progress)localSendProgress(progressQueue, taskInfo, progress);
        localSendProgress(progressQueue, taskInfo, struct( ...
            'value', 0, 'status', 'starting', 'phase', 'starting', ...
            'message', 'ROI extraction worker started.'));
    end

    try
        if isempty(progressCallback)
            extractAllROICrops(taskProject, args{:}, 'FOVIndex', 1);
        else
            extractAllROICrops(taskProject, args{:}, 'FOVIndex', 1, ...
                'ProgressCallback', progressCallback);
        end
    catch ME
        if ~isempty(progressQueue)
            localSendProgress(progressQueue, taskInfo, struct( ...
                'value', 0, 'status', 'failed', 'phase', 'failed', ...
                'message', ME.message));
        end
        rethrow(ME);
    end

    if ~isempty(progressQueue)
        localSendProgress(progressQueue, taskInfo, struct( ...
            'value', 1, 'status', 'done', 'phase', 'done', ...
            'message', 'ROI extraction worker finished.'));
    end
    fovOut = taskProject.fov(1);
end

function localSendProgress(progressQueue, taskInfo, progress)
    if isempty(progressQueue) || ~isstruct(progress)
        return;
    end
    event = progress;
    event.taskIndex = localNumericField(taskInfo, 'taskIndex', []);
    event.fovIndex = localNumericField(taskInfo, 'fovIndex', []);
    event.fovPosition = localNumericField(taskInfo, 'fovPosition', []);
    event.fovTotal = localNumericField(taskInfo, 'fovTotal', []);
    try
        send(progressQueue, event);
    catch
    end
end

function value = localNumericField(source, fieldName, fallback)
    value = fallback;
    try
        candidate = double(source.(fieldName));
        if isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    catch
    end
end
