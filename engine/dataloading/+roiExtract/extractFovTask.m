function fovOut = extractFovTask(fovIn, projectIo, projectId, args, matlabThreads)
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

    extractAllROICrops(taskProject, args{:}, 'FOVIndex', 1);
    fovOut = taskProject.fov(1);
end
