function didSave = save(obj, option, verbose)
% didSave = save(obj, option, verbose)
%
% Sauvegarde une ROI sur disque.
%
% - Images (toutes les couches de obj.image) -> im_<id>.h5
%   * 1 DATASET PAR CANAL LOGIQUE (donné par obj.display.channel)
%   * chaque dataset = [H W k T] où k = nb de sous-canaux pour ce canal
%     (ex: 1 pour grayscale, 3 pour RGB, etc.)
%   * les sous-canaux sont déterminés via obj.findChannelID(channelName)
%
% - Dataseries (obj.data) -> data_<id>.mat
%
% Après un "full save" (tous les canaux), on purge obj.image et obj.data
% pour que l'objet ROI devienne léger et sauvable dans le .mat du projet.
%
% option :
%   "" ou []            => full save : tous les canaux logiques + data
%   "data"              => on ne touche pas au .h5, juste les data_<id>.mat
%   "GFP"               => on met à jour uniquement le dataset logique "GFP"
%   {'GFP','SegMaskRGB'}=> on met à jour uniquement ces canaux logiques
%
% verbose : booléen
%
% didSave = true si au moins une écriture a été faite.

if nargin < 2 || isempty(option)
    option = "";
end
if nargin < 3 || isempty(verbose)
    verbose = true;
end

imArray   = obj.image;        % [H W C T], avec T>=1, C>=1
dsArray   = obj.data;         % dataseries array (peut être vide)
didSave   = false;

if isempty(obj.path) || ~isfolder(obj.path)
    if verbose
        disp('ERROR: Invalid or missing path for ROI save.');
    end
    return;
end

h5File   = fullfile(obj.path, ['im_'   obj.id '.h5']);
dataFile = fullfile(obj.path, ['data_' obj.id '.mat']);

% --- Interpréter 'option'
onlyData = (ischar(option)   && strcmp(option,'data')) || ...
    (isstring(option) && strcmp(option,"data"));

if onlyData
    % on va sauver UNIQUEMENT les data (.mat), pas d'HDF5 du tout
    requestedChannels = [];   % <-- IMPORTANT: [] et pas {}
else
    % normaliser en cell array si c'est un nom de canal spécifique
    if isstring(option); option = cellstr(option); end
    if ischar(option);   option = {option};        end
    if iscell(option)
        requestedChannels = option;   % ex {'GFP','SegMaskRGB'} => save partiel
    else
        requestedChannels = {};       % => full save (tous les canaux)
    end
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


            if ~onlyData && isequal(requestedChannels, {''})
                fullSave = true;
            else
                fullSave = false;
            end


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
                idxSet = obj.findChannelID(chanNameLogical);  % ex [1] ou [3 4 5]
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

                writeH5CompressedDataset(h5File, h5Path, chanBlock, chunkDim, thisClass);


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
    dispMeta.display_frame=d.binning;
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

