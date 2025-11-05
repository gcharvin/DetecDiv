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

h5File   = fullfile(obj.path, ['im_'   obj.id '.h5']);
dataFile = fullfile(obj.path, ['data_' obj.id '.mat']);

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
max_attempts = 1;


if isempty(imArray)
    disp('Image is empty, cannot save; Load image first !')
end

while ~success && attempts < max_attempts
    % try
    imageSaved = false;
    dataSaved  = false;

    % ==================================================
    % 1) Sauvegarde HDF5 (images)
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
        H = sz(1);
        W = sz(2);
        C = sz(3);
        T = sz(4);

        % Noms logiques des canaux (ex: {'Brightfield','GFP','SegMaskRGB'})
        logicNames = getLogicalChannelNames(obj);

        % fullSave = on veut tout réécrire dans le HDF5
        % ATTENTION: seulement si on n'est PAS en mode onlyData


        fullSave = (~onlyData) && isempty(requestedChannels);


        if fullSave
            % on repars d'un .h5 propre
            if exist(h5File,'file')
                delete(h5File);
            end
        else
            % mode partiel : on ne delete pas h5File
        end

        % Boucler sur CHAQUE canal LOGIQUE
        for iChan = 1:numel(logicNames)
            chanNameLogical = logicNames{iChan};

            % Décider si on écrit ce canal logique
            if fullSave
                doThisOne = true;
            else
                doThisOne = any(strcmpi(requestedChannels, chanNameLogical));
            end
            if ~doThisOne
                continue;
            end

            % Récupérer les indices de la 3e dimension correspondant à ce canal logique
            idxSet = obj.findChannelID(chanNameLogical, 'exact');  % renvoie un vecteur
            if isempty(idxSet)
                % fallback déterministe
                idxSet = find(obj.channelid == iChan).';
                if isempty(idxSet), idxSet = iChan; end
            end

            idxSet = idxSet(:)';

            if isempty(idxSet)
                % rien à sauver pour ce canal
                continue;
            end

            k = numel(idxSet);
            chanBlock = imArray(:,:,idxSet,:);   % [H W k T]
            thisClass = class(chanBlock);

            % Prépare le chemin dataset dans le HDF5
            dsetNameSanitized = sanitizeDatasetName(chanNameLogical);
            h5Path = ['/' dsetNameSanitized];

            % Chunking
            chunkT   = min(T,10);
            chunkDim = [H W k chunkT];
            %
            % % Vérifie si dataset existe déjà (en mode partiel)
            % dsetExists = h5datasetExists(h5File, h5Path);
            %
            % if ~dsetExists
            %     % créer dataset
            %     h5create(h5File, h5Path, [H W k T], ...
            %              'Datatype', thisClass, ...
            %              'ChunkSize', chunkDim);
            % else
            %     % dataset existe -> on suppose tailles compatibles;
            %     % sinon tu pourras rajouter un check h5info ici plus tard
            % end
            %
            % % Écrire / réécrire l'ensemble du bloc
            % h5write(h5File, h5Path, chanBlock, ...
            %         [1 1 1 1], [H W k T]);

            % writeH5CompressedDataset(h5File, h5Path, chanBlock, chunkDim, thisClass);

            upsertH5Dataset_frames(h5File, h5Path, chanBlock, [H W k T], thisClass);

            % Attributs utiles
            h5writeatt(h5File, h5Path, 'roi_id',          obj.id);
            h5writeatt(h5File, h5Path, 'bbox',            getBBox(obj));
            h5writeatt(h5File, h5Path, 'frames',          getFrames(obj,T));
            h5writeatt(h5File, h5Path, 'channel_name',    chanNameLogical);
            h5writeatt(h5File, h5Path, 'channel_indices', idxSet);
            h5writeatt(h5File, h5Path, 'channelid',       obj.channelid);


            % Attributs d'affichage (intensity, rgb, indexed, etc.)
            dispMeta = buildDisplayMetaForChannel(obj, iChan, k);
            metaFields = fieldnames(dispMeta);
            for ff = 1:numel(metaFields)
                nm = metaFields{ff};
                h5writeatt(h5File, h5Path, nm, dispMeta.(nm));
            end

            imageSaved = true;

            if verbose
                fprintf('ROI #%s: HDF5 save of "%s" (%d subchan, %d frames).\n',...
                    obj.id, chanNameLogical, k, T);
            end
        end

        % Après un FULL SAVE (tous les canaux), on allège l'objet
        if fullSave
            obj.image = [];
        end
    end

    % ==================================================
    % 2) Sauvegarde DATA -> .mat
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
        save(dataFile, 'data');
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


function writeH5CompressedDataset(h5filename, datasetName, data, chunkDim, thisClass)
% h5filename : chemin du .h5
% datasetName: chemin interne du dataset, ex '/Channel0'
% data       : bloc [H W k T]
% chunkDim   : chunk [H W k chunkT] calculé par l'appelant
% thisClass  : class(data) ('uint16', etc.), calculé par l'appelant
%
% Effet : (ré)crée dataset compressé gzip + écrit data



%     Compression plus forte (fichier plus petit, plus lent à sauver) :
%
% H5P.set_deflate(dcpl, 9);      % au lieu de 4
% chunkT   = min(T, 30);         % au lieu de 10
% chunkDim = [H W k chunkT];
%
%
% Compression plus rapide (fichier un peu plus gros, écriture plus fluide) :
%
% H5P.set_deflate(dcpl, 2);      % au lieu de 4
% chunkT   = min(T, 5);          % au lieu de 10
% chunkDim = [H W k chunkT];

% -- Assurer le dossier parent
parentDir = fileparts(h5filename);
if ~isempty(parentDir) && ~exist(parentDir,'dir')
    mkdir(parentDir);
end

% -- Ouvrir ou créer le fichier .h5
if exist(h5filename, 'file')
    file_id = H5F.open(h5filename, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
else
    file_id = H5F.create(h5filename, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
end

% -- Si le dataset existe déjà, on le supprime pour le recréer proprement
if H5L.exists(file_id, datasetName, 'H5P_DEFAULT')
    H5L.delete(file_id, datasetName, 'H5P_DEFAULT');
end

% -- Dimensions du tableau tel quel (on garde l'ordre MATLAB [H W k T])
% dims = size(data);
% rank = numel(dims);
%
% % -- Créer l'espace de datas
% space_id = H5S.create_simple(rank, dims, []);  % pas de flip -> cohérent avec h5read direct

dims_mat = size(data);           % [H W k T] en MATLAB
dims_h5  = fliplr(dims_mat);     % -> [T k W H] pour HDF5 C

space_id = H5S.create_simple(numel(dims_h5), dims_h5, []);

% -- Propriétés de création du dataset : chunk + deflate
dcpl = H5P.create('H5P_DATASET_CREATE');

% on impose le chunking calculé par l'appelant
% chunkDim doit être même ordre [H W k chunkT] compatible avec dims
% if numel(chunkDim) ~= numel(dims)
%     % sécurité minimale si jamais chunkDim ne matche pas
%     chunkDimSafe = dims;
%     if rank >= 4
%         chunkDimSafe(end) = min(dims(end), 10); % fallback
%     end
%     H5P.set_chunk(dcpl, chunkDimSafe);
% else
%     H5P.set_chunk(dcpl, chunkDim);
% end

chunk_mat = chunkDim;            % [H W k chunkT]
chunk_h5  = fliplr(chunk_mat);   % -> [chunkT k W H]
H5P.set_chunk(dcpl, chunk_h5);

% compression gzip niveau 4
H5P.set_deflate(dcpl, 4);

% -- Type HDF5 à partir de thisClass
switch thisClass
    case 'uint8'
        h5type = 'H5T_NATIVE_UCHAR';
    case 'int8'
        h5type = 'H5T_NATIVE_CHAR';
    case 'uint16'
        h5type = 'H5T_NATIVE_USHORT';
    case 'int16'
        h5type = 'H5T_NATIVE_SHORT';
    case 'uint32'
        h5type = 'H5T_NATIVE_UINT';
    case 'int32'
        h5type = 'H5T_NATIVE_INT';
    case 'single'
        h5type = 'H5T_NATIVE_FLOAT';
    case 'double'
        h5type = 'H5T_NATIVE_DOUBLE';
    otherwise
        % fallback : on convertit en double
        h5type = 'H5T_NATIVE_DOUBLE';
        data   = double(data);
end

% -- Créer dataset compressé
dset_id = H5D.create(file_id, datasetName, h5type, space_id, ...
    'H5P_DEFAULT', dcpl, 'H5P_DEFAULT');

% -- Écrire le bloc complet
H5D.write(dset_id, h5type, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', data);

% -- Fermer proprement
H5D.close(dset_id);
H5P.close(dcpl);
H5S.close(space_id);
H5F.close(file_id);
end



%% ===== Helpers =====

function names = getLogicalChannelNames(obj)
% Renvoie obj.display.channel en cellstr
names = {};
if isprop(obj,'display') && ~isempty(obj.display) && isstruct(obj.display) ...
        && isfield(obj.display,'channel') && ~isempty(obj.display.channel)

    ch = obj.display.channel;
    if isstring(ch), ch = cellstr(ch); end
    if ~iscell(ch),  ch = {char(string(ch))}; end
    names = ch;
end
if isempty(names)
    names = {'channel_001'};
end
end

function bb = getBBox(obj)
bb = [];
if isprop(obj,'value') && ~isempty(obj.value) && numel(obj.value)>=4
    bb = double(obj.value(1:4));
end
end

function fr = getFrames(obj,Tfallback)
fr = 1:double(Tfallback);
end

function dispMeta = buildDisplayMetaForChannel(obj, chanLogicalIdx, k)
d = obj.display;
nCh = numel(d.channel);

ii = min(chanLogicalIdx, nCh);
ival=find(obj.channelid==ii);

dispMeta = struct();

% intensity (reste tel quel : vecteur numérique)
if isfield(d,'intensity') && ~isempty(d.intensity)
    row = d.intensity(ii,:);
    dispMeta.display_intensity = row;
end

if isfield(d,'selectedchannel') && ~isempty(d.selectedchannel)
    row = d.selectedchannel(ii);
    dispMeta.display_selectedchannel = row;
end

% rgb (reste tel quel)
if isfield(d,'rgb') && ~isempty(d.rgb)
    row = d.rgb(ii,:);
    dispMeta.display_rgb = row;
end

% rgb (reste tel quel)
if isfield(d,'displaylim') && ~isempty(d.displaylim)
    row = d.displaylim(:,ival);
    if isempty(row), row = repmat([0;1], 1, k); end     % ✅ fallback
    dispMeta.display_displaylim = row;
end


% indexed -> uint8
if isfield(d,'indexed') && ~isempty(d.indexed)
    idxVal = d.indexed;
    if numel(idxVal) >= ii
        dispMeta.display_indexed = uint8(idxVal(ii) ~= 0);
    else
        dispMeta.display_indexed = uint8(idxVal(1) ~= 0);
    end
end

% alpha (numérique scalaire)
if isfield(d,'alpha') && ~isempty(d.alpha)
    aVal = d.alpha;
    if numel(aVal) >= ii
        dispMeta.display_alpha = aVal(ii);
    else
        dispMeta.display_alpha = aVal(1);
    end
end

% contour -> uint8
if isfield(d,'contour') && ~isempty(d.contour)
    cVal = d.contour;
    if numel(cVal) >= ii
        dispMeta.display_contour = uint8(cVal(ii) ~= 0);
    else
        dispMeta.display_contour = uint8(cVal(1) ~= 0);
    end
end

% contour -> uint8
if isfield(d,'log') && ~isempty(d.log)
    cVal = d.log;
    if numel(cVal) >= ii
        dispMeta.display_log = uint8(cVal(ii) ~= 0);
    else
        dispMeta.display_log = uint8(cVal(1) ~= 0);
    end
end

% width (numérique)
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

% nb de sous-canaux k (numérique)
dispMeta.num_subchannels = k;
end

function nameOut = sanitizeDatasetName(nameIn)
s = char(string(nameIn));
s = regexprep(s,'\s+','_');
s = regexprep(s,'[^A-Za-z0-9_\-\.]','_');
if isempty(s)
    s = 'channel';
end
nameOut = s;
end


function upsertH5Dataset_frames(h5filename, datasetName, data, dims_mat, thisClass)
% data      : [H W k Tnew]
H = dims_mat(1); W = dims_mat(2); k = dims_mat(3); Tnew = dims_mat(4);

% Ouvrir / créer le fichier
if exist(h5filename,'file')
    fid = H5F.open(h5filename, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
else
    fid = H5F.create(h5filename, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
end

dset_exists = H5L.exists(fid, datasetName, 'H5P_DEFAULT') > 0;

Told = 0; need_reopen_for_write = true;

if ~dset_exists
    % 1) Création extensible, chunkée, compressée
    createResizableDataset(fid, datasetName, thisClass, [H W k Tnew]);
else
    % 2) Dataset existe -> lire dimensions courantes (ordre HDF5 = [T k W H])
    dset_id  = H5D.open(fid, datasetName);
    space_id = H5D.get_space(dset_id);
    try
        info_one = h5info(h5filename, datasetName);
        dims_h5 = double(info_one.Dataspace.Size);  % [T k W H] normalement

    catch
        [cur_dims, ~] = H5S.get_simple_extent_dims(space_id);
        dims_h5 = double(cur_dims(:).');

    end
    H5S.close(space_id);

    % Sécuriser le rang
    if numel(dims_h5) < 4, dims_h5(end+1:4) = 1; end

    Told  = dims_h5(4)
    k_old = dims_h5(3)
    W_old = dims_h5(2)
    H_old = dims_h5(1)

    if H_old ~= H || W_old ~= W || k_old ~= k
        % 2a) Dimensions incompatibles -> recréer proprement
        H5D.close(dset_id);                 % ⚠️ ici on a bien un handle ouvert
        H5L.delete(fid, datasetName, 'H5P_DEFAULT');
        createResizableDataset(fid, datasetName, thisClass, [H W k Tnew]);
    else
        % 2b) Possible append -> étendre si besoin
        if Tnew > Told
            new_dims_h5 = double([Tnew  k  W  H]);   % [T k W H]
            H5D.set_extent(dset_id, new_dims_h5);
        end
        H5D.close(dset_id);  % ✅ on ferme uniquement si on l'a ouvert
    end
end

% 3) Écriture (append ou overwrite partiel) via hyperslab
dset_id = H5D.open(fid, datasetName);          % (ré)ouvre proprement
h5type  = matlabClassToH5(thisClass, data);
fspace  = H5D.get_space(dset_id);

if Tnew > Told
    % Append: écrire seulement Told+1 : Tnew
    start = double([Told  0  0  0]);           % [T k W H]
    count = double([Tnew - Told,  k,  W,  H]);
    H5S.select_hyperslab(fspace,'H5S_SELECT_SET', start, [], count, []);
    mspace = H5S.create_simple(4, double([Tnew - Told,  k,  W,  H]), []);
    H5D.write(dset_id, h5type, mspace, fspace, 'H5P_DEFAULT', data(:,:,:,Told+1:Tnew));
    H5S.close(mspace);
else
    % Overwrite les Tnew premières frames
    start = double([0  0  0  0]);
    count = double([Tnew,  k,  W,  H]);
    H5S.select_hyperslab(fspace,'H5S_SELECT_SET', start, [], count, []);
    mspace = H5S.create_simple(4, double([Tnew,  k,  W,  H]), []);
    H5D.write(dset_id, h5type, mspace, fspace, 'H5P_DEFAULT', data(:,:,:,1:Tnew));
    H5S.close(mspace);
end

H5S.close(fspace);
H5D.close(dset_id);
H5F.close(fid);
end



function createResizableDataset(fid, datasetName, thisClass, dims_mat)
H = dims_mat(1); W = dims_mat(2); k = max(1,dims_mat(3)); T = dims_mat(4); % k>=1

maxT = H5ML.get_constant_value('H5S_UNLIMITED');
maxdims_h5 = double([maxT  k  W  H]);      % [T k W H]
curdims_h5 = double([T    k  W  H]);

space_id = H5S.create_simple(4, curdims_h5, maxdims_h5);
dcpl     = H5P.create('H5P_DATASET_CREATE');

chunkT = max(1, min(T, 10));
H5P.set_chunk(dcpl, double([chunkT  k  W  H]));
H5P.set_deflate(dcpl, 4);

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

