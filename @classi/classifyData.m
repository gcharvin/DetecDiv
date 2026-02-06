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

outputName    = "";   % NEW

for i = 1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifier = varargin{i+1};
    end
    if strcmp(varargin{i},'ClassifierCNN')
        CNNflag = 1;
    end
    if strcmp(varargin{i},'Frames')
        frames = varargin{i+1};
    end
    if strcmp(varargin{i},'Progress')
        p = varargin{i+1};
    end
    if strcmp(varargin{i},'Channel')
        channel = varargin{i+1};
    end
    if strcmp(varargin{i},'Parallel')
        para = 1;
    end
    if strcmp(varargin{i},'RoiWithGT')
        roiwithgt = 1;
    end
    if strcmp(varargin{i},'GPU')
        gpu = 1;
    end

    % NEW (accept aliases)
   key = varargin{i};
if isstring(key), key = char(key); end

if ischar(key) && any(strcmpi(key, {'OutputName','GroupId','GroupID'}))
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
    str = fullfile(classi.path, ['netCNN_' classi.strid '.mat']);
    if exist(str,'file')
        load(str); %#ok<LOAD>
        disp(['Loading CNN classifier: ' str]);
        classifierCNN = classifier;
    else
        classifierCNN = [];
    end
else
    classifierCNN = [];
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
    if isPipelineFun
        ctxByIdx = cell(1, numel(roiobj));
    end
else
    logparf = 1;
end

% Channel list expansion if user forced "classify all ROIs"
if numel(channel) < numel(roiobj) && numel(channel) > 0
    channel(numel(channel)+1:numel(roiobj)) = {channel{end}};
end

% -----------------------------
% Main loop
% -----------------------------
for i = 1:numel(roiobj)

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
        roiobj(i).load;
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
        cha = channel{i};
    end
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
        p.Value   = 0.9 * double(i) / numel(roiobj);
        p.Message = ['Classifying ROI  ' roiobj(i).id];
    end

    % ---------------------------------------------------------
    % Dispatch
    % ---------------------------------------------------------
    if para
        if isPipelineFun
            ctx = struct();
            ctx.sel = struct('frames', fra, 'channels', cha);
            ctx.exec = struct('gpu', gpu, 'classifier', classifierStore, 'classifierCNN', classifierCNN, ...
                'classifierProvided', ~isempty(classifierStore), 'classifierCNNProvided', ~isempty(classifierCNN));
            ctx.names = struct('outputName', char(outputName));
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
            ctx = struct();
            ctx.sel = struct('frames', fra, 'channels', cha);
            ctx.exec = struct('gpu', gpu, 'classifier', classifierStore, 'classifierCNN', classifierCNN, ...
                'classifierProvided', ~isempty(classifierStore), 'classifierCNNProvided', ~isempty(classifierCNN));
            ctx.names = struct('outputName', char(outputName));
            try
                ctx = classi.buildCtx('classify', ctx);
            catch
            end
            out = feval(fhandle, roiobj(i), classi, ctx);
            if isstruct(out) && isfield(out,'patch') && ~isempty(out.patch) && exist('roiApplyPatch','file') == 2
                try
                    disp(['[DEBUG] classifyData: using roiApplyPatch for ROI ' num2str(roiobj(i).id)]);
                catch
                    disp('[DEBUG] classifyData: using roiApplyPatch for ROI (id unavailable)');
                end
                roiApplyPatch(roiobj(i), out.patch, ctx);
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
                    ROIManagement(roiobj(i), out.data, out.image, outputName, classiobj);
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

            ROIManagement(roiobj(i),data,image, outputName, classiobj)
        end
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
        if isPipelineFun
            [idx, out] = fetchNext(logparf(i));
            ctx = ctxByIdx{idx};
            if isstruct(out) && isfield(out,'patch') && ~isempty(out.patch) && exist('roiApplyPatch','file') == 2
                try
                    disp(['[DEBUG] classifyData: using roiApplyPatch for ROI ' num2str(roiobj(idx).id)]);
                catch
                    disp('[DEBUG] classifyData: using roiApplyPatch for ROI (id unavailable)');
                end
                roiApplyPatch(roiobj(idx), out.patch, ctx);
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
                    ROIManagement(roiobj(idx), out.data, out.image, outputName, classiobj);
                end
            end
        else
            [idx, data, image] = fetchNext(logparf(i));
            ROIManagement(roiobj(idx),data,image, outputName, classiobj);
        end

    end
end

if ~isempty(p)
    p.Value   = 0.9;
    p.Message = 'Saving project...Please wait...';
end

end % classifyData


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

    gfp = roiobj.image;
    nY  = size(gfp,1);
    nX  = size(gfp,2);
    nF  = size(gfp,4);

    % --- Detect instance segmentation types
    isCPSAM = false;

    if isprop(classif,'classifyFun') && strcmp(classif.classifyFun,'classifyCPSAMFun')
        isCPSAM = true;
    elseif isprop(classif,'description') && ~isempty(classif.description)
        isCPSAM = any(strcmp(classif.description, 'CellposeSAM'));
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

        if isCPSAM && isprop(classif,'outputType') && strcmp(classif.outputType, 'proba')
            chNameProba = [char(outputName) '_cellprob'];
            pixproba = findChannelID(roiobj, chNameProba);
            if isempty(pixproba)
                matrix = zeros(nY, nX, 1, nF, 'single');
                roiobj.addChannel(matrix, chNameProba, [1 0 1], [1 1 1]); % magenta continuous

                pixproba  = size(roiobj.image,3);
                selectid  = roiobj.channelid(pixproba);

                [roiobj.display.rgb, roiobj.display.intensity, roiobj.display.indexed] = ...
                    ensureDisplayRows(roiobj.display.rgb, roiobj.display.intensity, roiobj.display.indexed, selectid);

                roiobj.display.rgb(selectid,:)       = [1 0 1];
                roiobj.display.intensity(selectid,:) = [1 1 1];
                roiobj.display.indexed(selectid,1)   = false;
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


function ensureResultChannel(roiobj, chname, rgb, intensity, indexedFlag, nY, nX, nF)
    pixid = findChannelID(roiobj, chname);

    if isempty(pixid)
        matrix = uint16(zeros(nY, nX, 1, nF));
        roiobj.addChannel(matrix, chname, rgb, intensity);
        pixid = size(roiobj.image,3);

        selectid = roiobj.channelid(pixid);

        if ~isfield(roiobj.display,'indexed') || isempty(roiobj.display.indexed)
            roiobj.display.indexed = zeros(0,1);
        end

        [roiobj.display.rgb, roiobj.display.intensity, roiobj.display.indexed] = ...
            ensureDisplayRows(roiobj.display.rgb, roiobj.display.intensity, roiobj.display.indexed, selectid);

        roiobj.display.rgb(selectid,:)           = rgb;
        roiobj.display.intensity(selectid,:)     = intensity;
        roiobj.display.indexed(selectid,1)       = logical(indexedFlag);
        roiobj.display.selectedchannel(selectid) = true;
    else
        roiobj.image(:,:,pixid,:) = uint16(zeros(nY, nX, 1, nF));
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
function ROIManagement(roiobj, data, image, outputName, classiobj)

    % --- Only re-group classification outputs that belong to this classifier ---
    if nargin >= 5 && ~isempty(outputName) && isa(data,'dataseries')
        data = remapOnlyClassifierDataseries(data, classiobj, outputName);
    end

    roiobj.data  = data;
    roiobj.image = image;

    if numel(image)
        try
            disp(['[DEBUG] ROIManagement: calling roi.save for ROI ' num2str(roiobj.id)]);
        catch
            disp('[DEBUG] ROIManagement: calling roi.save (id unavailable)');
        end
        roiobj.save;   % sauvegarde tout
        roiobj.clear;
        disp('[DEBUG] ROIManagement: roi.save done (image+data), roi.clear called.');
    else
        try
            disp(['[DEBUG] ROIManagement: calling roi.save(''data'') for ROI ' num2str(roiobj.id)]);
        catch
            disp('[DEBUG] ROIManagement: calling roi.save(''data'') (id unavailable)');
        end
        roiobj.save('data');  % seulement les metadonnees
        disp('[DEBUG] ROIManagement: roi.save(''data'') done.');
    end
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
