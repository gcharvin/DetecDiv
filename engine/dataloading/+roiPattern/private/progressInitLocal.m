function prog = progressInitLocal(shallowObj, ctx, stage, fovIds, params)
% progressInitLocal  Initialize dataloading progress in shallowObj.runProfiles.

    if nargin < 4, fovIds = []; end
    if nargin < 5, params = struct(); end

    runId = getRunIdLocal(ctx);

    prog = struct();
    prog.runId     = runId;
    prog.stage     = char(string(stage));
    prog.params    = params;
    prog.fovIds    = fovIds(:)';
    prog.done      = cell(numel(prog.fovIds),1);
    prog.errors    = {};
    prog.createdAt = datetime('now');
    prog.updatedAt = datetime('now');

    if isempty(shallowObj)
        return;
    end
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

    rp.dataloading.runs.(runId) = prog;
    shallowObj.runProfiles = rp;
end
