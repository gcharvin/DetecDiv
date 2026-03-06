function prog = progressLoadLocal(shallowObj, ctx, stage)
% progressLoadLocal  Load dataloading progress from shallowObj.runProfiles.

    prog = struct();
    if nargin < 1 || isempty(shallowObj)
        return;
    end
    if ~isprop(shallowObj,'runProfiles') || isempty(shallowObj.runProfiles)
        return;
    end
    rp = shallowObj.runProfiles;
    if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
        return;
    end
    if ~isfield(rp.dataloading,'runs') || isempty(rp.dataloading.runs)
        return;
    end

    runId = getRunIdLocal(ctx);
    if isfield(rp.dataloading.runs, runId)
        prog = rp.dataloading.runs.(runId);
    end

    if nargin >= 3 && ~isempty(stage) && isfield(prog,'stage')
        if ~strcmpi(prog.stage, stage)
            prog = struct();
        end
    end
end
