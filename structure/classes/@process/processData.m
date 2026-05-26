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
    if para
        hadImageByIdx(i) = hadImageInMemory;
        hadDataByIdx(i) = hadDataInMemory;
    end


    % check that the requested number of frames is compatible with that of
    % the roi

    if fra~=-1
        % fra=intersect(fra,1:size(roiobj(i).image,4));
    else
        if numel(roiobj(i).image)==0
            roiobj(i).load;
        end

        fra=1:size(roiobj(i).image,4);
        %    fra=1:size(roiobj(i).image,4);
    end

    if numel(p)
        p.Value=0.9* double(i)./numel(roiobj);

        p.Message=['Processing ROI  ' roiobj(i).id];
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
        safeROIManagement(roiobj(i),image,data,saveChannels,cachePolicy,hadImageInMemory,hadDataInMemory);

    end
end

if para % parallel computing
    disp('Waiting for job to complete...');
    if numel(p)
        p.Message='Waiting for job to complete...';
    end

    %wait(logparf);

    for i=1:numel(logparf)
        %   [results,image]=fetchOutputs(logparf(i));

        [idx,param,data,image]=fetchNext(logparf(i));


        safeROIManagement(roiobj(idx),image,data,{},cachePolicy,hadImageByIdx(idx),hadDataByIdx(idx));
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

    function ROIManagement(roiobj,image,data,saveChannels,cachePolicyLocal,hadImageBefore,hadDataBefore)

        if nargin < 4
            saveChannels = {};
        end
        if nargin < 5 || isempty(cachePolicyLocal)
            cachePolicyLocal = 'auto';
        end
        if nargin < 6, hadImageBefore = false; end
        if nargin < 7, hadDataBefore = false; end

        imageCache = image;
        dataCache = data;
        roiobj.data=data;
        roiobj.image=image;
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

    function ok = safeROIManagement(roiobj,image,data,saveChannels,cachePolicyLocal,hadImageBefore,hadDataBefore)
        ok = true;
        try
            ROIManagement(roiobj,image,data,saveChannels,cachePolicyLocal,hadImageBefore,hadDataBefore);
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
end
