function addROI(classif, obj, varargin)
% addROI Import ROIs into a @classi object (training set builder).
%
% This function imports ROIs from either:
%   - a @fov (shallow project position), or
%   - another @classi (existing classifier),
% and makes the imported ROIs consistent with the destination classifier:
%   - channel selection (keep/remove)
%   - channel renaming / mapping (including classifier INPUT and OUTPUT mapping)
%   - ensures training dataseries exists (critical for annotation tools)
%   - optionally transfers/preserves annotations (training set) if requested
%
% Side effects / guarantees:
%   1) Every imported ROI will contain a valid training dataseries for classif.strid
%      (even if the source ROI had no dataseries at all).
%   2) The training dataseries length will match size(roi.image,4) (sequence length),
%      except for seq2one where a scalar id is stored in ROI.train but the dataseries
%      still exists to keep GUI logic stable.
%   3) Compatible with roiImporterGUI mapping:
%        ioMap(i).ioChannel is either:
%          - '-' (none),
%          - one of classif.channelName (INPUT channel),
%          - classif.strid (OUTPUT annotation mapping).
%        If ioChannel matches an INPUT, we FORCE rename source channel to that INPUT name.
%        If ioChannel == classif.strid, we treat it as output mapping (handled later).
%        Imported cell_information lineage metadata is then retargeted to the
%        destination annotation channel so lineage overlays keep following it.
%
% Parameters (varargin pairs):
%   'rois'         : vector of ROI indices to import (default all)
%   'convert'      : {srcClassesString, dstClassesString} for class mapping / preserve training
%   'adjustChannel': list of source channel names to keep (others removed)
%   'adjustName'   : legacy mapping helper (kept for backward compatibility)
%   'ioMap'        : struct array mapping channels (from roiImporterGUI)
%
% NOTE:
% - This file assumes helper functions exist:
%     - formatInDataSeries.core(roiObj)
%     - propValues(newObj,orgObj) (defined at end)
% - It also uses ROI methods:
%     - roi.removeChannel(name)
%     - roi.addChannel(matrix, name, rgb, lim)
%     - roi.findChannelID(name)
%
% ------------------------------------------------------------

% ---------- Parse inputs ----------
rois         = [];
convert      = {};
adjustName   = {};   % legacy channel-name mapping helper
adjustChannel= {};
ioMap        = [];

for i = 1:2:numel(varargin)
    key = varargin{i};
    if i+1 > numel(varargin), break; end
    val = varargin{i+1};

    switch lower(string(key))
        case "rois"
            rois = val;
        case "convert"
            convert = val;
        case "adjustname"
            adjustName = val;
        case "adjustchannel"
            adjustChannel = val;
        case "iomap"
            ioMap = val;
    end
end

disp('==== addROI ====');
disp('rois = '), disp(rois);
disp('adjustChannel = '), disp(adjustChannel);
disp('adjustName = '), disp(adjustName);
applyPackageClassMetadata(classif);

% ---------- Source type ----------
if isa(obj,'fov')
    objtype="fov";
    disp('You want to import ROIs from an existing @fov for training');
elseif isa(obj,'classi')
    objtype="classi";
    disp('You want to import ROIs from an existing @classi for training');
else
    disp('The object to transfer from is incompatible ! quitting');
    return;
end

% default import all ROIs
if isempty(rois)
    rois = 1:numel(obj.roi);
end

disp('These ROIs will be imported:');
disp(rois);

% ---------- Determine append index in classif.roi ----------
cc = numel(classif.roi);
if cc==1 && isempty(classif.roi(1).id)
    cc=0;
end

% ---------- Main loop ----------
for ii = 1:length(rois)
    disp(['Processing ROI ' num2str(ii) '/' num2str(length(rois))]);

    duplicate = 0;

    roitocopy = obj.roi(rois(ii));
    if isempty(roitocopy.image)
        roitocopy.load;
        if isempty(roitocopy.image)
            disp('ROI cannot be loaded or does not exist; skipping')
            continue
        end
    end

    % ----- Prevent duplicates by ROI name -----
    for j=1:numel(classif.roi)
        if strcmp(roitocopy.id, classif.roi(j).id)
            disp(['WARNING: Imported ROI "' roitocopy.id '" already exists in ' classif.strid '. Skipping.']);
            duplicate=j;
            break
        end
    end
    if duplicate > 0
        continue
    end

    % ----- Allocate new ROI slot -----
    if cc==0
        classif.roi = roi('',[]);
    else
        classif.roi(cc+1) = roi('',[]);
    end

    % Copy properties (but not .data; propValues excludes 'data')
    classif.roi(cc+1) = propValues(classif.roi(cc+1), roitocopy);
    classif.roi(cc+1).path = classif.path;
    classif.roi(cc+1).classes = classif.classes;

    % ============================================================
    % 1) CHANNEL ADJUSTMENTS (selection + mapping)
    % ============================================================

    % ----- Legacy adjustName mapping (kept for backward compatibility) -----
    % adjustName is assumed to contain *source names* to be renamed into classif.channelName{k}.
    % (This is older behavior and may be inconsistent with roiImporterGUI, but we keep it.)
    if ~isempty(adjustName)
        targetChannel = classif.channelName;
        for k = 1:numel(adjustName)
            thisName = adjustName{k};
            if isempty(thisName), continue; end
            if isstring(thisName), thisName = char(thisName); end
            if ~ischar(thisName), continue; end

            idx = find(matches(classif.roi(cc+1).display.channel, thisName));
            if ~isempty(idx) && k <= numel(targetChannel)
                classif.roi(cc+1).display.channel{idx(1)} = targetChannel{k};
            end
        end
    end

    % ----- Keep only selected channels (adjustChannel) -----
    if ~isempty(adjustChannel)
        currentChannels = classif.roi(cc+1).display.channel;
        if ischar(currentChannels), currentChannels = {currentChannels}; end
        if isstring(currentChannels), currentChannels = cellstr(currentChannels); end
        if ~iscell(currentChannels), currentChannels = {}; end

        if ischar(adjustChannel), adjustChannel = {adjustChannel}; end
        if isstring(adjustChannel), adjustChannel = cellstr(adjustChannel); end

        channelsToKeep   = intersect(currentChannels, adjustChannel, 'stable');
        channelsToRemove = setdiff(currentChannels, channelsToKeep, 'stable');

        for k = 1:numel(channelsToRemove)
            classif.roi(cc+1).removeChannel(channelsToRemove{k});
        end
    end

    % ============================================================
    % 2) TRAINING / DATASERIES CREATION OR TRANSFER
    % ============================================================

    % If we import from another classi and user requested conversion,
    % we may preserve training set by transferring the source dataseries
    trainingSetTransfer = false;
    pixtransferdata     = [];

    if strcmp(classif.category{1},'Image') || strcmp(classif.category{1},'LSTM') || strcmp(classif.category{1},'Timeseries')
        srcData = roitocopy.data;

        if objtype=="classi" && ~isempty(convert) && ~isempty(srcData)
            pixtransferdata = find(arrayfun(@(x) strcmp(x.groupid, obj.strid), srcData));
            if ~isempty(pixtransferdata)
                trainingSetTransfer = true;
            end
        end

        % If no transfer, create empty training arrays and convert them to dataseries
        if ~trainingSetTransfer
            disp('No training set available, creating empty training + dataseries');

            classif.roi(cc+1).train = [];
            classif.roi(cc+1).results = [];
            classif.roi(cc+1).train.(classif.strid) = [];

            nT = size(classif.roi(cc+1).image,4);

            % id vector for seq2seq; scalar for seq2one
            classif.roi(cc+1).train.(classif.strid).id = zeros(1, nT);
            if isprop(classif,'output') && classif.output == 1
                classif.roi(cc+1).train.(classif.strid).id = 0;
            end

            classif.roi(cc+1).train.(classif.strid).classes = classif.classes;

            % Convert ROI.train to dataseries (must create something under roi.data)
            formatInDataSeries.core(classif.roi(cc+1));
        end
    end

    % ============================================================
    % 3) TRANSFER DATASERIES FROM SOURCE ROI (non-empty ones)
    % ============================================================
    disp('Transfer all dataseries from copied ROI');

    roiData = classif.roi(cc+1).data;

    % Find first insertion index for extra dataseries
    if isempty(roiData)
        cd = 1;
    else
        try
            lastHasGroup = false;
            if isstruct(roiData) && isfield(roiData(end),'groupid')
                lastHasGroup = ~isempty(roiData(end).groupid);
            elseif isprop(roiData(end),'groupid')
                lastHasGroup = ~isempty(roiData(end).groupid);
            end
            if lastHasGroup
                cd = numel(roiData) + 1;
            else
                cd = 1;
            end
        catch
            cd = 1;
        end
    end

    dataToCopy = classif.roi(cc+1).data; %#ok<NASGU> % only to preserve old semantics

    % NOTE: we must copy from roitocopy.data, not from classif.roi(cc+1).data
    dataSrc = roitocopy.data;

    for ij = 1:numel(dataSrc)
        if ~isempty(dataSrc(ij).groupid)

            classif.roi(cc+1).data(cd) = dataseries;
            classif.roi(cc+1).data(cd) = propValues(classif.roi(cc+1).data(cd), dataSrc(ij));
            classif.roi(cc+1).data(cd).data = dataSrc(ij).data;

            % If we transfer training dataseries, we rewrite groupid to destination strid
            % and keep only training fields
            if trainingSetTransfer && ~isempty(pixtransferdata) && any(ij == pixtransferdata)
                disp('Found and transferred training set data from copied ROI');
                classif.roi(cc+1).data(cd).groupid = classif.strid;

                % Keep only training columns, remove previous results columns
                % This method is expected to exist on dataseries
                try
                    classif.roi(cc+1).data(cd).removeData('train','keep');
                catch
                    % If removeData signature differs, do not crash import
                    warning('addROI:removeDataFailed','Could not prune dataseries fields; leaving as-is.');
                end
            end

            cd = cd + 1;
        end
    end

    % ============================================================
    % 4) ENSURE TRAINING DATASERIES EXISTS (CRITICAL FOR ANNOTATION GUI)
    % ============================================================
    % Even after copying, the ROI might still not have a dataseries for classif.strid.
    % We guarantee it exists and has correct length.
    ensureTrainingDataseriesExists(classif.roi(cc+1), classif);

    % ============================================================
    % 5) APPLY roiImporterGUI CLASS MAPPING (convert)
    % ============================================================
    % For LSTM/classification import with "Preserve annotations",
    % roiImporterGUI sends convert = {sourceClasses, destinationClasses}.
    % We must remap transferred training labels/ids to destination classes.
    if trainingSetTransfer && ~isempty(convert)
        applyConvertClassMapping(classif.roi(cc+1), classif, convert);
    end

    % ============================================================
    % 6) APPLY roiImporterGUI CHANNEL MAP (ioMap)
    % ============================================================
    % This is the key compatibility fix:
    % - If ioMap(mm).ioChannel matches an INPUT channel (classif.channelName),
    %   then rename the source channel name to EXACTLY that input name.
    % - If ioMap(mm).ioChannel == classif.strid, it is output/annotation mapping:
    %   we do not rename here; output is handled later via outName.
    % - Otherwise if ioMap(mm).destName is specified, apply generic rename.
    if ~isempty(ioMap) && isstruct(ioMap)
        applyIOMapChannelRename(classif.roi(cc+1), classif, ioMap);
    end

    % ============================================================
    % 7) PIXEL/OBJECT/DELTA/PEDIGREE OUTPUT CHANNEL HANDLING
    % ============================================================
    if strcmp(classif.category{1},'Pixel') || strcmp(classif.category{1},'Object') || ...
       strcmp(classif.category{1},'Delta') || strcmp(classif.category{1},'Pedigree')

        im = classif.roi(cc+1).image;

        outName = annotationChannelNameForClassifier(classif);
        try
            if isprop(classif, 'classifierPkg') && strcmpi(char(string(classif.classifierPkg)), 'deeplab_pixel_classification')
                deeplab_pixel_classification.migrateAnnotationChannels(classif.roi(cc+1), classif, 'RemoveLegacy', true);
            end
        catch
        end

        % Special case: Pixel output channel may already exist in imported ROI and should be reused.
        if strcmp(classif.category{1},'Pixel') && ~isempty(ioMap) && isstruct(ioMap)
            reuseGT = reuseOutputAnnotationIfMapped(classif.roi(cc+1), classif, ioMap, outName);
        else
            reuseGT = false;
        end

        % If output channel does not exist, create a blank indexed annotation channel.
        pixOut = classif.roi(cc+1).findChannelID(outName);
        if isempty(pixOut)
            matrix = uint16(zeros(size(im,1), size(im,2), 1, size(im,4)));
            classif.roi(cc+1).addChannel(matrix, outName, [1 1 1], [0 0 0]);
            classif.roi(cc+1).display.selectedchannel(end) = 1;
        end

        % If importing from another classi, and both have a channel named by their strid,
        % copy pixels from source annotation channel to new annotation channel (legacy behavior)
        if isa(obj,'classi')
            pixid    = roitocopy.findChannelID(obj.strid);
            pixidnew = classif.roi(cc+1).findChannelID(outName);

            if ~isempty(pixid) && ~isempty(pixidnew)
                classif.roi(cc+1).image(:,:,pixidnew,:) = roitocopy.image(:,:,pixid,:);
            end
        end

        if reuseGT && ~isempty(ioMap) && isstruct(ioMap)
            syncCellInformationLineageChannel(classif.roi(cc+1), classif, ioMap, outName);
        end

        selectClassifierDisplayChannels(classif.roi(cc+1), classif, outName);
    end

    % ============================================================
    % 8) FINALIZE ROI
    % ============================================================
    classif.roi(cc+1).save;
    classif.roi(cc+1).clear;

    cc = cc + 1;
end

% ------------------------------------------------------------
% LOCAL HELPERS
% ------------------------------------------------------------

    function ensureTrainingDataseriesExists(roiObj, classifObj)
        % Ensure there is a dataseries with groupid==classif.strid and that it has
        % at least the columns needed by annotation routines.
        %
        % This prevents errors like "pix undefined" in score/addROI when no dataseries exists.

        if isempty(roiObj.data)
            roiObj.data = dataseries;
        end

        % Find existing ds for this classifier
        dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid, classifObj.strid), roiObj.data), 1, 'first');

        % Create if missing
        if isempty(dsIdx)
            % Append safely
            if numel(roiObj.data)==1 && isempty(roiObj.data(1).data) && isempty(roiObj.data(1).groupid)
                dsIdx = 1;
            else
                dsIdx = numel(roiObj.data) + 1;
                roiObj.data(dsIdx) = dataseries;
            end
            roiObj.data(dsIdx).class    = "classification";
            roiObj.data(dsIdx).groupid  = classifObj.strid;
            roiObj.data(dsIdx).parentid = roiObj.id;
        end

        ds = roiObj.data(dsIdx);

        % Determine full length
        nT = size(roiObj.image,4);

        % Guarantee a table exists
        if isempty(ds.data)
            ds.data = table;
        end

        % Ensure required columns exist
        % - labels_training is what GUI expects to show/hide for annotation.
        % - id_training can be useful for training targets.
        % - We keep consistent size (nT x 1) even if only a subset will be filled later.

        if ~ismember('labels_training', ds.data.Properties.VariableNames)
            ds.data.labels_training = categorical(repmat("undefined", nT, 1));
        else
            ds.data.labels_training = padCategorical(ds.data.labels_training, nT, "undefined");
        end

        if ~ismember('id_training', ds.data.Properties.VariableNames)
            ds.data.id_training = zeros(nT,1);
        else
            ds.data.id_training = padNumeric(ds.data.id_training, nT, 0);
        end

        % Basic plotting metadata (some UIs expect these fields)
        if ~isprop(ds,'plotProperties') || isempty(ds.plotProperties)
            % Minimal plotProperties containing labels_training
            ds.plotProperties = {
                true,  'labels_training', 'categorical', 'k', 2, 'label';
                false, 'id_training',     'double',      'k', 2, 'id';
            };
        else
            % Make sure labels_training row exists and is enabled
            pp = ds.plotProperties;
            names = lower(string(pp(:,2)));
            pidx = find(names=="labels_training",1);
            if isempty(pidx)
                pp(end+1,:) = {true, 'labels_training', 'categorical', 'k', 2, 'label'};
            else
                pp{pidx,1} = true;
            end
            ds.plotProperties = pp;
        end

        % Commit
        roiObj.data(dsIdx) = ds;

        % Also ensure ROI.train structure exists (used by some legacy tools)
        if ~isfield(roiObj,'train') || isempty(roiObj.train) || ~isfield(roiObj.train, classifObj.strid)
            roiObj.train.(classifObj.strid) = [];
            if isprop(classifObj,'output') && classifObj.output==1
                roiObj.train.(classifObj.strid).id = 0;
            else
                roiObj.train.(classifObj.strid).id = zeros(1,nT);
            end
            roiObj.train.(classifObj.strid).classes = classifObj.classes;
        end
    end

    function applyIOMapChannelRename(roiObj, classifObj, ioMapLocal)
        % Apply channel mapping as built by roiImporterGUI.
        % Expected struct fields: import, sourceName, destName, ioChannel.
        % ioChannel is either '-' / inputName / classif.strid (output).
        %
        % Key guarantee: if ioChannel is an INPUT channel, rename to that exact name.

        % Get current channel list
        chNames = {};
        if isfield(roiObj.display,'channel') && ~isempty(roiObj.display.channel)
            chNames = roiObj.display.channel;
            if ischar(chNames), chNames = {chNames}; end
            if isstring(chNames), chNames = cellstr(chNames); end
            if ~iscell(chNames), chNames = {}; end
        end

        if isempty(chNames)
            return
        end

        for mm = 1:numel(ioMapLocal)
            % Robust import flag
            doImport = true;
            if isfield(ioMapLocal,'import')
                val = ioMapLocal(mm).import;
                if isempty(val)
                    doImport = false;
                elseif islogical(val) && isscalar(val)
                    doImport = val;
                elseif isnumeric(val) && isscalar(val)
                    doImport = (val ~= 0);
                else
                    doImport = false;
                end
            end
            if ~doImport
                continue
            end

            % Source name
            src = '';
            if isfield(ioMapLocal,'sourceName'), src = ioMapLocal(mm).sourceName; end
            if isstring(src), src = char(src); end
            if ~ischar(src) || isempty(strtrim(src))
                continue
            end
            src = strtrim(src);

            % Destination name
            dest = '';
            if isfield(ioMapLocal,'destName'), dest = ioMapLocal(mm).destName; end
            if isstring(dest), dest = char(dest); end
            if ~ischar(dest), dest = ''; end
            dest = strtrim(dest);

            % I/O mapping channel
            ioCh = '';
            if isfield(ioMapLocal,'ioChannel'), ioCh = ioMapLocal(mm).ioChannel; end
            if isstring(ioCh), ioCh = char(ioCh); end
            if ~ischar(ioCh), ioCh = ''; end
            ioCh = strtrim(ioCh);

            % Find index of this source channel
            idx = find(strcmp(chNames, src), 1);
            if isempty(idx)
                % fallback: matches (case-insensitive)
                idx = find(matches(chNames, src), 1);
            end
            if isempty(idx)
                continue
            end

            % 1) If mapped to OUTPUT (annotation), do not rename here.
            if ~isempty(ioCh) && strcmp(ioCh, classifObj.strid)
                % handled later by output channel logic
                continue
            end

            % 2) If mapped to a classifier INPUT: force rename to ioCh
            if ~isempty(ioCh) && ~isempty(classifObj.channelName) && any(strcmp(classifObj.channelName, ioCh))
                roiObj.display.channel{idx} = ioCh;
                resetInputChannelDisplayStyle(roiObj, idx);
                chNames{idx} = ioCh;
                continue
            end

            % 3) Otherwise apply generic rename src -> dest if provided
            if ~isempty(dest) && ~strcmp(dest, src)
                roiObj.display.channel{idx} = dest;
                chNames{idx} = dest;
            end
        end

        % Defensive pass: whatever the source metadata was, classifier input
        % channels are raw image channels and must not appear as annotation masks.
        if isprop(classifObj, 'channelName') && ~isempty(classifObj.channelName)
            inputNames = cellstr(string(classifObj.channelName));
            for kk = 1:numel(inputNames)
                idx = find(strcmp(chNames, inputNames{kk}), 1);
                if ~isempty(idx)
                    resetInputChannelDisplayStyle(roiObj, idx);
                end
            end
        end
    end

    function resetInputChannelDisplayStyle(roiObj, idx)
        if isempty(roiObj.display) || ~isstruct(roiObj.display) || isempty(idx)
            return
        end
        nLog = max(idx, numel(roiObj.display.channel));
        roiObj.display = ensureDisplayVectorLocal(roiObj.display, 'indexed', nLog, 0);
        roiObj.display = ensureDisplayVectorLocal(roiObj.display, 'contour', nLog, 0);
        roiObj.display = ensureDisplayVectorLocal(roiObj.display, 'alpha', nLog, 1);
        roiObj.display = ensureDisplayVectorLocal(roiObj.display, 'width', nLog, 1);
        roiObj.display.indexed(idx) = 0;
        roiObj.display.contour(idx) = 0;
        roiObj.display.alpha(idx) = 1;
        roiObj.display.width(idx) = 1;
        if isfield(roiObj.display, 'intensity') && size(roiObj.display.intensity, 1) >= idx && ...
                all(double(roiObj.display.intensity(idx, :)) == 0)
            roiObj.display.intensity(idx, :) = [1 1 1];
        end
    end

    function display = ensureDisplayVectorLocal(display, fieldName, nLog, fillValue)
        if isfield(display, fieldName) && ~isempty(display.(fieldName))
            value = display.(fieldName)(:).';
        else
            value = [];
        end
        if numel(value) < nLog
            value(end+1:nLog) = fillValue;
        elseif numel(value) > nLog
            value = value(1:nLog);
        end
        display.(fieldName) = value;
    end

    function applyConvertClassMapping(roiObj, classifObj, convertSpec)
        % Apply class remapping requested in roiImporterGUI:
        % convertSpec = {sourceClassList, destinationClassList}
        % Example: {'bud neck cell', 'bud 0 cell'}.

        [srcClasses, dstTokens] = parseConvertSpec_(convertSpec);
        if isempty(srcClasses) || isempty(dstTokens) || isempty(classifObj.classes)
            return
        end

        nSrc = numel(srcClasses);
        remapIdx = zeros(nSrc,1); % old idx -> new idx (0 = delete)

        for kk = 1:nSrc
            tok = strtrim(char(string(dstTokens{kk})));
            if isempty(tok) || strcmp(tok,'0') || strcmp(tok,'-') || strcmp(tok,'--')
                remapIdx(kk) = 0;
                continue
            end
            j = find(strcmp(classifObj.classes, tok), 1);
            if isempty(j)
                remapIdx(kk) = 0;
            else
                remapIdx(kk) = j;
            end
        end

        if isempty(roiObj.data)
            return
        end

        dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid, classifObj.strid), roiObj.data), 1, 'first');
        if isempty(dsIdx)
            return
        end

        ds = roiObj.data(dsIdx);
        T  = ds.data;
        if ~istable(T) || isempty(T)
            return
        end

        vars = T.Properties.VariableNames;
        changed = false;

        if ismember('id_training', vars) && isnumeric(T.id_training)
            idOld = T.id_training;
            idNew = zeros(size(idOld));
            valid = idOld >= 1 & idOld <= nSrc;
            idNew(valid) = remapIdx(idOld(valid));
            if ~isequaln(idOld, idNew)
                T.id_training = idNew;
                changed = true;
            end
        end

        if ismember('labels_training', vars)
            lab = T.labels_training;
            if iscategorical(lab)
                s = string(lab);
            elseif isstring(lab)
                s = lab;
            elseif iscell(lab)
                s = string(lab);
            else
                s = string(lab);
            end

            out = s;
            for kk = 1:nSrc
                srcName = string(srcClasses{kk});
                newIdx  = remapIdx(kk);
                if newIdx > 0
                    out(s == srcName) = string(classifObj.classes{newIdx});
                else
                    out(s == srcName) = "";
                end
            end
            out(ismissing(s)) = "";
            labNew = categorical(out, string(classifObj.classes));

            if ~isequaln(lab, labNew)
                T.labels_training = labNew;
                changed = true;
            end
        end

        if changed
            ds.data = T;
            try
                if isempty(ds.userData) || ~isstruct(ds.userData)
                    ds.userData = struct();
                end
                ds.userData.classes = classifObj.classes;
            catch
            end
            roiObj.data(dsIdx) = ds;
        end
    end

    function [srcClasses, dstTokens] = parseConvertSpec_(convertSpec)
        srcClasses = {};
        dstTokens  = {};

        if isempty(convertSpec) || ~iscell(convertSpec) || numel(convertSpec) < 2
            return
        end

        srcClasses = splitClassList_(convertSpec{1});
        dstTokens  = splitClassList_(convertSpec{2});

        if isempty(srcClasses) || isempty(dstTokens)
            srcClasses = {};
            dstTokens  = {};
            return
        end

        nSrc = numel(srcClasses);
        if numel(dstTokens) < nSrc
            dstTokens(end+1:nSrc) = {''};
        elseif numel(dstTokens) > nSrc
            dstTokens = dstTokens(1:nSrc);
        end
    end

    function out = splitClassList_(in)
        out = {};

        if ischar(in) || (isstring(in) && isscalar(in))
            txt = char(string(in));
        elseif isstring(in)
            txt = strjoin(cellstr(in(:)'), ' ');
        elseif iscell(in)
            try
                txt = strjoin(cellfun(@(x) char(string(x)), in(:)', 'UniformOutput', false), ' ');
            catch
                txt = '';
            end
        else
            txt = '';
        end

        txt = strtrim(txt);
        if isempty(txt)
            return
        end

        parts = regexp(txt, '[,;\s]+', 'split');
        parts = parts(~cellfun(@isempty, parts));
        out   = cellfun(@(x) char(string(x)), parts, 'UniformOutput', false);
    end

    function reuseGT = reuseOutputAnnotationIfMapped(roiObj, classifObj, ioMapLocal, outName)
        % If the imported ROI already has an annotation channel that the user mapped to OUTPUT,
        % rename that existing channel to outName so we reuse it instead of creating a blank one.
        reuseGT = false;

        % Channel list
        chNames = roiObj.display.channel;
        if ischar(chNames), chNames = {chNames}; end
        if isstring(chNames), chNames = cellstr(chNames); end
        if ~iscell(chNames), chNames = {}; end

        for mm = 1:numel(ioMapLocal)
            if ~isImportMapEntryEnabled(ioMapLocal, mm)
                continue
            end

            ioCh = '';
            if isfield(ioMapLocal,'ioChannel'), ioCh = ioMapLocal(mm).ioChannel; end
            if isstring(ioCh), ioCh = char(ioCh); end
            if ~ischar(ioCh), ioCh = ''; end
            ioCh = strtrim(ioCh);

            if ~isOutputAnnotationMapping(ioCh, classifObj)
                continue
            end

            srcName  = '';
            destName = '';

            if isfield(ioMapLocal,'sourceName'), srcName = ioMapLocal(mm).sourceName; end
            if isstring(srcName), srcName = char(srcName); end
            if ~ischar(srcName), srcName = ''; end

            if isfield(ioMapLocal,'destName'), destName = ioMapLocal(mm).destName; end
            if isstring(destName), destName = char(destName); end
            if ~ischar(destName), destName = ''; end

            if isempty(destName)
                destName = srcName;
            end

            idxGT = find(matches(chNames, destName), 1);
            if isempty(idxGT) && ~isempty(srcName)
                idxGT = find(matches(chNames, srcName), 1);
            end

            if ~isempty(idxGT)
                idxOut = find(matches(chNames, outName), 1);
                if ~isempty(idxOut) && idxOut ~= idxGT
                    pixSrc = roiObj.findChannelID(chNames{idxGT});
                    pixOut = roiObj.findChannelID(outName);
                    if ~isempty(pixSrc) && ~isempty(pixOut) && numel(pixSrc) == numel(pixOut)
                        roiObj.image(:,:,pixOut,:) = roiObj.image(:,:,pixSrc,:);
                        copyDisplayStyleForLogicalChannel(roiObj, idxGT, idxOut, pixSrc, pixOut);
                        reuseGT = true;
                        break
                    end
                else
                    roiObj.display.channel{idxGT} = outName;
                    reuseGT = true;
                    break
                end
            end
        end
    end

    function copyDisplayStyleForLogicalChannel(roiObj, srcLogical, dstLogical, pixSrc, pixDst)
        if isempty(roiObj.display) || ~isstruct(roiObj.display)
            return
        end

        vectorFields = {'indexed','contour','alpha','width'};
        for ff = 1:numel(vectorFields)
            nm = vectorFields{ff};
            if isfield(roiObj.display, nm) && numel(roiObj.display.(nm)) >= max(srcLogical, dstLogical)
                roiObj.display.(nm)(dstLogical) = roiObj.display.(nm)(srcLogical);
            end
        end

        rowFields = {'rgb','intensity'};
        for ff = 1:numel(rowFields)
            nm = rowFields{ff};
            if isfield(roiObj.display, nm) && size(roiObj.display.(nm),1) >= max(srcLogical, dstLogical)
                roiObj.display.(nm)(dstLogical,:) = roiObj.display.(nm)(srcLogical,:);
            end
        end

        if isfield(roiObj.display, 'displaylim') && size(roiObj.display.displaylim,2) >= max([pixSrc(:); pixDst(:)])
            roiObj.display.displaylim(:, pixDst) = roiObj.display.displaylim(:, pixSrc);
        end
        if isfield(roiObj.display, 'selectedchannel') && numel(roiObj.display.selectedchannel) >= dstLogical
            roiObj.display.selectedchannel(dstLogical) = true;
        end
    end

    function selectClassifierDisplayChannels(roiObj, classifObj, outName)
        if isempty(roiObj.display) || ~isstruct(roiObj.display) || ...
                ~isfield(roiObj.display, 'channel') || isempty(roiObj.display.channel)
            return
        end

        chNames = roiObj.display.channel;
        if ischar(chNames), chNames = {chNames}; end
        if isstring(chNames), chNames = cellstr(chNames); end
        if ~iscell(chNames), return; end

        roiObj.display.selectedchannel = false(1, numel(chNames));

        inputNames = {};
        if isprop(classifObj, 'channelName') && ~isempty(classifObj.channelName)
            inputNames = cellstr(string(classifObj.channelName));
        end
        visibleNames = [inputNames(:); {outName}];

        for kk = 1:numel(visibleNames)
            nm = char(string(visibleNames{kk}));
            if isempty(nm), continue; end
            hit = find(strcmp(chNames, nm), 1);
            if ~isempty(hit)
                roiObj.display.selectedchannel(hit) = true;
            end
        end
    end

    function syncCellInformationLineageChannel(roiObj, classifObj, ioMapLocal, outName)
        % The lineage maps are copied with the dataseries, but their mask channel
        % metadata still points to the source classifier. When the user maps that
        % source mask as the destination annotation channel, retarget the metadata.
        if isempty(outName) || ~hasOutputAnnotationMapping(ioMapLocal, classifObj)
            return
        end

        if isempty(roiObj.data)
            return
        end

        pixOut = roiObj.findChannelID(outName);
        if iscell(pixOut)
            pixOut = cell2mat(pixOut);
        end
        if isempty(pixOut)
            return
        end

        dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roiObj.data));
        if isempty(dsIdx)
            return
        end

        for kk = dsIdx(:).'
            ds = roiObj.data(kk);
            if isempty(ds.userData) || ~isstruct(ds.userData)
                ds.userData = struct();
            end
            ds.userData.lineageChannelName = string(outName);
            ds.userData.lineageChannelPix  = double(pixOut(1));
            roiObj.data(kk) = ds;
        end
    end

    function tf = hasOutputAnnotationMapping(ioMapLocal, classifObj)
        tf = false;
        for mm = 1:numel(ioMapLocal)
            if ~isImportMapEntryEnabled(ioMapLocal, mm)
                continue
            end
            ioCh = '';
            if isfield(ioMapLocal,'ioChannel'), ioCh = ioMapLocal(mm).ioChannel; end
            if isstring(ioCh), ioCh = char(ioCh); end
            if ~ischar(ioCh), ioCh = ''; end
            if isOutputAnnotationMapping(ioCh, classifObj)
                tf = true;
                return
            end
        end
    end

    function tf = isOutputAnnotationMapping(ioCh, classifObj)
        ioCh = strtrim(char(string(ioCh)));
        target = '';
        try
            target = char(string(classifObj.strid));
        catch
        end
        tf = (~isempty(target) && strcmp(ioCh, target)) || strcmpi(ioCh, 'Classifier annotation');
    end

    function tf = isImportMapEntryEnabled(ioMapLocal, idx)
        tf = true;
        if ~isfield(ioMapLocal, 'import')
            return
        end
        val = ioMapLocal(idx).import;
        if isempty(val)
            tf = false;
        elseif islogical(val) && isscalar(val)
            tf = val;
        elseif isnumeric(val) && isscalar(val)
            tf = (val ~= 0);
        elseif ischar(val) || (isstring(val) && isscalar(val))
            tf = any(strcmpi(strtrim(char(string(val))), {'true','1','yes','on'}));
        else
            tf = false;
        end
    end

    function applyPackageClassMetadata(classifObj)
        try
            pkg = '';
            if isprop(classifObj, 'classifierPkg') && ~isempty(classifObj.classifierPkg)
                pkg = char(string(classifObj.classifierPkg));
            elseif isprop(classifObj, 'trainingFun') && ~isempty(classifObj.trainingFun)
                f = char(string(classifObj.trainingFun));
                dot = strfind(f, '.');
                if ~isempty(dot)
                    pkg = f(1:dot(1)-1);
                end
            end
            if isempty(pkg)
                return;
            end
            fun = [pkg '.ensureClassMetadata'];
            if ~isempty(which(fun))
                feval(fun, classifObj);
            end
        catch
        end
    end

    function outName = annotationChannelNameForClassifier(classifObj)
        outName = '';
        try
            pkg = '';
            if isprop(classifObj, 'classifierPkg') && ~isempty(classifObj.classifierPkg)
                pkg = char(string(classifObj.classifierPkg));
            end
            if ~isempty(pkg)
                fun = [pkg '.annotationChannelName'];
                if ~isempty(which(fun))
                    outName = char(string(feval(fun, classifObj)));
                end
            end
        catch
            outName = '';
        end

        if isempty(outName)
            if isempty(classifObj.classes)
                outName = [classifObj.strid '_cell'];
            else
                outName = [classifObj.strid '_' classifObj.classes{1}];
            end
        end
    end

    function v = padNumeric(v, n, fill)
        v = v(:);
        if numel(v) >= n
            v = v(1:n);
        else
            v(end+1:n,1) = fill;
        end
    end

    function c = padCategorical(c, n, undef)
        if ~iscategorical(c)
            c = categorical(c);
        end
        c = c(:);
        if numel(c) >= n
            c = c(1:n);
        else
            pad = categorical(repmat(string(undef), n-numel(c), 1));
            c = [c; pad];
        end
    end

end % --- end addROI ---


% ------------------------------------------------------------
% propValues helper (keeps original semantics: do not copy .data)
% ------------------------------------------------------------
function newObj = propValues(newObj, orgObj)
pl = properties(orgObj);
for k = 1:length(pl)
    if isprop(newObj, pl{k}) && ~strcmp(pl{k}, 'data')
        newObj.(pl{k}) = orgObj.(pl{k});
    end
end
end
