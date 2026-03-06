function prog = progressMarkLocal(shallowObj, ctx, stage, fovIdx, roiIdx)
% progressMarkLocal  Mark ROI indices as done for a given FOV.

    if nargin < 5
        roiIdx = [];
    end

    prog = progressLoadLocal(shallowObj, ctx, stage);
    if isempty(prog)
        prog = progressInitLocal(shallowObj, ctx, stage, fovIdx, struct());
    end

    if ~isfield(prog,'fovIds') || isempty(prog.fovIds)
        prog.fovIds = [];
        prog.done = {};
    end

    pos = find(prog.fovIds == fovIdx, 1);
    if isempty(pos)
        prog.fovIds(end+1) = fovIdx;
        prog.done{end+1} = [];
        pos = numel(prog.fovIds);
    end

    if isempty(roiIdx)
        prog.done{pos} = unique([prog.done{pos}]);
    else
        prog.done{pos} = unique([prog.done{pos} roiIdx(:)']);
    end

    prog.updatedAt = datetime('now');

    if ~isempty(shallowObj)
        if ~isprop(shallowObj,'runProfiles') || isempty(shallowObj.runProfiles)
            shallowObj.runProfiles = struct();
        end
        rp = shallowObj.runProfiles;
        if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
            rp.dataloading = struct();
        end
        if ~isfield(rp.dataloading,'runs') || isempty(rp.dataloading.runs)
            rp.dataloading.runs = struct();
        end
        rp.dataloading.runs.(getRunIdLocal(ctx)) = prog;
        shallowObj.runProfiles = rp;
    end
end