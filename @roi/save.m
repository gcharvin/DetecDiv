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

if isempty(imArray) && verbose==true
    disp('Image was not in memory, hence we don t save')
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

        %%% ATOMIC WRITE: on prépare un fichier de travail temporaire
        tmpUuid  = char(java.util.UUID.randomUUID);
        h5Tmp    = [h5File '.tmp.' tmpUuid];

        % Stratégie:
        % - fullSave      : nouveau fichier propre -> on écrit tout dans h5Tmp
        % - partial save  : si h5File existe, on le copie vers h5Tmp pour préserver le reste
        if fullSave
            % rien à copier — création à l'écriture par upsert
        else
            if exist(h5File,'file')
                copyfile(h5File, h5Tmp, 'f');
            end
        end

        % Boucler sur CHAQUE canal LOGIQUE
        for iChan = 1:numel(logicNames)
            chanNameLogical = logicNames{iChan};

            % Décider si on écrit ce canal logique
            doThisOne = fullSave || any(strcmpi(requestedChannels, chanNameLogical));
            if ~doThisOne, continue; end

            % Indices de la 3e dimension
            idxSet = obj.findChannelID(chanNameLogical, 'exact');  % vecteur
            if isempty(idxSet)
                idxSet = find(obj.channelid == iChan).';
                if isempty(idxSet), idxSet = iChan; end
            end
            idxSet = idxSet(:)';

            if isempty(idxSet), continue; end

            k = numel(idxSet);
            chanBlock = imArray(:,:,idxSet,:);   % [H W k T]
            thisClass = class(chanBlock);

            % Dataset path
            dsetNameSanitized = sanitizeDatasetName(chanNameLogical);
            h5Path = ['/' dsetNameSanitized];

            % Ecriture/Upsert dans le FICHIER TEMP (h5Tmp)
            upsertH5Dataset_frames(h5Tmp, h5Path, chanBlock, [H W k T], thisClass, absStart0);

            % Attributs
            h5writeatt(h5Tmp, h5Path, 'roi_id',          obj.id);
            h5writeatt(h5Tmp, h5Path, 'bbox',            getBBox(obj));
            h5writeatt(h5Tmp, h5Path, 'frames',          getFrames(obj,T));
            h5writeatt(h5Tmp, h5Path, 'channel_name',    chanNameLogical);
            h5writeatt(h5Tmp, h5Path, 'channel_indices', idxSet);
            h5writeatt(h5Tmp, h5Path, 'channelid',       obj.channelid);

            % Attributs d'affichage
            dispMeta = buildDisplayMetaForChannel(obj, iChan, k);
            names = fieldnames(dispMeta);
            for i = 1:numel(names)
                nm = names{i};
                v  = dispMeta.(nm);
                if isempty(v), continue; end
                v = to_h5_attr(v);
                try
                    h5writeatt(h5Tmp, h5Path, nm, v);
                catch
                    try
                        h5writeatt(h5Tmp, h5Path, nm, char(string(v)));
                    catch
                        % silencieux si ~verbose
                        if verbose
                            warning('roi:save:AttrWriteFailed','Attribute %s not written.', nm);
                        end
                    end
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
            if ~localVerifyH5(h5Tmp)
                if exist(h5Tmp,'file'); delete(h5Tmp); end
                error('roi:save:verifyH5','Temporary HDF5 verification failed.');
            end
            % backup ancien fichier
            if exist(h5File,'file')
                copyfile(h5File, h5BakFile, 'f'); %#ok<*NASGU>
            end
            % remplacement atomique
            if exist(h5File,'file'), delete(h5File); end
            movefile(h5Tmp, h5File, 'f');
        else
            % Rien écrit -> si un tmp vide a été créé par erreur, on le retire
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
        dataTmp  = [dataFile '.tmp.' tmpUuidD];
        save(dataTmp, 'data', '-v7.3');

        if ~localVerifyMat(dataTmp)
            if exist(dataTmp,'file'); delete(dataTmp); end
            error('roi:save:verifyMAT','Temporary MAT verification failed.');
        end

        if exist(dataFile,'file')
            copyfile(dataFile, dataBak, 'f');
        end
        if exist(dataFile,'file'), delete(dataFile); end
        movefile(dataTmp, dataFile, 'f');

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
if isfield(d,'frame') && ~isempty(d.frame)
    dispMeta.display_frame=d.frame;
end
if isfield(d,'binning') && ~isempty(d.binning)
    dispMeta.display_binning=d.binning;
end
dispMeta.num_subchannels = k;
end

function nameOut = sanitizeDatasetName(nameIn)
s = char(string(nameIn));
s = regexprep(s,'\s+','_');
s = regexprep(s,'[^A-Za-z0-9_\-\.]','_');
if isempty(s), s = 'channel'; end
nameOut = s;
end

function ok = localVerifyMat(matPath)     %%% ATOMIC WRITE helper
ok = false;
try
    vars = whos('-file', matPath);
    ok   = ~isempty(vars);
catch
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
