function logparf = classifyData(classiobj, roiobj, varargin)
% High level function to classify data
%
% classiobj : @classi
% roiobj    : array of @roi
%
% varargin (legacy + new):
%   'Classifier'      : provide classifier object (otherwise loads from disk)
%   'ClassifierCNN'   : flag (compare cnn+lstm)
%   'Frames'          : numeric array or cell array (per-roi)
%   'Channel'         : cell array (per-roi) or single item
%   'Progress'        : uiprogressdlg handle
%   'Parallel'        : enable parfeval
%   'RoiWithGT'       : classify only rois/frames with GT
%   'GPU'             : execute on GPU
%   'OutputName'      : (NEW) output name used for:
%                        (1) dataseries.groupid
%                        (2) results/prob channel names created in ROIpreprocessing
%                       default = classiobj.strid
%
% NOTES
% - GT lookup remains based on classiobj.strid (training channels).
% - OutputName controls output channels prefix and dataseries grouping.

% -----------------------------
% Parse inputs
% -----------------------------
para          = 0;
frames        = [];
p             = [];
channel       = [];
classifierCNN = [];
classifier    = [];
CNNflag       = 0;
roiwithgt     = 0;
gpu           = 0;
ctxBase       = struct();

outputName    = "";   % NEW
cachePolicy   = 'auto';
saveMode      = 'immediate';

for i = 1:numel(varargin)
    key = varargin{i};
    if isstring(key), key = char(key); end
    if ~ischar(key)
        continue;
    end

    if strcmp(key,'Classifier')
        classifier = varargin{i+1};
    end
    if strcmp(key,'ClassifierCNN')
        CNNflag = 1;
        if i < numel(varargin)
            nextValue = varargin{i+1};
            if ~(ischar(nextValue) || (isstring(nextValue) && isscalar(nextValue)))
                classifierCNN = nextValue;
            end
        end
    end
    if strcmp(key,'Frames')
        frames = varargin{i+1};
    end
    if strcmp(key,'Progress')
        p = varargin{i+1};
    end
    if strcmp(key,'Channel')
        channel = varargin{i+1};
    end
    if strcmp(key,'Parallel')
        para = 1;
    end
    if strcmp(key,'RoiWithGT')
        roiwithgt = 1;
    end
    if strcmp(key,'GPU')
        gpu = 1;
    end
    if strcmp(key,'Ctx')
        ctxBase = varargin{i+1};
        if isempty(ctxBase) || ~isstruct(ctxBase)
            ctxBase = struct();
        end
    end

    % NEW (accept aliases)
if any(strcmpi(key, {'OutputName','GroupId','GroupID'}))
    outputName = string(varargin{i+1});
end

end

% Default output name = classif.strid
if strlength(strtrim(outputName))==0
    outputName = string(classiobj.strid);
else
    outputName = strtrim(outputName);
end

classifierStore = classifier;
cachePolicy = resolveCachePolicyLocal(classiobj);
saveMode = resolveSaveModeLocal(ctxBase, classiobj);

classi     = classiobj;
[classifyFun, usesPkg] = resolveClassifyFun(classi);
if isempty(classifyFun)
    error('classifyData:NoClassifyFun','No classification function available for this classifier.');
end
fhandle   = eval(['@' classifyFun]);
isPipelineFun = usesPkg || any(strcmpi(classifyFun, {'classifyImageLSTMNetFun','cnn_lstm.classify'}));

disp(['Classifying roi data using ' classifyFun]);
if usesPkg
    disp(['[PKG CLASSIFY] ' classifyFun]);
    try
        if ismethod(classi,'runMsg')
            classi.runMsg('PKG CLASSIFY %s', classifyFun);
        end
    catch
    end
end

if ~isempty(p)
    p.Value   = 0.1;
    p.Message = 'Preparing classification....';
end

% -----------------------------
% Load classifiers if needed
% -----------------------------
mustload = isempty(classifier);

if CNNflag==1
    if isempty(classifierCNN)
        [classifierCNN, loadedPath] = loadAuxiliaryClassifierCNNLocal(classi);
        if ~isempty(classifierCNN)
            disp(['Loading CNN classifier: ' loadedPath]);
        end
    end
else
    if isempty(classifierCNN) && shouldPreloadAuxiliaryClassifierCNNLocal(classifyFun)
        [classifierCNN, loadedPath] = loadAuxiliaryClassifierCNNLocal(classi);
        if ~isempty(classifierCNN)
            disp(['Preloaded auxiliary CNN classifier: ' loadedPath]);
        end
    else
        classifierCNN = [];
    end
end

if mustload
    disp(['Loading classifier: ' classi.strid]);
    classifier = [];
    classifier = classi.loadClassifier('force'); % avoid pb if already loaded
    classifierStore = classifier;

    if isempty(classifierStore)
        disp('WARNING : could not load main classifier....');
    end
end

if ~isempty(p)
    p.Value   = 0.2;
    p.Message = 'Classifier is loaded.';
end

disp([num2str(numel(roiobj)) ' ROIs to classify, be patient...']);

if para
    logparf(1:numel(roiobj)) = parallel.FevalFuture;
    hadImageByIdx = false(1, numel(roiobj));
    hadDataByIdx = false(1, numel(roiobj));
    if isPipelineFun
        ctxByIdx = cell(1, numel(roiobj));
    end
else
    logparf = 1;
end

% Channel list expansion if user forced "classify all ROIs"
if iscell(channel) && numel(channel) < numel(roiobj) && numel(channel) > 0
    channel(numel(channel)+1:numel(roiobj)) = {channel{end}};
end

% -----------------------------
% Main loop
% -----------------------------
for i = 1:numel(roiobj)
    checkClassifyCancellation(classiobj, ctxBase, p);
    updateClassifyProgress(ctxBase, p, i-1, numel(roiobj), 'Classifying');

    goclassif = 1;
    roiIdStr = '';
    try
        if isempty(roiobj(i).id)
            roiIdStr = ['#' num2str(i)];
        else
            roiIdStr = num2str(roiobj(i).id);
        end
    catch
        roiIdStr = ['#' num2str(i)];
    end
    disp(['[DEBUG] classifyData: ROI ' num2str(i) '/' num2str(numel(roiobj)) ' id=' roiIdStr]);
    hadImageInMemory = ~isempty(roiobj(i).image);
    hadDataInMemory = ~isempty(roiobj(i).data);
    ensureRequiredChannelsLoadedLocal(roiobj(i), ctxBase, channelForRoiLocal(channel, i));
    if para
        hadImageByIdx(i) = hadImageInMemory;
        hadDataByIdx(i) = hadDataInMemory;
    end

    % ---------------------------------------------------------
    % Optional: classify only ROIs/frames with GT available
    % NOTE: GT lookup must remain based on classiobj.strid
    % ---------------------------------------------------------
    if roiwithgt==1
        switch classiobj.category{1}
            case 'Pixel'
                ch = roiobj(i).findChannelID(classiobj.strid);

                if ~isempty(ch)
                    if isempty(roiobj(i).image)
                        roiobj(i).load;
                    end

                    im   = roiobj(i).image;
                    imch = im(:,:,ch,:);

                    if sum(imch(:))>0
                        goclassif = 1;
                    else
                        goclassif = 0;
                    end
                else
                    goclassif = 0;
                end

            otherwise % image classification
                classistr = classiobj.strid;
                goclassif = 0;
                if ~isempty(roiobj(i).train) && isfield(roiobj(i).train, classistr)
                    if isfield(roiobj(i).train.(classistr),'id') && ~isempty(roiobj(i).train.(classistr).id)
                        ids = roiobj(i).train.(classistr).id;
                        if sum(ids)>0 || (numel(ids)==1 && ~isnan(ids))
                            goclassif = 1;
                        end
                    end
                end
        end
    end

    if goclassif==0
        if roiwithgt==1
            disp(['[DEBUG] classifyData: RoiWithGT enabled and no GT for ROI ' roiIdStr ' -> skipping']);
        else
            disp(['[DEBUG] classifyData: goclassif=0 for ROI ' roiIdStr ' -> skipping']);
        end
        disp(['There is no groundtruth available for roi ' num2str(roiobj(i).id) ' , skipping roi...']);
        continue;
    end

    % ---------------------------------------------------------
    % Load ROI image if needed
    % ---------------------------------------------------------
    if isempty(roiobj(i).image)
        disp(['[DEBUG] classifyData: ROI ' roiIdStr ' has empty image -> loading']);
        requiredChannels = requiredChannelsFromContextLocal(ctxBase, channelForRoiLocal(channel, i));
        if ~isempty(requiredChannels)
            roiobj(i).load('Channel', requiredChannels, 'Silent');
        else
            roiobj(i).load;
        end
    end
    if isempty(roiobj(i).image)
        warning(['ROI is empty; skipping... (ROI ' roiIdStr ')']);
        continue;
    end
    try
        disp(['[DEBUG] classifyData: ROI ' roiIdStr ' image size = ' mat2str(size(roiobj(i).image))]);
    catch
    end

    % ---------------------------------------------------------
    % Prepare output channels (NEW: depends on outputName)
    % ---------------------------------------------------------
    ROIpreprocessing(roiobj(i), classiobj, outputName);

    fra = 1:size(roiobj(i).image,4);
    reqFraStr = 'all';

    if ~isempty(frames)
        if iscell(frames)
            if numel(frames) >= i
                fra = frames{i};
                reqFraStr = mat2str(fra);
            end
        else
            fra = frames;
            reqFraStr = mat2str(fra);
        end
    end

    % Ensure requested frames are compatible
    if ~isequal(fra,-1)
        fra = intersect(fra, 1:size(roiobj(i).image,4));
    else
        fra = 1:size(roiobj(i).image,4);
    end
    try
        disp(['[DEBUG] classifyData: ROI ' roiIdStr ' frames req=' reqFraStr ' -> using ' mat2str(fra)]);
    catch
    end
    if isempty(fra)
        disp(['[DEBUG] classifyData: ROI ' roiIdStr ' has no frames after intersection -> skipping']);
        continue;
    end

    % Channel selection
    if isempty(channel)
        try
            cha = classiobj.getInputChannels();
        catch
            cha = classiobj.channelName;
        end
    else
        cha = channelForRoiLocal(channel, i);
        if iscell(cha) && numel(cha) == 1
            cha = cha{1};
        end
    end
    ensureChannelIndicesAddressableLocal(roiobj(i), cha);
    try
        if iscell(cha)
            chaStr = strjoin(cha, ',');
        elseif isnumeric(cha)
            chaStr = mat2str(cha);
        else
            chaStr = char(string(cha));
        end
        disp(['[DEBUG] classifyData: ROI ' roiIdStr ' channels=' chaStr]);
    catch
    end

    if ~isempty(p)
        updateClassifyProgress(ctxBase, p, i-1, numel(roiobj), 'Classifying');
    end
    checkClassifyCancellation(classiobj, ctxBase, p);

    % ---------------------------------------------------------
    % Dispatch
    % ---------------------------------------------------------
    if para
        if isPipelineFun
            ctx = buildPipelineClassifyCtx(ctxBase, fra, cha, gpu, classifierStore, classifierCNN, outputName, cachePolicy);
            try
                ctx = classi.buildCtx('classify', ctx);
            catch
            end
            ctxByIdx{i} = ctx; %#ok<AGROW>
            logparf(i) = parfeval(fhandle, 1, roiobj(i), classi, ctx);
        else
            if ~isempty(classifierCNN)
                logparf(i) = parfeval( ...
                    fhandle, 2, roiobj(i), classi, classifierStore, ...
                    'classifierCNN', classifierCNN, ...
                    'Frames', fra, 'Channel', cha, 'Exec', gpu, ...
                    'OutputName', char(outputName)); % NEW
            else
                logparf(i) = parfeval( ...
                    fhandle, 2, roiobj(i), classi, classifierStore, ...
                    'Frames', fra, 'Channel', cha, 'Exec', gpu, ...
                    'OutputName', char(outputName)); % NEW
            end
        end
    else
        if isPipelineFun
            ctx = buildPipelineClassifyCtx(ctxBase, fra, cha, gpu, classifierStore, classifierCNN, outputName, cachePolicy);
            try
                ctx = classi.buildCtx('classify', ctx);
            catch
            end
            out = feval(fhandle, roiobj(i), classi, ctx);
            if isstruct(out) && isfield(out,'patch') && patchHasPersistableOutput(out.patch) && exist('roiApplyPatch','file') == 2
                try
                    disp(['[DEBUG] classifyData: using roiApplyPatch for ROI ' num2str(roiobj(i).id)]);
                catch
                    disp('[DEBUG] classifyData: using roiApplyPatch for ROI (id unavailable)');
                end
                applyAndPersistClassifierPatch(roiobj(i), out.patch, ctx, outputName, cachePolicy, hadImageInMemory, hadDataInMemory, saveMode);
            else
                if exist('roiApplyPatch','file') ~= 2
                    warning('roiApplyPatch not found on path; falling back to ROIManagement.');
                end
                if isstruct(out) && (isfield(out,'data') || isfield(out,'image'))
                    if ~isfield(out,'data'), out.data = []; end
                    if ~isfield(out,'image'), out.image = []; end
                    try
                    disp(['[DEBUG] classifyData: using ROIManagement for ROI ' num2str(roiobj(i).id)]);
                catch
                    disp('[DEBUG] classifyData: using ROIManagement for ROI (id unavailable)');
                end
                    ROIManagement(roiobj(i), out.data, out.image, outputName, classiobj, cachePolicy, hadImageInMemory, hadDataInMemory, saveMode);
                end
            end
            disp(['Classified (pipeline) ' num2str(roiobj(i).id)]);
        else
            if ~isempty(classifierCNN)
                [data, image] = feval( ...
                    fhandle, roiobj(i), classi, classifierStore, ...
                    'classifierCNN', classifierCNN, ...
                    'Frames', fra, 'Channel', cha, 'Exec', gpu, ...
                    'OutputName', char(outputName)); % NEW
                disp(['Classified with separate CNN ' num2str(roiobj(i).id)]);
            else
                [data, image] = feval( ...
                    fhandle, roiobj(i), classi, classifierStore, ...
                    'Frames', fra, 'Channel', cha, 'Exec', gpu, ...
                    'OutputName', char(outputName)); % NEW
                disp(['Classified ' num2str(roiobj(i).id)]);
            end

            ROIManagement(roiobj(i),data,image, outputName, classiobj, cachePolicy, hadImageInMemory, hadDataInMemory, saveMode)
        end
        updateClassifyProgress(ctxBase, p, i, numel(roiobj), 'Classified');
    end
end

% -----------------------------
% Parallel fetch / management
% -----------------------------
if para
    disp('Waiting for job to complete...');
    if ~isempty(p)
        p.Message = 'Waiting for job to complete...';
    end

    for i = 1:numel(logparf)
        checkClassifyCancellation(classiobj, ctxBase, p);
        if isPipelineFun
            [idx, out] = fetchNext(logparf(i));
            ctx = ctxByIdx{idx};
            if isstruct(out) && isfield(out,'patch') && patchHasPersistableOutput(out.patch) && exist('roiApplyPatch','file') == 2
                try
                    disp(['[DEBUG] classifyData: using roiApplyPatch for ROI ' num2str(roiobj(idx).id)]);
                catch
                    disp('[DEBUG] classifyData: using roiApplyPatch for ROI (id unavailable)');
                end
                applyAndPersistClassifierPatch(roiobj(idx), out.patch, ctx, outputName, cachePolicy, hadImageByIdx(idx), hadDataByIdx(idx), saveMode);
            else
                if exist('roiApplyPatch','file') ~= 2
                    warning('roiApplyPatch not found on path; falling back to ROIManagement.');
                end
                if isstruct(out) && (isfield(out,'data') || isfield(out,'image'))
                    if ~isfield(out,'data'), out.data = []; end
                    if ~isfield(out,'image'), out.image = []; end
                    try
                        disp(['[DEBUG] classifyData: using ROIManagement for ROI ' num2str(roiobj(idx).id)]);
                    catch
                        disp('[DEBUG] classifyData: using ROIManagement for ROI (id unavailable)');
                    end
                    ROIManagement(roiobj(idx), out.data, out.image, outputName, classiobj, cachePolicy, hadImageByIdx(idx), hadDataByIdx(idx), saveMode);
                end
            end
        else
            [idx, data, image] = fetchNext(logparf(i));
            ROIManagement(roiobj(idx),data,image, outputName, classiobj, cachePolicy, hadImageByIdx(idx), hadDataByIdx(idx));
        end
        updateClassifyProgress(ctxBase, p, i, numel(logparf), 'Classified');

    end
end

if ~isempty(p)
    p.Value   = 0.9;
    p.Message = 'Saving project...Please wait...';
end

end % classifyData

function checkClassifyCancellation(classiobj, ctxBase, progressDlg)
if nargin < 2 || isempty(ctxBase)
    ctxBase = struct();
end
if nargin < 3
    progressDlg = [];
end
try
    cancelInfo = [];
    if isprop(classiobj, 'runProfiles') && isstruct(classiobj.runProfiles) ...
            && isfield(classiobj.runProfiles, 'classify') && isstruct(classiobj.runProfiles.classify) ...
            && isfield(classiobj.runProfiles.classify, 'cancel')
        cancelInfo = classiobj.runProfiles.classify.cancel;
    end
    if (~isstruct(cancelInfo) || isempty(fieldnames(cancelInfo))) && isstruct(ctxBase) ...
            && isfield(ctxBase,'cancel') && isstruct(ctxBase.cancel)
        cancelInfo = ctxBase.cancel;
    end
    requested = false;
    tokenFile = '';
    if isstruct(cancelInfo) && isfield(cancelInfo, 'tokenFile') && ~isempty(cancelInfo.tokenFile)
        tokenFile = char(string(cancelInfo.tokenFile));
        requested = exist(tokenFile, 'file') == 2;
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
        try
            pe = pyenv;
            if pe.Status == "Loaded"
                terminate(pyenv);
            end
        catch
        end
        error('runPipeline:Cancelled', 'Pipeline run cancelled by user between classifier ROIs.');
    end
catch ME
    rethrow(ME);
end
end

function updateClassifyProgress(ctx, progressDlg, roiIndex, totalRois, verb)
if isempty(progressDlg) || ~isvalid(progressDlg)
    return;
end
if nargin < 5 || isempty(verb)
    verb = 'Classifying';
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

function out = ternaryLocal(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end


% ========================================================================
% ROI preprocessing
%   - Creates/resets result channels before classification
%   - NEW: channel names use outputName instead of classif.strid
% ========================================================================
function ROIpreprocessing(roiobj, classif, outputName)

    if nargin < 3 || strlength(strtrim(string(outputName)))==0
        outputName = string(classif.strid);
    else
        outputName = strtrim(string(outputName));
    end

    if ~strcmp(classif.category, 'Pixel')
        return;
    end

    try
        if isprop(classif, 'classifierPkg') && strcmpi(char(string(classif.classifierPkg)), 'deeplab_pixel_classification')
            return;
        end
    catch
    end

    gfp = roiobj.image;
    nY  = size(gfp,1);
    nX  = size(gfp,2);
    nF  = size(gfp,4);

    % --- Detect instance segmentation types
    isCPSAM = false;

    if isprop(classif,'classifierPkg') && strcmpi(char(string(classif.classifierPkg)), 'cellposesam')
        isCPSAM = true;
    elseif isprop(classif,'classifyFun') && any(strcmpi(char(string(classif.classifyFun)), {'classifyCPSAMFun','cellposesam.classify'}))
        isCPSAM = true;
    elseif isprop(classif,'description') && ~isempty(classif.description)
        isCPSAM = any(contains(lower(string(classif.description)), 'cellpose'));
    end

    isInstanceSeg = (strcmp(classif.description{1}, 'YOLO instance segmentation') || ...
                     strcmp(classif.description{1}, 'Cell-TRACKTR')               || ...
                     isCPSAM);

    if isInstanceSeg
        for c = 1:numel(classif.classes)
            chname      = ['results_' char(outputName) '_' classif.classes{c}];
            rgb         = [1 1 1];
            intensity   = [0 0 0];
            indexedFlag = 1;
            ensureResultChannel(roiobj, chname, rgb, intensity, indexedFlag, nY, nX, nF);
        end

        if isCPSAM && localClassiWantsProbabilityOutput(classif)
            chNameProba = [char(outputName) '_cellprob'];
            pixproba = findChannelID(roiobj, chNameProba);
            if isempty(pixproba)
                matrix = zeros(nY, nX, 1, nF, 'single');
                roiobj.addChannel(matrix, chNameProba, [1 0 1], [1 1 1]); % magenta continuous
                pixproba = size(roiobj.image,3);
            end
            enforceResultChannelDisplay(roiobj, pixproba, [1 0 1], [1 1 1], false);
        elseif isCPSAM
            localDropChannelIfPresent(roiobj, ['results_' char(outputName)]);
            localDropChannelIfPresent(roiobj, [char(outputName) '_cellprob']);
            for c = 1:numel(classif.classes)
                localDropChannelIfPresent(roiobj, ['prob_' char(outputName) '_' classif.classes{c}]);
            end
        end

        return;
    end

    % --- Not instance segmentation -> follow outputType logic
    outType = '';
    if isprop(classif,'outputType') && ~isempty(classif.outputType)
        outType = classif.outputType;
    end

    switch outType
        case {'proba',''}
            for c = 1:numel(classif.classes)
                chname = ['prob_' char(outputName) '_' classif.classes{c}];
                rgb    = [1 1 1];

                intensity   = [1 1 1];
                indexedFlag = 0;

                if numel(classif.description) >= 3 && strcmp(classif.description{3}, 'Yolov11')
                    intensity   = [0 0 0];
                    indexedFlag = 1;
                end

                ensureResultChannel(roiobj, chname, rgb, intensity, indexedFlag, nY, nX, nF);
            end

        otherwise
            chname = ['results_' char(outputName)];
            rgb    = [1 1 1];

            if strcmp(classif.description{1}, 'Image pixel regression')
                intensity   = [1 1 1];
                indexedFlag = 0;
            else
                intensity   = [0 0 0];
                indexedFlag = 1;
            end

            ensureResultChannel(roiobj, chname, rgb, intensity, indexedFlag, nY, nX, nF);
    end
end


function localDropChannelIfPresent(roiobj, channelName)
try
    if ~isempty(findChannelID(roiobj, channelName))
        roiobj.removeChannel(channelName);
    end
catch ME
    warning('classifyData:DropProbabilityChannelFailed', ...
        'Could not drop stale probability channel "%s": %s', channelName, ME.message);
end
end

function ensureResultChannel(roiobj, chname, rgb, intensity, indexedFlag, nY, nX, nF)
    pixid = findChannelID(roiobj, chname);

    if isempty(pixid)
        matrix = uint16(zeros(nY, nX, 1, nF));
        roiobj.addChannel(matrix, chname, rgb, intensity);
        pixid = size(roiobj.image,3);
    else
        roiobj.image(:,:,pixid,:) = uint16(zeros(nY, nX, 1, nF));
    end
    enforceResultChannelDisplay(roiobj, pixid, rgb, intensity, indexedFlag);
end

function enforceResultChannelDisplay(roiobj, pixid, rgb, intensity, indexedFlag)
    if isempty(pixid) || ~isprop(roiobj,'channelid') || isempty(roiobj.channelid)
        return;
    end

    selectid = roiobj.channelid(pixid(1));

    if ~isfield(roiobj.display,'indexed') || isempty(roiobj.display.indexed)
        roiobj.display.indexed = zeros(0,1);
    end

    [roiobj.display.rgb, roiobj.display.intensity, roiobj.display.indexed] = ...
        ensureDisplayRows(roiobj.display.rgb, roiobj.display.intensity, roiobj.display.indexed, selectid);

    roiobj.display = localEnsureDisplayScalarField(roiobj.display, 'selectedchannel', 1, selectid);
    roiobj.display = localEnsureDisplayScalarField(roiobj.display, 'contour', 0, selectid);
    roiobj.display = localEnsureDisplayScalarField(roiobj.display, 'alpha', 1, selectid);
    roiobj.display = localEnsureDisplayScalarField(roiobj.display, 'width', 0, selectid);

    roiobj.display.rgb(selectid,:)           = rgb;
    roiobj.display.intensity(selectid,:)     = intensity;
    roiobj.display.indexed(selectid,1)       = logical(indexedFlag);
    roiobj.display.selectedchannel(selectid) = true;

    if indexedFlag
        roiobj.display.contour(selectid) = 1;
        roiobj.display.alpha(selectid) = 0.35;
        roiobj.display.width(selectid) = 1.5;
    else
        roiobj.display.contour(selectid) = 0;
        roiobj.display.alpha(selectid) = 1;
        roiobj.display.width(selectid) = 0;
    end
end

function [rgbTab, intTab, indexedTab] = ensureDisplayRows(rgbTab, intTab, indexedTab, idx)
    if isempty(rgbTab),     rgbTab     = ones(0,3); end
    if isempty(intTab),     intTab     = ones(0,3); end
    if isempty(indexedTab), indexedTab = zeros(0,1); end

    need = max(0, idx - size(rgbTab,1));
    if need > 0
        rgbTab(end+1:idx, :)     = 1;
        intTab(end+1:idx, :)     = 0;
        indexedTab(end+1:idx, 1) = 0;
    end
end


% ========================================================================
% ROI management + saving
%   NEW: apply outputName to dataseries.groupid (NO HEURISTICS)
% ========================================================================
function ROIManagement(roiobj, data, image, outputName, classiobj, cachePolicyLocal, hadImageBefore, hadDataBefore, saveMode)

    % --- Only re-group classification outputs that belong to this classifier ---
    if nargin >= 5 && ~isempty(outputName) && isa(data,'dataseries')
        data = remapOnlyClassifierDataseries(data, classiobj, outputName);
    end
    if nargin < 6 || isempty(cachePolicyLocal)
        cachePolicyLocal = 'auto';
    end
    if nargin < 7, hadImageBefore = false; end
    if nargin < 8, hadDataBefore = false; end
    if nargin < 9 || isempty(saveMode), saveMode = 'immediate'; end

    imageCache = image;
    dataCache = data;
    roiobj.data  = data;
    roiobj.image = image;
    localNormalizeIndexedResultChannels(roiobj);

    if shouldDeferSaveLocal(saveMode)
        markDeferredDirtyLocal(roiobj, true, numel(image) > 0);
        disp('[DEBUG] ROIManagement: defer save requested, ROI kept in memory.');
        return;
    end

    if numel(image)
        try
            disp(['[DEBUG] ROIManagement: calling roi.save for ROI ' num2str(roiobj.id)]);
        catch
            disp('[DEBUG] ROIManagement: calling roi.save (id unavailable)');
        end
        imageSaveChannels = localClassifierImageOutputChannels(roiobj, outputName, classiobj);
        if ~isempty(imageSaveChannels) && localRoiH5Exists(roiobj)
            try
                disp(['[DEBUG] ROIManagement: saving classifier output channels only: ' strjoin(imageSaveChannels, ', ')]);
            catch
            end
            roiobj.save(imageSaveChannels);
        else
            roiobj.save;   % sauvegarde tout
        end
        if shouldKeepRoiInMemory(cachePolicyLocal, hadImageBefore, hadDataBefore)
            roiobj.image = imageCache;
            roiobj.data = dataCache;
            disp('[DEBUG] ROIManagement: roi.save done, ROI kept in memory.');
        else
            roiobj.clear;
            disp('[DEBUG] ROIManagement: roi.save done (image+data), roi.clear called.');
        end
    else
        try
            disp(['[DEBUG] ROIManagement: calling roi.save(''data'') for ROI ' num2str(roiobj.id)]);
        catch
            disp('[DEBUG] ROIManagement: calling roi.save(''data'') (id unavailable)');
        end
        roiobj.save('data');  % seulement les metadonnees
        if shouldKeepRoiInMemory(cachePolicyLocal, hadImageBefore, hadDataBefore)
            roiobj.data = dataCache;
            disp('[DEBUG] ROIManagement: roi.save(''data'') done, data kept in memory.');
        else
            disp('[DEBUG] ROIManagement: roi.save(''data'') done.');
        end
    end
end

function applyAndPersistClassifierPatch(roiobj, patch, ctx, outputName, cachePolicyLocal, hadImageBefore, hadDataBefore, saveMode)
    if nargin < 5 || isempty(cachePolicyLocal)
        cachePolicyLocal = 'auto';
    end
    if nargin < 6, hadImageBefore = false; end
    if nargin < 7, hadDataBefore = false; end
    if nargin < 8 || isempty(saveMode), saveMode = 'immediate'; end

    imageCache = roiobj.image;
    dataCacheBefore = roiobj.data;
    roiApplyPatch(roiobj, patch, ctx);

    hasDataPatch = patchHasDataseries(patch);
    hasImagePatch = patchHasImageWrite(patch);
    expectedOutput = char(string(outputName));

    if hasDataPatch && ~roiHasDataseries(roiobj, expectedOutput)
        error('classifyData:MissingPatchOutput', ...
            'Classifier patch did not create expected dataseries "%s" for ROI "%s".', ...
            expectedOutput, safeRoiIdLocal(roiobj));
    end

    if shouldDeferSaveLocal(saveMode)
        if ~hasImagePatch && ~hasDataPatch
            error('classifyData:EmptyPatchOutput', ...
                'Classifier patch contained no image or dataseries output for ROI "%s".', ...
                safeRoiIdLocal(roiobj));
        end
        markDeferredDirtyLocal(roiobj, hasDataPatch, hasImagePatch);
        disp('[DEBUG] classifyData: defer save requested, classifier patch kept in memory.');
        return;
    end

    if hasImagePatch
        channelsToSave = patchImageChannels(patch);
        if ~isempty(channelsToSave) && localRoiH5Exists(roiobj)
            roiobj.save(channelsToSave);
        else
            roiobj.save;
        end
    elseif hasDataPatch
        roiobj.save('data');
    else
        error('classifyData:EmptyPatchOutput', ...
            'Classifier patch contained no image or dataseries output for ROI "%s".', ...
            safeRoiIdLocal(roiobj));
    end

    if shouldKeepRoiInMemory(cachePolicyLocal, hadImageBefore, hadDataBefore)
        if isempty(roiobj.image) && ~isempty(imageCache)
            roiobj.image = imageCache;
        end
    else
        roiobj.clear;
    end

    if shouldKeepRoiInMemory(cachePolicyLocal, hadImageBefore, hadDataBefore)
        if hasDataPatch
            % roi.save('data') clears data; keep the patched data in memory
            % when the caller had already loaded ROI data.
            try
                roiobj.load('data','Silent');
            catch
                roiobj.data = dataCacheBefore;
            end
        end
    end
end

function tf = patchHasDataseries(patch)
    tf = false;
    try
        if isfield(patch,'roi')
            patch = patch.roi;
        end
        tf = isfield(patch,'dataseries') && isfield(patch.dataseries,'upsert') && ~isempty(patch.dataseries.upsert);
    catch
        tf = false;
    end
end

function tf = patchHasPersistableOutput(patch)
    tf = patchHasDataseries(patch) || patchHasImageWrite(patch);
end

function tf = patchHasImageWrite(patch)
    tf = false;
    try
        if isfield(patch,'roi')
            patch = patch.roi;
        end
        tf = isfield(patch,'image') && isfield(patch.image,'write') && ~isempty(patch.image.write);
    catch
        tf = false;
    end
end

function channels = patchImageChannels(patch)
    channels = {};
    try
        if isfield(patch,'roi')
            patch = patch.roi;
        end
        if ~isfield(patch,'image') || ~isfield(patch.image,'write')
            return;
        end
        writes = patch.image.write;
        if isstruct(writes), writes = num2cell(writes); end
        for iWrite = 1:numel(writes)
            w = writes{iWrite};
            if isfield(w,'channel') && (ischar(w.channel) || isstring(w.channel))
                channels{end+1} = char(string(w.channel)); %#ok<AGROW>
            end
        end
        channels = unique(channels, 'stable');
    catch
        channels = {};
    end
end

function tf = roiHasDataseries(roiobj, groupid)
    tf = false;
    if isempty(groupid)
        return;
    end
    try
        if isempty(roiobj.data)
            return;
        end
        tf = any(arrayfun(@(ds) isprop(ds,'groupid') && strcmp(char(string(ds.groupid)), groupid), roiobj.data));
    catch
        tf = false;
    end
end

function roiId = safeRoiIdLocal(roiobj)
    roiId = '<unknown>';
    try
        roiId = char(string(roiobj.id));
    catch
    end
end

function localNormalizeIndexedResultChannels(roiobj)
try
    if ~isprop(roiobj,'display') || isempty(roiobj.display) || ~isstruct(roiobj.display)
        return;
    end
    if ~isfield(roiobj.display,'channel') || isempty(roiobj.display.channel)
        return;
    end

    nLog = numel(roiobj.display.channel);
    if ~isfield(roiobj.display,'indexed') || isempty(roiobj.display.indexed)
        roiobj.display.indexed = zeros(1, nLog);
    elseif numel(roiobj.display.indexed) < nLog
        roiobj.display.indexed(end+1:nLog) = 0;
    end

    if ~isfield(roiobj.display,'intensity') || isempty(roiobj.display.intensity)
        roiobj.display.intensity = ones(nLog, 3);
    elseif size(roiobj.display.intensity,1) < nLog
        roiobj.display.intensity(end+1:nLog,:) = 1;
    end

    if ~isfield(roiobj.display,'alpha') || isempty(roiobj.display.alpha)
        roiobj.display.alpha = ones(1, nLog);
    elseif numel(roiobj.display.alpha) < nLog
        roiobj.display.alpha(end+1:nLog) = 1;
    end

    if ~isfield(roiobj.display,'width') || isempty(roiobj.display.width)
        roiobj.display.width = ones(1, nLog);
    elseif numel(roiobj.display.width) < nLog
        roiobj.display.width(end+1:nLog) = 1;
    end

    if ~isfield(roiobj.display,'contour') || isempty(roiobj.display.contour)
        roiobj.display.contour = zeros(1, nLog);
    elseif numel(roiobj.display.contour) < nLog
        roiobj.display.contour(end+1:nLog) = 0;
    end

    for iLog = 1:nLog
        chName = lower(string(roiobj.display.channel{iLog}));
        isMaskLike = startsWith(chName, "results_") || contains(chName, "mask") || contains(chName, "track");
        if ~isMaskLike
            continue;
        end
        roiobj.display.intensity(iLog,:) = [0 0 0];
        roiobj.display.indexed(iLog) = 1;
        roiobj.display.contour(iLog) = 1;
        if roiobj.display.alpha(iLog) <= 0 || roiobj.display.alpha(iLog) > 0.5
            roiobj.display.alpha(iLog) = 0.35;
        end
        if roiobj.display.width(iLog) <= 0
            roiobj.display.width(iLog) = 1.5;
        end
    end
catch
end
end

function displayStruct = localEnsureDisplayScalarField(displayStruct, fieldName, defaultValue, idx)
if ~isfield(displayStruct, fieldName) || isempty(displayStruct.(fieldName))
    displayStruct.(fieldName) = repmat(defaultValue, 1, idx);
else
    value = displayStruct.(fieldName);
    value = value(:).';
    if numel(value) < idx
        value(end+1:idx) = defaultValue;
    end
    displayStruct.(fieldName) = value;
end
end

function channels = localClassifierImageOutputChannels(roiobj, outputName, classiobj)
channels = {};
try
    if nargin < 2 || strlength(strtrim(string(outputName))) == 0
        if nargin >= 3 && isprop(classiobj,'strid')
            outputName = string(classiobj.strid);
        else
            return;
        end
    end
    outputName = char(strtrim(string(outputName)));
    if isempty(outputName) || ~isprop(roiobj,'display') || ~isstruct(roiobj.display) ...
            || ~isfield(roiobj.display,'channel') || isempty(roiobj.display.channel)
        return;
    end

    names = roiobj.display.channel;
    if isstring(names), names = cellstr(names); end
    if ischar(names), names = {names}; end

    prefixes = {['results_' outputName '_']};
    exactNames = {['results_' outputName]};
    if localClassiWantsProbabilityOutput(classiobj)
        prefixes{end+1} = ['prob_' outputName '_']; %#ok<AGROW>
        exactNames{end+1} = [outputName '_cellprob']; %#ok<AGROW>
    end

    keep = false(1, numel(names));
    for iName = 1:numel(names)
        nm = char(string(names{iName}));
        keep(iName) = any(strcmpi(nm, exactNames));
        for iPrefix = 1:numel(prefixes)
            keep(iName) = keep(iName) || startsWith(nm, prefixes{iPrefix}, 'IgnoreCase', true);
        end
    end
    channels = names(keep);
catch
    channels = {};
end
end

function tf = localClassiWantsProbabilityOutput(classif)
tf = false;
try
    if ~(isprop(classif,'outputType') && ~isempty(classif.outputType))
        return;
    end
    outType = lower(strtrim(char(string(classif.outputType))));
    outType = strrep(outType, 'probability', 'proba');
    tf = any(strcmp(outType, {'proba','both'}));
catch
    tf = false;
end
end

function tf = localRoiH5Exists(roiobj)
tf = false;
try
    if ~isprop(roiobj,'path') || isempty(roiobj.path) || ~isprop(roiobj,'id') || isempty(roiobj.id)
        return;
    end
    tf = exist(fullfile(roiobj.path, ['im_' char(string(roiobj.id)) '.h5']), 'file') == 2;
catch
    tf = false;
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

function policy = resolveCachePolicyLocal(classiobj)
    policy = 'auto';
    try
        if isprop(classiobj,'runProfiles') && isstruct(classiobj.runProfiles) && isfield(classiobj.runProfiles,'classify')
            rp = classiobj.runProfiles.classify;
            if isstruct(rp)
                if isfield(rp,'io') && isstruct(rp.io) && isfield(rp.io,'cachePolicy') && ~isempty(rp.io.cachePolicy)
                    policy = lower(char(string(rp.io.cachePolicy)));
                elseif isfield(rp,'store') && isstruct(rp.store) && isfield(rp.store,'cacheMode') && ~isempty(rp.store.cacheMode)
                    policy = lower(char(string(rp.store.cacheMode)));
                elseif isfield(rp,'cachePolicy') && ~isempty(rp.cachePolicy)
                    policy = lower(char(string(rp.cachePolicy)));
                end
            end
        end
    catch
        policy = 'auto';
    end
    if ~any(strcmp(policy, {'auto','memory','disk'}))
        policy = 'auto';
    end
end

function mode = resolveSaveModeLocal(ctxBase, classiobj)
    mode = 'immediate';
    try
        if isstruct(ctxBase) && isfield(ctxBase,'io') && isstruct(ctxBase.io)
            if isfield(ctxBase.io,'deferredSave') && ~isempty(ctxBase.io.deferredSave) && logical(ctxBase.io.deferredSave)
                mode = 'defer';
                return;
            end
            if isfield(ctxBase.io,'saveMode') && ~isempty(ctxBase.io.saveMode)
                mode = normalizeSaveModeLocal(ctxBase.io.saveMode);
                return;
            end
        end
    catch
    end
    try
        if isprop(classiobj,'runProfiles') && isstruct(classiobj.runProfiles) && isfield(classiobj.runProfiles,'classify')
            rp = classiobj.runProfiles.classify;
            if isstruct(rp) && isfield(rp,'io') && isstruct(rp.io)
                if isfield(rp.io,'deferredSave') && ~isempty(rp.io.deferredSave) && logical(rp.io.deferredSave)
                    mode = 'defer';
                    return;
                end
                if isfield(rp.io,'saveMode') && ~isempty(rp.io.saveMode)
                    mode = normalizeSaveModeLocal(rp.io.saveMode);
                end
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

function markDeferredDirtyLocal(roiobj, hasData, hasImage)
    try
        if ~isstruct(roiobj.results)
            roiobj.results = struct();
        end
        dirty = struct('data', false, 'image', false);
        if isfield(roiobj.results, 'pipelineDeferredDirty') && isstruct(roiobj.results.pipelineDeferredDirty)
            dirty = roiobj.results.pipelineDeferredDirty;
            if ~isfield(dirty,'data'), dirty.data = false; end
            if ~isfield(dirty,'image'), dirty.image = false; end
        end
        dirty.data = logical(dirty.data || hasData);
        dirty.image = logical(dirty.image || hasImage);
        roiobj.results.pipelineDeferredDirty = dirty;
    catch
    end
end

function io = buildCacheIoStruct(cachePolicy)
    io = struct('cachePolicy', cachePolicy);
end

function tf = shouldPreloadAuxiliaryClassifierCNNLocal(classifyFun)
tf = false;
try
    fun = lower(strtrim(char(string(classifyFun))));
    tf = contains(fun, 'cnn_lstm') || contains(fun, 'lstm');
catch
    tf = false;
end
end

function [classifierCNN, filePath] = loadAuxiliaryClassifierCNNLocal(classi)
classifierCNN = [];
filePath = '';
try
    filePath = fullfile(char(string(classi.path)), ['netCNN_' char(string(classi.strid)) '.mat']);
    if exist(filePath, 'file') ~= 2
        return;
    end
    S = load(filePath);
    fields = {'classifier','netCNN','net'};
    for i = 1:numel(fields)
        if isfield(S, fields{i}) && ~isempty(S.(fields{i}))
            classifierCNN = S.(fields{i});
            return;
        end
    end
    names = fieldnames(S);
    if ~isempty(names)
        classifierCNN = S.(names{1});
    end
catch
    classifierCNN = [];
end
end

function ctx = buildPipelineClassifyCtx(ctxBase, fra, cha, gpu, classifierStore, classifierCNN, outputName, cachePolicy)
    if nargin < 1 || isempty(ctxBase) || ~isstruct(ctxBase)
        ctx = struct();
    else
        ctx = ctxBase;
    end

    if ~isfield(ctx,'sel') || ~isstruct(ctx.sel)
        ctx.sel = struct();
    end
    ctx.sel.frames = fra;
    ctx.sel.channels = cha;

    if ~isfield(ctx,'io') || ~isstruct(ctx.io)
        ctx.io = buildCacheIoStruct(cachePolicy);
    elseif ~isfield(ctx.io,'cachePolicy') || isempty(ctx.io.cachePolicy)
        ctx.io.cachePolicy = cachePolicy;
    end

    if ~isfield(ctx,'store') || ~isstruct(ctx.store)
        ctx.store = struct('cacheMode', cachePolicy);
    elseif ~isfield(ctx.store,'cacheMode') || isempty(ctx.store.cacheMode)
        ctx.store.cacheMode = cachePolicy;
    end

    if ~isfield(ctx,'exec') || ~isstruct(ctx.exec)
        ctx.exec = struct();
    end
    ctx.exec.gpu = gpu;
    ctx.exec.classifier = classifierStore;
    ctx.exec.classifierCNN = classifierCNN;
    ctx.exec.classifierProvided = ~isempty(classifierStore);
    ctx.exec.classifierCNNProvided = ~isempty(classifierCNN);

    if ~isfield(ctx,'names') || ~isstruct(ctx.names)
        ctx.names = struct();
    end
    ctx.names.outputName = char(outputName);
end

function out = remapOnlyClassifierDataseries(in, classiobj, outputName)
% Keep all existing dataseries unchanged EXCEPT those corresponding to
% this classifier's outputs (historically groupid == classiobj.strid).
%
% Behavior:
% - If outputName == classiobj.strid -> no change
% - Else:
%   - For each dataseries whose groupid == classiobj.strid:
%       -> copy it (new dataseries handle) and set groupid = outputName
%   - Remove any existing dataseries already having groupid == outputName
%     (to avoid duplicates), then append the copied ones.

    out = in;

    old = char(string(classiobj.strid));
    new = char(string(outputName));

    if isempty(new) || strcmp(new, old)
        return
    end

    % indices of "classifier outputs" to remap
    gid = arrayfun(@(d) char(string(d.groupid)), out, 'UniformOutput', false);
    isOld = strcmp(gid, old);

    if ~any(isOld)
        return
    end

    % remove already-present "new" outputs (avoid duplicates)
    isNew = strcmp(gid, new);
    out(isNew) = [];

    % copy only the old outputs and retag them
    oldSeries = in(isOld);
    newSeries = repmat(dataseries, size(oldSeries));
    for k = 1:numel(oldSeries)
        % deep-ish copy: new handle, same content
        newSeries(k) = oldSeries(k).copyData();
        newSeries(k).groupid = new;
    end

    % append
    out = [out(:).' newSeries(:).'];
end


function data = applyGroupIdToDataseries(data, outputName)
% Apply dataseries.groupid = outputName
% Works for:
% - dataseries array
% - cell arrays containing dataseries
% - structs/tables that contain dataseries fields (optional support)

    on = char(string(outputName));

    % direct dataseries array
    if isa(data, 'dataseries')
        for k = 1:numel(data)
            data(k).groupid = on;
        end
        return
    end

    % cell array container
    if iscell(data)
        for k = 1:numel(data)
            data{k} = applyGroupIdToDataseries(data{k}, outputName);
        end
        return
    end

    % struct container (best-effort but still type-safe)
    if isstruct(data)
        f = fieldnames(data);
        for ii = 1:numel(f)
            try
                v = data.(f{ii});
                if isa(v,'dataseries') || iscell(v) || isstruct(v)
                    data.(f{ii}) = applyGroupIdToDataseries(v, outputName);
                end
            catch
            end
        end
        return
    end

    % table container (best-effort but type-safe)
    if istable(data)
        vn = data.Properties.VariableNames;
        for ii = 1:numel(vn)
            try
                v = data.(vn{ii});
                if isa(v,'dataseries') || iscell(v) || isstruct(v)
                    data.(vn{ii}) = applyGroupIdToDataseries(v, outputName);
                end
            catch
            end
        end
        return
    end
end

function [fun, usesPkg] = resolveClassifyFun(classif)
% Prefer standardized package dispatch if available.
usesPkg = false;
fun = '';

pkg = '';
if isprop(classif,'classifierPkg') && ~isempty(classif.classifierPkg)
    pkg = classif.classifierPkg;
else
    if isprop(classif,'classifyFun') && ~isempty(classif.classifyFun)
        pkg = localInferPkg(classif.classifyFun);
    end
end

if ~isempty(pkg)
    cand = [pkg '.classify'];
    if ~isempty(which(cand))
        fun = cand;
        usesPkg = true;
        return;
    end
end

if isprop(classif,'classifyFun')
    fun = classif.classifyFun;
end
end

function ensureRequiredChannelsLoadedLocal(roiobjLocal, ctx, fallbackChannels)
channels = requiredChannelsFromContextLocal(ctx, fallbackChannels);
if isempty(channels)
    return;
end
try
    roiobjLocal.load('Channel', channels, 'Silent');
catch ME
    warning('classifyData:RequiredChannelLoadFailed', ...
        'Could not preload required ROI channel(s) %s for ROI "%s": %s', ...
        strjoin(channels, ', '), safeRoiIdLocal(roiobjLocal), ME.message);
end
end

function channels = requiredChannelsFromContextLocal(ctx, fallbackChannels)
if nargin < 2
    fallbackChannels = {};
end
channels = {};
try
    if isstruct(ctx) && isfield(ctx, 'io') && isstruct(ctx.io) && ...
            isfield(ctx.io, 'requiredChannels') && ~isempty(ctx.io.requiredChannels)
        channels = normalizeChannelListLocal(ctx.io.requiredChannels);
    end
catch
    channels = {};
end
if isempty(channels)
    channels = normalizeChannelListLocal(fallbackChannels);
end
end

function channels = channelForRoiLocal(channelArg, idx)
channels = {};
try
    if isempty(channelArg)
        return;
    end
    if iscell(channelArg) && numel(channelArg) >= idx
        channels = channelArg{idx};
    else
        channels = channelArg;
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
if ischar(value)
    s = strtrim(value);
    if isempty(s) || startsWith(s, '<') || any(strcmpi(s, {'none','auto','n/a','<all>'}))
        return;
    end
    channels = {s};
    return;
end
if isstring(value)
    vals = cellstr(value(:));
    for i = 1:numel(vals)
        s = strtrim(char(vals{i}));
        if isempty(s) || startsWith(s, '<') || any(strcmpi(s, {'none','auto','n/a','<all>'}))
            continue;
        end
        channels{end+1} = s; %#ok<AGROW>
    end
    channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
    return;
end
if iscell(value)
    for i = 1:numel(value)
        channels = [channels normalizeChannelListLocal(value{i})]; %#ok<AGROW>
    end
    channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
    return;
end
vals = cellstr(string(value(:)));
for i = 1:numel(vals)
    s = strtrim(char(string(vals{i})));
    if isempty(s) || startsWith(s, '<') || any(strcmpi(s, {'none','auto','n/a','<all>'}))
        continue;
    end
    channels{end+1} = s; %#ok<AGROW>
end
channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
end

function ensureChannelIndicesAddressableLocal(roiobjLocal, channels)
if isempty(roiobjLocal.image)
    return;
end
channelNames = normalizeChannelListLocal(channels);
if isempty(channelNames)
    return;
end
try
    pix = [];
    for i = 1:numel(channelNames)
        pix = [pix roiobjLocal.findChannelID(channelNames{i})]; %#ok<AGROW>
    end
    pix = pix(~isnan(pix) & pix > 0);
    if isempty(pix)
        return;
    end
    if max(pix) > size(roiobjLocal.image, 3)
        disp(['[DEBUG] classifyData: ROI ' safeRoiIdLocal(roiobjLocal) ...
            ' has partially loaded channels but classifier needs global channel indices -> reloading full ROI']);
        roiobjLocal.load('Silent');
    end
catch ME
    warning('classifyData:ChannelAddressabilityCheckFailed', ...
        'Could not verify loaded channel indices for ROI "%s": %s', ...
        safeRoiIdLocal(roiobjLocal), ME.message);
end
end

function pkg = localInferPkg(funSpec)
pkg = '';
f = funSpec;
if isa(f,'function_handle'), f = func2str(f); end
if isstring(f), f = char(f); end
dot = strfind(f, '.');
if ~isempty(dot)
    pkg = f(1:dot(1)-1);
    return;
end

if any(strcmp(f, {'trainImageLSTMNetFun','classifyImageLSTMNetFun'}))
    pkg = 'cnn_lstm';
    elseif any(strcmp(f, {'trainImageGoogleNetFun','classifyImageGoogleNetFun'}))
        pkg = 'cnn';
    elseif any(strcmp(f, {'trainCPSAMFun','classifyCPSAMFun'}))
        pkg = 'cellposesam';
    end
end
