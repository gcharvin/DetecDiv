function processData(classiobj,roiobj,varargin)
% high level function to process data

% classiobj is a @classi obj
% roiobj is an array of @roi

% varargin :

% 'Frames': input an array of frame numbers or a cell array of frames with
% the same size as the array of @roi

% 'Progress' : specifiy a handle to a progree bar to be updated during
% classification

% 'Parallel' : usd for parallele computing

% results outputs the array of future objects with information about errors
% etc...
para=0;
frames=[];
p=[];
gpu=0;
ctxBase=struct();
cachePolicy='auto';
saveMode='immediate';

for i=1:numel(varargin)
    key=varargin{i};
    if isstring(key), key=char(key); end
    if ~ischar(key)
        continue;
    end

    if strcmp(key,'Frames') % is a cell array with the same number of elements as number of rois. If it s a numeric array, then apply to all rois
        frames=varargin{i+1};
    end

    if strcmp(key,'Progress') % update progress bar
        p=varargin{i+1};
    end

    if strcmp(key,'Parallel') % parallel computing
        para=1;
    end

    if strcmp(key,'GPU') % classify with GPU
        gpu=1;
    end

    if strcmp(key,'Ctx') % pipeline context (struct)
        ctxBase=varargin{i+1};
        if isempty(ctxBase) || ~isstruct(ctxBase)
            ctxBase=struct();
        end
    end
end

cachePolicy = resolveCachePolicyLocal(ctxBase);
saveMode = resolveSaveModeLocal(ctxBase);
if isempty(frames) && isfield(ctxBase,'sel') && isstruct(ctxBase.sel) && ...
        isfield(ctxBase.sel,'frames') && ~isempty(ctxBase.sel.frames)
    frames = ctxBase.sel.frames;
end

classi=classiobj;
classifyFun=normalizeProcessFun(classi.processFun);
classi.processFun=classifyFun;
fhandle=eval(['@' classifyFun]);
param=classi.processArg;

% ---- Inform which execution path is used ----
useCtx = false;
if ischar(classifyFun) || isstring(classifyFun)
    useCtx = contains(string(classifyFun), '.process');
end
if useCtx
    if ~isempty(fieldnames(ctxBase))
        disp(['[processData] Using package/ctx processor: ' char(string(classifyFun)) ' (ctx override)']);
    else
        disp(['[processData] Using package/ctx processor: ' char(string(classifyFun)) ' (auto ctx)']);
    end
else
    disp(['[processData] Using legacy processor signature: ' char(string(classifyFun))]);
end

disp(['Prcoessing roi data using ' classifyFun]);

if numel(p)
    p.Value=0.1;
    p.Message='Preparing processing....';
end


if numel(p)
    p.Value=0.2;
    p.Message='Processor is loaded.';
end

disp([num2str(numel(roiobj)) ' ROIs to process, be patient...']);

if para
    logparf(1:numel(roiobj))= parallel.FevalFuture;
    hadImageByIdx = false(1, numel(roiobj));
    hadDataByIdx = false(1, numel(roiobj));
else

    logparf=1;
end


for i=1:numel(roiobj) %size(roilist,2) % loop on all ROIs using parrallel computing

    checkProcessCancellation(ctxBase, p);
    updateProcessProgress(ctxBase, p, i-1, numel(roiobj), 'Processing');


    if numel(frames)>0
        if iscell(frames)
            if numel(frames)>=i
                fra=frames{i};
            end
        else
            fra=frames;
        end
    else
        fra=-1;
    end

    hadImageInMemory = ~isempty(roiobj(i).image);
    hadDataInMemory = ~isempty(roiobj(i).data);
    ensureRequiredChannelsLoadedLocal(roiobj(i), ctxBase);
    if para
        hadImageByIdx(i) = hadImageInMemory;
        hadDataByIdx(i) = hadDataInMemory;
    end


    % check that the requested number of frames is compatible with that of
    % the roi

    if fra~=-1
        % fra=intersect(fra,1:size(roiobj(i).image,4));
    else
        if processorCanRunWithoutImage(classifyFun)
            fra=-1;
        else
            if numel(roiobj(i).image)==0
                roiobj(i).load;
            end

            fra=1:size(roiobj(i).image,4);
        end
        %    fra=1:size(roiobj(i).image,4);
    end

    if numel(p)
        updateProcessProgress(ctxBase, p, i-1, numel(roiobj), 'Processing');
    end

    % roiobj(i).classes=classi.classes;

    % Build ctx for pipeline-compatible processors
    ctx = ctxBase;
    ctx.frames = fra;
    ctx.gpu = gpu;
    if isprop(classi,'strid') && (~isfield(ctx,'outputName') || isempty(ctx.outputName))
        ctx.outputName = classi.strid;
    end

    % Merge params: ctx.params overrides classif.processArg
    paramEff = param;
    if isfield(ctx,'params') && ~isempty(ctx.params) && isstruct(ctx.params)
        if isempty(paramEff), paramEff = struct(); end
        if isstruct(paramEff)
            paramEff = mergeParamStruct(paramEff, ctx.params);
        else
            % if legacy param is non-struct, prefer ctx.params
            paramEff = ctx.params;
        end
    end

    if para % parallel computing
        if useCtx
            logparf(i)=parfeval(fhandle,2,paramEff,roiobj(i),ctx);
        else
            logparf(i)=parfeval(fhandle,2,paramEff,roiobj(i),fra);
        end
    else
        if useCtx
            [paramout,data,image]=feval(fhandle,paramEff,roiobj(i),ctx);
        else
            [paramout,data,image]=feval(fhandle,paramEff,roiobj(i),fra);
        end
        if isEmptyProcessorOutput(image, data)
            roiId = safeRoiId(roiobj(i));
            msg = sprintf('Processor "%s" returned no image or dataseries output for ROI "%s"; ROI file was not saved.', ...
                char(string(classifyFun)), roiId);
            if useCtx
                error('processData:NoProcessorOutput', '%s', msg);
            else
                warning('processData:NoProcessorOutput', '%s', msg);
                updateProcessProgress(ctxBase, p, i, numel(roiobj), 'No output');
                continue;
            end
        end
        disp(['Processed ' num2str(roiobj(i).id)]);

        % bb=       roiobj(i)
        %        size(image)
        %        size(roiobj(i).image)
        %        return
        % Save only newly created channel if provided by processor
        saveChannels = {};
        if isstruct(paramout)
            if isfield(paramout,'saveChannels') && ~isempty(paramout.saveChannels)
                saveChannels = paramout.saveChannels;
            elseif isfield(paramout,'outputChannelName') && ~isempty(paramout.outputChannelName)
                saveChannels = {char(string(paramout.outputChannelName))};
            end
        end
        safeROIManagement(roiobj(i),image,data,saveChannels,cachePolicy,hadImageInMemory,hadDataInMemory,saveMode);
        updateProcessProgress(ctxBase, p, i, numel(roiobj), 'Processed');

    end
end

if para % parallel computing
    disp('Waiting for job to complete...');
    if numel(p)
        p.Message='Waiting for job to complete...';
    end

    %wait(logparf);

    for i=1:numel(logparf)
        checkProcessCancellation(ctxBase, p);
        %   [results,image]=fetchOutputs(logparf(i));

        [idx,param,data,image]=fetchNext(logparf(i));


        if isEmptyProcessorOutput(image, data)
            roiId = safeRoiId(roiobj(idx));
            msg = sprintf('Processor "%s" returned no image or dataseries output for ROI "%s"; ROI file was not saved.', ...
                char(string(classifyFun)), roiId);
            if useCtx
                error('processData:NoProcessorOutput', '%s', msg);
            else
                warning('processData:NoProcessorOutput', '%s', msg);
                updateProcessProgress(ctxBase, p, i, numel(logparf), 'No output');
                continue;
            end
        end

        saveChannels = {};
        if isstruct(param)
            if isfield(param,'saveChannels') && ~isempty(param.saveChannels)
                saveChannels = param.saveChannels;
            elseif isfield(param,'outputChannelName') && ~isempty(param.outputChannelName)
                saveChannels = {char(string(param.outputChannelName))};
            end
        end
        safeROIManagement(roiobj(idx),image,data,saveChannels,cachePolicy,hadImageByIdx(idx),hadDataByIdx(idx),saveMode);
        updateProcessProgress(ctxBase, p, i, numel(logparf), 'Processed');
        %     roiobj(idx).results=results;
        %
        %     roiobj(idx).image=image;
        %     roiobj(idx).save
        %     roiobj(idx).clear;

        %   aa=results.my_classi_1.id
        % here image is empty !!!!
        %  roiout.save;
        %  roiout.clear,
    end
end

if numel(p)
    p.Value=0.9;
    p.Message='Saving project...Please wait...';
end


    function f = normalizeProcessFun(f)
        if isempty(f)
            return;
        end
        if isa(f,'function_handle')
            f = func2str(f);
        end
        f = char(string(f));
        if contains(f,'.process')
            return;
        end
        if contains(f,'.')
            return;
        end
        if ~isempty(which([f '.process']))
            f = [f '.process'];
        end
    end

    function out = mergeParamStruct(base, override)
        out = base;
        fn = fieldnames(override);
        for k = 1:numel(fn)
            out.(fn{k}) = override.(fn{k});
        end
    end

    function ROIManagement(roiobj,image,data,saveChannels,cachePolicyLocal,hadImageBefore,hadDataBefore,saveModeLocal)

        if nargin < 4
            saveChannels = {};
        end
        if nargin < 5 || isempty(cachePolicyLocal)
            cachePolicyLocal = 'auto';
        end
        if nargin < 6, hadImageBefore = false; end
        if nargin < 7, hadDataBefore = false; end
        if nargin < 8 || isempty(saveModeLocal), saveModeLocal = 'immediate'; end

        if isEmptyProcessorOutput(image, data)
            warning('processData:NoProcessorOutput', ...
                'Processor returned no image or dataseries output for ROI "%s"; ROI file was not saved.', ...
                safeRoiId(roiobj));
            return;
        end

        imageCache = image;
        dataCache = data;
        roiobj.data=data;
        roiobj.image=image;
        if shouldDeferSaveLocal(saveModeLocal)
            markDeferredDirtyLocal(roiobj, hasSavableDataseries(data), numel(image) > 0, saveChannels);
            disp('[processData] Defer save requested; processor output kept in ROI memory.');
            return;
        end
        if numel(image)
            if ~isempty(saveChannels)
                roiobj.save(saveChannels);
            else
                roiobj.save; % before we used to save the data only ('data')
            end
            if shouldKeepRoiInMemory(cachePolicyLocal, hadImageBefore, hadDataBefore)
                roiobj.image = imageCache;
                roiobj.data = dataCache;
            else
                roiobj.clear,
            end
        else
            didSaveData = roiobj.save('data');
            if ~didSaveData
                roiId = '<unknown>';
                try
                    roiId = char(string(roiobj.id));
                catch
                end
                warning('processData:NoDataSaved', ...
                    'Processor returned no savable data for ROI "%s".', roiId);
            end
            if shouldKeepRoiInMemory(cachePolicyLocal, hadImageBefore, hadDataBefore)
                roiobj.data = dataCache;
            end
        end
        %disp('You must save the shallow project to save these classified data !');
    end

    function tf = isEmptyProcessorOutput(image, data)
        tf = isempty(image) && ~hasSavableDataseries(data);
    end

    function tf = hasSavableDataseries(data)
        tf = false;
        if isempty(data)
            return;
        end
        if isa(data,'dataseries')
            try
                tf = any(arrayfun(@(ds) isprop(ds,'groupid') && ~isempty(ds.groupid), data));
            catch
                tf = numel(data) > 0;
            end
        elseif isstruct(data)
            tf = isfield(data,'groupid') && ~isempty(data.groupid);
        else
            tf = true;
        end
    end

    function roiId = safeRoiId(roiobjLocal)
        roiId = '<unknown>';
        try
            roiId = char(string(roiobjLocal.id));
        catch
        end
    end

    function ok = safeROIManagement(roiobj,image,data,saveChannels,cachePolicyLocal,hadImageBefore,hadDataBefore,saveModeLocal)
        ok = true;
        if nargin < 8 || isempty(saveModeLocal), saveModeLocal = 'immediate'; end
        try
            ROIManagement(roiobj,image,data,saveChannels,cachePolicyLocal,hadImageBefore,hadDataBefore,saveModeLocal);
        catch ME
            if startsWith(char(string(ME.identifier)), 'roi:save:') || ...
                    contains(ME.message, 'Unable to write to file')
                rethrow(ME);
            end
            ok = false;
            roiId = '<unknown>';
            try
                roiId = char(string(roiobj.id));
            catch
            end
            warning('processData:SkipROI', ...
                'Skipping ROI "%s" because saving processor output failed: %s', ...
                roiId, ME.message);
            try
                roiobj.image = [];
                roiobj.data = dataseries.empty;
            catch
            end
        end
    end

    function tf = shouldKeepRoiInMemory(policy, hadImageBefore, hadDataBefore)
        switch lower(char(string(policy)))
            case 'memory'
                tf = true;
            case 'auto'
                tf = logical(hadImageBefore || hadDataBefore);
            otherwise
                tf = false;
        end
    end

    function policy = resolveCachePolicyLocal(ctx)
        policy = 'auto';
        if ~isstruct(ctx) || isempty(fieldnames(ctx))
            return;
        end
        try
            if isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'cachePolicy') && ~isempty(ctx.io.cachePolicy)
                policy = lower(char(string(ctx.io.cachePolicy)));
            elseif isfield(ctx,'store') && isstruct(ctx.store) && isfield(ctx.store,'cacheMode') && ~isempty(ctx.store.cacheMode)
                policy = lower(char(string(ctx.store.cacheMode)));
            elseif isfield(ctx,'cachePolicy') && ~isempty(ctx.cachePolicy)
                policy = lower(char(string(ctx.cachePolicy)));
            end
        catch
            policy = 'auto';
        end
        if ~any(strcmp(policy, {'auto','memory','disk'}))
            policy = 'auto';
        end
    end

    function mode = resolveSaveModeLocal(ctx)
        mode = 'immediate';
        if ~isstruct(ctx) || isempty(fieldnames(ctx))
            return;
        end
        try
            if isfield(ctx,'io') && isstruct(ctx.io)
                if isfield(ctx.io,'deferredSave') && ~isempty(ctx.io.deferredSave) && logical(ctx.io.deferredSave)
                    mode = 'defer';
                    return;
                end
                if isfield(ctx.io,'saveMode') && ~isempty(ctx.io.saveMode)
                    mode = normalizeSaveModeLocal(ctx.io.saveMode);
                    return;
                end
            end
        catch
            mode = 'immediate';
        end
    end

    function mode = normalizeSaveModeLocal(mode)
        mode = lower(strtrim(char(string(mode))));
        switch mode
            case {'defer','deferred','roi','roi_final','roi_finalized','final','finalized','memory'}
                mode = 'defer';
            otherwise
                mode = 'immediate';
        end
    end

    function tf = shouldDeferSaveLocal(mode)
        tf = strcmp(normalizeSaveModeLocal(mode), 'defer');
    end

    function markDeferredDirtyLocal(roiobjLocal, hasData, hasImage, saveChannels)
        if nargin < 4
            saveChannels = {};
        end
        try
            if ~isstruct(roiobjLocal.results)
                roiobjLocal.results = struct();
            end
            dirty = struct('data', false, 'image', false, 'fullImage', false, 'channels', {{}});
            if isfield(roiobjLocal.results, 'pipelineDeferredDirty') && isstruct(roiobjLocal.results.pipelineDeferredDirty)
                dirty = roiobjLocal.results.pipelineDeferredDirty;
                if ~isfield(dirty,'data'), dirty.data = false; end
                if ~isfield(dirty,'image'), dirty.image = false; end
                if ~isfield(dirty,'fullImage'), dirty.fullImage = false; end
                if ~isfield(dirty,'channels'), dirty.channels = {}; end
            end
            dirty.data = logical(dirty.data || hasData);
            dirty.image = logical(dirty.image || hasImage);
            if hasImage && isempty(saveChannels)
                dirty.fullImage = true;
                dirty.channels = {};
            elseif hasImage && ~dirty.fullImage
                dirty.channels = unique([cellstr(string(dirty.channels(:)))' cellstr(string(saveChannels(:)))'], 'stable');
            end
            roiobjLocal.results.pipelineDeferredDirty = dirty;
        catch
        end
    end

    function checkProcessCancellation(ctx, progressDlg)
        requested = false;
        tokenFile = '';
        try
            if isstruct(ctx) && isfield(ctx,'cancel') && isstruct(ctx.cancel) ...
                    && isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
                tokenFile = char(string(ctx.cancel.tokenFile));
                requested = exist(tokenFile, 'file') == 2;
            end
        catch
            requested = false;
        end
        try
            if ~isempty(progressDlg) && isvalid(progressDlg) && isprop(progressDlg,'CancelRequested') && progressDlg.CancelRequested
                requested = true;
                if ~isempty(tokenFile) && exist(tokenFile, 'file') ~= 2
                    fid = fopen(tokenFile, 'w');
                    if fid > 0
                        fprintf(fid, 'cancel requested at %s\n', char(datetime('now')));
                        fclose(fid);
                    end
                end
            end
        catch
        end
        if requested
            error('runPipeline:Cancelled', 'Pipeline run cancelled by user between processor ROIs.');
        end
    end

    function updateProcessProgress(ctx, progressDlg, roiIndex, totalRois, verb)
        if isempty(progressDlg) || ~isvalid(progressDlg)
            return;
        end
        if nargin < 5 || isempty(verb)
            verb = 'Processing';
        end
        totalRois = max(1, totalRois);
        roiFrac = max(0, min(1, double(roiIndex) ./ totalRois));
        nodeIndex = 1;
        totalNodes = 1;
        startedTic = [];
        nodeId = '';
        try
            if isstruct(ctx) && isfield(ctx,'progress') && isstruct(ctx.progress)
                if isfield(ctx.progress,'currentNodeIndex'), nodeIndex = max(1, double(ctx.progress.currentNodeIndex)); end
                if isfield(ctx.progress,'totalNodes'), totalNodes = max(1, double(ctx.progress.totalNodes)); end
                if isfield(ctx.progress,'startedTic'), startedTic = ctx.progress.startedTic; end
                if isfield(ctx.progress,'currentNodeId'), nodeId = char(string(ctx.progress.currentNodeId)); end
            end
        catch
        end
        value = max(0, min(1, (nodeIndex - 1 + roiFrac) ./ totalNodes));
        etaText = '';
        try
            if ~isempty(startedTic) && value > 0.02
                elapsed = toc(startedTic);
                eta = elapsed * (1 - value) / value;
                etaText = [' | ETA ' formatDurationShortLocal(eta)];
            end
        catch
        end
        try
            progressDlg.Indeterminate = 'off';
            progressDlg.Value = value;
            displayIndex = max(1, min(totalRois, roiIndex));
            progressDlg.Message = sprintf('%s ROI %d/%d%s%s', char(string(verb)), displayIndex, totalRois, ...
                ternaryLocal(~isempty(nodeId), [' | ' nodeId], ''), etaText);
            drawnow limitrate;
        catch
        end
    end

    function txt = formatDurationShortLocal(secondsValue)
        secondsValue = max(0, double(secondsValue));
        if secondsValue < 60
            txt = sprintf('%ds', round(secondsValue));
        elseif secondsValue < 3600
            txt = sprintf('%dm%02ds', floor(secondsValue/60), round(mod(secondsValue,60)));
        else
            txt = sprintf('%dh%02dm', floor(secondsValue/3600), floor(mod(secondsValue,3600)/60));
        end
    end

    function ensureRequiredChannelsLoadedLocal(roiobjLocal, ctx)
        channels = requiredChannelsFromContextLocal(ctx);
        if isempty(channels)
            return;
        end
        try
            roiobjLocal.load('Channel', channels, 'Silent');
        catch ME
            warning('processData:RequiredChannelLoadFailed', ...
                'Could not preload required ROI channel(s) %s for ROI "%s": %s', ...
                strjoin(channels, ', '), safeRoiId(roiobjLocal), ME.message);
        end
    end

    function channels = requiredChannelsFromContextLocal(ctx)
        channels = {};
        try
            if isstruct(ctx) && isfield(ctx, 'io') && isstruct(ctx.io) && ...
                    isfield(ctx.io, 'requiredChannels') && ~isempty(ctx.io.requiredChannels)
                channels = normalizeChannelListLocal(ctx.io.requiredChannels);
            end
        catch
            channels = {};
        end
    end

    function channels = normalizeChannelListLocal(value)
        channels = {};
        if isempty(value)
            return;
        end
        if iscell(value)
            for ii = 1:numel(value)
                channels = [channels normalizeChannelListLocal(value{ii})]; %#ok<AGROW>
            end
            channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
            return;
        end
        if ischar(value) || (isstring(value) && isscalar(value))
            vals = regexp(char(string(value)), '[,;]', 'split');
        else
            vals = cellstr(string(value(:)));
        end
        for ii = 1:numel(vals)
            s = strtrim(char(string(vals{ii})));
            if isempty(s) || startsWith(s, '<') || any(strcmpi(s, {'none','auto','n/a','<all>'}))
                continue;
            end
            channels{end+1} = s; %#ok<AGROW>
        end
        channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
    end

    function out = ternaryLocal(cond, a, b)
        if cond
            out = a;
        else
            out = b;
        end
    end

    function tf = processorCanRunWithoutImage(funName)
        funName = lower(char(string(funName)));
        dataOnlyProcessors = { ...
            'computerls', ...
            'computerls.core', ...
            'computerls.process', ...
            'computelineage', ...
            'computelineage.core', ...
            'computelineage.process', ...
            'fociburststats', ...
            'fociburststats.core', ...
            'fociburststats.process' ...
            };
        tf = any(strcmp(funName, dataOnlyProcessors));
    end
end
