function ctx = ui(ctx)
% roiIdentify.ui  Launch ROIextracterGUI for interactive calibration.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if ~isfield(ctx,'shallow') || isempty(ctx.shallow)
        error('roiIdentify.ui:NoProject','shallow project required for ROIextracterGUI.');
    end

    shallowObj = ctx.shallow;

    % choose a reference fov
    if isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
        refIdx = ctx.fovIndex(1);
    else
        refIdx = 1;
    end
    if refIdx > numel(shallowObj.fov)
        refIdx = 1;
    end

    fovobj = shallowObj.fov(refIdx);
    app = ROIextracterGUI(fovobj);

    % intercept close to store params/pattern into shallowObj
    origClose = [];
    try, origClose = app.ROIidentifierUIFigure.CloseRequestFcn; catch, end
    app.ROIidentifierUIFigure.CloseRequestFcn = @(src,evt)onClose(src,evt,origClose);

    origBtn = [];
    try, origBtn = app.CloseButton.ButtonPushedFcn; catch, end
    try
        app.CloseButton.ButtonPushedFcn = @(src,evt)onClose(src,evt,origBtn);
    catch
    end

    try
        waitfor(app.ROIidentifierUIFigure);
    catch
    end

    ctx.fovList = shallowObj.fov;
    ctx.roiList = [];
    for i = 1:numel(ctx.fovList)
        r = ctx.fovList(i).roi;
        if ~isempty(r)
            ctx.roiList = [ctx.roiList r(:)']; %#ok<AGROW>
        end
    end

    function onClose(src, evt, origFcn)
        try
            if ~isempty(shallowObj) && isprop(shallowObj,'runProfiles')
                rp = shallowObj.runProfiles;
                if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
                    rp.dataloading = struct();
                end

                % capture pattern + params
                pat = struct();
                try, pat.rect = fovobj.pattern; catch, pat.rect = []; end
                try, pat.crop = fovobj.crop; catch, pat.crop = []; end
                try, pat.fovId = fovobj.id; catch, pat.fovId = ''; end
                pat.fovIndex = refIdx;
                try, pat.frame = app.ReferenceframeEditField.Value; catch, pat.frame = 1; end
                try, pat.channel = app.channelnameEditField.Value; catch, pat.channel = ''; end
                try
                    if isprop(fovobj,'channel')
                        pix = find(matches(fovobj.channel, pat.channel),1);
                        if ~isempty(pix), pat.channelIndex = pix; end
                    end
                catch
                end

                rp.dataloading.pattern = pat;

                p = struct();
                try, p.referenceFrame = app.ReferenceframeEditField.Value; catch, end
                try, p.threshold = app.ThresholdEditField.Value; catch, end
                try, p.channel = app.channelnameEditField.Value; catch, end
                try, p.channelIndex = pat.channelIndex; catch, end
                try, p.crop = pat.crop; catch, end
                rp.dataloading.roiIdentify = p;

                shallowObj.runProfiles = rp;
                try, shallowSave(shallowObj); catch, end
            end
        catch
        end

        if ~isempty(origFcn)
            try
                feval(origFcn, src, evt);
            catch
                try
                    origFcn(src, evt);
                catch
                end
            end
        end
    end
end
