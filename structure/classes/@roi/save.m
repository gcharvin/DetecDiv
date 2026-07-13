function didSave = save(obj, option, verbose)
% didSave = save(obj, option, verbose)

% ---- Normalize inputs ----
if nargin < 2, option  = [];   end
if nargin < 3, verbose = [];   end

% Accept a lone boolean as 'verbose'
if isempty(verbose) && islogical(option) && isscalar(option)
    verbose = option;
    option  = [];
end

% Also accept name-value 'Verbose',true/false in 'option'
if iscell(option)
    ix = find(strcmpi(option,'Verbose'),1);
    if ~isempty(ix) && numel(option) >= ix+1 && islogical(option{ix+1})
        verbose = option{ix+1};
        option([ix ix+1]) = []; % remove the pair
    end
end

if isempty(verbose), verbose = true; end

obj.normalizeDisplayCache();
imArray = obj.image;        % [H W C T]
dsArray = obj.data;
didSave = false;

if isempty(obj.path) || ~isfolder(obj.path)
    if verbose, disp('ERROR: Invalid or missing path for ROI save.'); end
    return;
end

absStart0 = [];
if isfield(obj.display,'write_abs_start') && ~isempty(obj.display.write_abs_start)
    absStart0 = double(obj.display.write_abs_start);   % 0-based
end

h5File    = fullfile(obj.path, ['im_'   obj.id '.h5']);
h5BakFile = fullfile(obj.path, ['im_'   obj.id '.bak']);   %%% ATOMIC WRITE (backup)
dataFile  = fullfile(obj.path, ['data_' obj.id '.mat']);
dataBak   = fullfile(obj.path, ['data_' obj.id '.bak']);   %%% ATOMIC WRITE (backup)

% ---------- Interpret 'option' ----------
onlyData = (ischar(option)   && strcmp(option,'data')) || ...
    (isstring(option) && option=="data");

if onlyData
    requestedChannels = [];   % special marker: only data.mat
else
    % normalize channel list
    if isstring(option); option = cellstr(option); end
    if ischar(option);   option = {option};        end
    if iscell(option)
        requestedChannels = option;   % partial save on these logical channels
    else
        requestedChannels = {};       % FULL SAVE (all logical channels)
    end
end

if iscell(requestedChannels)
    requestedChannels = cellfun(@(s)char(string(s)), requestedChannels, 'UniformOutput', false);
end

success      = false;
attempts     = 0;
max_attempts = 5;

if isempty(imArray) && ~onlyData && verbose==true
    disp('Image was not in memory, hence we don t save image data')
end

while ~success && attempts < max_attempts
%     try
    imageSaved = false;
    dataSaved  = false;

    % ==================================================
    % 1) Sauvegarde HDF5 (images) — ATOMIC
    % ==================================================
    if ~onlyData && ~isempty(imArray)

        % Harmoniser la taille de imArray en [H W C T]
        sz = size(imArray);
        if numel(sz) < 4
            if numel(sz)==2
                sz = [sz 1 1];
                imArray = reshape(imArray, sz);
            elseif numel(sz)==3
                sz = [sz 1];
                imArray = reshape(imArray, sz);
            end
        end
        H = sz(1); W = sz(2); C = sz(3); T = sz(4);

        % Noms logiques
        logicNames = getLogicalChannelNames(obj);

        % fullSave = tous les canaux
        fullSave = (~onlyData) && isempty(requestedChannels);

        % A ROI can legitimately hold a compact, partially loaded image in
        % memory (for example only ch1), while display/channelid still know
        % about every logical channel stored in the HDF5 file. In that case
        % a "full" save must preserve the HDF5 datasets that are not backed
        % by obj.image instead of indexing past the compact C dimension.
        [channelIndexSets, channelHasImage] = localImageBackedChannelSets(obj, logicNames, C);
        existingH5Channels = {};
        h5ChannelsNotInMemory = {};
        if fullSave && exist(h5File,'file')
            existingH5Channels = localH5LogicalChannelNames(h5File);
            h5ChannelsNotInMemory = setdiff(existingH5Channels, logicNames, 'stable');
        end
        if fullSave && exist(h5File,'file') && (any(~channelHasImage) || ~isempty(h5ChannelsNotInMemory))
            fullSave = false;
            requestedChannels = logicNames(channelHasImage);
            if verbose
                skipped = unique([logicNames(~channelHasImage), h5ChannelsNotInMemory], 'stable');
                fprintf(['ROI #%s: image in memory contains %d/%d logical channel(s); ' ...
                    'preserving existing HDF5 datasets for: %s.\n'], ...
                    obj.id, nnz(channelHasImage), max(numel(logicNames), numel(existingH5Channels)), ...
                    strjoin(skipped, ', '));
            end
        end

        if ~fullSave && ~exist(h5File,'file')
            if verbose
                disp('Partial save requested but no H5 exists, falling back to full save.');
            end
            fullSave = true;
            requestedChannels = {};
        end

        frameUpsertMode = ~isempty(absStart0);

        % If partial save but H5 is inconsistent (or size changed), fallback to full save.
        % During streaming ROI extraction, each call contains one time block.
        % In that mode T is expected to differ from the existing H5 length;
        % only spatial dimensions must match so previous blocks are preserved.
        if ~fullSave && exist(h5File,'file')
            if frameUpsertMode
                h5DimsOk = localH5SpatialDimsConsistent(h5File, [H W], verbose);
            else
                h5DimsOk = localH5DimsConsistent(h5File, [H W T], verbose);
            end
            if ~h5DimsOk
                if verbose
                    disp('Partial save disabled: H5 dimensions inconsistent, falling back to full save.');
                end
                fullSave = true;
                requestedChannels = {};
            end
        end

        %%% ATOMIC WRITE: on prépare un fichier de travail temporaire
        tmpUuid  = char(java.util.UUID.randomUUID);
        h5Tmp    = [h5File '.tmp.' tmpUuid];
        localH5Tmp = fullfile(tempdir, ['detecdiv_roi_h5_' tmpUuid '.h5']);

        if exist(localH5Tmp,'file'), delete(localH5Tmp); end
        if exist(h5Tmp,'file'), delete(h5Tmp); end

        % Stratégie:
        % - fullSave      : nouveau fichier propre -> on écrit tout dans h5Tmp
        % - partial save  : si h5File existe, on le copie vers h5Tmp pour préserver le reste
        if fullSave
            % rien à copier — création à l'écriture par upsert
        else
            if exist(h5File,'file')
                copyfile(h5File, localH5Tmp, 'f');
            end
        end

        % Boucler sur CHAQUE canal LOGIQUE
        for iChan = 1:numel(logicNames)
            chanNameLogical = logicNames{iChan};

            % Décider si on écrit ce canal logique
            doThisOne = fullSave || any(strcmpi(requestedChannels, chanNameLogical));
            if ~doThisOne, continue; end

            % Indices de la 3e dimension
            idxSet = channelIndexSets{iChan};
            if isempty(idxSet)
                if verbose
                    fprintf('ROI #%s: skipping HDF5 save of "%s" (channel not loaded in image memory).\n', ...
                        obj.id, chanNameLogical);
                end
                continue;
            end

            k = numel(idxSet);
            chanBlock = imArray(:,:,idxSet,:);   % [H W k T]
            thisClass = class(chanBlock);

            % Dataset path
            dsetNameSanitized = sanitizeDatasetName(chanNameLogical);
            h5Path = ['/' dsetNameSanitized];

            % For ordinary partial save, replace the full logical dataset.
            % For frameUpsertMode, keep it and overwrite only the requested
            % temporal hyperslab; deleting here would create black holes for
            % all previously extracted blocks.
            if ~fullSave && ~frameUpsertMode
                try
                    if exist(localH5Tmp,'file')
                        fid = H5F.open(localH5Tmp,'H5F_ACC_RDWR','H5P_DEFAULT');
                        if H5L.exists(fid, h5Path, 'H5P_DEFAULT') > 0
                            H5L.delete(fid, h5Path, 'H5P_DEFAULT');
                        end
                        H5F.close(fid);
                    end
                catch
                    % ignore if delete fails (will upsert)
                end
            end

            % Ecriture/Upsert dans le FICHIER TEMP local
            upsertH5Dataset_frames(localH5Tmp, h5Path, chanBlock, [H W k T], thisClass, absStart0);

            % Attributs
            h5writeatt(localH5Tmp, h5Path, 'roi_id',          obj.id);
            h5writeatt(localH5Tmp, h5Path, 'bbox',            getBBox(obj));
            h5writeatt(localH5Tmp, h5Path, 'frames',          getFrames(obj,T));
            h5writeatt(localH5Tmp, h5Path, 'channel_name',    chanNameLogical);
            h5writeatt(localH5Tmp, h5Path, 'channel_indices', idxSet);
            h5writeatt(localH5Tmp, h5Path, 'channelid',       obj.channelid);

            % Attributs d'affichage
            dispMeta = buildDisplayMetaForChannel(obj, iChan, k);
            names = fieldnames(dispMeta);
            for i = 1:numel(names)
                nm = names{i};
                v  = dispMeta.(nm);
                if isempty(v), continue; end
                v = to_h5_attr(v);
                try
                    h5writeatt(localH5Tmp, h5Path, nm, v);
                catch
                    try
                        h5writeatt(localH5Tmp, h5Path, nm, char(string(v)));
                    catch
                        % silencieux si ~verbose
                        if verbose
                            warning('roi:save:AttrWriteFailed','Attribute %s not written.', nm);
                        end
                    end
                end
            end

            % Extraction marker persisted in H5 for fast status checks.
            try
                if isprop(obj,'extraction') && isstruct(obj.extraction)
                    if isfield(obj.extraction,'status') && ~isempty(obj.extraction.status)
                        h5writeatt(localH5Tmp, h5Path, 'roi_extraction_status', char(string(obj.extraction.status)));
                    end
                    if isfield(obj.extraction,'updatedAt') && ~isempty(obj.extraction.updatedAt)
                        h5writeatt(localH5Tmp, h5Path, 'roi_extraction_updatedAt', char(string(obj.extraction.updatedAt)));
                    end
                    if isfield(obj.extraction,'runId') && ~isempty(obj.extraction.runId)
                        h5writeatt(localH5Tmp, h5Path, 'roi_extraction_runId', char(string(obj.extraction.runId)));
                    end
                end
            catch
                if verbose
                    warning('roi:save:ExtractionAttrWriteFailed','Could not write extraction attributes for %s.', obj.id);
                end
            end

            imageSaved = true;
            if verbose
                fprintf('ROI #%s: HDF5 save of "%s" (%d subchan, %d frames).\n', ...
                    obj.id, chanNameLogical, k, T);
            end
        end

        % Vérification + bascule atomique
        if imageSaved
            if ~localVerifyH5(localH5Tmp)
                if exist(localH5Tmp,'file'); delete(localH5Tmp); end
                if exist(h5Tmp,'file'); delete(h5Tmp); end
                error('roi:save:verifyH5','Temporary HDF5 verification failed.');
            end
            localInfo = dir(localH5Tmp);
            localBytes = localInfo.bytes;

            copyfile(localH5Tmp, h5Tmp, 'f');
            copied = false;
            for kCopy = 1:5
                if exist(h5Tmp,'file')
                    remoteInfo = dir(h5Tmp);
                    copied = ~isempty(remoteInfo) && remoteInfo.bytes == localBytes && remoteInfo.bytes > 0;
                    if copied, break; end
                end
                pause(0.2);
            end
            if ~copied
                if exist(localH5Tmp,'file'); delete(localH5Tmp); end
                if exist(h5Tmp,'file'); delete(h5Tmp); end
                error('roi:save:verifyRemoteH5Copy', ...
                    'Remote HDF5 temp copy failed or has unexpected size: %s', h5Tmp);
            end
            % backup ancien fichier
            if exist(h5File,'file')
                copyfile(h5File, h5BakFile, 'f'); %#ok<*NASGU>
            end
            % CIFS/SMB can transiently reject delete/rename with
            % "device or resource busy"; install with retries and copy fallback.
            localInstallStagedFile(h5Tmp, h5File, localBytes, 'HDF5');
            finalOk = false;
            for kMove = 1:5
                if exist(h5File,'file')
                    finalInfo = dir(h5File);
                    finalOk = ~isempty(finalInfo) && finalInfo.bytes == localBytes && finalInfo.bytes > 0;
                    if finalOk, break; end
                end
                pause(0.2);
            end
            if ~finalOk
                error('roi:save:verifyFinalH5Move', ...
                    'Final HDF5 file was not replaced correctly: %s', h5File);
            end
            if exist(localH5Tmp,'file'), delete(localH5Tmp); end
        else
            % Rien écrit -> si un tmp vide a été créé par erreur, on le retire
            if exist(localH5Tmp,'file'), delete(localH5Tmp); end
            if exist(h5Tmp,'file'), delete(h5Tmp); end
        end

        % Après un FULL SAVE (tous les canaux), on allège l'objet
        if fullSave
            obj.image = [];
        end
    end

    % ==================================================
    % 2) Sauvegarde DATA -> .mat — ATOMIC
    % ==================================================
    hasDataToSave = false;
    if ~isempty(dsArray)
        if isa(dsArray,'dataseries')
            hasDataToSave = any(arrayfun(@(ds) ...
                isprop(ds,'groupid') && ~isempty(ds.groupid), dsArray));
        elseif isstruct(dsArray)
            hasDataToSave = isfield(dsArray,'groupid') && ~isempty(dsArray.groupid);
        end
    end

    if onlyData || hasDataToSave
        data = dsArray; %#ok<NASGU>

        %%% ATOMIC WRITE for data .mat
        tmpUuidD = char(java.util.UUID.randomUUID);
        dataTmp  = [dataFile '.tmp.' tmpUuidD '.mat'];
        localDataTmp = fullfile(tempdir, ['detecdiv_roi_data_' tmpUuidD '.mat']);

        if exist(localDataTmp,'file'), delete(localDataTmp); end
        if exist(dataTmp,'file'), delete(dataTmp); end

        try
            save(localDataTmp, 'data', '-v7.3');
            [localOk, localME] = localVerifyMat(localDataTmp);
            if ~localOk
                if ~isempty(localME)
                    disp(getReport(localME,'extended'));
                end
                error('roi:save:verifyLocalMAT','Temporary local MAT verification failed.');
            end
            localInfo = dir(localDataTmp);
            localBytes = localInfo.bytes;

            copyfile(localDataTmp, dataTmp, 'f');
            delete(localDataTmp);

            copied = false;
            for k = 1:5
                if exist(dataTmp,'file')
                    remoteInfo = dir(dataTmp);
                    copied = ~isempty(remoteInfo) && remoteInfo.bytes == localBytes && remoteInfo.bytes > 0;
                    if copied, break; end
                end
                pause(0.2);
            end
            if ~copied
                error('roi:save:verifyRemoteMATCopy', ...
                    'Remote MAT temp copy failed or has unexpected size: %s', dataTmp);
            end
        catch MEwrite
            if exist(localDataTmp,'file'), delete(localDataTmp); end
            if exist(dataTmp,'file'), delete(dataTmp); end
            error('roi:save:dataMATWriteFailed', ...
                'Unable to stage ROI data MAT file for "%s": %s', dataFile, MEwrite.message);
        end

        if exist(dataFile,'file')
            copyfile(dataFile, dataBak, 'f');
        end
        localInstallStagedFile(dataTmp, dataFile, localBytes, 'MAT');

        dataSaved = true;

        if verbose
            fprintf('ROI #%s: MAT data saved (%s).\n', obj.id, dataFile);
        end

        % On purge aussi data pour alléger l'objet stocké dans le projet
        obj.data = dataseries.empty;
    end

    % ==================================================
    % 3) Log interne et sortie
    % ==================================================
    if imageSaved
        obj.log(['Saving ROI image datasets to ' h5File], 'Saving');
    end
    if dataSaved
        obj.log(['Saving ROI data to ' dataFile], 'Saving');
    end

    didSave  = imageSaved || dataSaved;
    success  = true;

    % catch ME
    %     attempts = attempts + 1;
    %     if verbose
    %         fprintf('Erreur lors de la sauvegarde (tentative %d/%d): %s\n', ...
    %             attempts, max_attempts, ME.message);
    %     end
    %     pause(0.5);
    % end
end

% Si tout s'est bien passé, on nettoie les backups .bak
if success
    if exist(h5BakFile,'file')
        delete(h5BakFile);
    end
    if exist(dataBak,'file')
        delete(dataBak);
    end
end


if ~success
    error(['Échec de la sauvegarde après ' num2str(max_attempts) ' tentatives.']);
end
end


%% ===== Helpers =====

function bpp = bytesPerClass(cls)
switch cls
    case {'uint8','int8'}
        bpp = 1;
    case {'uint16','int16'}
        bpp = 2;
    case {'uint32','int32','single'}
        bpp = 4;
    case {'uint64','int64','double'}
        bpp = 8;
    otherwise
        warning('Classe inconnue (%s), on suppose 2 bytes/pixel.', cls);
        bpp = 2;
end
end

function names = getLogicalChannelNames(obj)
names = {};
if isprop(obj,'display') && ~isempty(obj.display) && isstruct(obj.display) ...
        && isfield(obj.display,'channel') && ~isempty(obj.display.channel)
    ch = obj.display.channel;
    if isstring(ch), ch = cellstr(ch); end
    if ~iscell(ch),  ch = {char(string(ch))}; end
    names = ch;
end
if isempty(names), names = {'channel_001'}; end
end

function [idxSets, hasImage] = localImageBackedChannelSets(obj, logicNames, C)
idxSets = cell(1, numel(logicNames));
hasImage = false(1, numel(logicNames));

for iChan = 1:numel(logicNames)
    chanNameLogical = logicNames{iChan};
    idxSet = [];
    try
        idxSet = obj.findChannelID(chanNameLogical, 'exact');  % vector in obj.image C-space
    catch
        idxSet = [];
    end
    if isempty(idxSet)
        try
            idxSet = find(obj.channelid == iChan).';
        catch
            idxSet = [];
        end
        if isempty(idxSet)
            idxSet = iChan;
        end
    end

    idxSet = unique(idxSet(:).', 'stable');
    idxSet = idxSet(isfinite(double(idxSet)) & double(idxSet) >= 1 & double(idxSet) <= C);
    idxSets{iChan} = idxSet;
    hasImage(iChan) = ~isempty(idxSet);
end
end

function names = localH5LogicalChannelNames(h5File)
names = {};
try
    info = h5info(h5File);
catch
    return;
end
if ~isfield(info, 'Datasets') || isempty(info.Datasets)
    return;
end
names = cell(1, numel(info.Datasets));
for i = 1:numel(info.Datasets)
    datasetName = info.Datasets(i).Name;
    h5Path = ['/' datasetName];
    try
        names{i} = char(string(h5readatt(h5File, h5Path, 'channel_name')));
    catch
        names{i} = char(string(datasetName));
    end
end
names = names(~cellfun(@isempty, names));
names = unique(names, 'stable');
end

function bb = getBBox(obj)
bb = [];
if isprop(obj,'value') && ~isempty(obj.value) && numel(obj.value)>=4
    bb = double(obj.value(1:4));
end
end

function fr = getFrames(~,Tfallback)
fr = 1:double(Tfallback);
end

function dispMeta = buildDisplayMetaForChannel(obj, chanLogicalIdx, k)
d = obj.display;
nCh = numel(d.channel);
ii = min(chanLogicalIdx, nCh);
ival=find(obj.channelid==ii);
dispMeta = struct();
forceIndexed = localShouldForceIndexedChannel(d, ii);

if isfield(d,'intensity') && ~isempty(d.intensity)
    row = d.intensity(ii,:);
    dispMeta.display_intensity = row;
end
if isfield(d,'selectedchannel') && ~isempty(d.selectedchannel)
    row = d.selectedchannel(ii);
    dispMeta.display_selectedchannel = row;
end
if isfield(d,'rgb') && ~isempty(d.rgb)
    row = d.rgb(ii,:);
    dispMeta.display_rgb = row;
end
if isfield(d,'colorMode') && ~isempty(d.colorMode) && numel(d.colorMode) >= ii
    dispMeta.display_color_mode = char(string(d.colorMode{ii}));
end
if isfield(d,'colormapName') && ~isempty(d.colormapName) && numel(d.colormapName) >= ii
    dispMeta.display_colormap_name = char(string(d.colormapName{ii}));
end
if isfield(d,'displaylim') && ~isempty(d.displaylim)
    if ival<= size(d.displaylim,2)
        row = d.displaylim(:,ival);
    else
        row=[];
    end
    if isempty(row)
        row = repmat([0;1], 1, k);
    end
    dispMeta.display_displaylim = row;
end
if isfield(d,'indexed') && ~isempty(d.indexed)
    idxVal = d.indexed;
    if numel(idxVal) >= ii
        dispMeta.display_indexed = uint8(idxVal(ii) ~= 0);
    else
        dispMeta.display_indexed = uint8(idxVal(1) ~= 0);
    end
end
if forceIndexed
    dispMeta.display_indexed = uint8(1);
end
if isfield(d,'alpha') && ~isempty(d.alpha)
    aVal = d.alpha;
    if numel(aVal) >= ii
        dispMeta.display_alpha = aVal(ii);
    else
        dispMeta.display_alpha = aVal(1);
    end
end
if isfield(d,'contour') && ~isempty(d.contour)
    cVal = d.contour;
    if numel(cVal) >= ii
        dispMeta.display_contour = uint8(cVal(ii) ~= 0);
    else
        dispMeta.display_contour = uint8(cVal(1) ~= 0);
    end
end
if isfield(d,'log') && ~isempty(d.log)
    cVal = d.log;
    if numel(cVal) >= ii
        dispMeta.display_log = uint8(cVal(ii) ~= 0);
    else
        dispMeta.display_log = uint8(cVal(1) ~= 0);
    end
end
if isfield(d,'width') && ~isempty(d.width)
    wVal = d.width;
    if numel(wVal) >= ii
        dispMeta.display_contourwidth = wVal(ii);
    else
        dispMeta.display_contourwidth = wVal(1);
    end
end
if forceIndexed
    dispMeta.display_indexed = uint8(1);
    dispMeta.display_intensity = [0 0 0];
    dispMeta.display_contour = uint8(1);
    dispMeta.display_alpha = 0.35;
    dispMeta.display_contourwidth = 1.5;
end
if isfield(d,'frame') && ~isempty(d.frame)
    dispMeta.display_frame=d.frame;
end
if isfield(d,'binning') && ~isempty(d.binning)
    dispMeta.display_binning=d.binning;
end
if isfield(d,'valueTransform') && ~isempty(d.valueTransform) && isstruct(d.valueTransform) && numel(d.valueTransform) >= ii
    vt = d.valueTransform(ii);
    try
        mode = lower(strtrim(char(string(vt.mode))));
    catch
        mode = 'raw';
    end
    if strcmp(mode, 'physical')
        dispMeta.value_mode = 'physical';
        if isfield(vt, 'unit') && ~isempty(vt.unit)
            dispMeta.physical_unit = char(string(vt.unit));
        else
            dispMeta.physical_unit = 'physical';
        end
        if isfield(vt, 'physicalRange') && numel(vt.physicalRange) == 2
            dispMeta.physical_min = double(vt.physicalRange(1));
            dispMeta.physical_max = double(vt.physicalRange(2));
        end
        if isfield(vt, 'encodedRange') && numel(vt.encodedRange) == 2
            dispMeta.encoded_min = double(vt.encodedRange(1));
            dispMeta.encoded_max = double(vt.encodedRange(2));
        else
            dispMeta.encoded_min = 0;
            dispMeta.encoded_max = 65535;
        end
        if isfield(vt, 'transform') && ~isempty(vt.transform)
            dispMeta.physical_transform = char(string(vt.transform));
        else
            dispMeta.physical_transform = 'linear';
        end
    else
        dispMeta.value_mode = 'raw';
        dispMeta.physical_unit = 'raw';
    end
else
    dispMeta.value_mode = 'raw';
    dispMeta.physical_unit = 'raw';
end
dispMeta.num_subchannels = k;
end

function tf = localShouldForceIndexedChannel(d, ii)
tf = false;
try
    if ~isfield(d,'channel') || isempty(d.channel) || ii < 1 || ii > numel(d.channel)
        return;
    end
    name = lower(string(d.channel{ii}));
    tf = startsWith(name, "results_") || contains(name, "mask") || ...
        contains(name, "track") || endsWith(name, "_cell");
catch
    tf = false;
end
end


function [ok, ME] = localVerifyMat(matPath)
ok = false; ME = [];
try
    if ~exist(matPath,'file')
        error('roi:save:matMissing','File not found: %s', matPath);
    end
    vars = whos('-file', matPath);
    ok   = ~isempty(vars);
    if ~ok
        error('roi:save:matEmpty','No variables found in MAT: %s', matPath);
    end
catch ME
    ok = false;
end
end


function ok = localVerifyH5(h5Path)       %%% ATOMIC WRITE helper
ok = false;
try
    info = h5info(h5Path); %#ok<NASGU>
    ok = true;
catch
    ok = false;
end
end

function localInstallStagedFile(tmpFile, finalFile, expectedBytes, label)
if nargin < 4 || isempty(label)
    label = 'file';
end
lastMessage = '';
for attempt = 1:8
    try
        if exist(finalFile,'file')
            try
                delete(finalFile);
            catch MEdelete
                lastMessage = MEdelete.message;
                pause(min(0.25 * attempt, 2));
                continue;
            end
        end

        installed = false;
        try
            movefile(tmpFile, finalFile, 'f');
            installed = true;
        catch MEmove
            lastMessage = MEmove.message;
            if exist(tmpFile,'file') && exist(finalFile,'file') ~= 2
                try
                    copyfile(tmpFile, finalFile, 'f');
                    installed = true;
                catch MEcopy
                    lastMessage = [lastMessage ' | copy fallback: ' MEcopy.message];
                end
            end
        end

        if installed && localFileHasExpectedSize(finalFile, expectedBytes)
            if exist(tmpFile,'file')
                try, delete(tmpFile); catch, end
            end
            return;
        end
    catch ME
        lastMessage = ME.message;
    end
    pause(min(0.25 * attempt, 2));
end
error('roi:save:installStagedFileFailed', ...
    'Failed to install staged %s file "%s": %s', char(string(label)), finalFile, lastMessage);
end

function ok = localFileHasExpectedSize(filePath, expectedBytes)
ok = false;
try
    if exist(filePath,'file') ~= 2
        return;
    end
    info = dir(filePath);
    ok = ~isempty(info) && info.bytes == expectedBytes && info.bytes > 0;
catch
    ok = false;
end
end

function ok = localH5DimsConsistent(h5File, curHWT, verbose)
% Verify that all datasets in H5 share same H/W/T and match current image.
ok = false;
try
    info = h5info(h5File);
    dsets = info.Datasets;
    if isempty(dsets)
        ok = false;
        return;
    end

    H0 = []; W0 = []; T0 = [];
    for i = 1:numel(dsets)
        sz = dsets(i).Dataspace.Size;
        if isempty(sz), continue; end
        if numel(sz) < 4
            sz(end+1:4) = 1;
        end
        H = sz(1); W = sz(2); T = sz(4);
        if isempty(H0)
            H0 = H; W0 = W; T0 = T;
        else
            if H ~= H0 || W ~= W0 || T ~= T0
                if verbose
                    fprintf('H5 dim mismatch: %s has [%d %d %d] vs [%d %d %d]\n', ...
                        dsets(i).Name, H, W, T, H0, W0, T0);
                end
                ok = false;
                return;
            end
        end
    end

    if ~isempty(curHWT)
        if H0 ~= curHWT(1) || W0 ~= curHWT(2) || T0 ~= curHWT(3)
            if verbose
                fprintf('H5 dims [%d %d %d] do not match current image [%d %d %d]\n', ...
                    H0, W0, T0, curHWT(1), curHWT(2), curHWT(3));
            end
            ok = false;
            return;
        end
    end

    ok = true;
catch
    ok = false;
end
end

function ok = localH5SpatialDimsConsistent(h5File, curHW, verbose)
% Verify that H/W match current image while allowing T to grow blockwise.
ok = false;
try
    info = h5info(h5File);
    dsets = info.Datasets;
    if isempty(dsets)
        ok = false;
        return;
    end

    H0 = []; W0 = [];
    for i = 1:numel(dsets)
        sz = dsets(i).Dataspace.Size;
        if isempty(sz), continue; end
        if numel(sz) < 4
            sz(end+1:4) = 1;
        end
        H = sz(1); W = sz(2);
        if isempty(H0)
            H0 = H; W0 = W;
        else
            if H ~= H0 || W ~= W0
                if verbose
                    fprintf('H5 spatial dim mismatch: %s has [%d %d] vs [%d %d]\n', ...
                        dsets(i).Name, H, W, H0, W0);
                end
                ok = false;
                return;
            end
        end
    end

    if ~isempty(curHW)
        if H0 ~= curHW(1) || W0 ~= curHW(2)
            if verbose
                fprintf('H5 spatial dims [%d %d] do not match current image [%d %d]\n', ...
                    H0, W0, curHW(1), curHW(2));
            end
            ok = false;
            return;
        end
    end

    ok = true;
catch
    ok = false;
end
end

function upsertH5Dataset_frames(h5filename, datasetName, data, dims_mat, thisClass, absStart0)
% (inchangé, sauf qu'on écrit maintenant dans un fichier "work" passé en 1er arg)
if nargin < 6, absStart0 = []; end

H = dims_mat(1); W = dims_mat(2); k = dims_mat(3);
Tblock = size(data,4);

% -- open/create file
if exist(h5filename,'file')
    fid = H5F.open(h5filename,'H5F_ACC_RDWR','H5P_DEFAULT');
else
    fid = H5F.create(h5filename,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT');
end

exists = H5L.exists(fid, datasetName, 'H5P_DEFAULT') > 0;

t0 = 0; Told = 0;
if ~exists
    createResizableDataset(fid, datasetName, thisClass, [H W k 0]);
else
    dset_id  = H5D.open(fid, datasetName);
    space_id = H5D.get_space(dset_id);
    [~, cur_dims, ~] = H5S.get_simple_extent_dims(space_id);
    H5S.close(space_id);
    dims = double(cur_dims(:).'); dims(end+1:4)=1;
    Told  = dims(1); k_old = dims(2); W_old = dims(3); H_old = dims(4);
    H5D.close(dset_id);
    try, t0 = double(h5readatt(h5filename, datasetName, 'abs_t0')); catch, t0 = 0; end
    if H_old~=H || W_old~=W || k_old~=k
        if H5L.exists(fid, datasetName, 'H5P_DEFAULT')>0
            H5L.delete(fid, datasetName, 'H5P_DEFAULT');
        end
        createResizableDataset(fid, datasetName, thisClass, [H W k 0]);
        Told = 0;
    end
end

if ~isempty(absStart0)
    absStart = max(0, floor(absStart0));
else
    absStart = t0 + Told;
end

if absStart < t0 && (Told > 0)
    new_t0 = absStart; shift = (t0 - new_t0);
    dset_id = H5D.open(fid, datasetName);
    Tnew_tmp = Told + shift;
    H5D.set_extent(dset_id, double([Tnew_tmp  k  W  H]));
    H5D.close(dset_id);
    t0 = new_t0;
end

startRel = absStart - t0;         % 0-based
Tnew     = max(Told, startRel + Tblock);

dset_id = H5D.open(fid, datasetName);
if Tnew > Told
    H5D.set_extent(dset_id, double([Tnew  k  W  H]));
end

fspace  = H5D.get_space(dset_id);
start_f = double([startRel  0  0  0]);
count_f = double([Tblock    k  W  H]);
H5S.select_hyperslab(fspace,'H5S_SELECT_SET', start_f, [], count_f, []);

mspace = H5S.create_simple(4, count_f, []);
h5type = matlabClassToH5(thisClass, data);
H5D.write(dset_id, h5type, mspace, fspace, 'H5P_DEFAULT', data(:,:,:,1:Tblock));

try, h5writeatt(h5filename, datasetName, 'abs_t0', t0); catch, end
try, h5writeatt(h5filename, datasetName, 'abs_T',  Tnew); catch, end
try, h5writeatt(h5filename, datasetName, 'abs_range', [t0, t0+Tnew-1]); catch, end

H5S.close(mspace); H5S.close(fspace);
H5D.close(dset_id); H5F.close(fid);
end

function createResizableDataset(fid, datasetName, thisClass, dims_mat, deflateLevel)
if nargin < 5, deflateLevel = 2; end
H = dims_mat(1); W = dims_mat(2); k = max(1,dims_mat(3)); T = dims_mat(4);
maxT = H5ML.get_constant_value('H5S_UNLIMITED');

space_id = H5S.create_simple(4, double([T k W H]), double([maxT k W H]));
dcpl     = H5P.create('H5P_DATASET_CREATE');

bpp   = bytesPerClass(thisClass);
pixPerFrame = H*W*k;
targetBytes = 4*1024*1024;  % 4 MB
chunkT = max(1, floor(targetBytes/(pixPerFrame*bpp)));
if T > 0, chunkT = min(chunkT, T); end

H5P.set_chunk(dcpl, double([chunkT k W H]));
H5P.set_shuffle(dcpl);
H5P.set_deflate(dcpl, deflateLevel);

h5type  = matlabClassToH5(thisClass, []);
dset_id = H5D.create(fid, datasetName, h5type, space_id, ...
                     'H5P_DEFAULT', dcpl, 'H5P_DEFAULT');

H5D.close(dset_id);
H5P.close(dcpl);
H5S.close(space_id);
end

function h5type = matlabClassToH5(cls, data)
switch cls
    case 'uint8',   h5type = 'H5T_NATIVE_UCHAR';
    case 'int8',    h5type = 'H5T_NATIVE_CHAR';
    case 'uint16',  h5type = 'H5T_NATIVE_USHORT';
    case 'int16',   h5type = 'H5T_NATIVE_SHORT';
    case 'uint32',  h5type = 'H5T_NATIVE_UINT';
    case 'int32',   h5type = 'H5T_NATIVE_INT';
    case 'single',  h5type = 'H5T_NATIVE_FLOAT';
    case 'double',  h5type = 'H5T_NATIVE_DOUBLE';
    otherwise
        h5type = 'H5T_NATIVE_DOUBLE';
        if ~isempty(data), warning('Converting %s to double for HDF5.', cls); end
end
end

function val = to_h5_attr(val)
    if islogical(val)
        val = uint8(val);
    elseif isstring(val)
        if isscalar(val), val = char(val); else, val = cellstr(val); end
    elseif isa(val,'datetime')
        val = char(val);
    elseif iscategorical(val)
        val = cellstr(val);
    elseif iscell(val)
        if all(cellfun(@islogical,val))
            val = uint8([val{:}]);
        elseif ~all(cellfun(@ischar,val))
            val = char(jsonencode(val));
        end
    elseif istable(val) || isstruct(val)
        val = char(jsonencode(val));
    end
end
